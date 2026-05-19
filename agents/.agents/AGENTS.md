# Agent Conventions

Global conventions for any coding agent (pi, opencode, etc.) working on this machine.

## Skills

Skills live in `~/.agents/skills/` — each skill is a `SKILL.md` in its own directory. Agent harnesses discover skills natively from this location.

| Skill | When to use |
|-------|-------------|
| `agent-init` | New computer or environment setup for agent assistance |
| `basecamp` | Any Basecamp question or action via the Basecamp CLI |
| `create-skill` | Creating or updating a SKILL.md |
| `domainpanel` | Managing domains and DNS records across registrars |
| `git-workflow` | GitHub repo creation, branch protection, committing, PRs, merging |
| `go-develop` | Go HTTP servers, APIs, web apps, CLI tools, background workers |
| `import-sheet-data` | Reading data from Google Sheets |
| `javascript-init` | New JS/Node project scaffolding |
| `repo-init` | Initializing a repo for agent assistance |
| `shell-scripting` | Writing or reviewing POSIX shell scripts |
| `strip-ai-tells` | Cleaning up AI-generated text, docs, commit messages |
| `vue-develop` | Vue SPA front-end projects |
| `write-modern-javascript` | Vanilla JS for browser UIs — no transpiler, no framework |

## AGENTS.md Structure

Place critical action-specific rules in a "Before Actions" section at the top of AGENTS.md. This ensures they're seen before taking action, not after. Example:

```markdown
## Before Actions

**Before git operations:** Use `skill:git-workflow`. This repo has `bypass_private_pr: always`.

**Before editing configs:** If changes are made to configs not managed by this repo, offer to add them as symlink packages.
```

The section acts as a cache of essential rules with skill references, reducing the need to invoke skills for routine operations.

## Session Start Sequence

1. Read `AGENTS.md` (committed) — architecture, gotchas, pre-commit, skills to load
2. Read `LOCAL.md` (git ignored) if present — environment-specific context for this worktree
3. As needed, load skills from `~/.agents/skills/` or from the repo
4. When a `.git` is present but `AGENTS.md` is missing, ask if the `repo-init` skill should be used

## LOCAL.md

Git-ignored, ephemeral, worktree/environment-specific. Contains what differs between environments or operators:

- Notes only relevant to this machine/operator
- Paths to specific `.env` files (prod vs dev)
- Config info, base URLs, deploy targets — hostname, IP, `DB_URL`, etc.
- Agent-specific local env var overrides or flags
- Concrete versions of things that are parameterized or asked for in AGENTS.md or skills

**Create it** at session start if missing and you have environment-specific context to record.
**Never commit it** — add `LOCAL.md` to `.gitignore`.

## AGENTS.md vs LOCAL.md Split

| Put in AGENTS.md                        | Put in LOCAL.md                     |
| --------------------------------------- | ------------------------------------ |
| True for all agents in all environments | True for this machine/operator only |
| Invariants not obvious from code        | Which specific account/env to use   |
| Gotchas that look correct but aren't    | Prod vs dev credential file paths   |
| Pre-commit checklist                    | Deploy target details               |
| Config file names and schemas           | Session-specific overrides          |
| Which skills to load                    | —                                   |

**Leave out of both:** things an agent learns by reading the relevant source file (routes, struct fields, function signatures, test patterns).

## Installing Tools

Preference order — stop at the first that works:

1. Follow the installation instructions in the relevant skill
2. `webi` — e.g. `webi go` (then `go install` for Go tools), `webi node@lts` (then `npm install` for Node tools)
3. System package manager (`apt-get`, `brew`, etc.) — last resort only
