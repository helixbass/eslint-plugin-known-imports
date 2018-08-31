###*
# @fileoverview Rule to flag references to undeclared variables.
# @author Mark Macdonald
###

{loadKnownImports, getAddImportFix: getFix} = require '../utils'

#------------------------------------------------------------------------------
# Helpers
#------------------------------------------------------------------------------

###*
# Checks if the given node is the argument of a typeof operator.
# @param {ASTNode} node The AST node being checked.
# @returns {boolean} Whether or not the node is the argument of a typeof operator.
###
hasTypeOfOperator = ({parent}) ->
  parent.type is 'UnaryExpression' and parent.operator is 'typeof'

#------------------------------------------------------------------------------
# Rule Definition
#------------------------------------------------------------------------------

module.exports =
  meta:
    docs:
      description:
        'disallow the use of undeclared variables unless mentioned in `/*global */` comments'
      category: 'Variables'
      recommended: yes
      url: 'https://eslint.org/docs/rules/no-undef'

    schema: [
      type: 'object'
      properties:
        typeof:
          type: 'boolean'
        knownImports:
          type: 'object'
        knownImportsFile:
          type: 'string'
      additionalProperties: no
    ]
    fixable: 'code'

  create: (context) ->
    options = context.options[0] ? {}
    considerTypeOf = options.typeof is yes

    knownImports = null
    lazyLoadKnownImports = ->
      knownImports ?= loadKnownImports(
        fromConfig: options.knownImports
        configFilePath: options.knownImportsFile
      )
    allImports = []
    lastNonlocalImport = {}

    ImportDeclaration: (node) -> allImports.push node
    'Program:exit': (### node ###) ->
      globalScope = context.getScope()

      globalScope.through.forEach ({identifier}) ->
        return if not considerTypeOf and hasTypeOfOperator identifier

        context.report
          node: identifier
          message: "'{{name}}' is not defined."
          data: identifier
          fix: getFix {
            knownImports: lazyLoadKnownImports()
            name: identifier.name
            context
            allImports
            lastNonlocalImport
          }
