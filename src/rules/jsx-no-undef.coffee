###*
# @fileoverview Disallow undeclared variables in JSX
# @author Yannick Croissant
###

'use strict'

{getAddImportFix: getFix} = require '../utils'

###*
# Checks if a node name match the JSX tag convention.
# @param {String} name - Name of the node to check.
# @returns {boolean} Whether or not the node name match the JSX tag convention.
###
tagConvention = /^[a-z]|-/
isTagName = (name) -> tagConvention.test name

# ------------------------------------------------------------------------------
# Rule Definition
# ------------------------------------------------------------------------------

module.exports =
  meta:
    docs:
      description: 'Disallow undeclared variables in JSX'
      category: 'Possible Errors'
      recommended: yes
    schema: [
      type: 'object'
      properties:
        allowGlobals:
          type: 'boolean'
        # knownImports:
        #   type: 'object'
        # knownImportsFile:
        #   type: 'string'
      additionalProperties: no
    ]
    fixable: 'code'

  create: (context) ->
    config = context.options[0] or {}
    allowGlobals = config.allowGlobals or no

    ###*
    # Compare an identifier with the variables declared in the scope
    # @param {ASTNode} node - Identifier or JSXIdentifier node
    # @returns {void}
    ###
    checkIdentifierInJSX = (node) ->
      scope = context.getScope()
      sourceCode = context.getSourceCode()
      {sourceType} = sourceCode.ast
      {variables} = scope
      # Ignore 'this' keyword (also maked as JSXIdentifier when used in JSX)
      return if node.name is 'this'

      scopeType =
        if not allowGlobals and sourceType is 'module'
          'module'
        else
          'global'

      while scope.type isnt scopeType
        scope = scope.upper
        variables = [scope.variables..., variables...]
      if scope.childScopes.length
        variables = [scope.childScopes[0].variables..., variables...]
        # Temporary fix for babel-eslint
        variables = [
          scope.childScopes[0].childScopes[0].variables...
          variables...
        ] if scope.childScopes[0].childScopes.length

      for {name} in variables
        return if name is node.name

      context.report {
        node
        message: "'#{node.name}' is not defined."
        fix: getFix {
          name: node.name
          context
          allImports
          lastNonlocalImport
        }
      }

    allImports = []
    lastNonlocalImport = {}

    ImportDeclaration: (node) -> allImports.push node
    JSXOpeningElement: ({name}) ->
      switch name.type
        when 'JSXIdentifier'
          node = name
          return if isTagName node.name
        when 'JSXMemberExpression'
          node = name.object
          node = node.object while node and node.type isnt 'JSXIdentifier'
        when 'JSXNamespacedName'
          node = name.namespace

      checkIdentifierInJSX node
