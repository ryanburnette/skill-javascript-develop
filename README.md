# Dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Usage

Clone and stow packages:

```bash
git clone https://github.com/ryanburnette/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
stow git nvim ghostty-darwin btop starship macos  # macOS
stow git nvim btop starship                 # Linux
```

To unstow:

```bash
stow -D git nvim ghostty-darwin
```

## Tracking Changes

Stow uses symlinks, so edits to `~/.config/<package>` modify files directly in this repo. Track changes:

```bash
cd ~/.dotfiles
git status
git add <package>
git commit -m "config: update <package>"
git push
```

## Contents

| Package | Description |
|---------|-------------|
| `git` | Git configuration |
| `ghostty-darwin` | Ghostty terminal (macOS) |
| `nvim` | LazyVim Neovim configuration |
| `btop` | System monitor configuration |
| `starship` | Starship prompt configuration |
| `macos` | macOS system setup script |