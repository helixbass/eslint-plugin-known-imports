fs = require 'fs'
pathModule = require 'path'
{last, isString, mergeWith, startsWith} = require 'lodash'
{filter: ffilter, mapValues: fmapValues} = require 'lodash/fp'
{default: ExportMap} = require 'eslint-plugin-import/lib/ExportMap'
pkgDir = require 'pkg-dir'

normalizeKnownImports = (knownImports = {}) ->
  return knownImports if knownImports.imports
  imports: knownImports

# allKnownImportsKeys = ['imports']

normalizeKnownImportValue = (value) ->
  return module: value if isString value
  value

mergeKnownImportsField = (objValue, srcValue, key) ->
  normalizeKnownImportValues = fmapValues normalizeKnownImportValue
  return {
    ...normalizeKnownImportValues(objValue ? {})
    ...normalizeKnownImportValues(srcValue ? {})
  } if key is 'imports'

loadConfigFile = (filename) ->
  file = fs.readFileSync filename
  return JSON.parse file if /\.json$/.test filename
  return require('js-yaml').safeLoad file

configFileBasenames = [
  'known-imports.yaml'
  'known-imports.yml'
  'known-imports.json'
  '.known-imports.yaml'
  '.known-imports.yml'
  '.known-imports.json'
]

knownImportsCache = null
loadKnownImports = ({settings = {}} = {}) ->
  configFilePath = settings['known-imports/config-file-path']
  fromFile = if (
    knownImportsCache?.configFilePath is configFilePath and
    isFresh {
      cache: knownImportsCache
      settings
    }
  )
    knownImportsCache.value
  else
    loadedFromFile = normalizeKnownImports do ->
      if configFilePath
        throw new Error(
          "Couldn't load known imports file '#{configFilePath}'"
        ) unless fs.existsSync configFilePath
        return loadConfigFile configFilePath
      for filename in configFileBasenames when fs.existsSync filename
        return loadConfigFile filename
      projectRootDir = pkgDir.sync()
      if projectRootDir?
        for filename in configFileBasenames when (
          fs.existsSync pathModule.join projectRootDir, filename
        )
          return loadConfigFile pathModule.join projectRootDir, filename
      {}
    knownImportsCache = {
      configFilePath
      lastSeen: process.hrtime()
      value: loadedFromFile
    }
    loadedFromFile
  fromConfig = settings['known-imports/imports']
  fromConfig = normalizeKnownImports fromConfig
  mergeWith {}, fromFile, fromConfig, mergeKnownImportsField

defaultBlacklist = ['index']

addDefaultBlacklist = (knownImports) ->
  return knownImports unless knownImports?
  knownImports.blacklist ?= []
  knownImports.blacklist = [...knownImports.blacklist, ...defaultBlacklist]
  knownImports

knownImportExists = ({name, context: {settings}, context}) ->
  knownImports = addDefaultBlacklist loadKnownImports {settings}
  return null unless knownImports?
  {imports, whitelist, blacklist} = knownImports
  return null if blacklist?.length and name in blacklist
  knownImport = imports[name]
  knownImport ?= findKnownImport {name, whitelist, settings, context}
  knownImport ? null

isFresh = ({cache, settings}) ->
  return unless cache?
  {lastSeen} = cache
  {lifetime} = {
    lifetime: 30
    ...(settings?['known-imports/cache'] ? {})
  }
  process.hrtime(lastSeen)[0] < lifetime

getExportMap = ({path, context: {settings, parserPath, parserOptions}}) ->
  ExportMap.for {
    path
    settings
    parserPath
    parserOptions
  }

createDirectoryCache = ({directory, recursive, extensions, allowed, context}) ->
  cache = new Map()
  scanDir = (dir) ->
    dir = normalizePath dir
    for file in fs.readdirSync dir
      fullPath = dir + file
      if fs.statSync(fullPath).isDirectory()
        scanDir fullPath if recursive
      else
        relativePathWithExtension = fullPath.replace ///^#{directory}/?///, ''
        {dir: dirName, name, ext} = pathModule.parse relativePathWithExtension
        prefixRelativePath = "#{normalizePath dirName}#{name}"
        if 'filename' in allowed
          continue unless ext in extensions
          cache.set name, {
            prefixRelativePath
            fullPath
            type: 'filename'
          }
        if 'named' in allowed
          exports = getExportMap {
            path: fullPath
            context
          }
          if exports?
            for namedExport from exports.namespace.keys() when (
              namedExport isnt 'default'
            )
              cache.set namedExport, {
                prefixRelativePath
                fullPath
                type: 'named'
              }
  scanDir directory
  value: cache
  lastSeen: process.hrtime()

