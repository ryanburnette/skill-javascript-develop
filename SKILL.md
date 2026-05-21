---
name: javascript-develop
description: JavaScript development with ESLint, Prettier, and Docker. Use when writing Node.js scripts, Express APIs, or browser UIs. Never install Node packages on the host — always run npm/node in Docker.
---

## Core Rule

Never install Node.js, npm, or any JavaScript packages on the host machine. All
npm and node commands run inside Docker. No `brew install node`, no `npm install`
on the host.

## Running JavaScript

One-off script or command:

```sh
docker run --rm -v "$PWD":/app -w /app node:22-slim node script.js
```

With dependencies, use a `Dockerfile`:

```dockerfile
FROM node:22-slim
WORKDIR /app
COPY package.json package-lock.json* .npmrc* ./
RUN npm ci --no-audit --no-fund 2>/dev/null || npm install --no-audit --no-fund
COPY . .
CMD ["node", "main.js"]
```

Build and run:

```sh
docker build -t my-app .
docker run --rm my-app
```

With environment variables:

```sh
docker run --rm -v "$PWD":/app -w /app -e API_KEY=... node:22-slim node script.js
# or from a file:
docker run --rm -v "$PWD":/app -w /app --env-file .env node:22-slim node script.js
```

Interactive REPL:

```sh
docker run --rm -it node:22-slim node
```

## Node Version

Use `node:22-slim` unless the project specifies otherwise. Prefer `-slim` over
full images.

## Dependencies

List all dependencies in `package.json` with pinned versions:

```json
{
  "name": "my-app",
  "private": true,
  "type": "module",
  "dependencies": {
    "express": "5.1.0",
    "helmet": "8.1.0"
  }
}
```

Generate a lockfile inside the container:

```sh
docker run --rm -v "$PWD":/app -w /app node:22-slim sh -c "npm install && npm ls --depth=0"
```

## ESLint + Prettier Workflow

No LSP. Run ESLint iteratively while working, Prettier before committing.

### ESLint

Flat config (`eslint.config.js`). See `references/eslint-config.md` for the full
config template.

Run ESLint iteratively (fix mode):

```sh
docker run --rm -v "$PWD":/app -w /app node:22-slim npx eslint . --fix
```

Check only (no fix):

```sh
docker run --rm -v "$PWD":/app -w /app node:22-slim npx eslint .
```

### Prettier

Run before committing to format all JS files:

```sh
docker run --rm -v "$PWD":/app -w /app node:22-slim npx prettier --write "**/*.js"
```

See `references/npm-scripts.md` for shell scripts that wrap these commands.

## Load References On-Demand

SKILL.md contains the patterns and decisions. Full code examples are in reference
files. **Load only the references relevant to the current task** to preserve context.

| Task | Load |
|------|------|
| Setting up ESLint config | `references/eslint-config.md` |
| Setting up lint/build scripts | `references/npm-scripts.md` |
| Writing browser JS (module pattern, async handling) | `references/module-pattern.md` |
| Code style rules | `references/style-rules.md` |

## Project Setup

1. Run: `npm init -y`
2. Set `private: true` in package.json to prevent accidental npm publish
3. Set `"type": "module"` for ESM by default

## Code Style

- Single quotes, semicolons
- `function` declarations, no arrow functions for named logic
- No ternaries — use `if/else`
- No try/catch unless adding classification; let errors propagate to the unhandled handler
- `for (let x of list)` when the index isn't needed; no `.forEach()`
- Explicit over clever — no destructuring tricks, no array-of-tuples iteration
- String concatenation for simple strings, not template literals

See `references/style-rules.md` for the full style guide.

## Browser Pattern

Export a plain object (`App`), not a class. Expose it on `window` for inline
`onclick` handlers.

```html
<script type="module">
  import App from './app.js';
  window.App = App;
  App.init();
</script>
<button onclick="App.doThing(event, this.dataset.id)" data-id="123">Click</button>
```

No `addEventListener` wiring. Use `let $ = sel => document.querySelector(sel)`
instead of `getElementById`.

See `references/module-pattern.md` for the full module pattern, async error
handling with `unhandledrejection`, and form POST for redirects.

## Node/Express

For Express APIs, install baseline dependencies:

- `express` (use `express@5` for Express 5)
- `helmet` (security headers)
- `morgan` (request logging)

## Pre-commit

```sh
sh ./scripts/lint
sh ./scripts/build
```

See `references/npm-scripts.md` for the lint and build scripts.

## Guardrails

- NEVER run `brew install node` or any host-level Node install
- NEVER run `npm install` outside a container
- ALWAYS use `node:22-slim` or a project-specified image
- ALWAYS pin dependency versions in package.json
- ALWAYS use `--rm` for one-off containers to avoid accumulation
- ALWAYS run ESLint iteratively with `--fix` while working (no LSP)
- ALWAYS run Prettier before committing
- NEVER use LSP for JS linting — it wastes tokens
