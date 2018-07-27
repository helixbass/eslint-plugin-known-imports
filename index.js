module.exports = {
  rules: {
    'no-undef': require('./lib/rules/no-undef'),
    'jsx-no-undef': require('./lib/rules/jsx-no-undef'),
    'no-unused-vars': require('./lib/rules/no-unused-vars'),
    'react-in-jsx-scope': require('./lib/rules/react-in-jsx-scope'),
  },
  configs: {
    recommended: {
      plugins: ['known-imports'],
      rules: {
        'no-undef': 'off',
        'known-imports/no-undef': 'error',
        'react/jsx-no-undef': 'off',
        'known-imports/jsx-no-undef': 'error',
        'react/react-in-jsx-scope': 'off',
        'known-imports/react-in-jsx-scope': 'error',
        'no-unused-vars': 'off',
        'known-imports/no-unused-vars': 'error',
      },
    },
  },
}
