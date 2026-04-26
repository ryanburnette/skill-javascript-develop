---
name: basecamp-project-setup
description: |
  Set up a repo to use the official basecamp-cli for a specific Basecamp project.
  Use when creating a new repo that needs Basecamp integration, or when migrating
  a custom Basecamp integration to use the official CLI instead.
---

# basecamp-project-setup

Set up a git repo so an agent can manage a specific Basecamp project using the official `basecamp` CLI (github.com/basecamp/basecamp-cli).

## Prerequisites

1. `basecamp` CLI installed and authenticated (`basecamp auth login --scope full`)
2. The target Basecamp project ID and account ID

## Setup Steps

### 1. Install basecamp-cli

If not already installed, use the webi pattern (manual install to `~/.local`):

```bash
VER=0.7.2
curl -fsSL -o /tmp/basecamp.tar.gz \
  https://github.com/basecamp/basecamp-cli/releases/download/v${VER}/basecamp_${VER}_darwin_arm64.tar.gz
mkdir -p ~/.local/opt/basecamp-v${VER}/bin
tar -xzf /tmp/basecamp.tar.gz -C ~/.local/opt/basecamp-v${VER}/bin
ln -sf ~/.local/opt/basecamp-v${VER}/bin/basecamp ~/.local/bin/basecamp
rm /tmp/basecamp.tar.gz
basecamp --version
```

### 2. Authenticate

```bash
basecamp auth login --scope full
basecamp auth status
```

### 3. Create per-repo config

```bash
basecamp config init
basecamp config set project_id <PROJECT_ID>
basecamp config set account_id <ACCOUNT_ID>
basecamp config trust
```

This creates `.basecamp/config.json` with project and account scope. Commit this file to git.

### 4. Add the basecamp skill

Copy the official SKILL.md from the basecamp-cli repo into `.opencode/skills/basecamp/SKILL.md`:

```bash
mkdir -p .opencode/skills/basecamp
curl -fsSL -o .opencode/skills/basecamp/SKILL.md \
  https://raw.githubusercontent.com/basecamp/basecamp-cli/refs/heads/main/skills/basecamp/SKILL.md
```

### 5. Write AGENTS.md

Include these sections:

- **Project Context** — table of Basecamp projects this repo works with (project ID, account ID, purpose). This is the source of truth for the agent's understanding of scope. Even repos with a single project should use the table — it scales when more projects are added.
- **Before Actions** — never recreate Basecamp items (move/update/reposition instead), load the basecamp skill before interacting, use `--agent` or `--md` flags for agent output
- **Setup** — install location, auth command
- **Commands** — command table mapping common operations to `basecamp` CLI commands
- **Lessons** — project-specific lessons learned over time

### 6. Verify

```bash
basecamp auth status
basecamp projects list --md
basecamp todolists list --md
```

## Repo Structure

```
project-repo/
├── .basecamp/
│   └── config.json          # project_id + account_id (committed)
├── .opencode/
│   └── skills/
│       └── basecamp/
│           └── SKILL.md     # official basecamp-cli skill
├── .gitignore
├── AGENTS.md                # project context and command reference
└── opencode.json
```

No application code. The repo is a context + config wrapper around the `basecamp` CLI.

## Lessons

- Use official tools before building your own. The basecamp-cli already provides full API coverage, agent skill, structured output, and auto token refresh.
- Per-repo config (`.basecamp/config.json`) sets a default `project_id` as a CLI convenience. Commit it to git. The source of truth for project scope is AGENTS.md (use a Project Context table), not the config file.
- Project context (which projects, what for) belongs in AGENTS.md as a table, not just in `.basecamp/config.json`. Even single-project repos should use the table — it scales when more projects are added.
- Always include assignee and due date when showing todo items.
- `.opencode/skills/` is where opencode discovers project-local skills (not `skills/`).
- Never recreate Basecamp items. Move, update, or reposition existing items instead.
- The `basecamp` CLI supports multiple projects via `--in <project_id>` and multiple accounts via `--account <account_id>`.
- `basecamp todos update --due` is broken in v0.7.2 (returns ok but doesn't update the due date). Workaround: update due dates in the Basecamp web UI, or recreate the todo. Known issue: https://github.com/basecamp/basecamp-cli/issues/412
- Scheduled scripts belong in `bin/`, run on a container via cron, and are documented in AGENTS.md under "Scheduled Tasks". Sync the repo to the container with `bin/sync-to-container`.