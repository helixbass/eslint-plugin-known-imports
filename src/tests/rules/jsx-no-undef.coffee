eslint = require 'eslint'
rule = require '../../rules/jsx-no-undef'
{RuleTester} = eslint

parserOptions =
  ecmaVersion: 2016
  ecmaFeatures:
    jsx: yes
  sourceType: 'module'

ruleTester = new RuleTester {parserOptions}

ruleTester.run 'jsx-no-undef', rule,
  valid: [
    code: """
      import {View} from 'react-native'

      React.render(<View />)
    """
  ]
  invalid: [
    code: 'React.render(<View />)'
    output: """
      import {View} from 'react-native'

      React.render(<View />)
    """
    errors: [message: "'View' is not defined."]
  ,
    code: """
      import {ScrollView} from 'react-native'

      React.render(<View />)
    """
    output: """
      import {ScrollView, View} from 'react-native'

      React.render(<View />)
    """
    errors: [message: "'View' is not defined."]
  ,
    code: """
      import a from 'react-native'

      React.render(<View />)
    """
    output: """
      import a, {View} from 'react-native'

      React.render(<View />)
    """
    errors: [message: "'View' is not defined."]
  ,
    code: """
      import {ScrollView} from 'react-native'

      import local from 'local'

      React.render(<View />)
    """
    output: """
      import {ScrollView, View} from 'react-native'

      import local from 'local'

      React.render(<View />)
    """
    errors: [message: "'View' is not defined."]
  ,
    code: """
      import {ScrollView} from 'react-native'

      import local from 'local'

      React.render(<View><Text>abc</Text></View>)
    """
    output: """
      import {ScrollView, View} from 'react-native'

      import local from 'local'
      import Text from 'components/Text'

      React.render(<View><Text>abc</Text></View>)
    """
    errors: [
      message: "'View' is not defined."
    ,
      message: "'Text' is not defined."
    ]
  ,
    # uses eslintrc config
    code: """
      import {ScrollView} from 'react-native'

      import local from 'local'

      React.render(<View><LocalFromConfig>abc</LocalFromConfig></View>)
    """
    output: """
      import {ScrollView, View} from 'react-native'

      import local from 'local'
      import LocalFromConfig from 'components/LocalFromConfig'

      React.render(<View><LocalFromConfig>abc</LocalFromConfig></View>)
    """
    errors: [
      message: "'View' is not defined."
    ,
      message: "'LocalFromConfig' is not defined."
    ]
    settings:
      'known-imports/imports':
        LocalFromConfig:
          module: 'components/LocalFromConfig'
          default: yes
          local: yes
  ,
    # eslintrc config fully overrides known import
    code: """
      import {filter as ffilter} from 'lodash/fp'

      import local from 'local'

      React.render(<Text />)
    """
    output: """
      import {filter as ffilter} from 'lodash/fp'
      import {Text} from 'other-place'

      import local from 'local'

      React.render(<Text />)
    """
    errors: [message: "'Text' is not defined."]
    settings:
      'known-imports/imports':
        Text:
          module: 'other-place'
  ,
    # accepts path to known-imports config
    code: """
      import {filter as ffilter} from 'lodash/fp'

      import local from 'local'

      React.render(<Text />)
    """
    output: """
      import {filter as ffilter} from 'lodash/fp'
      import Text from 'somewhere-else'

      import local from 'local'

      React.render(<Text />)
    """
    errors: [message: "'Text' is not defined."]
    settings:
      'known-imports/config-file-path': 'other-known-imports.json'
  ,
    code: """
      <Empty />
    """
    output: """
      import Empty from 'fixtures/Empty'

      <Empty />
    """
    errors: [message: "'Empty' is not defined."]
  ]
