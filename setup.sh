#!/bin/sh
set -eu

DOTFILES="$HOME/.dotfiles"
BACKUP_MARKER=".bk"

echo "Setting up dotfiles symlinks..."

# Function to safely create symlink with backup
link_dot() {
    src="$1"
    dst="$2"

    # Check if source exists
    if [ ! -e "$src" ]; then
        echo "  SKIP: $src does not exist"
        return
    fi

    # Remove existing symlink (never mv a symlink - it can point into the repo)
    if [ -L "$dst" ]; then
        echo "  REMOVE: $dst (stale symlink)"
        rm "$dst"
    fi

    # Backup existing regular file/directory
    if [ -e "$dst" ]; then
        backup="${dst}${BACKUP_MARKER}"
        echo "  BACKUP: $dst -> $backup"
        mv "$dst" "$backup"
    fi

    # Create parent directory if needed
    dst_dir="$(dirname "$dst")"
    if [ ! -d "$dst_dir" ]; then
        echo "  MKDIR: $dst_dir"
        mkdir -p "$dst_dir"
    fi

    # Create symlink
    echo "  LINK: $dst -> $src"
    ln -sf "$src" "$dst"
}

# Git config
link_dot "$DOTFILES/git/.config/git" "$HOME/.config/git"

# Ghostty (macOS only)
if [ "$(uname)" = "Darwin" ]; then
    link_dot "$DOTFILES/ghostty-darwin/.config/ghostty" "$HOME/.config/ghostty"
fi

# Neovim
link_dot "$DOTFILES/nvim/.config/nvim" "$HOME/.config/nvim"

# btop
link_dot "$DOTFILES/btop/.config/btop" "$HOME/.config/btop"

# starship (note: starship uses starship.toml not directory)
link_dot "$DOTFILES/starship/.config/starship.toml" "$HOME/.config/starship.toml"

# lsd
link_dot "$DOTFILES/lsd/.config/lsd" "$HOME/.config/lsd"

# fish
link_dot "$DOTFILES/fish/.config/fish" "$HOME/.config/fish"

# SSH config.d files (bnna.sshconfig now contains all per-host entries using sclient)
# NOTE: The repo's ssh/.ssh/config.example is an EXAMPLE only. Never symlink ~/.ssh/config itself —
# each machine maintains its own local ~/.ssh/config (which should Include config.d/*.sshconfig).
link_dot "$DOTFILES/ssh/.ssh/config.d/bnna.sshconfig" "$HOME/.ssh/config.d/bnna.sshconfig"
link_dot "$DOTFILES/ssh/.ssh/config.d/cogburnbros.sshconfig" "$HOME/.ssh/config.d/cogburnbros.sshconfig"
link_dot "$DOTFILES/ssh/.ssh/config.d/ryanburnette.sshconfig" "$HOME/.ssh/config.d/ryanburnette.sshconfig"

# opencode (partial - AGENTS.md and skills only, opencode.json has local settings)
mkdir -p "$HOME/.config/opencode"
link_dot "$DOTFILES/opencode/.config/opencode/AGENTS.md" "$HOME/.config/opencode/AGENTS.md"
link_dot "$DOTFILES/opencode/.config/opencode/skills" "$HOME/.config/opencode/skills"

# Claude Code (settings.json only - rest of ~/.claude/ is runtime data)
link_dot "$DOTFILES/claude/.claude/settings.json" "$HOME/.claude/settings.json"

echo ""
echo "Done! Note:"
echo "  - SSH config requires manual setup (see README.md)"
echo "  - Run ~/.dotfiles/macos/.local/bin/macos-setup for macOS settings"
echo "  - Restart your terminal for starship/fish changes to take effect"