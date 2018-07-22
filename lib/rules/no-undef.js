/**
 * @fileoverview Rule to flag references to undeclared variables.
 * @author Mark Macdonald
 */

//------------------------------------------------------------------------------
// Helpers
//------------------------------------------------------------------------------

/**
 * Checks if the given node is the argument of a typeof operator.
 * @param {ASTNode} node The AST node being checked.
 * @returns {boolean} Whether or not the node is the argument of a typeof operator.
 */
function hasTypeOfOperator(node) {
  const parent = node.parent

  return parent.type === 'UnaryExpression' && parent.operator === 'typeof'
}

//------------------------------------------------------------------------------
// Rule Definition
//------------------------------------------------------------------------------

module.exports = {
  meta: {
    docs: {
      description:
        'disallow the use of undeclared variables unless mentioned in `/*global */` comments',
      category: 'Variables',
      recommended: true,
      url: 'https://eslint.org/docs/rules/no-undef',
    },

    schema: [
      {
        type: 'object',
        properties: {
          typeof: {
            type: 'boolean',
          },
        },
        additionalProperties: false,
      },
    ],
    fixable: 'code',
  },

  create(context) {
    const options = context.options[0]
    const considerTypeOf = (options && options.typeof === true) || false

    const fs = require('fs')
    let knownImports
    const knownImportsFilename = 'known-imports.json'
    if (fs.existsSync(knownImportsFilename)) {
      knownImports = JSON.parse(fs.readFileSync(knownImportsFilename))
    }
    const allImports = []

    return {
      ImportDeclaration(node) {
        allImports.push(node)
      },
      'Program:exit': function(/* node */) {
        const globalScope = context.getScope()

        let lastNonlocalImport

        globalScope.through.forEach(ref => {
          const identifier = ref.identifier

          if (!considerTypeOf && hasTypeOfOperator(identifier)) {
            return
          }

          let fix
          let knownImport = knownImports && knownImports[identifier.name]
          if (knownImport) {
            const sourceCode = context.getSourceCode()
            if (typeof knownImport === 'string') {
              knownImport = {module: knownImport}
            }
            const importName = `${
              knownImport.name ? `${knownImport.name} as ` : ''
            }${identifier.name}`
            fix = fixer => {
              const existingImport = allImports.find(
                ({source}) => source.value === knownImport.module
              )
              if (existingImport) {
                if (knownImport.default) {
                  const leadingBrace = sourceCode.getTokenBefore(
                    existingImport.specifiers[0]
                  )
                  return fixer.insertTextBefore(leadingBrace, `${importName}, `)
                }
                const namedImports = existingImport.specifiers.filter(
                  ({type}) => type === 'ImportSpecifier'
                )
                if (namedImports.length) {
                  const lastNamedImport = namedImports[namedImports.length - 1]
                  return fixer.insertTextAfter(
                    lastNamedImport,
                    `, ${importName}` // TODO: detect whether already has a trailing comma?
                  )
                }
                const lastSpecifier =
                  existingImport.specifiers[
                    existingImport.specifiers.length - 1
                  ]
                return fixer.insertTextAfter(lastSpecifier, `, {${importName}}`)
              }
              const lastExistingImport = (() => {
                if (!allImports.length) return null
                if (knownImport.local) return allImports[allImports.length - 1]
                lastNonlocalImport =
                  typeof lastNonlocalImport !== 'undefined'
                    ? lastNonlocalImport
                    : allImports.find(({range}) => {
                        const followingChars = sourceCode.text.slice(
                          range[1],
                          range[1] + 2
                        )
                        return followingChars === `\n\n`
                      })
                if (lastNonlocalImport) return lastNonlocalImport
                return allImports[allImports.length - 1]
              })()
              const insertNewImport = text => {
                if (lastExistingImport) {
                  return fixer.insertTextAfter(lastExistingImport, `\n${text}`)
                }
                const firstProgramToken = sourceCode.getFirstToken(
                  sourceCode.ast
                )
                return fixer.insertTextBefore(firstProgramToken, `${text}\n\n`)
              }
              if (knownImport.default) {
                return insertNewImport(
                  `import ${importName} from '${knownImport.module}'`
                )
              }
              return insertNewImport(
                `import {${importName}} from '${knownImport.module}'`
              )
            }
          }

          context.report({
            node: identifier,
            message: "'{{name}}' is not defined.",
            data: identifier,
            fix,
          })
        })
      },
    }
  },
}
