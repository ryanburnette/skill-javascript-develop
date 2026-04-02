# Middleware Patterns

chi middleware patterns for production apps.

## Middleware Signature

chi middleware wraps handlers:

```go
type Middleware func(http.Handler) http.Handler

// Example
func MyMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // Before handler
        next.ServeHTTP(w, r)
        // After handler
    })
}
```

## Built-in chi Middleware

```go
import "github.com/go-chi/chi/v5/middleware"

r := chi.NewRouter()

// Request logging
r.Use(middleware.Logger)

// Panic recovery
r.Use(middleware.Recoverer)

// Request ID (adds X-Request-ID header)
r.Use(middleware.RequestID)

// Timeout
r.Use(middleware.Timeout(60 * time.Second))

// Real IP (from X-Forwarded-For or X-Real-IP)
r.Use(middleware.RealIP)
```

## Custom Logging

```go
func Logging(logger *slog.Logger) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            start := time.Now()

            // Wrap response writer to capture status
            ww := &responseWriter{ResponseWriter: w, status: http.StatusOK}

            next.ServeHTTP(ww, r)

            logger.Info("request",
                "method", r.Method,
                "path", r.URL.Path,
                "status", ww.status,
                "duration", time.Since(start),
                "remote", r.RemoteAddr,
            )
        })
    }
}

type responseWriter struct {
    http.ResponseWriter
    status int
}

func (rw *responseWriter) WriteHeader(code int) {
    rw.status = code
    rw.ResponseWriter.WriteHeader(code)
}
```

## Panic Recovery

```go
func Recoverer(logger *slog.Logger) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            defer func() {
                if rvr := recover(); rvr != nil {
                    logger.Error("panic recovered",
                        "error", rvr,
                        "path", r.URL.Path,
                        "method", r.Method,
                    )
                    http.Error(w, "Internal Server Error", http.StatusInternalServerError)
                }
            }()
            next.ServeHTTP(w, r)
        })
    }
}
```

## Auth Middleware

```go
func RequireAuth(store sessions.Store, queries *database.Queries) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            session, err := store.Get(r, "myapp-session")
            if err != nil {
                http.Error(w, "unauthorized", http.StatusUnauthorized)
                return
            }

            userID, ok := session.Values["user_id"].(int64)
            if !ok {
                http.Error(w, "unauthorized", http.StatusUnauthorized)
                return
            }

            user, err := queries.GetUser(r.Context(), userID)
            if err != nil {
                http.Error(w, "unauthorized", http.StatusUnauthorized)
                return
            }

            // Add to context
            ctx := context.WithValue(r.Context(), "user", user)
            next.ServeHTTP(w, r.WithContext(ctx))
        })
    }
}
```

## Role-based Access

```go
func RequireRole(roles ...string) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            user, ok := r.Context().Value("user").(*database.User)
            if !ok || user == nil {
                http.Error(w, "unauthorized", http.StatusUnauthorized)
                return
            }

            // Check if user has required role
            for _, role := range roles {
                if user.Role == role {
                    next.ServeHTTP(w, r)
                    return
                }
            }

            http.Error(w, "forbidden", http.StatusForbidden)
        })
    }
}

// Usage
r.Group(func(r chi.Router) {
    r.Use(RequireAuth(store, queries))
    r.Use(RequireRole("admin"))
    r.Get("/admin", h.AdminDashboard)
})
```

## CORS

```go
func CORS origins []string) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            origin := r.Header.Get("Origin")
            
            // Check if origin is allowed
            allowed := false
            for _, o := range origins {
                if o == origin || o == "*" {
                    allowed = true
                    break
                }
            }

            if allowed {
                w.Header().Set("Access-Control-Allow-Origin", origin)
                w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
                w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
                w.Header().Set("Access-Control-Allow-Credentials", "true")
            }

            // Handle preflight
            if r.Method == "OPTIONS" {
                w.WriteHeader(http.StatusOK)
                return
            }

            next.ServeHTTP(w, r)
        })
    }
}
```

## Rate Limiting

Simple in-memory rate limiting:

```go
import "golang.org/x/time/rate"

func RateLimiter() func(http.Handler) http.Handler {
    limiters := make(map[string]*rate.Limiter)
    mu := sync.Mutex{}

    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            key := r.RemoteAddr // or user ID, API key, etc.

            mu.Lock()
            limiter, exists := limiters[key]
            if !exists {
                limiter = rate.NewLimiter(10, 20) // 10 req/s, burst 20
                limiters[key] = limiter
            }
            mu.Unlock()

            if !limiter.Allow() {
                http.Error(w, "rate limit exceeded", http.StatusTooManyRequests)
                return
            }

            next.ServeHTTP(w, r)
        })
    }
}
```

## Middleware Chain

Order matters. Typical order:

```go
r := chi.NewRouter()

// 1. Request ID (first, for logging)
r.Use(middleware.RequestID)

// 2. Logging
r.Use(middleware.Logger)

// 3. Panic recovery
r.Use(middleware.Recoverer)

// 4. CORS (before auth)
r.Use(CORS([]string{"https://example.com"}))

// 5. CSRF (for HTML forms)
r.Use(csrf.Protect([]byte(csrfKey)))

// Public routes
r.Get("/", h.Home)
r.Post("/login", h.Login)

// Protected routes (auth middleware applied here)
r.Group(func(r chi.Router) {
    r.Use(RequireAuth(store, queries))
    r.Get("/dashboard", h.Dashboard)
})

// Admin routes (additional middleware)
r.Group(func(r chi.Router) {
    r.Use(RequireAuth(store, queries))
    r.Use(RequireRole("admin"))
    r.Get("/admin", h.Admin)
})
```

## Middleware Context Values

Pass data through middleware:

```go
// Store value
func SetUser(user *database.User) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            ctx := context.WithValue(r.Context(), "user", user)
            next.ServeHTTP(w, r.WithContext(ctx))
        })
    }
}

// Retrieve value
func GetUser(r *http.Request) *database.User {
    user, _ := r.Context().Value("user").(*database.User)
    return user
}

// In handler
func (h *Handler) Dashboard(w http.ResponseWriter, r *http.Request) {
    user := GetUser(r)
    fmt.Fprintf(w, "Hello, %s", user.Email)
}
```

## Guardrails

- ALWAYS recover from panics in middleware
- ALWAYS log errors, not just panics
- NEVER panic in middleware
- NEVER store sensitive data in context values that could leak
- Use context values for request-scoped data only