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
  'Uppercase'
  'Lowercase'
  'Capitalize'
  'Uncapitalize'
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

BUILTIN_DOM_TYPES = require '../typenames/dom'
BUILTIN_DOM_ITERABLE_TYPES = require '../typenames/dom-iterable'
BUILTIN_SCRIPTHOST_TYPES = require '../typenames/scripthost'

BUILTIN_ES2015_COLLECTION_TYPES = require '../typenames/es2015-collection'
BUILTIN_ES2015_PROMISE_TYPES = ['PromiseConstructor']
BUILTIN_ES2015_GENERATOR_TYPES = require '../typenames/es2015-generator'
BUILTIN_ES2015_ITERABLE_TYPES = require '../typenames/es2015-iterable'
BUILTIN_ES2015_PROXY_TYPES = require '../typenames/es2015-proxy'
BUILTIN_ES2015_TYPES = [
  ...BUILTIN_ES5_TYPES
  ...BUILTIN_ES2015_COLLECTION_TYPES
  ...BUILTIN_ES2015_PROMISE_TYPES
  ...BUILTIN_ES2015_GENERATOR_TYPES
  ...BUILTIN_ES2015_ITERABLE_TYPES
  ...BUILTIN_ES2015_PROXY_TYPES
]

BUILTIN_ES2016_TYPES = BUILTIN_ES2015_TYPES

BUILTIN_ES2017_SHARED_MEMORY_TYPES = require '../typenames/es2017-shared-memory'
BUILTIN_ES2017_TYPES = [
  ...BUILTIN_ES2016_TYPES
  ...BUILTIN_ES2017_SHARED_MEMORY_TYPES
]

BUILTIN_ES2018_ASYNC_GENERATOR_TYPES = require(
  '../typenames/es2018-async-generator'
)
BUILTIN_ES2018_ASYNC_ITERABLE_TYPES = require(
  '../typenames/es2018-async-iterable'
)
BUILTIN_ES2018_TYPES = [
  ...BUILTIN_ES2017_TYPES
  ...BUILTIN_ES2018_ASYNC_GENERATOR_TYPES
  ...BUILTIN_ES2018_ASYNC_ITERABLE_TYPES
]

BUILTIN_ES2019_TYPES = BUILTIN_ES2018_TYPES

BUILTIN_ES2020_SYMBOL_WELLKNOWN_TYPES = ['SymbolConstructor']
BUILTIN_ES2020_TYPES = [
  ...BUILTIN_ES2019_TYPES
  ...BUILTIN_ES2020_SYMBOL_WELLKNOWN_TYPES
]

BUILTIN_ESNEXT_BIGINT_TYPES = require '../typenames/esnext-bigint'
BUILTIN_ESNEXT_TYPES = [...BUILTIN_ES2020_TYPES, ...BUILTIN_ESNEXT_BIGINT_TYPES]

ALL_BUILTIN_TYPES = [
  ...BUILTIN_UTILITY_TYPES
  ...BUILTIN_DOM_TYPES
  ...BUILTIN_DOM_ITERABLE_TYPES
  ...BUILTIN_SCRIPTHOST_TYPES
  ...BUILTIN_ESNEXT_TYPES
]
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
      return if node.name is 'const'
      if node.parent?.type is 'TSTypeReference' and node is node.parent.typeName
        allIdentifiersWhichAreTypeReferences[node.name] = node
      else
        allIdentifiersBesidesTypeReferences[node.name] = node
    'Program:exit': (### node ###) ->
      for identifierName, identifier of (
        allIdentifiersWhichAreTypeReferences
      ) when (
        not allIdentifiersBesidesTypeReferences[identifierName] and
          not ALL_BUILTIN_TYPES_LOOKUP[identifierName] and
          identifierName not in (context.settings['known-imports/global-types'] ? [])
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
