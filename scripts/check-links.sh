#!/usr/bin/env bash
# Relative markdown link gate: every relative link in the tracked markdown
# scope resolves to an existing path, relative to the linking file.
#
# Usage: check-links.sh [ROOT]
#
# ROOT is a git work tree, default `.`. Scope is `markdown_in_scope`
# (scripts/lib/tracked.sh), shared with scripts/check-line-limits.sh.
#
# Exit codes: 0 clean, 1 on any broken link, 2 on a failure to run.

set -euo pipefail

# The helper beside this script. `%/*` leaves a slash-less path whole, so
# a bare `bash check-links.sh` from scripts/ gets its own arm. A failed
# `source` returns 1, which `set -e` would surface as a broken link: exit 2.
case "${BASH_SOURCE[0]}" in
*/*) LIB_DIR="${BASH_SOURCE[0]%/*}/lib" ;;
*) LIB_DIR=lib ;;
esac
# shellcheck source-path=SCRIPTDIR source=lib/tracked.sh
source "$LIB_DIR/tracked.sh" || exit 2

parse_root check-links "$@"

EXIT_CODE=0

# Report one line and set the exit code for each link in $1 (root-relative)
# whose target does not resolve, relative to $1's own directory.
# shellcheck disable=SC2317 # reached only through handle_file, itself
# invoked indirectly by name via walk_tracked_files's $handler
check_links_in() {
    local file="$1" dir links link target scheme check_target status=0
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
        # Not a file link: an anchor into this file, or a URI with a scheme.
        # A scheme is RFC 3986's: a letter, then letters, digits, `+`, `-`
        # or `.` up to the first `:`. A relative path whose first segment
        # holds a colon must be written `./a:b.md` (RFC 3986 4.2), so
        # `sub/a:b.md` fails the character test and is still checked.
        # Residual: under bash 3.2 the glob ranges follow the locale's
        # collation, so a non-ASCII letter before the colon may pass as a
        # scheme and skip the link.
        case "$target" in
        '#'*) continue ;;
        [A-Za-z]*:*)
            scheme="${target%%:*}"
            case "$scheme" in
            *[!A-Za-z0-9+.-]*) ;;
            *) continue ;;
            esac
            ;;
        esac
        # Only the part before `#` must exist; the report prints the target
        # as written, the string a reader finds in the linking file.
        check_target="${target%%#*}"
        if [ ! -e "$ROOT/$dir/$check_target" ]; then
            printf 'broken-link: %s -> %s\n' "$file" "$target"
            EXIT_CODE=1
        fi
    done <<<"$links"
}

# shellcheck disable=SC2317 # invoked indirectly by name via
# walk_tracked_files's $handler
handle_file() {
    # Not `markdown_in_scope "$1" && check_links_in "$1"`: that form
    # returns 1 for an out-of-scope file, and walk_tracked_files calls its
    # handler under `set -e`, so the run would end 1 at the first one.
    if markdown_in_scope "$1"; then
        check_links_in "$1"
    fi
}

walk_tracked_files check-links "$ROOT" handle_file

exit "$EXIT_CODE"
