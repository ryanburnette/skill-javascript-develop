# Dotfiles Agent Configuration

## Before Actions

**Before git operations:** Use `skill:git-workflow`. This repo has `bypass_private_pr: always` — direct commits to main are allowed.

**Before diagnosing unverified commits:** Check `~/.config/git/config.local` exists and contains `commit.gpgsign = true`, `user.signingkey`, and `gpg.ssh.allowedSignersFile`. The shared Git config only sets SSH signing format; machine-local config enables signing.

**Before editing configs:** If changes are made to configs not managed by this repo, offer to add them as symlinks.

## Symlink Workflow

This repo uses direct symlinks to manage dotfiles.

### Skills (Git Submodules)

Skills live in `~/.agents/skills/` — each skill is a git submodule pointing to its own `ryanburnette/skill-<name>` private repo. Agent harnesses (pi, opencode, etc.) discover skills natively from `~/.agents/skills/`.

**Adding a new skill:**

1. Create the skill repo on GitHub (private):
   ```bash
   gh repo create ryanburnette/skill-<name> --private
   ```
2. Add as submodule:
   ```bash
   cd ~/.dotfiles
   git submodule add git@github.com:ryanburnette/skill-<name>.git skills/.agents/skills/<name>
   ```
3. Update README.md and commit.

**Updating a skill:**

```bash
cd ~/.dotfiles
git submodule update --remote skills/.agents/skills/<name>
git add skills/.agents/skills/<name>
git commit -m "chore: update skill-<name>"
git push
```

**New machine setup** — `setup.sh` runs `git submodule update --init --recursive` automatically.

**Migration from old location:** Skills previously lived under `~/.config/opencode/skills/` (symlinked from `opencode/.config/opencode/skills/`). If `~/.config/opencode/skills` is a stale symlink pointing to a deleted directory, remove it and ensure `~/.agents/skills/` is symlinked instead. Running `./setup.sh` handles this automatically.

### Adding a New Config

To add a new package (e.g., `foo` config at `~/.config/foo`):

1. Create directory structure in dotfiles:

   ```bash
   mkdir -p foo/.config/foo
   cp -r ~/.config/foo/* foo/.config/foo/
   ```

2. Create symlink (setup.sh handles backups with `.bk` suffix):

   ```bash
   mv ~/.config/foo ~/.config/foo.bk
   ln -sf ~/.dotfiles/foo/.config/foo ~/.config/foo
   ```

3. Update README.md:
   - Add package to the table
   - Add symlink command to manual setup section

4. Commit and push:
   ```bash
   git add foo README.md
   git commit -m "feat: add foo config"
   git push
   ```

### Directory Structure

Each package is a directory at the repo root containing the target structure:

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

### Tracking Changes

Edits to `~/.config/<package>` modify files directly in this repo via symlinks. Changes are live immediately but must be manually committed and pushed:

```bash
cd ~/.dotfiles
git status
git add <package>
git commit -m "config: update <package>"
git push
```

**Important:** Periodically check `git status` for uncommitted changes made on other machines or by automated processes.

### Tool Installation Priority

When setting up a new machine, install tools in this order:

1. **git** - webi or system
2. **gh** - `webi gh` (for git credential helper)
3. **starship** - `curl -sS https://starship.rs/install.sh | sh`
4. **lsd** - `webi lsd`
5. **aliasman** - `webi aliasman`
6. **neovim** - download from GitHub releases (need full package: bin + lib + share)
7. **btop** - build from source or `brew install btop`
8. **ghostty** - download from ghostty.org (macOS)

### Key Lessons Learned

- **neovim**: Don't just copy the binary - needs `lib/` and `share/` directories too. Official tarball structure: `bin/nvim`, `lib/nvim/`, `share/nvim/runtime/`
- **lazy.nvim**: Requires working HTTPS git URLs. Set credential helper: `git config --global credential.helper "/path/to/gh auth git-credential"`
- **starship**: Official install script is interactive; manually download tarball from GitHub releases if needed
- **btop**: No macOS binaries provided; build from source or use brew
