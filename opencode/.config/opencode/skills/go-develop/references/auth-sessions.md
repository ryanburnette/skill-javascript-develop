# Auth with Sessions

Session-based authentication for web apps with user accounts. Use this, NOT JWT, for web apps.

## Why Sessions, Not JWT

| Sessions | JWT |
|----------|-----|
| Stored server-side | Stored client-side |
| Easy to revoke | Hard to revoke (needs blacklist) |
| Simple logout | Requires refresh tokens |
| Built-in CSRF protection | Manual CSRF handling |
| `gorilla/sessions` handles everything | You manage tokens |

JWT is for: stateless APIs, service-to-service auth, mobile apps.
Sessions are for: web apps with user accounts.

## Setup

### Install

```bash
go get github.com/gorilla/sessions
go get golang.org/x/crypto/bcrypt
go get github.com/gorilla/csrf
```

### Environment

```bash
# Generate secrets (32 bytes each)
openssl rand -base64 32

# .env
SESSION_KEY=your-base64-encoded-session-key
CSRF_KEY=your-base64-encoded-csrf-key
```

### Session Store

```go
package auth

import (
    "github.com/gorilla/sessions"
)

const SessionName = "myapp-session"

func NewStore(sessionKey []byte) sessions.Store {
    store := sessions.NewCookieStore(sessionKey)
    store.Options = &sessions.Options{
        Path:     "/",
        MaxAge:   86400 * 7, // 7 days
        HttpOnly: true,
        Secure:   true,      // Set false for development
        SameSite: http.SameSiteLaxMode,
    })
    return store
}
```

## Password Handling

### Hashing

```go
package auth

import "golang.org/x/crypto/bcrypt"

func HashPassword(password string) (string, error) {
    bytes, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
    return string(bytes), err
}

func CheckPassword(password, hash string) bool {
    err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
    return err == nil
}
```

### Login Handler

```go
func (h *Handler) Login(w http.ResponseWriter, r *http.Request) {
    var req struct {
        Email    string `json:"email"`
        Password string `json:"password"`
    }
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, "invalid request", http.StatusBadRequest)
        return
    }

    // Get user by email
    user, err := h.db.GetUserByEmail(r.Context(), req.Email)
    if err == sql.ErrNoRows {
        http.Error(w, "invalid credentials", http.StatusUnauthorized)
        return
    }
    if err != nil {
        http.Error(w, "internal error", http.StatusInternalServerError)
        return
    }

    // Verify password
    if !auth.CheckPassword(req.Password, user.PasswordHash) {
        http.Error(w, "invalid credentials", http.StatusUnauthorized)
        return
    }

    // Create session
    session, _ := h.store.Get(r, auth.SessionName)
    session.Values["user_id"] = user.ID
    if err := session.Save(r, w); err != nil {
        http.Error(w, "internal error", http.StatusInternalServerError)
        return
    }

    json.NewEncoder(w).Encode(user)
}
```

### Logout Handler

```go
func (h *Handler) Logout(w http.ResponseWriter, r *http.Request) {
    session, _ := h.store.Get(r, auth.SessionName)
    session.Values["user_id"] = nil
    session.Options.MaxAge = -1 // Delete cookie
    session.Save(r, w)

    w.WriteHeader(http.StatusOK)
    json.NewEncoder(w).Encode(map[string]string{"status": "logged out"})
}
```

### Register Handler

```go
func (h *Handler) Register(w http.ResponseWriter, r *http.Request) {
    var req struct {
        Email    string `json:"email"`
        Password string `json:"password"`
    }
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, "invalid request", http.StatusBadRequest)
        return
    }

    // Validate
    if req.Email == "" || req.Password == "" {
        http.Error(w, "email and password required", http.StatusBadRequest)
        return
    }
    if len(req.Password) < 8 {
        http.Error(w, "password must be at least 8 characters", http.StatusBadRequest)
        return
    }

    // Check if exists
    _, err := h.db.GetUserByEmail(r.Context(), req.Email)
    if err == nil {
        http.Error(w, "email already registered", http.StatusConflict)
        return
    }

    // Hash password
    passwordHash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
    if err != nil {
        http.Error(w, "internal error", http.StatusInternalServerError)
        return
    }

    // Create user
    user, err := h.db.CreateUser(r.Context(), database.CreateUserParams{
        Email:        req.Email,
        PasswordHash: string(passwordHash),
        CreatedAt:    time.Now(),
    })
    if err != nil {
        http.Error(w, "internal error", http.StatusInternalServerError)
        return
    }

    // Auto-login
    session, _ := h.store.Get(r, auth.SessionName)
    session.Values["user_id"] = user.ID
    session.Save(r, w)

    w.WriteHeader(http.StatusCreated)
    json.NewEncoder(w).Encode(user)
}
```

