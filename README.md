eslint-plugin-known-imports
===========================

Let ESLint automatically write and remove ES6 `import` statements for you

![known-imports-demo](https://user-images.githubusercontent.com/440230/44939205-6bf56280-ad51-11e8-880a-95fa2c94c824.gif)

## Installation

Install [ESLint](https://www.github.com/eslint/eslint) either locally or globally.

```sh
$ npm install eslint --save-dev
```

If you installed `eslint` globally, you have to install known-imports plugin globally too. Otherwise, install it locally.

```sh
$ npm install eslint-plugin-known-imports --save-dev
```

## How does it work?

#### eslint --fix
You have to be running ESLint in "fix" mode (in your editor, or with `--fix` on the command line)

The plugin provides enhanced versions of existing ESLint rules like `no-undef` and `no-unused-vars`
#### Describe your known imports
You tell the plugin which imports should be auto-generated when you use certain names in your code, typically by providing a `known-imports.json` or `known-imports.yaml` file in your project root directory

## Typical ESLint config
#### For a React project:
```
"plugins": ["known-imports", ...],
"extends: ["plugin:known-imports/recommended-react", ...]
```
#### For a non-React project:
```
"plugins": ["known-imports", ...],
"extends: ["plugin:known-imports/recommended", ...]
```
Then you provide a `known-imports.json` or `known-imports.yaml` file in the project root directory, see the next section for its format
## Specifying known imports
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

The keys are the names used in your code (that would be reported as unknown by `no-undef` or `react/jsx-no-undef`)

#### Named (non-default) imports
Just specify the `module` you're importing the name from:
```
"View": {"module": "react-native"}
```
would generate:
```
import {View} from 'react-native'
```
There's also an equivalent shorthand:
```
"View": "react-native"
```
#### Aliases
Add `"name": "originalName"`:
```
"fmap": {"module": "lodash/fp", "name": "map"}
```
would generate:
```
import {map as fmap} from 'lodash/fp'
```
#### Default imports
Add `"default": true`:
```
"moment": {"module": "moment", "default": true}
```
would generate:
```
import moment from 'moment'
```
#### Local imports
Add `"local": true` to distinguish project-local imports eg:
```
"MySharedComponent": {"module": "components/MySharedComponent", "default": true, "local": true}
```
You only need to distinguish local imports if you want to follow the convention where nonlocal imports come first, followed by a blank line and then local imports

## Configuration

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

## List of supported rules

* known-imports/no-undef: see docs for [`no-undef`](https://eslint.org/docs/rules/no-undef)
* known-imports/jsx-no-undef: see docs for [`jsx-no-undef`](https://github.com/yannickcr/eslint-plugin-react/blob/master/docs/rules/jsx-no-undef.md)

## Shareable configurations

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
