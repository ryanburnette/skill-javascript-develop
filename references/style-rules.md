# Style Rules

## General

- **No ternaries** — use `if/else`
- **No arrow functions** for named logic — use `function` declarations
- **No try/catch** unless adding classification; let errors propagate to the unhandled
  rejection handler
- **`for (let x of list)`** when the index isn't needed; no `.forEach()`
- **Explicit over clever** — name each thing, no destructuring tricks, no array-of-tuples iteration
- **No destructuring** of config args — use property access (`p.from`, `p.serverToken`),
  not `let { from, serverToken } = config`
- **No spread** (`...`) — use `Array.concat()` and `Object.assign()`
- **`URLSearchParams.set()`** per param, not object shorthand
- **String concatenation** for simple strings, not template literals

## Module pattern

- A reusable service is a module singleton: `let Foo = {};` with `Foo.init(cfg)`
  and `Foo.method()`, `export default Foo`. See `lib/badnews.js`.
- No factory functions returning instances (`createFoo()`). No `let m =
  Object.assign(Foo, {...})` wrapper; the namespace object already holds the
  methods.
- Default imports, not destructured: `import Foo from './foo.js'`, not
  `import { createFoo } from './foo.js'`.

## env and init

- `process.env` reads live only in an `init` function called from `main`, never
  in request handlers or module top level. `init` captures env into module scope
  or constructs the service.
- No inline `@type` on a captured var just to satisfy tsc. Let the type flow
  from the imported module; if it must be annotated, declare it uninitialized
  (`let mailer;`) like the existing `let pubkey;` pattern, not `= null`.

## imports

- Local imports use the `.js` extension: `import Foo from './foo.js'`.
- Node ESM needs the explicit extension (no extensionless resolution).

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
