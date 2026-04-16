---
name: git-workflow
description: GitHub repo creation, branch protection, committing, WIP PRs, and merging. Use when creating a GitHub repo, starting a feature branch, managing PRs, or merging into main.
---

## Public vs Private Repos

**If unclear which applies to the current project, ask the user to clarify.**

### Public Repos

Working on a public repo requires PRs to protect the project. All branch
protection rules apply.

### Private Repos

Working on a private repo allows direct commits to main. No PRs required unless
the user explicitly requests them.

## Create a New GitHub Repo

```sh
gh repo create ryanburnette/<name> --public --source . --remote origin --push
```

After the first push to `main`, apply branch protection:

```sh
gh api repos/ryanburnette/<name>/branches/main/protection \
  --method PUT \
  --field enforce_admins=true \
  --field required_linear_history=true \
  --field allow_force_pushes=false \
  --field allow_deletions=false \
  --field 'required_pull_request_reviews[required_approving_review_count]=0' \
  --field 'required_pull_request_reviews[dismiss_stale_reviews]=false' \
  --field 'required_status_checks=null' \
  --field 'restrictions=null'
# Note: required_status_checks MUST be included (even as null) or the API returns 422.
```

This enforces:

- PR required before any merge to `main`
- Linear history — no merge commits; rebase or squash only
- Rules apply to admins too (`enforce_admins=true`)
- No force pushes, no branch deletion

## Committing

Stage specific files — never `git add -A`:

```sh
git add path/to/file another/file
git commit -m "$(cat <<'EOF'
type: short summary of what and why
EOF
)"
```

Commit often. Each commit is a safe checkpoint.

**Note:** The skill stages and commits. The user handles `git push` manually.

## Feature Branches and WIP PRs

```sh
git checkout -b feature/my-thing
# work, commit
git push -u origin feature/my-thing
```

Open a draft PR immediately:

```sh
gh pr create \
  --title "WIP: my thing" \
  --body "$(cat <<'EOF'
## What

Brief description.

## Status

- [x] Initial scaffolding
- [ ] Tests
EOF
)" \
  --draft
```

Update the PR description as work progresses:

```sh
gh pr edit <number> --body "$(cat <<'EOF'
updated body...
EOF
)"
```

## Force Pushes — Require User Confirmation

**Always ask before running any force push, including `--force-with-lease` and `--force-with-lease`.**

Force pushes are destructive. Even with safeguards, they can cause data loss. Get explicit user approval first.

## History: Always Rebase or Squash

Never merge commits. Every branch must rebase onto `main` before merging.

Clean up a feature branch before merge:

```sh
# Rebase interactively to squash/fixup noise commits
git rebase -i main

# Or just rebase to keep all commits in order
git rebase main
git push --force-with-lease origin feature/my-thing  # requires user confirmation
```

## Merging into Main — Only After Explicit Approval

**For public repos:** Follow the PR workflow above. Merge only after user approval.

**For private repos:** Direct commits to main are acceptable. Commit normally after completing work.

**Never self-merge on public repos. Never use `--admin` to bypass branch protection.**

## Working with GitHub Issues

**Always read the entire issue thread before starting work.**

```sh
gh issue view <number> --comments
```

Or use the API for full thread:

```sh
gh api repos/<owner>/<repo>/issues/<number>/comments --jq '.[] | "=== \(.user.login) on \(.created_at) ===\n\(.body)\n"'
```

Key reminders:
- Comments may contain clarifications or scope changes not in the original issue
- Read ALL comments before making any code changes
- Ask questions if the requirements are unclear

**Close issues in commit messages:**

```sh
git commit -m "fix: description of fix

Closes #6"
```

This automatically closes the issue when pushed to main.
