fs = require 'fs'
pathModule = require 'path'
picomatch = require 'picomatch'
{last, isString, mergeWith, startsWith, first, isArray} = require 'lodash'
{
  filter: ffilter
  mapValues: fmapValues
  sortBy
  takeWhile
} = require 'lodash/fp'
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

appendToCacheKey = (cache, key, value) ->
  currentValue = cache.get(key) ? []
  cache.set key, [...currentValue, value]

ensureArray = (val) ->
  return val if isArray val
  [val]

NON_ROOT_DIRECTORY_IGNORE_PATTERN_REGEX = ///
  ^
  [^/]
  [^.] *
  $
///
getIsNonRootDirectoryPattern = (ignorePattern) ->
  NON_ROOT_DIRECTORY_IGNORE_PATTERN_REGEX.test ignorePattern

INDEX_PATH_REGEX = ///
  ^ (.+) / index $
///
stripIndex = (path) ->
  match = INDEX_PATH_REGEX.exec path
  return path unless match?
  match[1]

PARENT_DIRECTORY_NAME_REGEX = ///
  (?:
    ^ | /
  )
  (
    [^/]+
  )
  $
///
getParentDirectoryName = (prefixRelativePath) ->
  match = PARENT_DIRECTORY_NAME_REGEX.exec prefixRelativePath
  return null unless match?
  match[1]

createDirectoryCache = ({
  directory
  recursive
  extensions
  allowed
  context
  context: {settings}
  ignore
}) ->
  cache = new Map()
  getIgnoreMatcher = (
    {shouldOnlyMatchNonRootDirectoryPatterns = no, basename = no} = {}
  ) ->
    unless ignore?
      return -> no
    picomatch(
      if shouldOnlyMatchNonRootDirectoryPatterns
        ensureArray ignore
          .filter getIsNonRootDirectoryPattern
          .map((ignorePattern) ->
            ignorePattern.replace /// \/ $ ///, ''
          )
      else
        ensureArray(ignore).map((ignorePattern) ->
          ignorePattern.replace(/// ^ \/ ///, '').replace /// \/ $ ///, ''
        )
    ,
      {
        contains: shouldOnlyMatchNonRootDirectoryPatterns
        cwd: directory
        basename
      }
    )
  ignoreMatcher = getIgnoreMatcher basename: yes
  ignoreMatcherNoBasename = getIgnoreMatcher()
  ignoreMatcherContains = getIgnoreMatcher(
    shouldOnlyMatchNonRootDirectoryPatterns: yes
  )
  scanDir = (dir) ->
    dir = normalizePath dir
    for file in fs.readdirSync dir
      fullPath = dir + file
      relativePathWithExtension = fullPath.replace ///^#{directory}/?///, ''
      if fs.statSync(fullPath).isDirectory()
        continue if ignoreMatcherNoBasename relativePathWithExtension
        continue if ignoreMatcherContains relativePathWithExtension
        scanDir fullPath if recursive
      else
        continue if ignoreMatcher relativePathWithExtension
        {dir: dirName, name, ext} = pathModule.parse relativePathWithExtension
        prefixRelativePath = stripIndex "#{normalizePath dirName}#{name}"
        exports = getExportMap {
          path: fullPath
          context
        }
        if name is 'index' and prefixRelativePath
          name = getParentDirectoryName(prefixRelativePath) ? name
          fullPath = fullPath.replace /// / index #{ext} $ ///, ''
        if 'filename' in allowed
          # eslint-disable-next-line coffee/no-loop-func
          do ->
            return unless ext in extensions
            if exports?
              return unless exports.namespace.has 'default'
            appendToCacheKey(
              cache
              if settings['known-imports/case-insensitive-whitelist-filename']
                name.toLowerCase()
              else
                name
            ,
              {
                prefixRelativePath
                fullPath
                type: 'filename'
              }
            )

        if 'named' in allowed
          if exports?
            for namedExport from exports.namespace.keys() when (
              namedExport isnt 'default'
            )
              appendToCacheKey cache, namedExport, {
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
  ignore
}) ->
  directoryCache = directoryCaches[directory]
  directoryCache = directoryCaches[directory] = createDirectoryCache {
    directory
    recursive
    extensions
    allowed
    context
    ignore
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
  ignore
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
    ignore
  }

  foundExact = directoryCache.get(name) ? []
  foundCaseInsensitive = (
    if settings['known-imports/case-insensitive-whitelist-filename']
      directoryCache.get(name.toLowerCase()) ? []
    else
      []
  ).filter ({type}) -> type is 'filename'
  hasAmbiguousMatches =
    foundExact.length > 1 or
    (not foundExact.length and foundCaseInsensitive.length > 1)
  return null if (
    settings['known-imports/should-autoimport-ambiguous-imports'] is no and
    hasAmbiguousMatches
  )
  filename = context.getFilename()
  getRelativePath = ({fullPath}) ->
    pathModule.relative pathModule.dirname(filename), fullPath
  getDotsPrefixLength = (match) ->
    [
      _ # eslint-disable-line coffee/no-unused-vars
      dotsPrefix
    ] = ///
      ^
      (
        (?:
          \.\./
        ) *
      )
    ///.exec getRelativePath match
    dotsPrefix.length
  found = if hasAmbiguousMatches
    ambiguousMatches = if foundExact.length
      foundExact
    else
      foundCaseInsensitive
    # closestFirst =
    #   sortBy((match) ->
    #     [
    #       if match.type is 'named' then 'A' else 'B'
    #       getDotsPrefixLength match
    #     ]
    #   ) ambiguousMatches
    closestFirst = sortBy(getDotsPrefixLength) ambiguousMatches
    shortestDotsPrefixLength = getDotsPrefixLength closestFirst[0]
    haveSameSharedParentDirectory =
      takeWhile((match) ->
        getDotsPrefixLength(match) is shortestDotsPrefixLength
      ) closestFirst
    first(
      sortBy((match) ->
        getRelativePath(match).replace(
          ///
          /
          [^/] +
          $
        ///
          ''
        ).length
      ) haveSameSharedParentDirectory
    )
  else
    [...foundExact, ...foundCaseInsensitive][0]
  return null unless found
  {prefixRelativePath, type} = found

  importPath = if settings['known-imports/relative-paths']
    relativePath = getRelativePath found
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

