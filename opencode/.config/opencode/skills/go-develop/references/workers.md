# Background Workers

Patterns for background tasks with goroutines, channels, and graceful shutdown.

## Simple Worker Pattern

For background tasks that run continuously:

```go
package worker

import (
    "context"
    "log/slog"
    "time"
)

type Worker struct {
    tasks chan Task
    done  chan struct{}
}

type Task struct {
    ID   string
    Data interface{}
}

func NewWorker(bufferSize int) *Worker {
    return &Worker{
        tasks: make(chan Task, bufferSize),
        done:  make(chan struct{}),
    }
}

func (w *Worker) Start(ctx context.Context) {
    go func() {
        for {
            select {
            case task := <-w.tasks:
                if err := w.process(ctx, task); err != nil {
                    slog.Error("processing task", "id", task.ID, "error", err)
                }
            case <-w.done:
                slog.Info("worker shutting down")
                return
            case <-ctx.Done():
                slog.Info("worker context cancelled")
                return
            }
        }
    }()
}

func (w *Worker) Stop() {
    close(w.done)
}

func (w *Worker) Submit(task Task) bool {
    select {
    case w.tasks <- task:
        return true
    default:
        // Channel full
        return false
    }
}

func (w *Worker) process(ctx context.Context, task Task) error {
    // Process the task
    slog.Info("processing task", "id", task.ID)
    // ... do work ...
    return nil
}
```

## Periodic Task

For tasks that run on a schedule:

```go
package worker

import (
    "context"
    "time"
)

type PeriodicWorker struct {
    interval time.Duration
    task     func(ctx context.Context) error
    done     chan struct{}
}

func NewPeriodicWorker(interval time.Duration, task func(ctx context.Context) error) *PeriodicWorker {
    return &PeriodicWorker{
        interval: interval,
        task:     task,
        done:     make(chan struct{}),
    }
}

func (w *PeriodicWorker) Start(ctx context.Context) {
    ticker := time.NewTicker(w.interval)
    go func() {
        defer ticker.Stop()
        for {
            select {
            case <-ticker.C:
                if err := w.task(ctx); err != nil {
                    slog.Error("periodic task failed", "error", err)
                }
            case <-w.done:
                return
            case <-ctx.Done():
                return
            }
        }
    }()
}

func (w *PeriodicWorker) Stop() {
    close(w.done)
}
```

### Usage

```go
// Cleanup expired sessions every hour
cleanupTask := func(ctx context.Context) error {
    _, err := queries.DeleteExpiredSessions(ctx, time.Now())
    return err
}

cleanupWorker := worker.NewPeriodicWorker(1*time.Hour, cleanupTask)
cleanupWorker.Start(ctx)
defer cleanupWorker.Stop()
```

## Job Queue with Multiple Workers

For processing jobs from a queue:

```go
package worker

import (
    "context"
    "sync"
)

type JobQueue struct {
    jobs     chan Job
    workers  int
    wg       sync.WaitGroup
    process func(ctx context.Context, job Job) error
}

type Job struct {
    ID   string
    Type string
    Data []byte
}

func NewJobQueue(workers int, bufferSize int, process func(ctx context.Context, job Job) error) *JobQueue {
    return &JobQueue{
        jobs:     make(chan Job, bufferSize),
        workers:  workers,
        process:  process,
    }
}

func (q *JobQueue) Start(ctx context.Context) {
    for i := 0; i < q.workers; i++ {
        q.wg.Add(1)
        go q.worker(ctx, i)
    }
}

func (q *JobQueue) Stop() {
    close(q.jobs)
    q.wg.Wait()
}

func (q *JobQueue) Submit(job Job) bool {
    select {
    case q.jobs <- job:
        return true
    default:
        return false
    }
}

func (q *JobQueue) worker(ctx context.Context, id int) {
    defer q.wg.Done()
    for job := range q.jobs {
        if err := q.process(ctx, job); err != nil {
            slog.Error("job failed", "worker", id, "job", job.ID, "error", err)
        }
    }
}
```

### Usage

```go
// Create job queue with 5 workers
queue := worker.NewJobQueue(5, 100, func(ctx context.Context, job worker.Job) error {
    switch job.Type {
    case "send_email":
        return sendEmail(ctx, job.Data)
    case "generate_report":
        return generateReport(ctx, job.Data)
    default:
        return fmt.Errorf("unknown job type: %s", job.Type)
    }
})

queue.Start(ctx)

// Submit jobs
queue.Submit(worker.Job{
    ID:   "job-1",
    Type: "send_email",
    Data: []byte(`{"to": "user@example.com", "subject": "Hello"}`),
})

// Graceful shutdown
defer queue.Stop()
```

