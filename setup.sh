#!/bin/sh
set -eu

g_dotfiles="$(CDPATH=; cd -- "$(dirname -- "$0")" && pwd -P)"
g_backup_marker=".bk"

echo "Setting up dotfiles symlinks..."

# Function to safely create symlink with backup
link_dot() {
    src="$1"
    dst="$2"

    # Check if source exists
    if test ! -e "$src"; then
        echo "  SKIP: $src does not exist"
        return
    fi

    # Prevent circular symlinks: if the dst parent resolves into the dotfiles
    # repo (via directory-level symlinks), creating another symlink would either
    # be redundant or create a circular link inside the repo
    dst_parent="$(dirname "$dst")"
    if test -d "$dst_parent" || test -L "$dst_parent"; then
        dst_real="$(cd "$dst_parent" 2>/dev/null && pwd -P)" || dst_real=""
        case "$dst_real" in
            "$g_dotfiles" | "$g_dotfiles"/*)
                echo "  SKIP: $dst (parent already links into dotfiles repo)"
                return
                ;;
        esac
    fi

    # Remove existing symlink (never mv a symlink - it can point into the repo)
    if test -L "$dst"; then
        echo "  REMOVE: $dst (stale symlink)"
        rm "$dst"
    fi

    # Backup existing regular file/directory (increment to avoid overwriting previous backups)
    if test -e "$dst"; then
        backup="${dst}${g_backup_marker}"
        i=2
        while test -e "$backup"; do
            backup="${dst}${g_backup_marker}${i}"
            i=$((i + 1))
        done
        echo "  BACKUP: $dst -> $backup"
        mv "$dst" "$backup"
    fi

    # Create parent directory if needed
    dst_dir="$(dirname "$dst")"
    if test ! -d "$dst_dir"; then
        echo "  MKDIR: $dst_dir"
        mkdir -p "$dst_dir"
    fi

    # Create symlink
    echo "  LINK: $dst -> $src"
    ln -sf "$src" "$dst"
}

# Git config
link_dot "$g_dotfiles/git/.config/git" "$HOME/.config/git"

# Ghostty (macOS only)
if test "$(uname)" = "Darwin"; then
    link_dot "$g_dotfiles/ghostty-darwin/.config/ghostty" "$HOME/.config/ghostty"
fi

# Neovim
link_dot "$g_dotfiles/nvim/.config/nvim" "$HOME/.config/nvim"

# btop
link_dot "$g_dotfiles/btop/.config/btop" "$HOME/.config/btop"

# starship (note: starship uses starship.toml not directory)
link_dot "$g_dotfiles/starship/.config/starship.toml" "$HOME/.config/starship.toml"

# lsd
link_dot "$g_dotfiles/lsd/.config/lsd" "$HOME/.config/lsd"

# fish
link_dot "$g_dotfiles/fish/.config/fish" "$HOME/.config/fish"

# SSH config.d files (bnna.sshconfig now contains all per-host entries using sclient)
# NOTE: The repo's ssh/.ssh/config.example is an EXAMPLE only. Never symlink ~/.ssh/config itself —
# each machine maintains its own local ~/.ssh/config (which should Include config.d/*.sshconfig).
link_dot "$g_dotfiles/ssh/.ssh/config.d/bnna.sshconfig" "$HOME/.ssh/config.d/bnna.sshconfig"
link_dot "$g_dotfiles/ssh/.ssh/config.d/cogburnbros.sshconfig" "$HOME/.ssh/config.d/cogburnbros.sshconfig"
link_dot "$g_dotfiles/ssh/.ssh/config.d/ryanburnette.sshconfig" "$HOME/.ssh/config.d/ryanburnette.sshconfig"


# Agent conventions and skills (submodules — each skill is its own repo)
if test -f "$g_dotfiles/.gitmodules"; then
    git -C "$g_dotfiles" submodule update --init --recursive 2>/dev/null
fi
link_dot "$g_dotfiles/agents/.agents/AGENTS.md" "$HOME/.agents/AGENTS.md"
link_dot "$g_dotfiles/agents/.agents/skills" "$HOME/.agents/skills"

# opencode (partial - AGENTS.md only, opencode.json has local settings, skills via ~/.agents/skills/)
link_dot "$g_dotfiles/opencode/.config/opencode/AGENTS.md" "$HOME/.config/opencode/AGENTS.md"

# Claude Code (settings.json only - rest of ~/.claude/ is runtime data)
link_dot "$g_dotfiles/claude/.claude/settings.json" "$HOME/.claude/settings.json"

# proxmox-sh (LXC management; clone from https://github.com/therootcompany/proxmox-sh)
link_dot "$g_dotfiles/proxmox-sh/.config/proxmox-sh" "$HOME/.config/proxmox-sh"

# Pi coding agent (settings.json + extensions; packages installed separately via pi install)
link_dot "$g_dotfiles/pi/.config/pi" "$HOME/.pi/agent"

echo ""
echo "Done! Note:"
echo "  - SSH config requires manual setup (see README.md)"
echo "  - Run ~/.dotfiles/macos/.local/bin/macos-setup for macOS settings"
echo "  - Install pi packages: pi install npm:@aliou/pi-guardrails && pi install npm:pi-brave-search && pi install git:github.com/visua1hue/pi-pane"
echo "  - Restart your terminal for starship/fish changes to take effect"
