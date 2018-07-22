const fs = require('fs')

const loadKnownImports = () => {
  const knownImportsFilename = 'known-imports.json'
  if (!fs.existsSync(knownImportsFilename)) return null

  return JSON.parse(fs.readFileSync(knownImportsFilename))
}

const getFix = ({
  knownImports,
  name,
  context,
  allImports,
  lastNonlocalImport,
}) => {
  let knownImport = knownImports && knownImports[name]
  if (!knownImport) return null

  const sourceCode = context.getSourceCode()
  if (typeof knownImport === 'string') {
    knownImport = {module: knownImport}
  }
  const importName = `${
    knownImport.name ? `${knownImport.name} as ` : ''
  }${name}`
  return fixer => {
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
        existingImport.specifiers[existingImport.specifiers.length - 1]
      return fixer.insertTextAfter(lastSpecifier, `, {${importName}}`)
    }
    const lastExistingImport = (() => {
      if (!allImports.length) return null
      if (knownImport.local) return allImports[allImports.length - 1]
      lastNonlocalImport.found =
        typeof lastNonlocalImport.found !== 'undefined'
          ? lastNonlocalImport.found
          : allImports.find(({range}) => {
              const followingChars = sourceCode.text.slice(
                range[1],
                range[1] + 2
              )
              return followingChars === `\n\n`
            })
      if (lastNonlocalImport.found) return lastNonlocalImport.found
      return allImports[allImports.length - 1]
    })()
    const insertNewImport = text => {
      if (lastExistingImport) {
        return fixer.insertTextAfter(lastExistingImport, `\n${text}`)
      }
      const firstProgramToken = sourceCode.getFirstToken(sourceCode.ast)
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

module.exports = {loadKnownImports, getFix}
