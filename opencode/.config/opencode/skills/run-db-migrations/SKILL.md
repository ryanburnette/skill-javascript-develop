---
name: run-db-migrations
description: Database migrations with sql-migrate CLI. Use when creating or running DB schema migrations.
deprecated: This skill references AJ's internal sql-migrate CLI. For mainstream Go development, use embedded migrations with database/sql. See go-develop skill for migration patterns.
---

## Migrations

Install: `go install github.com/therootcompany/golib/cmd/sql-migrate/v2@v2.1.1`

CLI-only tool — generates shell scripts, does not connect to DB.

```sh
sql-migrate -d ./db/migrations init --sql-command psql
sql-migrate -d ./db/migrations create add-users-table
sql-migrate -d ./db/migrations sync | sh
sql-migrate -d ./db/migrations up | sh
```

Each migration file tracks itself in `_migrations` table. The Go app does not self-migrate at startup.