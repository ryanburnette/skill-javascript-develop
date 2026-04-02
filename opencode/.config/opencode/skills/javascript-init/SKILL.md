---
name: javascript-init
description: Initialize a new JavaScript project with ESM, JSHint, and standard tooling. Use when creating a new JS/Node project or setting up project scaffolding.
---

## Package Setup

1. Run: `npm init -y`
2. Set `private: true` in package.json to prevent accidental npm publish
3. Set `"type": "module"` for ESM by default

## JSHint Configuration

See [references/jshintrc.md](references/jshintrc.md)

## .gitignore

See [references/gitignore.md](references/gitignore.md)

## Code Style

- Use single quotes
- Always use semicolons
- Use `function` declarations, avoid arrow functions
- No `'use strict';` directive needed with ESM

## Express Projects

For Express APIs, install baseline dependencies:

- `express` (use `express@5` for Express 5)
- `helmet` (security headers)
- `morgan` (request logging)

## Pre-commit

See [references/npm-scripts.md](references/npm-scripts.md)