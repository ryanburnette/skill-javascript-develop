---
name: write-http-handlers
description: HTTP routing and middleware patterns with chi. Use when writing handlers, routes, or middleware.
---

## Production-first

Build for production from the start. Error handling, logging, auth, graceful shutdown are part of initial implementation, not polish.

## Router Setup

```go
import "github.com/go-chi/chi/v5"
import "github.com/go-chi/chi/v5/middleware"

func main() {
    r := chi.NewRouter()
    
    // Global middleware
    r.Use(middleware.Logger)
    r.Use(middleware.Recoverer)
    r.Use(middleware.RequestID)
    
    // Routes
    r.Get("/", homeHandler)
    r.Get("/users", listUsers)
    r.Get("/users/{id}", getUser)
    r.Post("/users", createUser)
    
    http.ListenAndServe(":3080", r)
}
```

## Route Groups

```go
// Public routes
r.Get("/", h.Home)
r.Post("/login", h.Login)
r.Post("/register", h.Register)

// Protected routes
r.Group(func(r chi.Router) {
    r.Use(RequireAuth)
    r.Get("/dashboard", h.Dashboard)
    r.Post("/logout", h.Logout)
})

// API routes
r.Route("/api", func(r chi.Router) {
    r.Get("/users", h.ListUsers)
    r.Get("/users/{id}", h.GetUser)
})

// Nested routes
r.Route("/api/v1", func(r chi.Router) {
    r.Get("/users", h.ListUsers)
    r.Get("/users/{id}", h.GetUser)
})
```

## Middleware Chain

Middleware wraps handlers. Each middleware decides whether to pass the request to the next handler.

```go
// Middleware signature
func MyMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // Before handler
        next.ServeHTTP(w, r)
        // After handler
    })
}

// Create middleware
func Logger(logger *slog.Logger) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            start := time.Now()
            next.ServeHTTP(w, r)
            logger.Info("request",
                "method", r.Method,
                "path", r.URL.Path,
                "duration", time.Since(start),
            )
        })
    }
}

// Use middleware
r.Use(Logger(logger))
r.Use(middleware.Recoverer)
```

## Path Parameters

```go
// Define route with parameter
r.Get("/users/{id}", getUser)

// Get parameter in handler
func getUser(w http.ResponseWriter, r *http.Request) {
    id := chi.URLParam(r, "id")
    // ...
}
```

## Handler Struct Pattern

Group handlers and dependencies in a struct:

```go
type Handler struct {
    db      *sql.DB
    queries *database.Queries
    store   sessions.Store
}

func (h *Handler) GetUser(w http.ResponseWriter, r *http.Request) {
    id := chi.URLParam(r, "id")
    user, err := h.queries.GetUser(r.Context(), id)
    if err != nil {
        http.Error(w, "not found", http.StatusNotFound)
        return
    }
    json.NewEncoder(w).Encode(user)
}

// Register routes
func Register(r chi.Router, h *Handler) {
    r.Get("/users", h.ListUsers)
    r.Get("/users/{id}", h.GetUser)
    r.Post("/users", h.CreateUser)
}
```

## Error Handling

```go
func (h *Handler) GetUser(w http.ResponseWriter, r *http.Request) {
    id := chi.URLParam(r, "id")
    
    user, err := h.queries.GetUser(r.Context(), id)
    
    // Not found
    if err == sql.ErrNoRows {
        respondError(w, "user not found", http.StatusNotFound)
        return
    }
    
    // Internal error
    if err != nil {
        slog.Error("getting user", "id", id, "error", err)
        respondError(w, "internal error", http.StatusInternalServerError)
        return
    }
    
    respondJSON(w, user)
}

func respondJSON(w http.ResponseWriter, data interface{}) {
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(data)
}

func respondError(w http.ResponseWriter, message string, status int) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(status)
    json.NewEncoder(w).Encode(map[string]string{"error": message})
}
```

## API Response Structure

NEVER return bare arrays or bare objects. Always wrap responses in a Result structure:

