# SQLite with sqlc

Configuration and patterns for production SQLite with sqlc.

## Why SQLite + sqlc

- **Single binary deployment** — no external database server
- **Pure Go driver** — `modernc.org/sqlite` works on Alpine without CGO
- **Type-safe queries** — sqlc generates Go from SQL, no ORM magic
- **Production-ready** — when configured correctly

## SQLite Configuration

SQLite is NOT a toy database. It handles millions of requests when configured correctly.

### Connection Pool

```go
import (
    "database/sql"
    _ "modernc.org/sqlite"
)

func Open(path string) (*sql.DB, error) {
    db, err := sql.Open("sqlite", path)
    if err != nil {
        return nil, err
    }

    // SQLite limitations
    db.SetMaxOpenConns(1) // Single writer
    db.SetMaxIdleConns(1)

    // Required pragmas
    pragmas := []string{
        "PRAGMA journal_mode=WAL",      // Write-Ahead Logging
        "PRAGMA foreign_keys=ON",       // Enforce foreign keys
        "PRAGMA busy_timeout=5000",    // Wait 5s on lock
        "PRAGMA synchronous=NORMAL",   // Fast but safe
    }

    for _, p := range pragmas {
        if _, err := db.Exec(p); err != nil {
            db.Close()
            return nil, err
        }
    }

    return db, nil
}
```

### Test Database

```go
func TestWithDatabase(t *testing.T) *sql.DB {
    db, err := sql.Open("sqlite", ":memory:")
    if err != nil {
        t.Fatal(err)
    }

    // Same pragmas as production
    db.SetMaxOpenConns(1)
    for _, p := range []string{
        "PRAGMA journal_mode=WAL",
        "PRAGMA foreign_keys=ON",
    } {
        db.Exec(p)
    }

    return db
}
```

## sqlc Configuration

`config/sqlc.yaml`:

```yaml
version: "2"
sql:
  - engine: "sqlite"
    queries: "db/queries/"
    schema: "db/migrations/"
    gen:
      go:
        package: "database"
        out: "internal/database"
        emit_json_tags: true
        emit_empty_slices: true
```

Run: `sqlc generate`

## Query Definitions

`db/queries/users.sql`:

```sql
-- name: GetUser :one
SELECT * FROM users WHERE id = ?;

-- name: GetUserByEmail :one
SELECT * FROM users WHERE email = ?;

-- name: ListUsers :many
SELECT * FROM users ORDER BY created_at DESC;

-- name: CreateUser :one
INSERT INTO users (email, password_hash, created_at)
VALUES (?, ?, ?)
RETURNING *;

-- name: UpdateUser :one
UPDATE users
SET email = ?, password_hash = ?
WHERE id = ?
RETURNING *;

-- name: DeleteUser :exec
DELETE FROM users WHERE id = ?;

-- name: CountUsers :one
SELECT COUNT(*) FROM users;
```

`db/queries/sessions.sql`:

```sql
-- name: CreateSession :one
INSERT INTO sessions (user_id, token, expires_at)
VALUES (?, ?, ?)
RETURNING *;

-- name: GetSessionByToken :one
SELECT * FROM sessions WHERE token = ?;

-- name: DeleteSession :exec
DELETE FROM sessions WHERE token = ?;

-- name: DeleteExpiredSessions :exec
DELETE FROM sessions WHERE expires_at < ?;
```

## Migrations

Keep migrations simple and sequential.

`db/migrations/001_users.sql`:

```sql
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_email ON users(email);
```

`db/migrations/002_sessions.sql`:

```sql
CREATE TABLE sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    token TEXT NOT NULL UNIQUE,
    expires_at DATETIME NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX idx_sessions_token ON sessions(token);
CREATE INDEX idx_sessions_user_id ON sessions(user_id);
```

`db/migrations/003_tasks.sql`:

```sql
CREATE TABLE tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    title TEXT NOT NULL,
    completed INTEGER NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX idx_tasks_user_id ON tasks(user_id);
```

## Migration Runner

