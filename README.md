# Dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Usage

Clone and stow:

```bash
git clone https://github.com/ryanburnette/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
stow .
```

To unstow:

```bash
stow -D .
```

## Platform-Specific Configs

Ghostty is macOS-only. On Linux, skip it:

```bash
stow git nvim
```

## Contents

| Package | Description |
|---------|-------------|
| `git` | Git configuration |
| `ghostty-darwin` | Ghostty terminal (macOS) |
| `nvim` | LazyVim Neovim configuration |