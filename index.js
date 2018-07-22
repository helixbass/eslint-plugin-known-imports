module.exports = {
  rules: {
    'no-undef': require('./lib/rules/no-undef'),
    'jsx-no-undef': require('./lib/rules/jsx-no-undef'),
  },
  configs: {
    recommended: {
      plugins: ['known-imports'],
      rules: {
        'no-undef': 0,
        'known-imports/no-undef': 2,
        'react/jsx-no-undef': 0,
        'known-imports/jsx-no-undef': 2,
      },
    },
  },
}
