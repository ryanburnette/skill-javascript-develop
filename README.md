# Dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Usage

Clone and stow packages:

```bash
git clone https://github.com/ryanburnette/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
stow git nvim ghostty-darwin btop  # macOS
stow git nvim btop                 # Linux
```

To unstow:

```bash
stow -D git nvim ghostty-darwin
```

## Contents

| Package | Description |
|---------|-------------|
| `git` | Git configuration |
| `ghostty-darwin` | Ghostty terminal (macOS) |
| `nvim` | LazyVim Neovim configuration |
| `btop` | System monitor configuration |