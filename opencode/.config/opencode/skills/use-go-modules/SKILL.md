---
name: use-go-modules
description: Mainstream Go module stack and import conventions. Use when adding dependencies, choosing libraries, or deciding import paths.
---

## Stack

Use mainstream, well-documented packages. Check pkg.go.dev before adding dependencies.

| Purpose | Package | Import Path |
|---------|---------|-------------|
| Router | chi v5 | `github.com/go-chi/chi/v5` |
| Database driver (SQLite) | modernc sqlite | `modernc.org/sqlite` |
| Database driver (PostgreSQL) | pgx v5 | `github.com/jackc/pgx/v5` |
| SQL → Go | sqlc | `github.com/sqlc-dev/sqlc` |
| Sessions | gorilla sessions | `github.com/gorilla/sessions` |
| CSRF | gorilla csrf | `github.com/gorilla/csrf` |
| Password hashing | bcrypt | `golang.org/x/crypto/bcrypt` |
| Env loading | godotenv | `github.com/joho/godotenv` |
| CSV/TSV encoding | csvutil | `github.com/jszwec/csvutil` |
| Static file embedding | statigz | `github.com/vearutop/statigz` |
| Logging | slog | `log/slog` (stdlib) |
| JSON | encoding/json | `encoding/json` (stdlib) |

## Version Features

| Feature | Use | Since |
|---------|-----|-------|
| HTTP routing | `mux.HandleFunc("GET /{id}", h)`, `r.PathValue("id")` | 1.22 |
| JSON omitzero | `json:"f,omitzero"` | 1.24 |
| Loop variables | Per-iteration scope | 1.22 |
| Iterators | `iter` package, `range` over func | 1.23 |
| Random | `math/rand/v2` | 1.22 |
| Null types | `database/sql.Null[T]` | 1.22 |
| Crypto CSPRNG | `crypto/*` uses internal CSPRNG | 1.26 |
| PBKDF2 | `crypto/pbkdf2` | 1.24 |

Type safety: avoid `any`; use shallow interfaces or create marker interfaces.

## Installing Tools

1. Follow skill instructions
2. `webi go` (then `go install` for Go tools)
3. System package manager — last resort

## Build

- `go build` / `go run` / `go install`
- `go generate ./...` (sqlc, stringer, embed manifests)
- `go tool` (Go 1.24+) for versioned tool dependencies
- POSIX shell scripts in `scripts/` for anything `go` can't express

Codegen directives live in Go source:

```go
//go:generate sqlc generate
//go:generate go tool stringer -type=Status
```

`make` and `Makefile` are not approved.

## Pre-commit

```sh
go generate ./...
go fmt ./...
goimports -w .
go build ./...
go test ./...
go vet ./...
```

## Config

- No YAML unless required by 3rd party
- POSIX .env for ENVs
- TSV for data exports

## Guardrails

- ALWAYS check pkg.go.dev before adding a dependency
- NEVER import custom/internal libraries unless you maintain them
- NEVER use CGO-dependent packages for Alpine deployment
- Prefer stdlib when reasonable