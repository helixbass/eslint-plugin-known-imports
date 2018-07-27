/**
 * @fileoverview Prevent missing React when using JSX
 * @author Glen Mailer
 */
'use strict'

const variableUtil = require('eslint-plugin-react/lib/util/variable')
const pragmaUtil = require('eslint-plugin-react/lib/util/pragma')
const docsUrl = require('eslint-plugin-react/lib/util/docsUrl')

// -----------------------------------------------------------------------------
// Rule Definition
// -----------------------------------------------------------------------------

const getFix = ({pragma, context, allImports}) => {
  if (pragma !== 'React') return null

  const sourceCode = context.getSourceCode()
  const firstToken = sourceCode.getFirstToken(sourceCode.ast)
  const existingReactImport = allImports.find(
    ({source: {value}}) => value === 'react'
  )
  if (!existingReactImport) {
    return fixer =>
      fixer.insertTextBefore(firstToken, `import React from 'react'\n`)
  }
  const firstSpecifier = existingReactImport.specifiers[0]
  const openingBrace = sourceCode.getTokenBefore(firstSpecifier)
  return fixer => fixer.insertTextBefore(openingBrace, 'React, ')
}

module.exports = {
  meta: {
    docs: {
      description: 'Prevent missing React when using JSX',
      category: 'Possible Errors',
      recommended: true,
      url: docsUrl('react-in-jsx-scope'),
    },
    schema: [],
    fixable: 'code',
  },

  create: function(context) {
    const pragma = pragmaUtil.getFromContext(context)
    const NOT_DEFINED_MESSAGE = "'{{name}}' must be in scope when using JSX"

    const allImports = []

    function checkIfReactIsInScope(node) {
      const variables = variableUtil.variablesInScope(context)
      if (variableUtil.findVariable(variables, pragma)) {
        return
      }
      context.report({
        node: node,
        message: NOT_DEFINED_MESSAGE,
        data: {
          name: pragma,
        },
        fix: getFix({pragma, context, allImports}),
      })
    }

    return {
      ImportDeclaration(node) {
        allImports.push(node)
      },
      JSXOpeningElement: checkIfReactIsInScope,
      JSXOpeningFragment: checkIfReactIsInScope,
    }
  },
}