```go
package database

import (
    "database/sql"
    "embed"
    "sort"
)

//go:embed migrations/*.sql
var migrationsFS embed.FS

func Migrate(db *sql.DB) error {
    // Create migrations table
    _, err := db.Exec(`
        CREATE TABLE IF NOT EXISTS _migrations (
            name TEXT PRIMARY KEY,
            applied_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    `)
    if err != nil {
        return err
    }

    // Get applied migrations
    applied := make(map[string]bool)
    rows, _ := db.Query("SELECT name FROM _migrations")
    if rows != nil {
        defer rows.Close()
        for rows.Next() {
            var name string
            rows.Scan(&name)
            applied[name] = true
        }
    }

    // Read and apply migrations
    entries, _ := migrationsFS.ReadDir("migrations")
    sort.Slice(entries, func(i, j int) bool {
        return entries[i].Name() < entries[j].Name()
    })

    for _, entry := range entries {
        name := entry.Name()
        if applied[name] {
            continue
        }

        content, err := migrationsFS.ReadFile("migrations/" + name)
        if err != nil {
            return err
        }

        if _, err := db.Exec(string(content)); err != nil {
            return err
        }

        if _, err := db.Exec("INSERT INTO _migrations (name) VALUES (?)", name); err != nil {
            return err
        }
    }

    return nil
}
```

## Using sqlc-generated Code

```go
// In handler
func (h *Handler) GetUser(w http.ResponseWriter, r *http.Request) {
    id, err := strconv.Atoi(chi.URLParam(r, "id"))
    if err != nil {
        http.Error(w, "invalid id", http.StatusBadRequest)
        return
    }

    user, err := h.db.GetUser(r.Context(), int64(id))
    if err == sql.ErrNoRows {
        http.Error(w, "not found", http.StatusNotFound)
        return
    }
    if err != nil {
        http.Error(w, "internal error", http.StatusInternalServerError)
        return
    }

    json.NewEncoder(w).Encode(user)
}

// Create
func (h *Handler) CreateUser(w http.ResponseWriter, r *http.Request) {
    var req struct {
        Email    string `json:"email"`
        Password string `json:"password"`
    }
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, "invalid request", http.StatusBadRequest)
        return
    }

    hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
    if err != nil {
        http.Error(w, "internal error", http.StatusInternalServerError)
        return
    }

    user, err := h.db.CreateUser(r.Context(), database.CreateUserParams{
        Email:        req.Email,
        PasswordHash: string(hashedPassword),
        CreatedAt:    time.Now(),
    })
    if err != nil {
        http.Error(w, "internal error", http.StatusInternalServerError)
        return
    }

    json.NewEncoder(w).Encode(user)
}
```

## Common Patterns

### Nullable fields

```sql
-- name: GetArticle :one
SELECT id, title, COALESCE(content, '') as content FROM articles WHERE id = ?;
```

### Pagination

```sql
-- name: ListUsersPaginated :many
SELECT * FROM users
ORDER BY created_at DESC
LIMIT ? OFFSET ?;
```

```go
users, err := h.db.ListUsersPaginated(r.Context(), database.ListUsersPaginatedParams{
    Limit:  20,
    Offset: (page - 1) * 20,
})
```

### Transactions

```go
func (h *Handler) TransferPoints(w http.ResponseWriter, r *http.Request) {
    tx, err := h.db.BeginTx(r.Context(), nil)
    if err != nil {
        http.Error(w, "internal error", http.StatusInternalServerError)
        return
    }
    defer tx.Rollback()

    qtx := database.New(tx)

    // Debit
    err = qtx.UpdateBalance(r.Context(), database.UpdateBalanceParams{
        ID:     fromID,
        Amount: -amount,
    })
    if err != nil {
        return
    }

    // Credit
    err = qtx.UpdateBalance(r.Context(), database.UpdateBalanceParams{
        ID:     toID,
        Amount: amount,
    })
    if err != nil {
        return
    }

    tx.Commit()
}
```

## Guardrails

- ALWAYS use `modernc.org/sqlite` (pure Go, no CGO)
- ALWAYS set `MaxOpenConns(1)` for SQLite writes
- ALWAYS enable WAL mode and foreign keys
- NEVER use `AUTOINCREMENT` on its own (use `INTEGER PRIMARY KEY AUTOINCREMENT` only if needed — `INTEGER PRIMARY KEY` is already auto-incrementing)
- NEVER run migrations on every request — only on startup