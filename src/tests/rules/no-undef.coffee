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
    code: '''
      import {map as fmap} from 'lodash/fp'

      fmap(x => x)
    '''
  ]
  invalid: [
    code: 'fmap(x => x)'
    output: '''
      import {map as fmap} from 'lodash/fp'

      fmap(x => x)
    '''
    errors: [message: "'fmap' is not defined.", type: 'Identifier']
  ,
    code: '''
      import a from 'b'

      fmap(x => x)
    '''
    output: '''
      import a from 'b'
      import {map as fmap} from 'lodash/fp'

      fmap(x => x)
    '''
    errors: [message: "'fmap' is not defined.", type: 'Identifier']
  ,
    code: '''
      import {filter as ffilter} from 'lodash/fp'

      fmap(x => x)
    '''
    output: '''
      import {filter as ffilter, map as fmap} from 'lodash/fp'

      fmap(x => x)
    '''
    errors: [message: "'fmap' is not defined.", type: 'Identifier']
  ,
    code: '''
      import {filter as ffilter} from 'lodash/fp'

      import local from 'local'

      numeral(1)
    '''
    output: '''
      import {filter as ffilter} from 'lodash/fp'
      import numeral from 'numeral'

      import local from 'local'

      numeral(1)
    '''
    errors: [message: "'numeral' is not defined.", type: 'Identifier']
  ,
    code: '''
      import {filter as ffilter} from 'numeral'

      import local from 'local'

      numeral(1)
    '''
    output: '''
      import numeral, {filter as ffilter} from 'numeral'

      import local from 'local'

      numeral(1)
    '''
    errors: [message: "'numeral' is not defined.", type: 'Identifier']
  ,
    code: '''
      import def from 'lodash/fp'

      fmap(x => x)
    '''
    output: '''
      import def, {map as fmap} from 'lodash/fp'

      fmap(x => x)
    '''
    errors: [message: "'fmap' is not defined.", type: 'Identifier']
  ,
    code: '''
      import {filter as ffilter} from 'lodash/fp'

      import local from 'local'

      withExtractedNavParams()
    '''
    output: '''
      import {filter as ffilter} from 'lodash/fp'

      import local from 'local'
      import {withExtractedNavParams} from 'utils/navigation'

      withExtractedNavParams()
    '''
    errors: [
      message: "'withExtractedNavParams' is not defined."
      type: 'Identifier'
    ]
  ,
    # uses eslintrc config
    code: '''
      import {filter as ffilter} from 'lodash/fp'

      import local from 'local'

      localFromConfig()
    '''
    output: '''
      import {filter as ffilter} from 'lodash/fp'

      import local from 'local'
      import localFromConfig from '../localFromConfig'

      localFromConfig()
    '''
    errors: [
      message: "'localFromConfig' is not defined."
      type: 'Identifier'
    ]
    settings:
      'known-imports/imports':
        localFromConfig:
          module: '../localFromConfig'
          default: yes
          local: yes
  ,
    # merges eslintrc config
    code: '''
      import {filter as ffilter} from 'lodash/fp'

      import local from 'local'

      fmap(localFromConfig())
    '''
    output: '''
      import {filter as ffilter, map as fmap} from 'lodash/fp'

      import local from 'local'
      import localFromConfig from '../localFromConfig'

      fmap(localFromConfig())
    '''
    errors: [
      message: "'fmap' is not defined."
      type: 'Identifier'
    ,
      message: "'localFromConfig' is not defined."
      type: 'Identifier'
    ]
    settings:
      'known-imports/imports':
        localFromConfig:
          module: '../localFromConfig'
          default: yes
          local: yes
  ,
    # eslintrc config fully overrides known import
    code: '''
      import {filter as ffilter} from 'lodash/fp'

      import local from 'local'

      numeral(1)
    '''
    output: '''
      import {filter as ffilter} from 'lodash/fp'
      import {numeral} from 'other-numeral'

      import local from 'local'

      numeral(1)
    '''
    errors: [
      message: "'numeral' is not defined."
      type: 'Identifier'
    ]
    settings:
      'known-imports/imports':
        numeral:
          module: 'other-numeral'
  ,
    # ...and when using shorthand
    code: '''
      import {filter as ffilter} from 'lodash/fp'

      import local from 'local'

      numeral(1)
    '''
    output: '''
      import {filter as ffilter} from 'lodash/fp'
      import {numeral} from 'other-numeral'

      import local from 'local'

      numeral(1)
    '''
    errors: [
      message: "'numeral' is not defined."
      type: 'Identifier'
    ]
    settings:
      'known-imports/imports':
        numeral: 'other-numeral'
  ,
    # accepts path to known-imports config
    code: '''
      import {filter as ffilter} from 'lodash/fp'

      import local from 'local'

      fmap(1)
    '''
    output: '''
      import {filter as ffilter} from 'lodash/fp'
      import {fmap} from 'somewhere-else'

      import local from 'local'

      fmap(1)
    '''
    errors: [
      message: "'fmap' is not defined."
      type: 'Identifier'
    ]
    settings:
      'known-imports/config-file-path': 'other-known-imports.json'
  ,
    code: '''
      "use strict"

      fmap(x => x)
    '''
    output: '''
      "use strict"

      import {map as fmap} from 'lodash/fp'

      fmap(x => x)
    '''
    errors: [message: "'fmap' is not defined.", type: 'Identifier']
  ,
    # no blank line before local imports by default
    code: '''
      import {filter as ffilter} from 'lodash/fp'

      withExtractedNavParams()
    '''
    output: '''
      import {filter as ffilter} from 'lodash/fp'
      import {withExtractedNavParams} from 'utils/navigation'

      withExtractedNavParams()
    '''
    errors: [
      message: "'withExtractedNavParams' is not defined."
      type: 'Identifier'
    ]
  ,
    # blank line before local imports
    code: '''
      import {filter as ffilter} from 'lodash/fp'

      withExtractedNavParams()
    '''
    output: '''
      import {filter as ffilter} from 'lodash/fp'

      import {withExtractedNavParams} from 'utils/navigation'

      withExtractedNavParams()
    '''
    errors: [
      message: "'withExtractedNavParams' is not defined."
      type: 'Identifier'
    ]
    settings:
      'known-imports/blank-line-before-local-imports': yes
  ,
    code: '''
      d3.chart()
    '''
    output: '''
      import * as d3 from 'd3'

      d3.chart()
    '''
    errors: [
      message: "'d3' is not defined."
      type: 'Identifier'
    ]
  ,
    # whitelist filename
    code: '''
      Empty()
    '''
    output: '''
      import Empty from 'fixtures/Empty'

      Empty()
    '''
    errors: [
      message: "'Empty' is not defined."
      type: 'Identifier'
    ]
  ,
    # whitelist filename case insensitively (case-insensitive-whitelist-filename rule off)
    code: '''
      Empty2()
    '''
    output: '''
      Empty2()
    '''
    errors: [
      message: "'Empty2' is not defined."
      type: 'Identifier'
    ]
  ,
    # whitelist filename case insensitively (case-insensitive-whitelist-filename rule on)
    code: '''
      Empty2()
    '''
    output: '''
      import Empty2 from 'fixtures/empty2'

      Empty2()
    '''
    errors: [
      message: "'Empty2' is not defined."
      type: 'Identifier'
    ]
    settings: 'known-imports/case-insensitive-whitelist-filename': true
  ,
    # whitelist filename nested
    code: '''
      emptyNest()
    '''
    output: '''
      import emptyNest from 'fixtures/nested/emptyNest'

      emptyNest()
    '''
    errors: [
      message: "'emptyNest' is not defined."
      type: 'Identifier'
    ]
  ,
    # whitelist named
    code: '''
      one()
    '''
    output: '''
      import {one} from 'fixtures/named'

      one()
    '''
    errors: [
      message: "'one' is not defined."
      type: 'Identifier'
    ]
  ,
    # whitelist named always case sensitive
    code: '''
      One()
    '''
    output: '''
      One()
    '''
    errors: [
      message: "'One' is not defined."
      type: 'Identifier'
    ]
    settings: 'known-imports/case-insensitive-whitelist-filename': true
  ,
    # prioritize explicit over whitelist
    code: '''
      Empty()
    '''
    output: '''
      import {Empty} from 'explicit'

      Empty()
    '''
    errors: [
      message: "'Empty' is not defined."
      type: 'Identifier'
    ]
    settings:
      'known-imports/imports':
        Empty: 'explicit'
  ,
    # don't use local convention by default for whitelist
    code: '''
      import a from 'b'

      Empty()
    '''
    output: '''
      import a from 'b'
      import Empty from 'fixtures/Empty'

      Empty()
    '''
    errors: [
      message: "'Empty' is not defined."
      type: 'Identifier'
    ]
  ,
    # local convention for whitelist
    code: '''
      import a from 'b'

      Empty()
    '''
    output: '''
      import a from 'b'

      import Empty from 'fixtures/Empty'

      Empty()
    '''
    errors: [
      message: "'Empty' is not defined."
      type: 'Identifier'
    ]
    settings:
      'known-imports/blank-line-before-local-imports': yes
  ,
    # blacklist
    code: '''
      blacklisted()
    '''
    output: '''
      blacklisted()
    '''
    errors: [
      message: "'blacklisted' is not defined."
      type: 'Identifier'
    ]
  ,
    # index blacklisted by default
    code: '''
      index()
    '''
    output: '''
      index()
    '''
    errors: [
      message: "'index' is not defined."
      type: 'Identifier'
    ]
  ,
    # relative paths
    code: '''
      Empty()
    '''
    settings:
      'known-imports/relative-paths': yes
    output: '''
      import Empty from './tests/fixtures/Empty'

      Empty()
    '''
    errors: [
      message: "'Empty' is not defined."
      type: 'Identifier'
    ]
    filename: 'lib/foo.js'
  ,
    # prefer "nearest" import in terms of parent directories
    code: '''
      ambiguous()
    '''
    output: '''
      import {ambiguous} from 'fixtures/nested/ambiguous2'

      ambiguous()
    '''
    errors: [
      message: "'ambiguous' is not defined."
      type: 'Identifier'
    ]
    filename: 'lib/tests/fixtures/nested/foo.js'
  ,
    # prefer "nearest" import in terms of nested directories
    code: '''
      ambiguous()
    '''
    output: '''
      import {ambiguous} from 'fixtures/ambiguous1'

      ambiguous()
    '''
    errors: [
      message: "'ambiguous' is not defined."
      type: 'Identifier'
    ]
    filename: 'lib/foo.js'
  ]
