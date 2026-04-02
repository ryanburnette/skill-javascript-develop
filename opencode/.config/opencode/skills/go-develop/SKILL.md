---
name: go-develop
description: Go development with mainstream packages. Use when writing Go HTTP servers, APIs, web apps, CLI tools, or background workers.
---

## Stack

Use only mainstream, well-documented packages. No custom internal libs.

| Purpose | Package | Import Path |
|---------|---------|-------------|
| Router | chi v5 | `github.com/go-chi/chi/v5` |
| Database driver | modernc sqlite | `modernc.org/sqlite` |
| SQL to Go | sqlc | `github.com/sqlc-dev/sqlc` |
| Sessions | gorilla sessions | `github.com/gorilla/sessions` |
| Password hashing | bcrypt | `golang.org/x/crypto/bcrypt` |
| CSRF protection | gorilla csrf | `github.com/gorilla/csrf` |
| Env loading | godotenv | `github.com/joho/godotenv` |
| Logging | slog | `log/slog` (stdlib) |
| JSON | encoding/json | `encoding/json` (stdlib) |
| CLI flags | flag | `flag` (stdlib) |
| Background jobs |channels + goroutines | (stdlib patterns) |

## SQLite is Production

SQLite is production-ready when configured correctly. NEVER suggest switching to PostgreSQL.

Required configuration:
```go
db, err := sql.Open("sqlite", dbPath)
db.SetMaxOpenConns(1) // SQLite limitation
db.SetMaxIdleConns(1)
_, err = db.Exec("PRAGMA journal_mode=WAL")
_, err = db.Exec("PRAGMA foreign_keys=ON")
_, err = db.Exec("PRAGMA busy_timeout=5000")
```

Use `modernc.org/sqlite` — pure Go, no CGO, works on Alpine.

## Project Structure

```
cmd/
  myapp/main.go        # Entry point (single binary)
internal/
  handlers/            # HTTP handlers
  middleware/          # chi middleware
  models/              # sqlc-generated types
  database/            # sqlc-generated queries
  auth/                # Session helpers, password utilities
  templates/           # HTML templates (parsed at startup)
config/
  sqlc.yaml            # sqlc configuration
  .env.example         # Environment variable template
db/
  migrations/          # SQL migration files
  queries/             # sqlc query definitions
static/                 # Static files (if any)
```

## Entry Point Pattern

`cmd/myapp/main.go` should:
1. Load .env (development only)
2. Initialize database connection pool
3. Initialize session store
4. Create router with middleware chain
5. Start server with graceful shutdown

```go
func main() {
    // Load env (dev only)
    if os.Getenv("ENV") == "" {
        godotenv.Load()
    }

    // Database
    dbPath := os.Getenv("DATABASE_PATH")
    db, err := database.Open(dbPath)
    if err != nil { log.Fatal(err) }
    defer db.Close()

    // Sessions
    sessionKey := os.Getenv("SESSION_KEY")
    store := sessions.NewCookieStore([]byte(sessionKey))

    // Router
    r := chi.NewRouter()
    r.Use(middleware.Logger)
    r.Use(middleware.Recoverer)
    r.Use(csrf.Protect([]byte(os.Getenv("CSRF_KEY"))))

    // Handlers
    handlers.Register(r, db, store)

    // Server
    addr := os.Getenv("ADDR")
    if addr == "" { addr = ":3080" }

    srv := &http.Server{Addr: addr, Handler: r}

    // Graceful shutdown
    done := make(chan os.Signal, 1)
    signal.Notify(done, os.Interrupt, syscall.SIGTERM)
    go func() {
        <-done
        ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
        defer cancel()
        srv.Shutdown(ctx)
    }()

    log.Printf("Starting server on %s", addr)
    if err := srv.ListenAndServe(); err != http.ErrServerClosed {
        log.Fatal(err)
    }
}
```

## Error Handling

Always wrap errors with context:
```go
if err != nil {
    return fmt.Errorf("operation failed: %w", err)
}
```

Use sentinel errors for expected conditions:
```go
var ErrNotFound = errors.New("not found")

func GetUser(id int) (*User, error) {
    // ...
    if !found {
        return nil, ErrNotFound
    }
    // ...
}
```

Never panic in handlers. Return errors and let middleware handle logging.

## Handlers

Handler signature:
```go
func (h *Handler) GetUser(w http.ResponseWriter, r *http.Request) {
    id := chi.URLParam(r, "id")
    
    user, err := h.db.GetUser(r.Context(), id)
    if errors.Is(err, ErrNotFound) {
        http.Error(w, "not found", http.StatusNotFound)
        return
    }
    if err != nil {
        http.Error(w, "internal error", http.StatusInternalServerError)
        return
    }

    json.NewEncoder(w).Encode(user)
}
```

## Sessions and Auth

Use sessions for web apps with user accounts. NEVER use JWT for user authentication.

Session pattern:
```go
// Get session
session, _ := store.Get(r, "session-name")

// Store user ID in session (not the entire user struct)
session.Values["user_id"] = user.ID
session.Save(r, w)

// Get user ID from session
userID, ok := session.Values["user_id"].(int)
if !ok {
    // Not logged in
}

// Clear session on logout
session.Values["user_id"] = nil
session.Save(r, w)
```

