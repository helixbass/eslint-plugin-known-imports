###*
# @fileoverview Prevent missing React when using JSX
# @author Glen Mailer
###
'use strict'

variableUtil = require 'eslint-plugin-react/lib/util/variable'
pragmaUtil = require 'eslint-plugin-react/lib/util/pragma'
docsUrl = require 'eslint-plugin-react/lib/util/docsUrl'

# -----------------------------------------------------------------------------
# Rule Definition
# -----------------------------------------------------------------------------

getFix = ({pragma, context, allImports}) ->
  return null unless pragma is 'React'

  sourceCode = context.getSourceCode()
  firstToken = sourceCode.getFirstToken sourceCode.ast
  existingReactImport = allImports.find ({source: {value}}) -> value is 'react'
  unless existingReactImport
    return (fixer) ->
      fixer.insertTextBefore firstToken, "import React from 'react'\n"
  firstSpecifier = existingReactImport.specifiers[0]
  openingBrace = sourceCode.getTokenBefore firstSpecifier
  (fixer) -> fixer.insertTextBefore openingBrace, 'React, '

module.exports =
  meta:
    docs:
      description: 'Prevent missing React when using JSX'
      category: 'Possible Errors'
      recommended: yes
      url: docsUrl 'react-in-jsx-scope'
    schema: []
    fixable: 'code'

  create: (context) ->
    pragma = pragmaUtil.getFromContext context
    NOT_DEFINED_MESSAGE = "'{{name}}' must be in scope when using JSX"

    allImports = []

    checkIfReactIsInScope = (node) ->
      variables = variableUtil.variablesInScope context
      return if variableUtil.findVariable variables, pragma
      context.report {
        node
        message: NOT_DEFINED_MESSAGE
        data:
          name: pragma
        fix: getFix {pragma, context, allImports}
      }

    ImportDeclaration: (node) -> allImports.push node
    JSXOpeningElement: checkIfReactIsInScope
    JSXOpeningFragment: checkIfReactIsInScope
