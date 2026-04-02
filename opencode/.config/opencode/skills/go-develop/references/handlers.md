# HTTP Handlers

Handler patterns for JSON APIs and HTML templates.

## Handler Struct Pattern

Use a struct to hold dependencies:

```go
package handlers

import (
    "database/sql"
    "encoding/json"
    "net/http"
    "strconv"

    "github.com/go-chi/chi/v5"
    "github.com/gorilla/sessions"

    "myapp/internal/database"
)

type Handler struct {
    db      *sql.DB
    queries *database.Queries
    store   sessions.Store
}

func Register(r chi.Router, db *sql.DB, queries *database.Queries, store sessions.Store) {
    h := &Handler{
        db:      db,
        queries: queries,
        store:   store,
    }

    r.Get("/", h.Home)
    r.Get("/users", h.ListUsers)
    r.Get("/users/{id}", h.GetUser)
    r.Post("/users", h.CreateUser)
}
```

## JSON Responses

### Success Response

```go
func (h *Handler) GetUser(w http.ResponseWriter, r *http.Request) {
    id, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
    if err != nil {
        http.Error(w, "invalid id", http.StatusBadRequest)
        return
    }

    user, err := h.queries.GetUser(r.Context(), id)
    if err == sql.ErrNoRows {
        http.Error(w, "not found", http.StatusNotFound)
        return
    }
    if err != nil {
        slog.Error("getting user", "error", err)
        http.Error(w, "internal error", http.StatusInternalServerError)
        return
    }

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(user)
}
```

### List with Pagination

```go
func (h *Handler) ListUsers(w http.ResponseWriter, r *http.Request) {
    page, _ := strconv.Atoi(r.URL.Query().Get("page"))
    if page < 1 {
        page = 1
    }

    limit := 20
    offset := (page - 1) * limit

    users, err := h.queries.ListUsersPaginated(r.Context(), database.ListUsersPaginatedParams{
        Limit:  int64(limit),
        Offset: int64(offset),
    })
    if err != nil {
        slog.Error("listing users", "error", err)
        http.Error(w, "internal error", http.StatusInternalServerError)
        return
    }

    response := map[string]interface{}{
        "users": users,
        "page":  page,
    }

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(response)
}
```

### Create with Validation

```go
func (h *Handler) CreateUser(w http.ResponseWriter, r *http.Request) {
    var req struct {
        Email    string `json:"email"`
        Password string `json:"password"`
        Name     string `json:"name"`
    }

    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, "invalid JSON", http.StatusBadRequest)
        return
    }

    // Validation
    if req.Email == "" {
        respondError(w, "email required", http.StatusBadRequest)
        return
    }
    if len(req.Password) < 8 {
        respondError(w, "password must be at least 8 characters", http.StatusBadRequest)
        return
    }

    // Check duplicate
    existing, _ := h.queries.GetUserByEmail(r.Context(), req.Email)
    if existing.ID > 0 {
        respondError(w, "email already registered", http.StatusConflict)
        return
    }

    // Hash password
    hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
    if err != nil {
        slog.Error("hashing password", "error", err)
        http.Error(w, "internal error", http.StatusInternalServerError)
        return
    }

    // Create
    user, err := h.queries.CreateUser(r.Context(), database.CreateUserParams{
        Email:        req.Email,
        PasswordHash: string(hashedPassword),
        Name:         req.Name,
        CreatedAt:    time.Now(),
    })
    if err != nil {
        slog.Error("creating user", "error", err)
        http.Error(w, "internal error", http.StatusInternalServerError)
        return
    }

    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusCreated)
    json.NewEncoder(w).Encode(user)
}

func respondError(w http.ResponseWriter, message string, status int) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(status)
    json.NewEncoder(w).Encode(map[string]string{"error": message})
}
```

### Update

```go
func (h *Handler) UpdateUser(w http.ResponseWriter, r *http.Request) {
    id, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
    if err != nil {
        http.Error(w, "invalid id", http.StatusBadRequest)
        return
    }

    var req struct {
        Name string `json:"name"`
    }
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, "invalid JSON", http.StatusBadRequest)
        return
    }

    user, err := h.queries.UpdateUser(r.Context(), database.UpdateUserParams{
        ID:   id,
        Name: req.Name,
    })
    if err != nil {
        slog.Error("updating user", "error", err)
        http.Error(w, "internal error", http.StatusInternalServerError)
        return
    }

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(user)
}
```

### Delete

```go
func (h *Handler) DeleteUser(w http.ResponseWriter, r *http.Request) {
    id, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
    if err != nil {
        http.Error(w, "invalid id", http.StatusBadRequest)
        return
    }

    err = h.queries.DeleteUser(r.Context(), id)
    if err != nil {
        slog.Error("deleting user", "error", err)
        http.Error(w, "internal error", http.StatusInternalServerError)
        return
    }

    w.WriteHeader(http.StatusNoContent)
}
```

## HTML Templates

### Template Setup

```go
package handlers

import (
    "html/template"
    "io/fs"
)

var templates *template.Template

func ParseTemplates(fsys fs.FS) error {
    var err error
    templates, err = template.New("").ParseFS(fsys, "templates/*.html")
    return err
}
```

