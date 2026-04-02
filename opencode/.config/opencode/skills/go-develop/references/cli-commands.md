# CLI Commands

Patterns for command-line applications with subcommands.

## Basic CLI Structure

Use `flag.FlagSet` for subcommands (not global `flag`):

```go
package main

import (
    "flag"
    "fmt"
    "os"
)

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
        versionCmd()
    case "help":
        helpCmd()
    default:
        fmt.Fprintf(os.Stderr, "unknown command: %s\n", os.Args[1])
        printUsage()
        os.Exit(1)
    }
}

func printUsage() {
    fmt.Println("myapp - a web application")
    fmt.Println()
    fmt.Println("Usage:")
    fmt.Println("  myapp <command> [options]")
    fmt.Println()
    fmt.Println("Commands:")
    fmt.Println("  serve     Start the HTTP server")
    fmt.Println("  migrate   Run database migrations")
    fmt.Println("  version   Print version")
    fmt.Println("  help      Show this help")
}
```

## Serve Command

```go
func serveCmd(args []string) {
    fs := flag.NewFlagSet("serve", flag.ExitOnError)
    
    addr := fs.String("addr", ":3080", "listen address")
    dbPath := fs.String("db", "./data.db", "database path")
    env := fs.String("env", "development", "environment (development|production)")
    
    if err := fs.Parse(args); err != nil {
        fmt.Fprintf(os.Stderr, "error parsing flags: %v\n", err)
        os.Exit(1)
    }

    fmt.Printf("Starting server on %s\n", *addr)
    fmt.Printf("Database: %s\n", *dbPath)
    fmt.Printf("Environment: %s\n", *env)

    // Start server...
}
```

## Migrate Command

```go
func migrateCmd(args []string) {
    fs := flag.NewFlagSet("migrate", flag.ExitOnError)
    
    dbPath := fs.String("db", "./data.db", "database path")
    direction := fs.String("direction", "up", "migration direction (up|down)")
    
    if err := fs.Parse(args); err != nil {
        fmt.Fprintf(os.Stderr, "error parsing flags: %v\n", err)
        os.Exit(1)
    }

    db, err := sql.Open("sqlite", *dbPath)
    if err != nil {
        fmt.Fprintf(os.Stderr, "opening database: %v\n", err)
        os.Exit(1)
    }
    defer db.Close()

    switch *direction {
    case "up":
        if err := database.Migrate(db); err != nil {
            fmt.Fprintf(os.Stderr, "migration failed: %v\n", err)
            os.Exit(1)
        }
        fmt.Println("Migrations applied successfully")
    case "down":
        fmt.Fprintln(os.Stderr, "down migrations not implemented")
        os.Exit(1)
    default:
        fmt.Fprintf(os.Stderr, "unknown direction: %s\n", *direction)
        os.Exit(1)
    }
}
```

## Version Command

```go
var (
    Version   = "dev"
    BuildTime = "unknown"
)

func versionCmd() {
    fmt.Printf("myapp %s\n", Version)
    fmt.Printf("Built: %s\n", BuildTime)
}
```

Build with version info:
```bash
go build -ldflags "-X main.Version=1.0.0 -X main.BuildTime=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

## Help Command

```go
func helpCmd() {
    fmt.Println("myapp - a web application")
    fmt.Println()
    fmt.Println("Usage:")
    fmt.Println("  myapp <command> [options]")
    fmt.Println()
    fmt.Println("Commands:")
    fmt.Println("  serve     Start the HTTP server")
    fmt.Println("  migrate   Run database migrations")
    fmt.Println("  version   Print version")
    fmt.Println()
    fmt.Println("Use 'myapp <command> -help' for command-specific help.")
}
```

## Subcommand Help

Handle `-h`, `-help`, `--help` consistently:

```go
func serveCmd(args []string) {
    fs := flag.NewFlagSet("serve", flag.ExitOnError)
    
    addr := fs.String("addr", ":3080", "listen address")
    dbPath := fs.String("db", "./data.db", "database path")
    env := fs.String("env", "development", "environment")
    
    // Handle help before parsing
    for _, arg := range args {
        if arg == "-h" || arg == "-help" || arg == "--help" {
            fmt.Println("Usage: myapp serve [options]")
            fmt.Println()
            fmt.Println("Options:")
            fs.SetOutput(os.Stdout)
            fs.PrintDefaults()
            os.Exit(0)
        }
    }

    fs.Parse(args)
    // ... continue with serve logic
}
```

## Command with Positional Arguments

```go
func createUserCmd(args []string) {
    fs := flag.NewFlagSet("create-user", flag.ExitOnError)
    role := fs.String("role", "user", "user role (user|admin)")
    
    fs.Parse(args)
    
    // Remaining args
    remaining := fs.Args()
    if len(remaining) < 2 {
        fmt.Fprintln(os.Stderr, "Usage: myapp create-user [options] <email> <password>")
        fs.PrintDefaults()
        os.Exit(1)
    }

    email := remaining[0]
    password := remaining[1]

    fmt.Printf("Creating user: %s\n", email)
    fmt.Printf("Role: %s\n", *role)
    // ... create user
}
```

## Environment Variables with Flags

Allow both flags and env vars:

```go
func serveCmd(args []string) {
    fs := flag.NewFlagSet("serve", flag.ExitOnError)
    
    addr := fs.String("addr", os.Getenv("ADDR"), "listen address (default :3080)")
    dbPath := fs.String("db", os.Getenv("DATABASE_PATH"), "database path (default ./data.db)")
    
    // Set defaults if empty
    if *addr == "" {
        *addr = ":3080"
    }
    if *dbPath == "" {
        *dbPath = "./data.db"
    }
    
    fs.Parse(args)
    // ...
}
```

## Loading .env

```go
import "github.com/joho/godotenv"

