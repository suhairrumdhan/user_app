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
      files: ["test/admin_panel/TC-ADM-P05-full-load.js"],
      parserOptions: {sourceType: "module"},
      globals: {__ENV: "readonly", __VU: "readonly", __ITER: "readonly"},
      rules: {quotes: ["error", "single", {allowTemplateLiterals: true}]},
    },
    {
      files: ["**/*.spec.*"],
      env: {
        mocha: true,
      },
      rules: {},
    },
  ],
  // BigInt is a standard ES2020 global and is supported by the configured
  // Node.js 24 runtime. ESLint's legacy `es6` environment does not declare it.
  globals: {
    BigInt: "readonly",
  },
};
