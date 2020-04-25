const fs = require('fs')

const filename = process.argv[2]

const lines = fs.readFileSync(filename, 'utf8')

const TYPE_REGEX = /(type|interface) ([A-Z]\w+)(<[^>]+>)?\s+/g

let match
let types = []
while (match = TYPE_REGEX.exec(lines)) {
  types.push(match[2])
}

const outFilename = process.argv[3]

fs.writeFileSync(outFilename, `module.exports = [${types.map(typeName => `'${typeName}'`).join('\n')}]`, 'utf-8')
