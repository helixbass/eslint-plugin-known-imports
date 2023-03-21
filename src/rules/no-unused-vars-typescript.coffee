{PatternVisitor} = require '@typescript-eslint/scope-manager'
{AST_NODE_TYPES, TSESLint} = require '@typescript-eslint/utils'
util = require '@typescript-eslint/eslint-plugin/dist/util'
{getRemoveImportFix} = require '../utils'

module.exports = util.createRule(
  name: 'no-unused-vars'
  meta:
    type: 'problem'
    docs:
      description: 'Disallow unused variables'
      recommended: 'warn'
      extendsBaseRule: yes
    schema: [
      oneOf: [
        enum: ['all', 'local']
      ,
        type: 'object'
        properties:
          vars:
            enum: ['all', 'local']
          varsIgnorePattern:
            type: 'string'
          args:
            enum: ['all', 'after-used', 'none']
          ignoreRestSiblings:
            type: 'boolean'
          argsIgnorePattern:
            type: 'string'
          caughtErrors:
            enum: ['all', 'none']
          caughtErrorsIgnorePattern:
            type: 'string'
          destructuredArrayIgnorePattern:
            type: 'string'
          onlyRemoveKnownImports:
            type: 'boolean'
        additionalProperties: no
      ]
    ]
    messages:
      unusedVar: "'{{varName}}' is {{action}} but never used{{additional}}."
    fixable: 'code'
  defaultOptions: [{}]
  create: (context, [firstOption]) ->
    filename = context.getFilename()
    sourceCode = context.getSourceCode()
    MODULE_DECL_CACHE = new Map()

    options = do ->
      _options =
        vars: 'all'
        args: 'after-used'
        ignoreRestSiblings: no
        caughtErrors: 'none'
        onlyRemoveKnownImports: no

      if firstOption
        if typeof firstOption is 'string'
          _options.vars = firstOption
        else
          _options.vars = firstOption.vars ? _options.vars
          _options.args = firstOption.args ? _options.args
          _options.ignoreRestSiblings =
            firstOption.ignoreRestSiblings ? _options.ignoreRestSiblings
          _options.caughtErrors =
            firstOption.caughtErrors ? _options.caughtErrors
          _options.onlyRemoveKnownImports =
            firstOption.onlyRemoveKnownImports ? _options.onlyRemoveKnownImports

          if firstOption.varsIgnorePattern
            _options.varsIgnorePattern = new RegExp(
              firstOption.varsIgnorePattern
              'u'
            )

          if firstOption.argsIgnorePattern
            _options.argsIgnorePattern = new RegExp(
              firstOption.argsIgnorePattern
              'u'
            )

          if firstOption.caughtErrorsIgnorePattern
            _options.caughtErrorsIgnorePattern = new RegExp(
              firstOption.caughtErrorsIgnorePattern
              'u'
            )

          if firstOption.destructuredArrayIgnorePattern
            _options.destructuredArrayIgnorePattern = new RegExp(
              firstOption.destructuredArrayIgnorePattern
              'u'
            )
      _options

    collectUnusedVariables = ->
      ###*
      # Determines if a variable has a sibling rest property
      # @param variable eslint-scope variable object.
      # @returns True if the variable is exported, false if not.
      ###
      hasRestSibling = (node) ->
        node.type is AST_NODE_TYPES.Property and
        node.parent?.type is AST_NODE_TYPES.ObjectPattern and
        node.parent.properties[node.parent.properties.length - 1].type is AST_NODE_TYPES.RestElement

      hasRestSpreadSibling = (variable) ->
        if options.ignoreRestSiblings
          hasRestSiblingDefinition = variable.defs.some((def) ->
            hasRestSibling(def.name.parent)
          )
          hasRestSiblingReference = variable.references.some((ref) ->
            hasRestSibling(ref.identifier.parent)
          )

          return hasRestSiblingDefinition or hasRestSiblingReference

        no

      ###*
      # Checks whether the given variable is after the last used parameter.
      # @param variable The variable to check.
      # @returns `true` if the variable is defined after the last used parameter.
      ###
      isAfterLastUsedArg = (variable) ->
        def = variable.defs[0]
        params = context.getDeclaredVariables def.node
        posteriorParams = params.slice params.indexOf(variable) + 1

        # If any used parameters occur after this parameter, do not report.
        not posteriorParams.some (v) ->
          v.references.length > 0 or v.eslintUsed

      unusedVariablesOriginal = util.collectUnusedVariables context
      unusedVariablesReturn = []
      for variable from unusedVariablesOriginal
        # explicit global variables don't have definitions.
        if variable.defs.length is 0
          unusedVariablesReturn.push variable
          continue
        def = variable.defs[0]

        # skip variables in the global scope if configured to
        continue if (
          variable.scope.type is TSESLint.Scope.ScopeType.global and
          options.vars is 'local'
        )

        refUsedInArrayPatterns = variable.references.some((ref) ->
          ref.identifier.parent?.type is AST_NODE_TYPES.ArrayPattern
        )

        continue if (
          (def.name.parent?.type is AST_NODE_TYPES.ArrayPattern or
            refUsedInArrayPatterns
          ) and
          'name' of def.name and
          options.destructuredArrayIgnorePattern?.test(def.name.name)
        )

        # skip catch variables
        if def.type is TSESLint.Scope.DefinitionType.CatchClause
          continue if options.caughtErrors is 'none'
          # skip ignored parameters
          continue if (
            'name' of def.name and
            options.caughtErrorsIgnorePattern?.test def.name.name
          )

        if def.type is TSESLint.Scope.DefinitionType.Parameter
          # if "args" option is "none", skip any parameter
          continue if options.args is 'none'
          # skip ignored parameters
          continue if (
            'name' of def.name and options.argsIgnorePattern?.test def.name.name
          )
          # if "args" option is "after-used", skip used variables
          continue if (
            options.args is 'after-used' and
            util.isFunction(def.name.parent) and
            not isAfterLastUsedArg variable
          )
        else
          # skip ignored variables
          continue if (
            'name' of def.name and options.varsIgnorePattern?.test def.name.name
          )

        continue if hasRestSpreadSibling variable

        # in case another rule has run and used the collectUnusedVariables,
        # we want to ensure our selectors that marked variables as used are respected
        continue if variable.eslintUsed

        unusedVariablesReturn.push variable

      unusedVariablesReturn

    checkModuleDeclForExportEquals = (node) ->
      cached = MODULE_DECL_CACHE.get node
      return cached if cached?

      if node.body && node.body.type is AST_NODE_TYPES.TSModuleBlock
        for statement from node.body.body
          if statement.type is AST_NODE_TYPES.TSExportAssignment
            MODULE_DECL_CACHE.set node, yes
            return yes

      MODULE_DECL_CACHE.set node, no
      no

    ambientDeclarationSelector = (parent, childDeclare) ->
      [
        # Types are ambiently exported
        "#{parent} > :matches(#{[
          AST_NODE_TYPES.TSInterfaceDeclaration
          AST_NODE_TYPES.TSTypeAliasDeclaration
        ].join ', '})"
        # Value things are ambiently exported if they are "declare"d
        "#{parent} > :matches(#{[
          AST_NODE_TYPES.ClassDeclaration
          AST_NODE_TYPES.TSDeclareFunction
          AST_NODE_TYPES.TSEnumDeclaration
          AST_NODE_TYPES.TSModuleDeclaration
          AST_NODE_TYPES.VariableDeclaration
        ].join ', '})#{if childDeclare then '[declare = true]' else ''}"
      ].join ', '
    markDeclarationChildAsUsed = (node) ->
      identifiers = []
      switch node.type
        when AST_NODE_TYPES.TSInterfaceDeclaration, AST_NODE_TYPES.TSTypeAliasDeclaration, AST_NODE_TYPES.ClassDeclaration, AST_NODE_TYPES.FunctionDeclaration, AST_NODE_TYPES.TSDeclareFunction, AST_NODE_TYPES.TSEnumDeclaration, AST_NODE_TYPES.TSModuleDeclaration
          if node.id?.type is AST_NODE_TYPES.Identifier
            identifiers.push node.id

        when AST_NODE_TYPES.VariableDeclaration
          for declaration from node.declarations
            visitPattern declaration, (pattern) ->
              identifiers.push pattern
              undefined

      scope = context.getScope()
      shouldUseUpperScope = [
        AST_NODE_TYPES.TSModuleDeclaration
        AST_NODE_TYPES.TSDeclareFunction
      ].includes node.type

      unless scope.variableScope is scope
        scope = scope.variableScope
      else if shouldUseUpperScope and scope.upper
        scope = scope.upper

      for id from identifiers
        superVar = scope.set.get id.name
        if superVar
          superVar.eslintUsed = yes

    visitPattern = (node, cb) ->
      visitor = new PatternVisitor {}, node, cb
      visitor.visit node

    return (
      # declaration file handling


        [ambientDeclarationSelector(AST_NODE_TYPES.Program, yes)]: (node) ->
          return unless util.isDefinitionFile filename
          markDeclarationChildAsUsed node
          undefined

        'TSModuleDeclaration > TSModuleDeclaration': (node) ->
          if node.id.type is AST_NODE_TYPES.Identifier
            scope = context.getScope()
            if scope.upper
              scope = scope.upper
            superVar = scope.set.get(node.id.name)
            if superVar
              superVar.eslintUsed = true
          undefined

        # children of a namespace that is a child of a declared namespace are auto-exported
        [ambientDeclarationSelector(
          'TSModuleDeclaration[declare = true] > TSModuleBlock TSModuleDeclaration > TSModuleBlock'
          no
        )]: (node) ->
          markDeclarationChildAsUsed node
          undefined

        # declared namespace handling
        [ambientDeclarationSelector(
          'TSModuleDeclaration[declare = true] > TSModuleBlock'
          no
        )]: (node) ->
          # declared ambient modules with an `export =` statement will only export that one thing
          # all other statements are not automatically exported in this case
          moduleDecl = util.nullThrows(
            node.parent?.parent
            util.NullThrowsReasons.MissingParent
          )

          return if (
            moduleDecl.id.type is AST_NODE_TYPES.Literal and
            checkModuleDeclForExportEquals moduleDecl
          )

          markDeclarationChildAsUsed node
          undefined

        # collect
        'Program:exit': (programNode) ->
          getDefinedMessageData = (unusedVar) ->
            defType = unusedVar?.defs[0]?.type
            if (
              defType is TSESLint.Scope.DefinitionType.CatchClause and
              options.caughtErrorsIgnorePattern
            )
              type = 'args'
              pattern = options.caughtErrorsIgnorePattern.toString()
            else if (
              defType is TSESLint.Scope.DefinitionType.Parameter and
              options.argsIgnorePattern
            )
              type = 'args'
              pattern = options.argsIgnorePattern.toString()
            else if (
              defType isnt TSESLint.Scope.DefinitionType.Parameter and
              options.varsIgnorePattern
            )
              type = 'vars'
              pattern = options.varsIgnorePattern.toString()

            additional = if type
              ". Allowed unused #{type} must match #{pattern}"
            else
              ''

            {
              varName: unusedVar.name
              action: 'defined'
              additional
            }

          ###*
          # Generate the warning message about the variable being
          # assigned and unused, including the ignore pattern if configured.
          # @param unusedVar eslint-scope variable object.
          # @returns The message data to be used with this unused variable.
          ###
          getAssignedMessageData = (unusedVar) ->
            def = unusedVar.defs[0]
            additional = ''

            if options.destructuredArrayIgnorePattern and def?.name.parent?.type is AST_NODE_TYPES.ArrayPattern
              additional = ". Allowed unused elements of array destructuring patterns must match #{options.destructuredArrayIgnorePattern.toString()}"
            else if options.varsIgnorePattern
              additional = ". Allowed unused vars must match #{options.varsIgnorePattern.toString()}"

            {
              varName: unusedVar.name
              action: 'assigned a value'
              additional
            }

          unusedVars = collectUnusedVariables()

          for unusedVar in unusedVars
            # Report the first declaration.
            if unusedVar.defs.length > 0
              writeReferences = unusedVar.references.filter((ref) ->
                ref.isWrite() and ref.from.variableScope is unusedVar.scope.variableScope
              )

              context.report
                node: if writeReferences.length
                  writeReferences[writeReferences.length - 1]
                    .identifier
                else
                  unusedVar.identifiers[0]
                messageId: 'unusedVar'
                data: if (
                  unusedVar.references.some((ref) ->
                    ref.isWrite()
                  )
                )
                  getAssignedMessageData unusedVar
                else
                  getDefinedMessageData unusedVar
                fix: getRemoveImportFix {
                  unusedVar
                  context
                  onlyRemoveKnownImports: options.onlyRemoveKnownImports
                }

              # If there are no regular declaration, report the first `/*globals*/` comment directive.
            else if (
              'eslintExplicitGlobalComments' of unusedVar and
              unusedVar.eslintExplicitGlobalComments
            )
              directiveComment = unusedVar.eslintExplicitGlobalComments[0]

              context.report
                node: programNode
                loc: util.getNameLocationInGlobalDirectiveComment(
                  sourceCode
                  directiveComment
                  unusedVar.name
                )
                messageId: 'unusedVar'
                data: getDefinedMessageData unusedVar
          undefined
    )
)

