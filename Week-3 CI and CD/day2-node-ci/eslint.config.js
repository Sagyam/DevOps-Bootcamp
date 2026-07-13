// eslint.config.js
import { defineConfig } from "eslint/config";
import js from "@eslint/js";
import globals from "globals";

export default defineConfig([
  // Inherit recommended rules
  js.configs.recommended, 

  {
    // Apply settings to specific files
    files: ["src/**/*.js"], 
    
    // Set up the environment runtime
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "module",
      globals: {
        ...globals.browser,
        ...globals.node
      }
    },
    
    // Add or override specific linting rules
    rules: {
      "no-unused-vars": "warn",
      "semi": ["error", "always"],
      "prefer-const": "error"
    }
  }
]);