func main() {
    // Load .env in development
    env := os.Getenv("ENV")
    if env == "" || env == "development" {
        if err := godotenv.Load(); err != nil {
            // .env file is optional
        }
    }

    // Now use os.Getenv for all config
    addr := os.Getenv("ADDR")
    if addr == "" {
        addr = ":3080"
    }

    // ... continue
}
```

## Full Example

```go
package main

import (
    "database/sql"
    "flag"
    "fmt"
    "log"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"

    "github.com/go-chi/chi/v5"
    "github.com/go-chi/chi/v5/middleware"
    "github.com/joho/godotenv"
    _ "modernc.org/sqlite"
)

var (
    Version   = "dev"
    BuildTime = "unknown"
)

func main() {
    // Load .env
    if os.Getenv("ENV") == "" {
        godotenv.Load()
    }

    if len(os.Args) < 2 {
        printUsage()
        os.Exit(1)
    }

    cmd := os.Args[1]
    args := os.Args[2:]

    switch cmd {
    case "serve":
        serveCmd(args)
    case "migrate":
        migrateCmd(args)
    case "version":
        versionCmd()
    case "help":
        helpCmd()
    default:
        fmt.Fprintf(os.Stderr, "unknown command: %s\n", cmd)
        printUsage()
        os.Exit(1)
    }
}

func printUsage() {
    fmt.Println("myapp - a web application")
    fmt.Println()
    fmt.Println("Usage: myapp <command> [options]")
    fmt.Println()
    fmt.Println("Commands:")
    fmt.Println("  serve     Start the HTTP server")
    fmt.Println("  migrate   Run database migrations")
    fmt.Println("  version   Print version")
    fmt.Println("  help      Show this help")
}

func serveCmd(args []string) {
    fs := flag.NewFlagSet("serve", flag.ExitOnError)
    
    addr := fs.String("addr", getEnv("ADDR", ":3080"), "listen address")
    dbPath := fs.String("db", getEnv("DATABASE_PATH", "./data.db"), "database path")
    
    // Handle help
    for _, arg := range args {
        if arg == "-h" || arg == "-help" || arg == "--help" {
            fmt.Println("Usage: myapp serve [options]")
            fmt.Println()
            fmt.Println("Options:")
            fs.SetOutput(os.Stdout)
            fs.PrintDefaults()
            os.Exit(0)
        }
    }
    
    fs.Parse(args)

    // Open database
    db, err := sql.Open("sqlite", *dbPath)
    if err != nil {
        log.Fatal("opening database: ", err)
    }
    defer db.Close()

    // Setup router
    r := chi.NewRouter()
    r.Use(middleware.Logger)
    r.Use(middleware.Recoverer)

    r.Get("/", func(w http.ResponseWriter, r *http.Request) {
        w.Write([]byte("Hello, World!"))
    })

    // Server
    srv := &http.Server{
        Addr:    *addr,
        Handler: r,
    }

    // Graceful shutdown
    done := make(chan os.Signal, 1)
    signal.Notify(done, os.Interrupt, syscall.SIGTERM)
    
    go func() {
        log.Printf("Starting server on %s", *addr)
        if err := srv.ListenAndServe(); err != http.ErrServerClosed {
            log.Fatal("server error: ", err)
        }
    }()
    
    <-done
    log.Println("Shutting down...")
    
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()
    srv.Shutdown(ctx)
}

func migrateCmd(args []string) {
    fs := flag.NewFlagSet("migrate", flag.ExitOnError)
    dbPath := fs.String("db", getEnv("DATABASE_PATH", "./data.db"), "database path")
    
    fs.Parse(args)

    db, err := sql.Open("sqlite", *dbPath)
    if err != nil {
        log.Fatal("opening database: ", err)
    }
    defer db.Close()

    // Run migrations
    if err := database.Migrate(db); err != nil {
        log.Fatal("migration failed: ", err)
    }
    
    fmt.Println("Migrations applied successfully")
}

func versionCmd() {
    fmt.Printf("myapp %s\n", Version)
    fmt.Printf("Built: %s\n", BuildTime)
}

func helpCmd() {
    printUsage()
}

func getEnv(key, defaultVal string) string {
    if val := os.Getenv(key); val != "" {
        return val
    }
    return defaultVal
}
```

## Flag Reservations

| Flag | Reserved For |
|------|-------------|
| `-h` | Help (not `--help`) |
| `-v` | Verbose (not `--version`) |
| `-V`, `-version`, `--version`, `version` | Print version and exit |
| `help`, `-help`, `--help` | Print usage |

## Guardrails

- Use `flag.NewFlagSet` (never global `flag`)
- Handle `-h`, `-help`, `--help` before parsing flags
- Reserve `-v` for verbose, `-V` for version
- Allow both flags and environment variables for configuration
- Provide sensible defaults