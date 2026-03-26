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

## Contents

- `alacritty` - Alacritty terminal config
- `nvim` - LazyVim Neovim configuration