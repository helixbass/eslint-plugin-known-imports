fs = require 'fs'

loadKnownImports = ->
  knownImportsFilename = 'known-imports.json'
  return null unless fs.existsSync knownImportsFilename

  JSON.parse fs.readFileSync knownImportsFilename

getFix = ({knownImports, name, context, allImports, lastNonlocalImport}) ->
  knownImport = knownImports?[name]
  unless knownImport then return null

  sourceCode = context.getSourceCode()
  if typeof knownImport is 'string' then knownImport = module: knownImport
  importName = "#{
    if knownImport.name then "#{knownImport.name} as " else ''
  }#{name}"
  (fixer) ->
    existingImport = allImports.find ({source}) ->
      source.value is knownImport.module
    if existingImport
      if knownImport.default
        leadingBrace = sourceCode.getTokenBefore existingImport.specifiers[0]
        return fixer.insertTextBefore leadingBrace, "#{importName}, "
      namedImports = existingImport.specifiers.filter ({type}) ->
        type is 'ImportSpecifier'
      if namedImports.length
        lastNamedImport = namedImports[namedImports.length - 1]
        return fixer.insertTextAfter(
          lastNamedImport
          ", #{importName}" # TODO: detect whether already has a trailing comma?
        )
      lastSpecifier =
        existingImport.specifiers[existingImport.specifiers.length - 1]
      return fixer.insertTextAfter lastSpecifier, ", {#{importName}}"
    lastExistingImport = do ->
      return null unless allImports.length
      return allImports[allImports.length - 1] if knownImport.local
      lastNonlocalImport.found ?= allImports.find ({range}) ->
        followingChars = sourceCode.text.slice range[1], range[1] + 2
        followingChars is '\n\n'
      return lastNonlocalImport.found if lastNonlocalImport.found?
      allImports[allImports.length - 1]
    insertNewImport = (text) ->
      return fixer.insertTextAfter lastExistingImport, "\n#{text}" if (
        lastExistingImport
      )
      firstProgramToken = sourceCode.getFirstToken sourceCode.ast
      fixer.insertTextBefore firstProgramToken, "#{text}\n\n"
    return insertNewImport(
      "import #{importName} from '#{knownImport.module}'"
    ) if knownImport.default
    insertNewImport "import {#{importName}} from '#{knownImport.module}'"

module.exports = {loadKnownImports, getFix}
