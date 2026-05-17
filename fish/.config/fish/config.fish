if status is-interactive
    # Commands to run in interactive sessions can go here
end

# Generated for envman. Do not edit.
test -s "$HOME/.config/envman/load.fish"; and source "$HOME/.config/envman/load.fish"

command -q starship; and starship init fish | source


# opencode
fish_add_path "$HOME/.opencode/bin"
