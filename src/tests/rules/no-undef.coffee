rule = require '../../rules/no-undef'
{RuleTester} = require 'eslint'

parserOptions =
  ecmaVersion: 2016
  ecmaFeatures:
    jsx: yes
  sourceType: 'module'

ruleTester = new RuleTester {parserOptions}

ruleTester.run 'no-undef', rule,
  valid: [
    code: """
      import {map as fmap} from 'lodash/fp'

      fmap(x => x)
    """
  ]
  invalid: [
    code: 'fmap(x => x)'
    output: """
      import {map as fmap} from 'lodash/fp'

      fmap(x => x)
    """
    errors: [message: "'fmap' is not defined.", type: 'Identifier']
  ,
    code: """
      import a from 'b'

      fmap(x => x)
    """
    output: """
      import a from 'b'
      import {map as fmap} from 'lodash/fp'

      fmap(x => x)
    """
    errors: [message: "'fmap' is not defined.", type: 'Identifier']
  ,
    code: """
      import {filter as ffilter} from 'lodash/fp'

      fmap(x => x)
    """
    output: """
      import {filter as ffilter, map as fmap} from 'lodash/fp'

      fmap(x => x)
    """
    errors: [message: "'fmap' is not defined.", type: 'Identifier']
  ,
    code: """
      import {filter as ffilter} from 'lodash/fp'

      import local from 'local'

      numeral(1)
    """
    output: """
      import {filter as ffilter} from 'lodash/fp'
      import numeral from 'numeral'

      import local from 'local'

      numeral(1)
    """
    errors: [message: "'numeral' is not defined.", type: 'Identifier']
  ,
    code: """
      import {filter as ffilter} from 'numeral'

      import local from 'local'

      numeral(1)
    """
    output: """
      import numeral, {filter as ffilter} from 'numeral'

      import local from 'local'

      numeral(1)
    """
    errors: [message: "'numeral' is not defined.", type: 'Identifier']
  ,
    code: """
      import def from 'lodash/fp'

      fmap(x => x)
    """
    output: """
      import def, {map as fmap} from 'lodash/fp'

      fmap(x => x)
    """
    errors: [message: "'fmap' is not defined.", type: 'Identifier']
  ,
    code: """
      import {filter as ffilter} from 'lodash/fp'

      import local from 'local'

      withExtractedNavParams()
    """
    output: """
      import {filter as ffilter} from 'lodash/fp'

      import local from 'local'
      import {withExtractedNavParams} from 'utils/navigation'

      withExtractedNavParams()
    """
    errors: [
      message: "'withExtractedNavParams' is not defined."
      type: 'Identifier'
    ]
  ,
    code: """
      import {filter as ffilter} from 'lodash/fp'

      import local from 'local'

      localFromConfig()
    """
    output: """
      import {filter as ffilter} from 'lodash/fp'

      import local from 'local'
      import localFromConfig from '../localFromConfig'

      localFromConfig()
    """
    errors: [
      message: "'localFromConfig' is not defined."
      type: 'Identifier'
    ]
    options: [
      knownImports:
        localFromConfig:
          module: '../localFromConfig'
          default: yes
          local: yes
    ]
  ]
