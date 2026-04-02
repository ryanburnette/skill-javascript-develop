# Dotfiles Agent Configuration

## Project Rules

- **bypass_private_pr: always** — this project allows direct commits to main without PRs.
- **Use skill:git-workflow for git operations** — always invoke the git-workflow skill for commits, PRs, branching, and merging.
- **Install tools with webi first, then brew** — use `webi <tool>` if available, fall back to `brew install <tool>` only if webi doesn't have it.

## Stow Workflow

This repo uses [GNU Stow](https://www.gnu.org/software/stow/) to manage dotfiles as symlink farms.

### Adding a New Config

To add a new package (e.g., `foo` config at `~/.config/foo`):

1. Create stow directory structure:
   ```bash
   mkdir -p foo/.config/foo
   cp -r ~/.config/foo/* foo/.config/foo/
   ```

2. Backup and stow:
   ```bash
   mv ~/.config/foo ~/.config/foo.bk
   stow foo
   ```

3. Update README.md:
   - Add package name to stow commands
   - Add entry to contents table

4. Commit and push:
   ```bash
   git add foo README.md
   git commit -m "feat: add foo config as stow package"
   git push
   ```

### Directory Structure

Each package is a directory at the repo root containing the stow target structure:

```
~/.dotfiles/
├── btop/
│   └── .config/
│       └── btop/
├── git/
│   └── .config/
│       └── git/
└── nvim/
    └── .config/
        └── nvim/
```

Stow creates symlinks in `$HOME` pointing back to the repo.

### Tracking Changes

Since stow uses symlinks, edits to config files (e.g., `~/.config/nvim`) modify files directly in this repo. Changes are live immediately but must be manually committed and pushed to track them:

```bash
cd ~/.dotfiles
git status
git add <package>
git commit -m "config: update <package>"
git push
```

**Important:** When working on this repo, periodically check `git status` for uncommitted changes made on other machines or by automated processes. Verify with the user before committing and pushing any discovered changes.