#!/usr/bin/env bash
# Relative markdown link gate: every relative link in the tracked markdown
# scope resolves to an existing path, relative to the linking file.
#
# Usage: check-links.sh [ROOT]
#
# ROOT is a git work tree, default `.`. Scope mirrors
# scripts/check-line-limits.sh's markdown scope (Item 2.1).
#
# Slice 1: docs/*.md only. Later slices add skills/, root and exclusions
# (slice 2); skipping URLs, mailto:, pure anchors and #fragment stripping
# (slice 3); ignoring code spans and fenced blocks (slice 4).
#
# Exit codes: 0 clean, 1 on any broken link, 2 on a failure to run.

set -euo pipefail

# shellcheck source=scripts/lib/tracked.sh
source "${BASH_SOURCE[0]%/*}/lib/tracked.sh"

parse_root check-links "$@"

EXIT_CODE=0

# Report one line and set the exit code for each link in $1 (root-relative)
# whose target does not resolve, relative to $1's own directory.
# shellcheck disable=SC2317 # reached only through handle_file, itself
# invoked indirectly by name via walk_tracked_files's $handler
check_links_in() {
    local file="$1" dir links link target status=0
    # Parameter expansion, not `$(dirname …)`: a command substitution strips
    # a trailing newline from a directory name.
    case "$file" in
    */*) dir="${file%/*}" ;;
    *) dir=. ;;
    esac
    # Only the `](target)` half of an inline link: the link text may hold
    # parentheses or nested brackets, and matching it too would cut the
    # target at the wrong `(` or miss the link outright. Residual: a target
    # containing `)`, which CommonMark allows when balanced, is cut at its
    # first `)` and reported broken — loud, not silent. `LC_ALL=C` and `-a`:
    # in a UTF-8 locale a target with a non-UTF-8 byte fails `[^)]` and goes
    # unmatched, and a NUL byte makes grep print "binary file matches" in
    # place of the links, both exit 0 over links never checked.
    # Captured rather than read from `< <(grep …)`: a process substitution
    # discards grep's status. 1 is no match; 2 is an unreadable file, and
    # leaves it unchecked: exit 2, since a bare `set -e` abort would surface
    # as 1 and read as a broken link.
    links=$(LC_ALL=C grep -aoE -e '\]\([^)]*\)' -- "$ROOT/$file") || status=$?
    if [ "$status" -gt 1 ]; then
        printf 'check-links: cannot read %s\n' "$file" >&2
        exit 2
    fi
    while IFS= read -r link; do
        [ -n "$link" ] || continue
        target="${link#](}"
        target="${target%)}"
        if [ ! -e "$ROOT/$dir/$target" ]; then
            printf 'broken-link: %s -> %s\n' "$file" "$target"
            EXIT_CODE=1
        fi
    done <<<"$links"
}

# Slice 1 scope: docs/*.md only. A later slice widens this to
# `markdown_in_scope`'s full table (Item 2.2's scope slice).
# shellcheck disable=SC2317 # invoked indirectly by name via
# walk_tracked_files's $handler
handle_file() {
    case "$1" in
    docs/*.md) check_links_in "$1" ;;
    esac
}

walk_tracked_files check-links "$ROOT" handle_file

exit "$EXIT_CODE"
