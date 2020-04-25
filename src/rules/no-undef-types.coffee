###*
# @fileoverview Rule to flag references to undeclared types
# @author Julian Rosse
###

{getAddImportFix: getFix} = require '../utils'

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Rule Definition
# ------------------------------------------------------------------------------

BUILTIN_UTILITY_TYPES = [
  'Partial'
  'Readonly'
  'Record'
  'Pick'
  'Omit'
  'Exclude'
  'Extract'
  'NonNullable'
  'Parameters'
  'ConstructorParameters'
  'ReturnType'
  'InstanceType'
  'Required'
  'ThisParameterType'
  'OmitThisParameter'
  'ThisType'
]

BUILTIN_ES5_TYPES = [
  'Symbol'
  'PropertyKey'
  'PropertyDescriptor'
  'PropertyDescriptorMap'
  'Object'
  'ObjectConstructor'
  'Function'
  'FunctionConstructor'
  'CallableFunction'
  'NewableFunction'
  'IArguments'
  'String'
  'StringConstructor'
  'Boolean'
  'BooleanConstructor'
  'Number'
  'NumberConstructor'
  'TemplateStringsArray'
  'ReadonlyArray'
  'ImportMeta'
  'Math'
  'Date'
  'DateConstructor'
  'RegExpMatchArray'
  'RegExpExecArray'
  'Array'
  'RegExp'
  'RegExpConstructor'
  'Error'
  'ErrorConstructor'
  'EvalError'
  'EvalErrorConstructor'
  'RangeError'
  'RangeErrorConstructor'
  'ReferenceError'
  'ReferenceErrorConstructor'
  'SyntaxError'
  'SyntaxErrorConstructor'
  'TypeError'
  'TypeErrorConstructor'
  'URIError'
  'URIErrorConstructor'
  'JSON'
  'ConcatArray'
  'ArrayConstructor'
  'TypedPropertyDescriptor'
  'ClassDecorator'
  'PropertyDecorator'
  'MethodDecorator'
  'ParameterDecorator'
  'PromiseConstructorLike'
  'PromiseLike'
  'Promise'
  'ArrayLike'
  'ArrayBuffer'
  'ArrayBufferTypes'
  'ArrayBufferLike'
  'ArrayBufferConstructor'
  'ArrayBufferView'
  'DataView'
  'DataViewConstructor'
  'Int8Array'
  'Int8ArrayConstructor'
  'Uint8Array'
  'Uint8ArrayConstructor'
  'Uint8ClampedArray'
  'Uint8ClampedArrayConstructor'
  'Int16Array'
  'Int16ArrayConstructor'
  'Uint16Array'
  'Uint16ArrayConstructor'
  'Int32Array'
  'Int32ArrayConstructor'
  'Uint32Array'
  'Uint32ArrayConstructor'
  'Float32Array'
  'Float32ArrayConstructor'
  'Float64Array'
  'Float64ArrayConstructor'
]

ALL_BUILTIN_TYPES = [...BUILTIN_UTILITY_TYPES, ...BUILTIN_ES5_TYPES]
ALL_BUILTIN_TYPES_LOOKUP = do ->
  ret = {}
  (ret[builtinType] = yes) for builtinType in ALL_BUILTIN_TYPES
  ret

module.exports =
  meta:
    docs:
      description:
        'disallow the use of undeclared types unless mentioned in `/*global */` comments'
      # category: 'Variables'
      # recommended: yes
      # url: 'https://eslint.org/docs/rules/no-undef'

    schema: []
    fixable: 'code'

  create: (context) ->
    allImports = []
    lastNonlocalImport = {}
    allIdentifiersBesidesTypeReferences = {}
    allIdentifiersWhichAreTypeReferences = {}

    ImportDeclaration: (node) -> allImports.push node
    Identifier: (node) ->
      if node.parent?.type is 'TSTypeReference' and node is node.parent.typeName
        allIdentifiersWhichAreTypeReferences[node.name] = node
      else
        allIdentifiersBesidesTypeReferences[node.name] = node
    'Program:exit': (### node ###) ->
      for identifierName, identifier of (
        allIdentifiersWhichAreTypeReferences
      ) when (
        not allIdentifiersBesidesTypeReferences[identifierName] and
          not ALL_BUILTIN_TYPES_LOOKUP[identifierName]
      )
        context.report
          node: identifier
          message: "'{{name}}' is not defined."
          data: identifier
          fix: getFix {
            name: identifier.name
            context
            allImports
            lastNonlocalImport
          }