## Auth Middleware

```go
package middleware

import (
    "context"
    "database/sql"
    "net/http"

    "github.com/gorilla/sessions"

    "myapp/internal/database"
)

type contextKey string

const UserKey contextKey = "user"

func RequireAuth(store sessions.Store, db *sql.DB, queries *database.Queries) func(http.Handler) http.Handler {
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

            // Add user to context
            ctx := context.WithValue(r.Context(), UserKey, user)
            next.ServeHTTP(w, r.WithContext(ctx))
        })
    }
}

// Helper to get user from context
func GetUserFromContext(ctx context.Context) *database.User {
    user, _ := ctx.Value(UserKey).(*database.User)
    return user
}
```

## Using Auth Middleware

```go
func Register(r chi.Router, db *sql.DB, queries *database.Queries, store sessions.Store) {
    h := &Handler{db: db, queries: queries, store: store}

    // Public routes
    r.Get("/", h.Home)
    r.Get("/login", h.LoginForm)
    r.Post("/login", h.Login)
    r.Get("/register", h.RegisterForm)
    r.Post("/register", h.Register)

    // Protected routes
    r.Group(func(r chi.Router) {
        r.Use(middleware.RequireAuth(store, db, queries))
        r.Get("/dashboard", h.Dashboard)
        r.Post("/logout", h.Logout)
        r.Get("/profile", h.Profile)
    })
}

// In handlers
func (h *Handler) Dashboard(w http.ResponseWriter, r *http.Request) {
    user := middleware.GetUserFromContext(r.Context())
    if user == nil {
        http.Error(w, "unauthorized", http.StatusUnauthorized)
        return
    }

    fmt.Fprintf(w, "Welcome, %s", user.Email)
}
```

## CSRF Protection

gorilla/csrf provides automatic CSRF tokens for HTML forms.

### Setup

```go
import "github.com/gorilla/csrf"

// In main
r.Use(csrf.Protect([]byte(csrfKey)))
```

### HTML Forms

```html
<form action="/login" method="POST">
    <input type="hidden" name="{{.csrfField}}" value="{{.csrfToken}}">
    <!-- or use the helper -->
    {{ csrfField .csrfToken }}
    
    <input name="email" type="email">
    <input name="password" type="password">
    <button type="submit">Login</button>
</form>
```

### JSON API

For JSON APIs, CSRF is not needed if you're using session cookies with `SameSite`:
- Browsers send cookies automatically
- `SameSite=Lax` or `SameSite=Strict` prevents CSRF
- No need for CSRF tokens in JSON APIs

## Session Security

### Cookie Options

```go
store.Options = &sessions.Options{
    Path:     "/",
    MaxAge:   86400 * 7,    // 7 days
    HttpOnly: true,          // Not accessible via JavaScript
    Secure:   true,          // HTTPS only (false in dev)
    SameSite: http.SameSiteLaxMode, // Or Strict for more security
}
```

### Regenerate on Login

Always regenerate session IDs on login to prevent session fixation:

```go
func (h *Handler) Login(w http.ResponseWriter, r *http.Request) {
    // ... authenticate ...

    session, _ := h.store.Get(r, auth.SessionName)
    
    // Regenerate session ID
    session.ID = ""
    session.Values["user_id"] = user.ID
    session.Save(r, w)
}
```

### Session Expiration

```go
// Check expiration in middleware
session, _ := h.store.Get(r, auth.SessionName)
if session.IsNew {
    http.Error(w, "session expired", http.StatusUnauthorized)
    return
}
```

## Guardrails

- ALWAYS use bcrypt for password hashing
- ALWAYS store session keys and CSRF keys in environment variables
- ALWAYS use `HttpOnly: true` for session cookies
- ALWAYS set `SameSite` on cookies
- NEVER store passwords in plain text
- NEVER store entire user structs in sessions (just user ID)
- NEVER use JWT for web app authentication