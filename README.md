ESLint-plugin-known-imports
===========================

Generates missing project-specific known imports by overriding ESLint rules `no-undef` and `react/jsx-no-undef`

# Installation

Install [ESLint](https://www.github.com/eslint/eslint) either locally or globally.

```sh
$ npm install eslint --save-dev
```

If you installed `ESLint` globally, you have to install known-imports plugin globally too. Otherwise, install it locally.

```sh
$ npm install eslint-plugin-known-imports --save-dev
```

# Specifying "known" imports

The plugin works by adding ESLint "fixing" capabilities that generate `import` statements whenever you reference
an unknown variable that you've specified in a `known-imports.json` file in your project root directory (technically,
whichever directory ESLint is run from)

### Example
Here's an example `known-imports.json` that may give you the idea:
```
{
  "View": "react-native",
  "isEmpty": "lodash",
  "moment": {"module": "moment", "default": true},
  "fmap": {"module": "lodash/fp", "name": "map"},
  "withExtractedNavParams": {"module": "utils/navigation", "local": true},
}
```

### `known-imports.json` format

The keys are the names (that would be reported by `no-undef` or `react/jsx-no-undef`). If the value is a string,
that's shorthand for specifying the `module`, eg the first one above could be written
```
"View": {"module": "react-native"}
```
The "default" is a named import (which would be imported as eg `import {View} from 'react-native'`). To generate a
`default` import, specify `"default": true`. So eg this:
```
"moment": {"module": "moment", "default": true}
```
would generate:
```
import moment from 'moment'
```
To specify a named import alias, use `"name": "originalName"`, eg this:
```
"fmap": {"module": "lodash/fp", "name": "map"}
```
would generate:
```
import {map as fmap} from 'lodash/fp'
```
A convention is assumed where non-project-local imports come first, followed by a blank line and then project-local imports.
By default a known import is considered non-local and the `import` statement will be generated at the end of the existing
non-local imports. If you specify `"local": true`, the `import` statement will be generated at the end of the existing
local imports (if any).

It should detect existing imports from the same module and append to the existing `import` statement

# Configuration

Use [our preset](#recommended) to get reasonable defaults:

```json
  "extends": [
    "eslint:recommended",
    "plugin:known-imports/recommended"
  ]
```

Add "known-imports" to the plugins section.

```json
  "plugins": [
    "known-imports"
  ]
```

If not using the recommended preset, enable the rules that you would like to use and disable their corresponding "base" rules.

```json
  "rules": {
    "no-undef": "off",
    "known-imports/no-undef": "error",
    "react/jsx-no-undef": "off",
    "known-imports/jsx-no-undef": "error",
  }
```

# List of supported rules

* known-imports/no-undef: see docs for [`no-undef`](https://eslint.org/docs/rules/no-undef)
* known-imports/jsx-no-undef: see docs for [`jsx-no-undef`](https://github.com/yannickcr/eslint-plugin-react/blob/master/docs/rules/jsx-no-undef.md)

# Shareable configurations

## Recommended

This plugin exports a `recommended` configuration that includes overrides of both `no-undef` and `react/jsx-no-undef`

To enable this configuration use the `extends` property in your `.eslintrc` config file:

```json
{
  "extends": ["eslint:recommended", "plugin:known-imports/recommended"]
}
```

See [ESLint documentation](http://eslint.org/docs/user-guide/configuring#extending-configuration-files) for more information about extending configuration files.

# License

ESLint-plugin-known-imports is licensed under the [MIT License](http://www.opensource.org/licenses/mit-license.php).
