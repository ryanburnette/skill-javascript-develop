# Project Layout

Standard Go project structure for web apps, APIs, and CLI tools.

## Directory Structure

```
myapp/
├── cmd/
│   └── myapp/
│       └── main.go          # Entry point
├── internal/
│   ├── handlers/            # HTTP handlers
│   │   ├── user.go
│   │   ├── auth.go
│   │   └── handlers.go     # Register function
│   ├── middleware/          # chi middleware
│   │   ├── auth.go
│   │   └── logging.go
│   ├── models/              # Domain types (not sqlc-generated)
│   │   └── user.go
│   ├── database/            # sqlc-generated (do not edit)
│   │   ├── db.go
│   │   ├── models.go
│   │   └── users.sql.go
│   ├── auth/                # Auth helpers
│   │   ├── session.go
│   │   └── password.go
│   └── templates/           # Parsed templates
│       └── templates.go
├── config/
│   ├── sqlc.yaml            # sqlc configuration
│   └── .env.example         # Environment variable template
├── db/
│   ├── migrations/          # SQL migrations
│   │   ├── 001_users.sql
│   │   └── 002_sessions.sql
│   └── queries/             # sqlc queries
│       └── users.sql
├── static/                  # Static files (if any)
│   ├── css/
│   └── js/
├── templates/               # HTML templates
│   ├── layout.html
│   ├── login.html
│   └── dashboard.html
├── go.mod
├── go.sum
├── Makefile                 # Optional build commands
└── README.md
```

## Import Organization

Group imports in this order:

```go
package handlers

import (
    // Standard library
    "context"
    "database/sql"
    "encoding/json"
    "net/http"

    // Third-party packages
    "github.com/go-chi/chi/v5"
    "github.com/gorilla/sessions"

    // Local packages
    "myapp/internal/database"
    "myapp/internal/models"
)
```

## main.go Pattern

```go
package main

import (
    "context"
    "log"
    "log/slog"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"

    "github.com/go-chi/chi/v5"
    "github.com/go-chi/chi/v5/middleware"
    "github.com/gorilla/csrf"
    "github.com/gorilla/sessions"
    "github.com/joho/godotenv"
    _ "modernc.org/sqlite"

    "myapp/internal/database"
    "myapp/internal/handlers"
)

func main() {
    // Load .env in development
    if os.Getenv("ENV") == "" {
        godotenv.Load()
    }

    // Setup logging
    logger := slog.New(slog.NewTextHandler(os.Stdout, nil))
    slog.SetDefault(logger)

    // Database
    dbPath := os.Getenv("DATABASE_PATH")
    if dbPath == "" {
        dbPath = "./data.db"
    }

    db, err := database.Open(dbPath)
    if err != nil {
        log.Fatal("opening database: ", err)
    }
    defer db.Close()

    // Sessions
    sessionKey := os.Getenv("SESSION_KEY")
    if sessionKey == "" {
        log.Fatal("SESSION_KEY is required")
    }
    store := sessions.NewCookieStore([]byte(sessionKey))

    // CSRF
    csrfKey := os.Getenv("CSRF_KEY")
    if csrfKey == "" {
        log.Fatal("CSRF_KEY is required")
    }

    // Router
    r := chi.NewRouter()
    r.Use(middleware.Logger)
    r.Use(middleware.Recoverer)
    r.Use(csrf.Protect([]byte(csrfKey)))

    // Handlers
    handlers.Register(r, db, store)

    // Server
    addr := os.Getenv("ADDR")
    if addr == "" {
        addr = ":3080"
    }

    srv := &http.Server{
        Addr:    addr,
        Handler: r,
    }

    // Graceful shutdown
    done := make(chan os.Signal, 1)
    signal.Notify(done, os.Interrupt, syscall.SIGTERM)

    go func() {
        <-done
        log.Println("Shutting down...")

        ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
        defer cancel()

        if err := srv.Shutdown(ctx); err != nil {
            log.Println("Shutdown error:", err)
        }
    }()

    log.Printf("Starting server on %s", addr)
    if err := srv.ListenAndServe(); err != http.ErrServerClosed {
        log.Fatal("Server error: ", err)
    }
}
```

## Environment Variables

`.env.example`:
```
ENV=development
ADDR=:3080
DATABASE_PATH=./data.db
SESSION_KEY=your-32-byte-session-secret-here
CSRF_KEY=your-32-byte-csrf-secret-here
```

Generate secrets:
```bash
# Generate 32 random bytes (base64 encoded)
openssl rand -base64 32
```

## Package Naming

- Package name matches directory name
- No `package api`, `package handler`, etc. — use specific names
- `package handlers` (plural) for handler collection
- `package database` for sqlc-generated code
- `package auth` for auth utilities