###*
# @fileoverview Tests for react-in-jsx-scope
# @author Glen Mailer
###

'use strict'

# -----------------------------------------------------------------------------
# Requirements
# -----------------------------------------------------------------------------

rule = require '../../rules/react-in-jsx-scope'
{RuleTester} = require 'eslint'

parserOptions =
  ecmaVersion: 2018
  sourceType: 'module'
  ecmaFeatures:
    jsx: yes

settings =
  react:
    pragma: 'Foo'

# -----------------------------------------------------------------------------
# Tests
# -----------------------------------------------------------------------------

ruleTester = new RuleTester {parserOptions}
ruleTester.run 'react-in-jsx-scope', rule,
  valid: [
    'var React, App; <App />;'
    'var React; <img />;'
    'var React; <x-gif />;'
    'var React, App, a=1; <App attr={a} />;'
    'var React, App, a=1; function elem() { return <App attr={a} />; }'
    'var React, App; <App />;'
    '/** @jsx Foo */ var Foo, App; <App />;'
    '/** @jsx Foo.Bar */ var Foo, App; <App />;'
    """
      import React from 'react/addons';
      const Button = createReactClass({
        render() {
          return (
            <button {...this.props}>{this.props.children}</button>
          )
        }
      });
      export default Button;
    """
  ,
    {code: 'var Foo, App; <App />;', settings}
  ]
  invalid: [
    code: 'var App, a = <App />;'
    output: """
      import React from 'react'
      var App, a = <App />;
    """
    errors: [message: "'React' must be in scope when using JSX"]
  ,
    code: 'var a = <App />;'
    output: """
      import React from 'react'
      var a = <App />;
    """
    errors: [message: "'React' must be in scope when using JSX"]
  ,
    code: 'var a = <img />;'
    output: """
      import React from 'react'
      var a = <img />;
    """
    errors: [message: "'React' must be in scope when using JSX"]
  ,
    code: '/** @jsx React.DOM */ var a = <img />;'
    output: """
      /** @jsx React.DOM */ import React from 'react'
      var a = <img />;
    """
    errors: [message: "'React' must be in scope when using JSX"]
  ,
    code: '/** @jsx Foo.bar */ var React, a = <img />;'
    errors: [message: "'Foo' must be in scope when using JSX"]
  ,
    code: 'var React, a = <img />;'
    errors: [message: "'Foo' must be in scope when using JSX"]
    settings: settings
  ,
    code: """
      import {Fragment} from 'react'
      var a = <Fragment>b</Fragment>
    """
    output: """
      import React, {Fragment} from 'react'
      var a = <Fragment>b</Fragment>
    """
    errors: [message: "'React' must be in scope when using JSX"]
  ]