## Database Polling Worker

For processing jobs stored in database:

```go
package worker

import (
    "context"
    "database/sql"
    "time"
)

type DatabasePoller struct {
    db       *sql.DB
    queries  *database.Queries
    interval time.Duration
    process func(ctx context.Context, job database.Job) error
    done     chan struct{}
}

func NewDatabasePoller(db *sql.DB, queries *database.Queries, interval time.Duration, process func(ctx context.Context, job database.Job) error) *DatabasePoller {
    return &DatabasePoller{
        db:       db,
        queries:  queries,
        interval: interval,
        process:  process,
        done:     make(chan struct{}),
    }
}

func (p *DatabasePoller) Start(ctx context.Context) {
    ticker := time.NewTicker(p.interval)
    go func() {
        defer ticker.Stop()
        for {
            select {
            case <-ticker.C:
                p.poll(ctx)
            case <-p.done:
                return
            case <-ctx.Done():
                return
            }
        }
    }()
}

func (p *DatabasePoller) Stop() {
    close(p.done)
}

func (p *DatabasePoller) poll(ctx context.Context) {
    // Get pending jobs
    jobs, err := p.queries.ListPendingJobs(ctx)
    if err != nil {
        slog.Error("listing jobs", "error", err)
        return
    }

    for _, job := range jobs {
        // Mark as processing
        err := p.queries.MarkJobProcessing(ctx, job.ID)
        if err != nil {
            slog.Error("marking job processing", "id", job.ID, "error", err)
            continue
        }

        // Process
        err = p.process(ctx, job)
        if err != nil {
            slog.Error("job failed", "id", job.ID, "error", err)
            p.queries.MarkJobFailed(ctx, database.MarkJobFailedParams{
                ID:     job.ID,
                Error:  sql.NullString{String: err.Error(), Valid: true},
            })
            continue
        }

        // Mark complete
        p.queries.MarkJobComplete(ctx, job.ID)
    }
}
```

## Graceful Shutdown

Always handle shutdown gracefully:

```go
package main

import (
    "context"
    "log"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"
)

func main() {
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()

    // Start background workers
    emailWorker := worker.NewJobQueue(3, 50, processEmail)
    emailWorker.Start(ctx)
    defer emailWorker.Stop()

    cleanupWorker := worker.NewPeriodicWorker(1*time.Hour, cleanupSessions)
    cleanupWorker.Start(ctx)
    defer cleanupWorker.Stop()

    // Start HTTP server
    srv := &http.Server{Addr: ":3080", Handler: mux}
    go func() {
        if err := srv.ListenAndServe(); err != http.ErrServerClosed {
            log.Fatal("server error: ", err)
        }
    }()

    // Wait for shutdown signal
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, os.Interrupt, syscall.SIGTERM)
    <-quit

    log.Println("Shutting down...")

    // Give workers time to finish
    shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer shutdownCancel()

    // Stop accepting new connections
    srv.Shutdown(shutdownCtx)

    // Cancel context to stop workers
    cancel()

    log.Println("Shutdown complete")
}
```

## Goroutine Leak Prevention

Always ensure goroutines can exit:

```go
// BAD: Goroutine leak
func badWorker() {
    for {
        // This runs forever if channel is never closed
        job := <-jobs
        process(job)
    }
}

// GOOD: Context cancellation
func goodWorker(ctx context.Context) {
    for {
        select {
        case job := <-jobs:
            process(job)
        case <-ctx.Done():
            return
        }
    }
}

// GOOD: Channel closure
func goodWorker2(done <-chan struct{}) {
    for {
        select {
        case job, ok := <-jobs:
            if !ok {
                return // Channel closed
            }
            process(job)
        case <-done:
            return
        }
    }
}
```

## Guardrails

- ALWAYS use context for cancellation
- ALWAYS close channels or use done signal to stop goroutines
- ALWAYS handle graceful shutdown in main
- NEVER spawn unbounded goroutines (use worker pool)
- NEVER ignore errors in goroutines (log them)
- Use `sync.WaitGroup` to wait for workers to finish