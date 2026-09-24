#!/usr/bin/env bash
# lib/probes.sh — probe_<verdict> functions the hook runs outside the sandbox
# (A-3 contract, docs/design.md FR-4): each probe reads the Bash tool result
# text on stdin, takes the sandbox flag as $1 and the payload cwd as $2, and
# prints an outcome token on its first line followed by key=value lines
# (pid=, bytes=, age=, path=); exit 0.
#
# Item 2.4 slice 1: the absent-lock case only, flag false -> mask. Path
# extraction is case-insensitive on the leading U, as lib/matchers.sh
# match_git_lock is. Later slices add gone/orphan/held/unknown, the holder
# check, size/age, the character-device rule and relative-path resolution
# against $2; probe_config_lock stays an inert stub until slice 8.
#
# Consistent with lib/matchers.sh and lib/verdicts.sh: sourced by
# hooks/annotate.sh, which already sets -u, and directly by bats tests, which
# do not; keeping -u here means an unset variable errors in both contexts.
set -u

# Extracts the single-quoted path from git's "Unable to create '<path>':
# File exists" line on stdin.
_probe_lock_path() {
    sed -n "s/.*[Uu]nable to create '\([^']*\)'.*/\1/p" | head -n 1
}

probe_git_lock() {
    local flag="$1" text path
    text=$(cat)
    path=$(printf '%s\n' "$text" | _probe_lock_path)

    if [ ! -e "$path" ] && [ ! -L "$path" ] && [ "$flag" = false ]; then
        printf 'mask\n'
        printf 'path=%s\n' "$path"
    fi
}

probe_config_lock() {
    cat >/dev/null
}
