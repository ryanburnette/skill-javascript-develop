# Dotfiles Agent Configuration

## Stow Workflow

This repo uses [GNU Stow](https://www.gnu.org/software/stow/) to manage dotfiles as symlink farms.

### Adding a New Config

To add a new package (e.g., `foo` config at `~/.config/foo`):

1. Create stow directory structure:
   ```bash
   mkdir -p foo/.config/foo
   cp -r ~/.config/foo/* foo/.config/foo/
   ```

2. Backup and stow:
   ```bash
   mv ~/.config/foo ~/.config/foo.bk
   stow foo
   ```

3. Update README.md:
   - Add package name to stow commands
   - Add entry to contents table

4. Commit and push:
   ```bash
   git add foo README.md
   git commit -m "feat: add foo config as stow package"
   git push
   ```

### Directory Structure

Each package is a directory at the repo root containing the stow target structure:

```
~/.dotfiles/
├── btop/
│   └── .config/
│       └── btop/
├── git/
│   └── .config/
│       └── git/
└── nvim/
    └── .config/
        └── nvim/
```

Stow creates symlinks in `$HOME` pointing back to the repo.