directoryCaches = {}
updateDirectoryCache = ({
  directory
  recursive
  extensions
  settings
  allowed
  context
}) ->
  directoryCache = directoryCaches[directory]
  directoryCache = directoryCaches[directory] = createDirectoryCache {
    directory
    recursive
    extensions
    allowed
    context
  } unless isFresh {cache: directoryCache, settings}
  directoryCache.value

normalizePath = (path) ->
  return path unless path
  return path if /// / $ ///.test path
  "#{path}/"

getExtensions = ({settings}) ->
  settings['known-imports/extensions'] ? [
    '.js'
    '.jsx'
    '.coffee'
    '.ts'
    '.tsx'
  ]

ensureLeadingDot = (path) ->
  return "./#{path}" if path.length and not startsWith path, '.'
  path

findKnownImportInDirectory = ({
  directory
  allowed = ['filename']
  prefix = ''
  recursive = yes
  extensions
  name
  settings
  context
  projectRootDir
}) ->
  directory = pathModule.join projectRootDir, directory if projectRootDir?
  directory = normalizePath directory
  prefix = normalizePath prefix
  directoryCache = updateDirectoryCache {
    directory
    recursive
    extensions
    settings
    allowed
    context
  }
  return null unless found = directoryCache.get name
  {prefixRelativePath, fullPath, type} = found
  filename = context.getFilename()
  importPath = if settings['known-imports/relative-paths']
    relativePath = pathModule.relative pathModule.dirname(filename), fullPath
    extension = pathModule.extname relativePath
    ensureLeadingDot(
      if extension in extensions
        pathModule.join(
          pathModule.dirname relativePath
          pathModule.basename relativePath, extension
        )
      else
        relativePath
    )
  else
    "#{prefix}#{prefixRelativePath}"
  module: importPath
  default: type is 'filename'
  local: yes

findKnownImport = ({name, whitelist, settings = {}, context}) ->
  return null unless whitelist?.length
  extensions = getExtensions {settings}
  projectRootDir = pkgDir.sync()
  for directoryConfig in whitelist
    continue unless (
      found = findKnownImportInDirectory {
        ...directoryConfig
        name
        extensions
        settings
        context
        projectRootDir
      }
    )
    return found

shouldIncludeBlankLineBeforeLocalImports = ({context: {settings = {}}}) ->
  !!settings['known-imports/blank-line-before-local-imports']

getAddImportFix = ({name, context, allImports, lastNonlocalImport}) ->
  knownImport = knownImportExists {name, context}
  return null unless knownImport?

  sourceCode = context.getSourceCode()
  importName = "#{
    if knownImport.namespace
      '* as '
    else if knownImport.name
      "#{knownImport.name} as "
    else
      ''
  }#{name}"
  (fixer) ->
    prependDefaultImport = ->
      # TODO: check that there's not already a default import?
      leadingBrace = sourceCode.getTokenBefore existingImport.specifiers[0]
      fixer.insertTextBefore leadingBrace, "#{importName}, "

    appendToExistingNamedImports = ->
      fixer.insertTextAfter(
        last namedImports
        ", #{importName}" # TODO: detect whether already has a trailing comma?
      )

    appendOnlyNamedImport = ->
      fixer.insertTextAfter lastSpecifier, ", {#{importName}}"

    existingImport = allImports.find ({source}) ->
      source.value is knownImport.module
    if existingImport
      return prependDefaultImport() if knownImport.default
      namedImports = ffilter(type: 'ImportSpecifier') existingImport.specifiers
      return appendToExistingNamedImports() if namedImports.length
      lastSpecifier = last existingImport.specifiers
      return appendOnlyNamedImport()
    lastExistingImport = do ->
      return null unless allImports.length
      lastNonlocalImport.found ?= allImports.find ({range}) ->
        followingChars = sourceCode.text[range[1]...(range[1] + 2)]
        followingChars is '\n\n'
      return last allImports if knownImport.local
      return lastNonlocalImport.found if lastNonlocalImport.found?
      last allImports
    insertNewImport = (text) ->
      return fixer.insertTextAfter(
        lastExistingImport
        "\n#{
          if (
            knownImport.local and
            shouldIncludeBlankLineBeforeLocalImports {context}
          )
            onlyExistingNonlocalImports =
              lastNonlocalImport.found is last allImports
            if onlyExistingNonlocalImports
              '\n'
            else
              ''
          else
            ''
        }#{text}"
      ) if lastExistingImport
      firstProgramToken = sourceCode.getFirstToken sourceCode.ast,
        # skip directives
        filter: ({type}) -> type isnt 'String'
      fixer.insertTextBefore firstProgramToken, "#{text}\n\n"
    insertNewImport(
      "import #{
        if knownImport.default or knownImport.namespace
          importName
        else
          "{#{importName}}"
      } from '#{knownImport.module}'"
    )

module.exports = {knownImportExists, getAddImportFix}
