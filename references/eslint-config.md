# ESLint Flat Config

## Full Config

```js
import globals from 'globals';

export default [
  {
    languageOptions: {
      ecmaVersion: 2024,
      sourceType: 'module',
      globals: {
        ...globals.node,
        ...globals.browser,
      },
    },
  },
  {
    rules: {
      'semi': ['error', 'always'],
      'quotes': ['error', 'single'],
      'no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
      'no-console': 'warn',
      'no-eval': 'error',
      'no-var': 'error',
    },
  },
];
```

## Dependencies

```sh
npm install --save-dev eslint globals
```

## Run

```sh
npx eslint . --fix
```