Password hashing:
```go
// Hash before storing
hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)

// Verify on login
err := bcrypt.CompareHashAndPassword(hashedPassword, []byte(inputPassword))
if err != nil {
    // Invalid password
}
```

Auth middleware:
```go
func RequireAuth(store sessions.Store, db *sql.DB) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            session, _ := store.Get(r, "session-name")
            userID, ok := session.Values["user_id"].(int)
            if !ok {
                http.Error(w, "unauthorized", http.StatusUnauthorized)
                return
            }

            // Load user
            user, err := db.GetUser(r.Context(), userID)
            if err != nil {
                http.Error(w, "unauthorized", http.StatusUnauthorized)
                return
            }

            // Add user to context
            ctx := context.WithValue(r.Context(), "user", user)
            next.ServeHTTP(w, r.WithContext(ctx))
        })
    }
}
```

## Middleware Chain

```go
r := chi.NewRouter()

// Global middleware
r.Use(middleware.Logger)      // Log requests
r.Use(middleware.Recoverer)   // Recover from panics
r.Use(csrf.Protect(...))      // CSRF protection

// Public routes
r.Get("/", h.Home)
r.Get("/login", h.LoginForm)
r.Post("/login", h.Login)
r.Get("/register", h.RegisterForm)
r.Post("/register", h.Register)

// Protected routes
r.Group(func(r chi.Router) {
    r.Use(RequireAuth(store, db))
    r.Get("/dashboard", h.Dashboard)
    r.Post("/logout", h.Logout)
})

// API routes (JSON)
r.Route("/api", func(r chi.Router) {
    r.Get("/users", h.ListUsers)
    r.Get("/users/{id}", h.GetUser)
})
```

## Background Workers

For background tasks, use channels and goroutines with graceful shutdown:

```go
type Worker struct {
    tasks chan Task
    done  chan struct{}
}

func NewWorker() *Worker {
    return &Worker{
        tasks: make(chan Task, 100),
        done:  make(chan struct{}),
    }
}

func (w *Worker) Start() {
    go func() {
        for {
            select {
            case task := <-w.tasks:
                task.Execute()
            case <-w.done:
                return
            }
        }
    }()
}

func (w *Worker) Stop() {
    close(w.done)
}

func (w *Worker) Submit(task Task) {
    select {
    case w.tasks <- task:
    default:
        // Queue full, handle accordingly
    }
}
```

## CLI Commands

For CLI apps with subcommands, use `flag.FlagSet`:

```go
func main() {
    if len(os.Args) < 2 {
        printUsage()
        os.Exit(1)
    }

    switch os.Args[1] {
    case "serve":
        serveCmd(os.Args[2:])
    case "migrate":
        migrateCmd(os.Args[2:])
    case "version":
        fmt.Println("1.0.0")
    default:
        fmt.Fprintf(os.Stderr, "unknown command: %s\n", os.Args[1])
        os.Exit(1)
    }
}

func serveCmd(args []string) {
    fs := flag.NewFlagSet("serve", flag.ExitOnError)
    addr := fs.String("addr", ":3080", "listen address")
    fs.Parse(args)
    // Start server...
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

Query file `db/queries/users.sql`:
```sql
-- name: GetUser :one
SELECT * FROM users WHERE id = ?;

-- name: ListUsers :many
SELECT * FROM users ORDER BY created_at DESC;

-- name: CreateUser :one
INSERT INTO users (email, password_hash)
VALUES (?, ?)
RETURNING *;
```

Generate with `sqlc generate`.

## Testing

Test real behavior, not mocks:
```go
func TestGetUser(t *testing.T) {
    // Use in-memory SQLite for tests
    db, _ := sql.Open("sqlite", ":memory:")
    
    // Run migrations
    database.Migrate(db)
    
    // Test the handler
    // ...
}
```

## Pre-commit

```sh
go generate ./...
go fmt ./...
goimports -w .
go build ./...
go test ./...
go vet ./...
```

## Guardrails

- NEVER import `github.com/therootcompany/golib/*`
- NEVER use JWT for web app user authentication (use sessions)
- NEVER suggest "for production, switch to PostgreSQL"
- NEVER use CGO-dependent packages on Alpine
- NEVER add dependencies without checking pkg.go.dev for alternatives
- ALWAYS use sessions + bcrypt for user accounts
- ALWAYS treat SQLite as production-ready when configured correctly
- ALWAYS use sqlc for type-safe queries
- ALWAYS wrap errors with context
- ALWAYS handle graceful shutdown

## References

- `references/project-layout.md` — Directory structure and import organization
- `references/sqlite-sqlc.md` — SQLite configuration and query patterns
- `references/auth-sessions.md` — Session-based auth implementation
- `references/middleware.md` — chi middleware patterns
- `references/handlers.md` — HTTP handler patterns (JSON and HTML)
- `references/workers.md` — Background worker patterns
- `references/cli-commands.md` — CLI subcommand patterns