getRemoveImportFix = ({unusedVar, onlyRemoveKnownImports, context}) ->
  def = unusedVar.defs[0]
  return null unless def.type is 'ImportBinding'
  return null if (
    onlyRemoveKnownImports and
    not knownImportExists {name: unusedVar.name, context}
  )

  importDeclaration = def.parent
  importSpecifier = def.node

  sourceCode = context.getSourceCode()

  (fixer) ->
    removeEntireImport = ->
      nextToken = sourceCode.getTokenAfter importDeclaration
      if (precedingComments = sourceCode.getCommentsBefore nextToken).length
        nextToken = precedingComments[0]
      nextTokenIsPrecededByBlankLine =
        sourceCode.text[(nextToken.range[0] - 2)...nextToken.range[0]] is '\n\n'
      importIsAtBeginningOfFile = not sourceCode.getTokenBefore(
        importDeclaration
      )
      fixer.removeRange [
        importDeclaration.range[0]
        if nextTokenIsPrecededByBlankLine and not importIsAtBeginningOfFile
          nextToken.range[0] - 1
        else
          nextToken.range[0]
      ]

    removeThroughFollowingComma = ({commaToken}) ->
      followingToken = sourceCode.getTokenAfter commaToken
      return fixer.removeRange [
        importSpecifier.range[0]
        followingToken.range[0]
      ]

    removeThroughPrecedingComma = ({commaToken}) ->
      beforeToken = sourceCode.getTokenBefore commaToken
      return fixer.removeRange [beforeToken.range[1], importSpecifier.range[1]]

    removeBracesAndPrecedingComma = ->
      openingBrace = sourceCode.getTokenBefore importSpecifier,
        filter: ({value}) -> value is '{'
      closingBrace = sourceCode.getTokenAfter importSpecifier,
        filter: ({value}) -> value is '}'
      precedingComma = sourceCode.getTokenBefore openingBrace
      # assert(precedingComma.value === ',')
      beforeToken = sourceCode.getTokenBefore precedingComma
      return fixer.removeRange [beforeToken.range[1], closingBrace.range[1]]
      # followingComma = sourceCode.getTokenAfter(closingBrace)

    return removeEntireImport() if importDeclaration.specifiers.length is 1

    nextToken = sourceCode.getTokenAfter importSpecifier
    return removeThroughFollowingComma commaToken: nextToken if (
      nextToken.value is ','
    )

    precedingToken = sourceCode.getTokenBefore importSpecifier
    return removeThroughPrecedingComma commaToken: precedingToken if (
      precedingToken.value is ','
    )

    isOnlyNamedImport =
      importSpecifier.type is 'ImportSpecifier' and
      importDeclaration.specifiers.filter(({type}) ->
        type is 'ImportSpecifier'
      ).length is 1
    return removeBracesAndPrecedingComma() if isOnlyNamedImport
    fixer.remove importSpecifier

module.exports = {knownImportExists, getAddImportFix, getRemoveImportFix}
