# Style Rules

## General

- **No ternaries** — use `if/else`
- **No arrow functions** for named logic — use `function` declarations
- **No try/catch** unless adding classification; let errors propagate to the unhandled
  rejection handler
- **`for (let x of list)`** when the index isn't needed; no `.forEach()`
- **Explicit over clever** — name each thing, no destructuring tricks, no array-of-tuples iteration
- **`URLSearchParams.set()`** per param, not object shorthand
- **String concatenation** for simple strings, not template literals

## Formatting

Prettier handles all formatting. Run before committing:

```sh
docker run --rm -v "$PWD":/app -w /app node:22-slim npx prettier --write "**/*.js"
```

Prettier config (`.prettierrc`):

```json
{
  "singleQuote": true,
  "semi": true,
  "trailingComma": "none"
}
```
