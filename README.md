# Dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Usage

Clone and stow packages:

```bash
git clone https://github.com/ryanburnette/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
stow git nvim ghostty-darwin btop starship lsd ssh macos opencode  # macOS
stow git nvim btop starship lsd ssh opencode                 # Linux
```

To unstow:

```bash
stow -D git nvim ghostty-darwin
```

## Tracking Changes

Stow uses symlinks, so edits to `~/.config/<package>` modify files directly in this repo. Periodically check for uncommitted changes:

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

Run `dotstatus` periodically to catch any config changes made on this machine or by automated processes.

## Contents

| Package | Description |
|---------|-------------|
| `git` | Git configuration |
| `ghostty-darwin` | Ghostty terminal (macOS) |
| `nvim` | LazyVim Neovim configuration |
| `btop` | System monitor configuration |
| `starship` | Starship prompt configuration |
| `macos` | macOS system setup script |
| `lsd` | LSD (ls replacement) configuration |
| `ssh` | SSH config.d host configurations |
| `opencode` | OpenCode configuration with skills |

## SSH Setup

After stowing the `ssh` package, ensure `~/.ssh/config` includes:

```
Include ~/.ssh/config.d/**/*.sshconfig
```

This file is system-specific (may contain `Host *` blocks with local paths like the 1Password SSH agent) and is not managed by stow.