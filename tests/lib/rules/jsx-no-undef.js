const eslint = require('eslint')
const rule = require('../../../lib/rules/jsx-no-undef')
const {RuleTester} = eslint

const parserOptions = {
  ecmaVersion: 2016,
  ecmaFeatures: {
    jsx: true,
  },
  sourceType: 'module',
}

const ruleTester = new RuleTester({parserOptions})

ruleTester.run('jsx-no-undef', rule, {
  valid: [
    {
      code: `
        import {View} from 'react-native'

        React.render(<View />)
      `,
    },
  ],
  invalid: [
    {
      code: 'React.render(<View />)',
      output: `\
import {View} from 'react-native'

React.render(<View />)`,
      errors: [{message: "'View' is not defined."}],
    },
    {
      code: `\
import {ScrollView} from 'react-native'

React.render(<View />)`,
      output: `\
import {ScrollView, View} from 'react-native'

React.render(<View />)`,
      errors: [{message: "'View' is not defined."}],
    },
    {
      code: `\
import a from 'react-native'

React.render(<View />)`,
      output: `\
import a, {View} from 'react-native'

React.render(<View />)`,
      errors: [{message: "'View' is not defined."}],
    },
    {
      code: `\
import {ScrollView} from 'react-native'

import local from 'local'

React.render(<View />)`,
      output: `\
import {ScrollView, View} from 'react-native'

import local from 'local'

React.render(<View />)`,
      errors: [{message: "'View' is not defined."}],
    },
    {
      code: `\
import {ScrollView} from 'react-native'

import local from 'local'

React.render(<View><Text>abc</Text></View>)`,
      output: `\
import {ScrollView, View} from 'react-native'

import local from 'local'
import Text from 'components/Text'

React.render(<View><Text>abc</Text></View>)`,
      errors: [
        {message: "'View' is not defined."},
        {message: "'Text' is not defined."},
      ],
    },
  ],
})