###

Edge cases that aren't currently handled due to laziness and them being super edgy edge cases


--- function params referenced in typeof type refs in the function declaration ---
--- NOTE - TS gets these cases wrong

function _foo(
  arg: number // arg should be unused
): typeof arg {
  return 1 as any;
}

function _bar(
  arg: number, // arg should be unused
  _arg2: typeof arg,
) {}


--- function names referenced in typeof type refs in the function declaration ---
--- NOTE - TS gets these cases right

function foo( // foo should be unused
): typeof foo {
    return 1 as any;
}

function bar( // bar should be unused
  _arg: typeof bar
) {}


--- if an interface is merged into a namespace  ---
--- NOTE - TS gets these cases wrong

namespace Test {
    interface Foo { // Foo should be unused here
        a: string;
    }
    export namespace Foo {
       export type T = 'b';
    }
}
type T = Test.Foo; // Error: Namespace 'Test' has no exported member 'Foo'.


namespace Test {
    export interface Foo {
        a: string;
    }
    namespace Foo { // Foo should be unused here
       export type T = 'b';
    }
}
type T = Test.Foo.T; // Error: Namespace 'Test' has no exported member 'Foo'.
###

###

We currently extend base `no-unused-vars` implementation because it's easier and lighter-weight.

Because of this, there are a few false-negatives which won't get caught.
We could fix these if we fork the base rule; but that's a lot of code (~650 lines) to add in.
I didn't want to do that just yet without some real-world issues, considering these are pretty rare edge-cases.

These cases are mishandled because the base rule assumes that each variable has one def, but type-value shadowing
creates a variable with two defs

--- type-only or value-only references to type/value shadowed variables ---
--- NOTE - TS gets these cases wrong

type T = 1;
const T = 2; // this T should be unused

type U = T; // this U should be unused
const U = 3;

const _V = U;


--- partially exported type/value shadowed variables ---
--- NOTE - TS gets these cases wrong

export interface Foo {}
const Foo = 1; // this Foo should be unused

interface Bar {} // this Bar should be unused
export const Bar = 1;
###
