#!/bin/sh
set -eu

# Check all submodule versions against remote main.
# Usage: ./scripts/submodule-versions.sh

g_dotfiles="$(
   CDPATH=
   cd -- "$(dirname -- "$0")/.." && pwd -P
)"

# Print table header
printf "%-45s %-12s %-12s %s\n" "SUBMODULE" "CURRENT" "REMOTE" "STATUS"
printf "%-45s %-12s %-12s %s\n" "-------" "-------" "------" "------"

cd "$g_dotfiles"

# Use git submodule foreach to iterate over each submodule.
# The --quiet flag suppresses the default "entering ..." message.
git submodule foreach --quiet '
    b_path="$sm_path"
    b_hash="$(git rev-parse HEAD)"
    b_remote_hash="$(git ls-remote origin refs/heads/main 2>/dev/null | awk "{print \$1}")" || true

    if test -z "$b_remote_hash"; then
        printf "%-45s %-12s %-12s %s\n" "$b_path" "${b_hash:0:7}" "N/A" "NO REMOTE"
    elif test "$b_hash" = "$b_remote_hash"; then
        printf "%-45s %-12s %-12s %s\n" "$b_path" "${b_hash:0:7}" "${b_remote_hash:0:7}" "UP TO DATE"
    else
        printf "%-45s %-12s %-12s %s\n" "$b_path" "${b_hash:0:7}" "${b_remote_hash:0:7}" "OUTDATED"
    fi
'
