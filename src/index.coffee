module.exports =
  rules:
    'no-undef': require './rules/no-undef'
    'jsx-no-undef': require './rules/jsx-no-undef'
    'no-unused-vars': require './rules/no-unused-vars'
    'react-in-jsx-scope': require './rules/react-in-jsx-scope'
  configs:
    recommended:
      plugins: ['known-imports']
      rules:
        'no-undef': 'off'
        'known-imports/no-undef': 'error'
        'no-unused-vars': 'off'
        'known-imports/no-unused-vars': 'error'
    'recommended-react':
      plugins: ['known-imports']
      rules:
        'no-undef': 'off'
        'known-imports/no-undef': 'error'
        'react/jsx-no-undef': 'off'
        'known-imports/jsx-no-undef': 'error'
        'react/react-in-jsx-scope': 'off'
        'known-imports/react-in-jsx-scope': 'error'
        'no-unused-vars': 'off'
        'known-imports/no-unused-vars': 'error'
