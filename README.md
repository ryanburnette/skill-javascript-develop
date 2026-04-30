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

## SSH Setup

The main `~/.ssh/config` file is system-specific and not managed by this repo. Ensure it includes:

```
Include ~/.ssh/config.d/*.sshconfig
Include ~/.ssh/config.d/bnna.d/*.sshconfig
```

The `setup.sh` symlinks the individual SSH config files from `ssh/.ssh/config.d/`.

## macOS Setup

Run the setup script for key repeat settings:

```bash
~/.dotfiles/macos/.local/bin/macos-setup
```

Note: Restart system for key repeat changes to take effect.

## Tool Installation Order

If you need to install tools before setting up configs:

1. `git` - webi or system
2. `starship` - `curl -sS https://starship.rs/install.sh | sh`
3. `lsd` - `webi lsd`
4. `btop` - build from source or `brew install btop`
5. `neovim` - download from GitHub releases
6. `ghostty` - download from ghostty.org
7. `opencode` - download from opencode.ai
8. `aliasman` - `webi aliasman`

See individual tool docs for installation methods.