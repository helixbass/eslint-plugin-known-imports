fs = require 'fs'
path = require 'path'
{last, isString, mergeWith} = require 'lodash'
{filter: ffilter, mapValues: fmapValues} = require 'lodash/fp'

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
  return

loadConfigFile = (filename) ->
  file = fs.readFileSync filename
  return JSON.parse file if /\.json$/.test filename
  return require('js-yaml').safeLoad file

knownImportsCache = null
loadKnownImports = ({settings = {}} = {}) ->
  configFilePath = settings['known-imports/config-file-path']
  fromFile =
    if (
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
        for filename in [
          'known-imports.yaml'
          'known-imports.yml'
          'known-imports.json'
        ] when fs.existsSync(filename)
          return loadConfigFile filename
        {}
      knownImportsCache = {
        configFilePath
        lastSeen: process.hrtime()
        value: loadedFromFile
      }
      loadedFromFile
  fromConfig = settings['known-imports/imports']
  fromConfig = normalizeKnownImports fromConfig
  mergeWith fromFile, fromConfig, mergeKnownImportsField

knownImportExists = ({name, context: {settings}}) ->
  !!loadKnownImports({settings}).imports[name]
  knownImports = loadKnownImports {settings}
  return null unless knownImports?
  {imports, whitelist} = knownImports
  knownImport = imports[name]
  knownImport ?= findKnownImport {name, whitelist, settings}
  knownImport ? null

isFresh = ({cache, settings}) ->
  return unless cache?
  {lastSeen} = cache
  {lifetime} = {
    lifetime: 30
    ...(settings?['known-imports/cache'] ? {})
  }
  process.hrtime(lastSeen)[0] < lifetime

createDirectoryCache = ({directory, recursive, extensions}) ->
  cache = new Map()
  scanDir = (dir) ->
    dir = normalizePath dir
    for file in fs.readdirSync dir
      fullPath = dir + file
      if fs.statSync(fullPath).isDirectory()
        scanDir fullPath if recursive
      else
        relativePath = fullPath.replace ///^#{directory}/?///, ''
        {dir: dirName, name, ext} = path.parse relativePath
        continue unless ext in extensions
        cache.set name, "#{normalizePath dirName}#{name}"
  scanDir directory
  value: cache
  lastSeen: process.hrtime()

directoryCaches = {}
updateDirectoryCache = ({directory, recursive, extensions, settings}) ->
  directoryCache = directoryCaches[directory]
  directoryCache = directoryCaches[directory] = createDirectoryCache {
    directory
    recursive
    extensions
  } unless isFresh {cache: directoryCache, settings}
  directoryCache.value

normalizePath = (path) ->
  return path unless path
  return path if /// / $ ///.test path
  "#{path}/"

findKnownImportInDirectory = ({
  directory
  allowed = ['filename']
  prefix = ''
  recursive = yes
  extensions
  name
  settings
}) ->
  directory = normalizePath directory
  prefix = normalizePath prefix
  if 'filename' in allowed
    directoryCache = updateDirectoryCache {
      directory
      recursive
      extensions
      settings
    }
    return null unless (relativePath = directoryCache.get name)
    importPath = "#{prefix}#{relativePath}"
    module: importPath
    default: yes
    local: yes

findKnownImport = ({name, whitelist, settings = {}}) ->
  return null unless whitelist?.length
  extensions = settings['known-imports/extensions'] ? ['.js', '.jsx', '.coffee']
  for directoryConfig in whitelist
    continue unless (
      (found = findKnownImportInDirectory {
        ...directoryConfig
        name
        extensions
        settings
      })
    )
    return found

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
        "\n#{if knownImport.local
          onlyExistingNonlocalImports =
            lastNonlocalImport.found is last allImports
          if onlyExistingNonlocalImports
            '\n'
          else
            ''
        else
          ''}#{text}"
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
