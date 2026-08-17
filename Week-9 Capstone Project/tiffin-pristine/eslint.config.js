// Flat config (ESLint 9+). Students do not need to know JS deeply to read
// this: each block says "for these files, turn on these rule sets".
import js from '@eslint/js';
import globals from 'globals';
import security from 'eslint-plugin-security';
import prettier from 'eslint-config-prettier';

export default [
  { ignores: ['node_modules/**', 'coverage/**', 'dist/**', 'src/public/**'] },

  // Baseline recommended rules for all JS.
  js.configs.recommended,

  // Security linting: flags eval, child_process with user input,
  // non-literal fs paths, unsafe regex, and object injection.
  security.configs.recommended,

  {
    files: ['**/*.js'],
    languageOptions: {
      ecmaVersion: 2024,
      sourceType: 'module',
      globals: { ...globals.node },
    },
    rules: {
      // These are the rules that would have caught bugs in the legacy repo.
      'no-console': 'error', // use the structured logger instead
      'no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
      'no-var': 'error',
      'prefer-const': 'error',
      eqeqeq: ['error', 'always'],
      'no-eval': 'error',
      'no-implied-eval': 'error',
      'no-process-exit': 'error',
      'require-await': 'error',
      'no-return-await': 'error',
    },
  },

  // Tests and shutdown scripts may use console / process.exit.
  {
    files: ['src/server.js', 'db/migrate.js'],
    rules: { 'no-process-exit': 'off' },
  },
  {
    files: ['test/**/*.js'],
    rules: { 'no-console': 'off', 'security/detect-object-injection': 'off' },
  },

  // Must be last: disables stylistic rules that fight Prettier.
  prettier,
];
