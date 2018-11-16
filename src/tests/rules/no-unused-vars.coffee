###*
# @fileoverview Tests for no-unused-vars rule.
# @author Ilya Volodin
###

'use strict'

#------------------------------------------------------------------------------
# Requirements
#------------------------------------------------------------------------------

eslint = require 'eslint'
rule = require '../../rules/no-unused-vars'
{RuleTester} = eslint

#------------------------------------------------------------------------------
# Tests
#------------------------------------------------------------------------------

parserOptions = sourceType: 'module'

ruleTester = new RuleTester {parserOptions}

###*
# Returns an expected error for defined-but-not-used variables.
# @param {string} varName The name of the variable
# @param {string} [type] The node type (defaults to "Identifier")
# @returns {Object} An expected error object
###
definedError = (varName, type) ->
  message: "'#{varName}' is defined but never used."
  type: type or 'Identifier'

ruleTester.run 'no-unused-vars', rule,
  valid: [code: 'export var foo = 123;']
  invalid: [
    code: """
      import x from "y";
      export const a = 1;
    """
    output: """
      export const a = 1;
    """
    errors: [definedError 'x']
    options: [onlyRemoveKnownImports: no]
  ,
    code: """
      import {x} from "y";
      export const a = 1;
    """
    output: """
      export const a = 1;
    """
    errors: [definedError 'x']
    options: [onlyRemoveKnownImports: no]
  ,
    code: """
      import {x, y} from "y";
      export {y};
    """
    output: """
      import {y} from "y";
      export {y};
    """
    errors: [definedError 'x']
    options: [onlyRemoveKnownImports: no]
  ,
    code: """
      import {w, x, y} from "y";
      export {w, y};
    """
    output: """
      import {w, y} from "y";
      export {w, y};
    """
    errors: [definedError 'x']
    options: [onlyRemoveKnownImports: no]
  ,
    code: """
      import {w, x} from "y";
      export {w};
    """
    output: """
      import {w} from \"y\";
      export {w};
    """
    errors: [definedError 'x']
    options: [onlyRemoveKnownImports: no]
  ,
    code: """
      import x, {w} from "y";
      export {w};
    """
    output: """
      import {w} from "y";
      export {w};
    """
    errors: [definedError 'x']
    options: [onlyRemoveKnownImports: no]
  ,
    code: """
      import w, {x} from "y";
      export {w};
    """
    output: """
      import w from "y";
      export {w};
    """
    errors: [definedError 'x']
    options: [onlyRemoveKnownImports: no]
  ,
    code: """
      import w, {y as x} from "y";
      export {w};
    """
    output: """
      import w from "y";
      export {w};
    """
    errors: [definedError 'x']
    options: [onlyRemoveKnownImports: no]
  ,
    code: """
      import {w, y as x, z} from \"y\";
      export {w, z};
    """
    output: """
      import {w, z} from "y";
      export {w, z};
    """
    errors: [definedError 'x']
    options: [onlyRemoveKnownImports: no]
  ,
    code: """
      import {y as x, z} from "y";
      export {z};
    """
    output: """
      import {z} from "y";
      export {z};
    """
    errors: [definedError 'x']
    options: [onlyRemoveKnownImports: no]
  ,
    code: """
      import {y as x, z} from "y";
      export {z};
    """
    output: """
      import {z} from "y";
      export {z};
    """
    errors: [definedError 'x']
    options: [onlyRemoveKnownImports: no]
  ,
    code: """
      import {w, y as x} from "y";
      export {w};
    """
    output: """
      import {w} from "y";
      export {w};
    """
    errors: [definedError 'x']
    options: [onlyRemoveKnownImports: no]
  ,
    code: """
      import * as y from "y";
      export {w};
    """
    output: """
      export {w};
    """
    errors: [definedError 'y']
    options: [onlyRemoveKnownImports: no]
  ,
    code: """
      import View from "react-native";
      export const a = 1;
    """
    output: """
      export const a = 1;
    """
    errors: [definedError 'View']
    options: [onlyRemoveKnownImports: yes]
  ,
    code: """
      import x from "y";
      export const a = 1;
    """
    output: """
      import x from "y";
      export const a = 1;
    """
    errors: [definedError 'x']
    options: [onlyRemoveKnownImports: yes]
  ,
    code: """
      import {map as fmap} from "lodash/fp";
      export const a = 1;
    """
    output: """
      export const a = 1;
    """
    errors: [definedError 'fmap']
    options: [onlyRemoveKnownImports: yes]
  ,
    # respect knownImportsFile config
    code: """
      import numeral from "numeral";
      export const a = 1;
    """
    output: """
      import numeral from "numeral";
      export const a = 1;
    """
    errors: [definedError 'numeral']
    options: [
      onlyRemoveKnownImports: yes, knownImportsFile: 'other-known-imports.json'
    ]
  ,
    # respect inline knownImports
    code: """
      import numeral from "numeral";
      export const a = 1;
    """
    output: """
      export const a = 1;
    """
    errors: [definedError 'numeral']
    options: [
      onlyRemoveKnownImports: yes
      knownImportsFile: 'other-known-imports.json'
      knownImports:
        numeral:
          module: 'numeral'
          default: yes
    ]
  ,
    # preserve blank line
    code: """
      import b from "b";
      import c from "c";

      import someLocalDependency from "../somewhere";

      export const a = b + someLocalDependency;
    """
    output: """
      import b from "b";

      import someLocalDependency from "../somewhere";

      export const a = b + someLocalDependency;
    """
    errors: [definedError 'c']
  ,
    # ...but not at the beginning of the file
    code: """
      import c from "c";

      import someLocalDependency from "../somewhere";

      export const a = someLocalDependency;
    """
    output: """
      import someLocalDependency from "../somewhere";

      export const a = someLocalDependency;
    """
    errors: [definedError 'c']
  ]
