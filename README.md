# Dotfiles

Symlinked directly to `$HOME` using `ln -sf`.

## Setup

After cloning, run the setup script:

```bash
git clone https://github.com/ryanburnette/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./setup.sh
```

## Package List

| Package | Target | Description |
|---------|--------|-------------|
| `git` | `~/.config/git` | Git configuration |
| `ghostty-darwin` | `~/.config/ghostty` | Ghostty terminal (macOS) |
| `nvim` | `~/.config/nvim` | LazyVim Neovim configuration |
| `btop` | `~/.config/btop` | System monitor configuration |
| `starship` | `~/.config/starship.toml` | Starship prompt configuration |
| `lsd` | `~/.config/lsd` | LSD (ls replacement) configuration |
| `fish` | `~/.config/fish` | Fish shell configuration |
| `ssh` | `~/.ssh/config.d` | SSH config.d host configurations |
| `opencode` | `~/.config/opencode` | OpenCode (partial: AGENTS.md + skills symlinked) |
| `claude` | `~/.claude/settings.json` | Claude Code (partial: settings.json only) |

## Manual Setup

If you prefer to set up manually, run these commands from the `~/.dotfiles` directory:

```bash
# For each package, backup existing file/dir if needed, then:
ln -sf ~/.dotfiles/<package>/.config/<package> ~/.config/<package>

# Example for nvim:
mv ~/.config/nvim ~/.config/nvim.bk
ln -sf ~/.dotfiles/nvim/.config/nvim ~/.config/nvim
```

## Tracking Changes

Edits to `~/.config/<package>` modify files directly in this repo. Periodically check for uncommitted changes:

```bash
cd ~/.dotfiles
git status
git add <package>
git commit -m "config: update <package>"
git push
```

A helper alias:

```bash
alias dotstatus='cd ~/.dotfiles && git status --short'
```

Run `dotstatus` periodically to catch any config changes.

## Git Setup

The shared git config (`~/.config/git/config`) is symlinked from this repo. Machine-specific settings (signing key, credential helper, allowed signers) live in `~/.config/git/config.local`, which is gitignored.

The shared config sets `gpg.format = ssh`, but it does not enable signing by itself. Each machine must have `config.local` with `commit.gpgsign = true` and a `user.signingkey` path, otherwise new commits will be unsigned and GitHub will not mark them as verified.

On each machine, copy the example and adjust:

```bash
cp ~/.dotfiles/git/.config/git/config.local.example ~/.config/git/config.local
```

Edit `config.local` to set the correct signing key path, credential helper, and allowed signers file for that machine. If a machine doesn't support SSH signing, set `gpgsign = false` in its `config.local`.

Note: `credential.helper` does not expand `~/` — use the full absolute path (e.g. `/Users/you/.local/bin/gh auth git-credential`). The other settings (`signingkey`, `allowedSignersFile`) do support `~/` expansion.

Verification checklist for new machines:

```bash
git config --show-origin --get-regexp '^(commit\.gpgsign|user\.signingkey|gpg\.format|gpg\.ssh\.allowedSignersFile|user\.email)'
test -f ~/.ssh/allowed_signers
ssh-keygen -lf ~/.ssh/id_ed25519.pub
gh api user/ssh_signing_keys --jq '.[] | [.title, .key] | @tsv'
```

The local public key listed by `user.signingkey` must also be added to GitHub as an SSH signing key. If `gh api user/ssh_signing_keys` returns a scope error, run:

```bash
gh auth refresh -h github.com -s admin:ssh_signing_key
```

To test local signing without changing the branch, create and verify a temporary signed commit object:

```bash
commit=$(git commit-tree -S HEAD^{tree} -p HEAD -m 'test signing config')
git verify-commit "$commit"
```

## OpenCode Setup

The shared OpenCode instructions and skills are symlinked from this repo. The main `opencode.json` is local-only because it contains machine-specific model and provider choices.

On each machine, copy the example and adjust:

```bash
cp ~/.dotfiles/opencode/.config/opencode/opencode.json.example ~/.config/opencode/opencode.json
```

## SSH Setup

The main `~/.ssh/config` file is system-specific and not managed by this repo. Ensure it includes:

```
Include ~/.ssh/config.d/*.sshconfig
```

The `setup.sh` symlinks the individual SSH config files from `ssh/.ssh/config.d/`. See `ssh/.ssh/config.example` for an example local `~/.ssh/config`, including machine-specific options like `IdentityAgent`.

## macOS Setup

Run the setup script for key repeat settings:

```bash
~/.dotfiles/macos/.local/bin/macos-setup
```

Note: Restart system for key repeat changes to take effect.

## Tool Installation Order

If you need to install tools before setting up configs:

1. `git` - webi or system
2. `gh` - `webi gh` for git credential helper
3. `starship` - `curl -sS https://starship.rs/install.sh | sh`
4. `lsd` - `webi lsd`
5. `aliasman` - `webi aliasman`
6. `neovim` - download from GitHub releases
7. `btop` - build from source or `brew install btop`
8. `ghostty` - download from ghostty.org
9. `opencode` - download from opencode.ai

See individual tool docs for installation methods.
