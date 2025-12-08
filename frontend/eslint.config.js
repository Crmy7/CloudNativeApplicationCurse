import js from "@eslint/js";
import vuePlugin from "eslint-plugin-vue";

export default [
  js.configs.recommended,
  ...vuePlugin.configs["flat/recommended"],

  {
    files: ["src/**/*.{js,vue}"],
    rules: {
      "vue/multi-word-component-names": "off",
    },
  },
];