### Render Helper

```go
type ViewData struct {
    Title   string
    User    *database.User
    CSRF    string
    Error   string
    Success string
    Data    interface{}
}

func (h *Handler) render(w http.ResponseWriter, name string, data ViewData) {
    w.Header().Set("Content-Type", "text/html; charset=utf-8")
    if err := templates.ExecuteTemplate(w, name, data); err != nil {
        slog.Error("rendering template", "error", err, "template", name)
        http.Error(w, "internal error", http.StatusInternalServerError)
    }
}
```

### Template Files

`templates/layout.html`:

```html
<!DOCTYPE html>
<html>
<head>
    <title>{{.Title}}</title>
</head>
<body>
    {{template "nav" .}}
    {{template "content" .}}
    {{template "footer" .}}
</body>
</html>

{{define "nav"}}
<nav>
    {{if .User}}
        <span>{{.User.Email}}</span>
        <form action="/logout" method="POST">
            {{.CSRF}}
            <button type="submit">Logout</button>
        </form>
    {{else}}
        <a href="/login">Login</a>
    {{end}}
</nav>
{{end}}

{{define "footer"}}
<footer>&copy; 2024 MyApp</footer>
{{end}}
```

`templates/dashboard.html`:

```html
{{define "content"}}
<div class="dashboard">
    <h1>Welcome, {{.User.Name}}</h1>
    {{if .Error}}
        <div class="error">{{.Error}}</div>
    {{end}}
    {{if .Success}}
        <div class="success">{{.Success}}</div>
    {{end}}
    
    <h2>Your Tasks</h2>
    <ul>
        {{range .Data.([]*database.Task)}}
            <li>{{.Title}}</li>
        {{end}}
    </ul>
</div>
{{end}}
```

### HTML Handler

```go
func (h *Handler) Dashboard(w http.ResponseWriter, r *http.Request) {
    user, ok := r.Context().Value("user").(*database.User)
    if !ok || user == nil {
        http.Redirect(w, r, "/login", http.StatusSeeOther)
        return
    }

    tasks, err := h.queries.ListTasksByUser(r.Context(), user.ID)
    if err != nil {
        h.render(w, "dashboard.html", ViewData{
            Title: "Dashboard",
            User:  user,
            Error: "Failed to load tasks",
        })
        return
    }

    h.render(w, "dashboard.html", ViewData{
        Title: "Dashboard",
        User:  user,
        Data:  tasks,
    })
}
```

### Form Submission

```go
func (h *Handler) CreateTask(w http.ResponseWriter, r *http.Request) {
    user, ok := r.Context().Value("user").(*database.User)
    if !ok {
        http.Redirect(w, r, "/login", http.StatusSeeOther)
        return
    }

    title := r.FormValue("title")
    if title == "" {
        h.render(w, "dashboard.html", ViewData{
            Title: "Dashboard",
            User:  user,
            Error: "Title is required",
        })
        return
    }

    _, err := h.queries.CreateTask(r.Context(), database.CreateTaskParams{
        UserID:    user.ID,
        Title:     title,
        Completed: false,
        CreatedAt: time.Now(),
    })
    if err != nil {
        h.render(w, "dashboard.html", ViewData{
            Title: "Dashboard",
            User:  user,
            Error: "Failed to create task",
        })
        return
    }

    http.Redirect(w, r, "/dashboard", http.StatusSeeOther)
}
```

## Error Handling Patterns

### HTTP Errors

```go
func (h *Handler) GetUser(w http.ResponseWriter, r *http.Request) {
    id, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
    if err != nil {
        respondError(w, "invalid id", http.StatusBadRequest)
        return
    }

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

### Custom Error Types

```go
type AppError struct {
    Code    int
    Message string
    Err     error
}

func (e *AppError) Error() string {
    if e.Err != nil {
        return fmt.Sprintf("%s: %v", e.Message, e.Err)
    }
    return e.Message
}

func (e *AppError) Unwrap() error {
    return e.Err
}

func NotFound(message string) *AppError {
    return &AppError{Code: http.StatusNotFound, Message: message}
}

func Internal(message string, err error) *AppError {
    return &AppError{Code: http.StatusInternalServerError, Message: message, Err: err}
}

// Usage
func (h *Handler) GetUser(w http.ResponseWriter, r *http.Request) {
    user, err := h.queries.GetUser(r.Context(), id)
    if err == sql.ErrNoRows {
        respondError(w, NotFound("user not found"))
        return
    }
    if err != nil {
        respondError(w, Internal("failed to get user", err))
        return
    }
    respondJSON(w, user)
}

func respondError(w http.ResponseWriter, err *AppError) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(err.Code)
    json.NewEncoder(w).Encode(map[string]string{"error": err.Message})
}
```

## Guardrails

- ALWAYS return proper HTTP status codes
- ALWAYS log internal errors (never just `http.Error`)
- NEVER expose internal error details to clients
- NEVER panic in handlers (use middleware recovery)
- ALWAYS validate input before database operations
- Use `sql.ErrNoRows` to check for not found conditions