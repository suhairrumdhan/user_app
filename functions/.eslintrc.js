module.exports = {
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    ecmaVersion: 2022,
  },
  extends: [
    "eslint:recommended",
  ],
  rules: {
    "require-jsdoc": "off",
    "max-len": "off",
    "indent": "off",
    "object-curly-spacing": "off",
    "operator-linebreak": "off",
    "prefer-arrow-callback": "off",
    "quotes": ["error", "double", {allowTemplateLiterals: true}],
    "no-restricted-globals": ["error", "name", "length"],
  },
  overrides: [
    {
      files: ["**/*.spec.*"],
      env: {
        mocha: true,
      },
      rules: {},
    },
  ],
  globals: {},
};