module.exports = {
  root: true,
  env: {
    node: true,
    es2022: true,
  },
  parser: '@typescript-eslint/parser',
  parserOptions: {
    ecmaVersion: 2022,
    sourceType: 'module',
  },
  plugins: ['@typescript-eslint'],
  extends: [
    'eslint:recommended',
    'google',
    'plugin:@typescript-eslint/recommended',
  ],
  ignorePatterns: ['lib/**/*', 'node_modules/**/*', '.eslintrc.cjs'],
  rules: {
    // google's default is 2-space indent with a specific object-curly-spacing
    // opinion that fights Prettier-style formatting; we keep the rest of the
    // Google style guide but relax indentation/quote rules to match our
    // `dart format`-equivalent expectation of "one non-negotiable formatter,
    // no style debates in review" without requiring a second formatter tool.
    'indent': 'off',
    'quotes': ['error', 'single', {allowTemplateLiterals: true}],
    'require-jsdoc': 'off',
    'valid-jsdoc': 'off',
    'max-len': ['warn', {code: 100, ignoreUrls: true, ignoreStrings: true}],
    '@typescript-eslint/no-unused-vars': ['error', {argsIgnorePattern: '^_'}],
  },
};
