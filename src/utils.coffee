fs = require 'fs'
{last, isString, mergeWith} = require 'lodash'
{filter: ffilter, mapValues: fmapValues} = require 'lodash/fp'

normalizeKnownImports = (knownImports) ->
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

loadKnownImports = ({fromConfig = {}} = {}) ->
  fromFile = normalizeKnownImports do ->
    for filename in [
      'known-imports.yaml'
      'known-imports.yml'
      'known-imports.json'
    ] when fs.existsSync(filename)
      file = fs.readFileSync filename
      return JSON.parse file if /\.json$/.test filename
      return require('js-yaml').safeLoad file
    {}
  fromConfig = normalizeKnownImports fromConfig
  mergeWith fromFile, fromConfig, mergeKnownImportsField

getAddImportFix = ({
  knownImports
  name
  context
  allImports
  lastNonlocalImport
}) ->
  knownImport = knownImports.imports[name]
  return null unless knownImport

  sourceCode = context.getSourceCode()
  importName = "#{
    if knownImport.name then "#{knownImport.name} as " else ''
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
      return last allImports if knownImport.local
      lastNonlocalImport.found ?= allImports.find ({range}) ->
        followingChars = sourceCode.text[range[1]...(range[1] + 2)]
        followingChars is '\n\n'
      return lastNonlocalImport.found if lastNonlocalImport.found?
      last allImports
    insertNewImport = (text) ->
      return fixer.insertTextAfter lastExistingImport, "\n#{text}" if (
        lastExistingImport
      )
      firstProgramToken = sourceCode.getFirstToken sourceCode.ast
      fixer.insertTextBefore firstProgramToken, "#{text}\n\n"
    insertNewImport(
      "import #{
        if knownImport.default
          importName
        else
          "{#{importName}}"
      } from '#{knownImport.module}'"
    )

module.exports = {loadKnownImports, getAddImportFix}