```go
type Timing struct {
    Action    string  `json:"action"`     // e.g., "db_query", "api_call"
    Items     int     `json:"items"`      // number of items fetched/affected
    SizeBytes int64   `json:"size_bytes"` // payload size (if applicable)
    Batch     bool    `json:"batch"`      // true if batch operation, false if single
    Duration  float64 `json:"duration_ms"` // time in milliseconds (rounded)
}

type Result struct {
    Error   *string  `json:"error,omitempty"`   // error message if failed
    Code    *int     `json:"code,omitempty"`    // error code if failed
    Result  any      `json:"result"`            // payload (nil on error)
    Timings []Timing `json:"timings"`            // performance metrics
}

func respondResult(w http.ResponseWriter, result any, timings []Timing) {
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(Result{
        Result:  result,
        Timings: timings,
    })
}

func respondError(w http.ResponseWriter, message string, code int, timings []Timing) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(code)
    json.NewEncoder(w).Encode(Result{
        Error:   &message,
        Code:    &code,
        Timings: timings,
    })
}

// Track timing for any operation
func trackTiming(action string, batch bool, items int, sizeBytes int64, start time.Time) Timing {
    return Timing{
        Action:    action,
        Items:     items,
        SizeBytes: sizeBytes,
        Batch:     batch,
        Duration:  float64(time.Since(start).Microseconds()) / 1000.0,
    }
}
```

Example handler with full timing:

```go
func (h *Handler) ListUsers(w http.ResponseWriter, r *http.Request) {
    var timings []Timings
    
    start := time.Now()
    users, err := h.queries.ListUsers(r.Context())
    if err != nil {
        timings = append(timings, trackTiming("db_list_users", true, 0, 0, start))
        respondError(w, "failed to fetch users", http.StatusInternalServerError, timings)
        return
    }
    
    timings = append(timings, trackTiming("db_list_users", true, len(users), 0, start))
    
    // Calculate size if needed
    sizeBytes := int64(0)
    for _, u := range users {
        b, _ := json.Marshal(u)
        sizeBytes += int64(len(b))
    }
    
    respondResult(w, users, timings)
}
```

For CSV/file downloads, use `X-Timings` header instead:

```go
w.Header().Set("X-Timings", `db_query:45items:batch:true:12.3ms`)
```

## TSV Endpoint

```go
import "github.com/jszwec/csvutil"

func (h *Handler) ListUsersTSV(w http.ResponseWriter, r *http.Request) {
    users, err := h.queries.ListUsers(r.Context())
    if err != nil {
        http.Error(w, "internal error", http.StatusInternalServerError)
        return
    }

    w.Header().Set("Content-Type", "text/tab-separated-values; charset=utf-8")
    w.Header().Set("Content-Disposition", "attachment; filename=users.tsv")

    enc := csvutil.NewEncoder(w)
    enc.Delimiter = '\t'
    for _, user := range users {
        if err := enc.Encode(user); err != nil {
            slog.Error("encoding user", "error", err)
            return
        }
    }
}
```

## Testing

Prefer real code over mocks. Test actual behavior — real DB queries, real handler logic — not fakes.

```go
func TestGetUser(t *testing.T) {
    // Use in-memory SQLite
    db, _ := sql.Open("sqlite", ":memory:")
    database.Migrate(db)
    queries := database.New(db)

    h := &Handler{db: db, queries: queries}

    // Create test user
    queries.CreateUser(context.Background(), database.CreateUserParams{
        Email:        "test@example.com",
        PasswordHash: "hashed",
        CreatedAt:    time.Now(),
    })

    // Test handler
    r := httptest.NewRequest("GET", "/users/1", nil)
    w := httptest.NewRecorder()

    h.GetUser(w, r)

    if w.Code != http.StatusOK {
        t.Errorf("expected 200, got %d", w.Code)
    }
}
```

## Guardrails

- ALWAYS use chi.Router for routing (not global http.ServeMux)
- ALWAYS log errors, never silently ignore them
- NEVER panic in handlers
- NEVER expose internal error details to clients
- NEVER return bare arrays or bare objects as API responses — always wrap in Result
- ALWAYS include `timings` array in every API response
- ALWAYS track timing for every db query, API call, or significant operation
- Use context for request-scoped values