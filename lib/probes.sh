#!/usr/bin/env bash
# lib/probes.sh — probe_<verdict> functions the hook runs outside the sandbox
# (A-3 contract, docs/design.md FR-4): each probe reads the Bash tool result
# text on stdin, takes the sandbox flag as $1 and the payload cwd as $2, and
# prints an outcome token on its first line followed by key=value lines
# (pid=, bytes=, age=, path=); exit 0.
#
# set -u as in lib/matchers.sh and lib/verdicts.sh. hooks/annotate.sh sets it
# before sourcing those; bats does not, so setting it here keeps an unset
# variable an error when a test sources this file directly.
set -u

# Prints the lock path from git's "Unable to create '<path>.lock': <reason>"
# line on stdin, first such line only; empty when there is none. Git quotes
# the path without escaping, so the capture runs to the last `.lock': ` on
# the line rather than stopping at the first single quote: a path holding a
# quote survives, one holding `.lock': ` itself would not. The leading U is
# case-insensitive, as in lib/matchers.sh match_git_lock. LC_ALL=C: under a
# UTF-8 locale GNU sed's `.` does not match an invalid byte and BSD sed exits
# with "illegal byte sequence", so either loses a path a byte-wise match keeps.
_probe_lock_path() {
    LC_ALL=C sed -n "s/.*[Uu]nable to create '\(.*\.lock\)': .*/\1/p" \
        | head -n 1
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
