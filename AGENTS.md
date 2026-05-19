# Dotfiles Agent Configuration

## Before Actions

**Before git operations:** Use `skill:git-workflow`. This repo has `bypass_private_pr: always` — direct commits to main are allowed.

**Before diagnosing unverified commits:** Check `~/.config/git/config.local` exists and contains `commit.gpgsign = true`, `user.signingkey`, and `gpg.ssh.allowedSignersFile`. The shared Git config only sets SSH signing format; machine-local config enables signing.

**Before editing configs:** If changes are made to configs not managed by this repo, offer to add them as symlinks.

## Don'ts

- Don't edit `~/.config/git/config.local` — it's machine-local
- Don't commit from inside a symlinked path — always `cd ~/.dotfiles` first
- Don't commit `auth.json`, `models.json`, or API keys — they're machine-local and gitignored
- Don't add a pi package without also updating `setup.sh` and `README.md`
- Don't add or remove a skill without updating the skills table in `agents/.agents/AGENTS.md`

## Symlink Workflow

This repo uses direct symlinks to manage dotfiles. See `README.md` for the full package list and manual setup commands.

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
3. Update `setup.sh` and `README.md` (add package to table and manual setup section)
4. Commit and push

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

### Pi Coding Agent

`~/.pi/agent` is symlinked to `pi/.config/pi/` in this repo. Settings and extension configs are tracked; secrets and generated files are gitignored.

**Pi packages** must be installed separately (not via symlinks) — they live in `~/.pi/agent/npm/` and `~/.pi/agent/git/`, which are gitignored:

```bash
pi install npm:@aliou/pi-guardrails
pi install npm:pi-brave-search
pi install git:github.com/visua1hue/pi-pane
```

After installing guardrails, run `/guardrails:onboarding` in pi.

**Adding a new pi package:**

1. Install: `pi install npm:<package>` or `pi install git:github.com/...`
2. Commit the updated `pi/.config/pi/settings.json` (packages list is auto-updated).
3. Add the install command to `setup.sh`, `README.md`, and this section.

**Secrets:** `auth.json`, `models.json`, and `BRAVE_API_KEY` are machine-local and gitignored. Never commit API keys.

### Key Lessons Learned

- **neovim**: Don't just copy the binary — needs `lib/` and `share/` directories too. Official tarball structure: `bin/nvim`, `lib/nvim/`, `share/nvim/runtime/`
- **lazy.nvim**: Requires working HTTPS git URLs. Set credential helper: `git config --global credential.helper "/path/to/gh auth git-credential"`
- **starship**: Official install script is interactive; manually download tarball from GitHub releases if needed
- **btop**: No macOS binaries provided; build from source or use brew
