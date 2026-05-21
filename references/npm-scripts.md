# Lint and Build Scripts

## scripts/lint

```sh
#!/usr/bin/env sh
set -eu

docker run --rm -v "$PWD":/app -w /app node:22-slim npx eslint . --fix
```

## scripts/lint-check

```sh
#!/usr/bin/env sh
set -eu

docker run --rm -v "$PWD":/app -w /app node:22-slim npx eslint .
```

## scripts/format

```sh
#!/usr/bin/env sh
set -eu

docker run --rm -v "$PWD":/app -w /app node:22-slim npx prettier --write "**/*.js"
```

## scripts/build

```sh
#!/usr/bin/env sh
set -eu

docker run --rm -v "$PWD":/app -w /app node:22-slim node main.js
```

## Usage

```sh
sh ./scripts/lint        # lint and fix
sh ./scripts/lint-check  # check only, no fix
sh ./scripts/format      # prettier format
sh ./scripts/build       # run the app
```
