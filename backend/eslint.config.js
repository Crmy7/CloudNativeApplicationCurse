// ESLint Flat Config for a CommonJS backend

const js = require("@eslint/js");

module.exports = [
  js.configs.recommended,
  {
    files: ["**/*.js"],
    languageOptions: {
      sourceType: "commonjs",
      ecmaVersion: 2021,
      globals: {
        console: "readonly",
        process: "readonly",
        module: "readonly",
        __dirname: "readonly",
        __filename: "readonly",
        require: "readonly"
      }
    },
    rules: {
      "no-unused-vars": "warn",
      "no-undef": "off"
    }
  }
];
