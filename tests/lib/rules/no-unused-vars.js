/**
 * @fileoverview Tests for no-unused-vars rule.
 * @author Ilya Volodin
 */

'use strict'

//------------------------------------------------------------------------------
// Requirements
//------------------------------------------------------------------------------

const eslint = require('eslint')
const rule = require('../../../lib/rules/no-unused-vars')
const {RuleTester} = eslint

//------------------------------------------------------------------------------
// Tests
//------------------------------------------------------------------------------

const parserOptions = {
  sourceType: 'module',
}

const ruleTester = new RuleTester({parserOptions})

/**
 * Returns an expected error for defined-but-not-used variables.
 * @param {string} varName The name of the variable
 * @param {string} [type] The node type (defaults to "Identifier")
 * @returns {Object} An expected error object
 */
function definedError(varName, type) {
  return {
    message: `'${varName}' is defined but never used.`,
    type: type || 'Identifier',
  }
}

ruleTester.run('no-unused-vars', rule, {
  valid: [{code: 'export var foo = 123;'}],
  invalid: [
    {
      code: `\
        import x from "y";
        export const a = 1;`,
      output: `\
        export const a = 1;`,
      errors: [definedError('x')],
      options: [{onlyRemoveKnownImports: false}],
    },
    {
      code: `\
        import {x} from "y";
        export const a = 1;`,
      output: `\
        export const a = 1;`,
      errors: [definedError('x')],
      options: [{onlyRemoveKnownImports: false}],
    },
    {
      code: `\
        import {x, y} from "y";
        export {y};`,
      output: `\
        import {y} from "y";
        export {y};`,
      errors: [definedError('x')],
      options: [{onlyRemoveKnownImports: false}],
    },
    {
      code: `\
        import {w, x, y} from "y";
        export {w, y};`,
      output: `\
        import {w, y} from "y";
        export {w, y};`,
      errors: [definedError('x')],
      options: [{onlyRemoveKnownImports: false}],
    },
    {
      code: `\
        import {w, x} from "y";
        export {w};`,
      output: `\
        import {w} from "y";
        export {w};`,
      errors: [definedError('x')],
      options: [{onlyRemoveKnownImports: false}],
    },
    {
      code: `\
        import x, {w} from "y";
        export {w};`,
      output: `\
        import {w} from "y";
        export {w};`,
      errors: [definedError('x')],
      options: [{onlyRemoveKnownImports: false}],
    },
    {
      code: `\
        import w, {x} from "y";
        export {w};`,
      output: `\
        import w from "y";
        export {w};`,
      errors: [definedError('x')],
      options: [{onlyRemoveKnownImports: false}],
    },
    {
      code: `\
        import w, {y as x} from "y";
        export {w};`,
      output: `\
        import w from "y";
        export {w};`,
      errors: [definedError('x')],
      options: [{onlyRemoveKnownImports: false}],
    },
    {
      code: `\
        import {w, y as x, z} from "y";
        export {w, z};`,
      output: `\
        import {w, z} from "y";
        export {w, z};`,
      errors: [definedError('x')],
      options: [{onlyRemoveKnownImports: false}],
    },
    {
      code: `\
        import {y as x, z} from "y";
        export {z};`,
      output: `\
        import {z} from "y";
        export {z};`,
      errors: [definedError('x')],
      options: [{onlyRemoveKnownImports: false}],
    },
    {
      code: `\
        import {y as x, z} from "y";
        export {z};`,
      output: `\
        import {z} from "y";
        export {z};`,
      errors: [definedError('x')],
      options: [{onlyRemoveKnownImports: false}],
    },
    {
      code: `\
        import {w, y as x} from "y";
        export {w};`,
      output: `\
        import {w} from "y";
        export {w};`,
      errors: [definedError('x')],
      options: [{onlyRemoveKnownImports: false}],
    },
    {
      code: `\
        import View from "react-native";
        export const a = 1;`,
      output: `\
        export const a = 1;`,
      errors: [definedError('View')],
      options: [{onlyRemoveKnownImports: true}],
    },
    {
      code: `\
        import x from "y";
        export const a = 1;`,
      output: `\
        import x from "y";
        export const a = 1;`,
      errors: [definedError('x')],
      options: [{onlyRemoveKnownImports: true}],
    },
    {
      code: `\
        import {map as fmap} from "lodash/fp";
        export const a = 1;`,
      output: `\
        export const a = 1;`,
      errors: [definedError('fmap')],
      options: [{onlyRemoveKnownImports: true}],
    },
  ],
})
