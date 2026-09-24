#!/usr/bin/env bash
# Relative markdown link gate: every relative inline link in the tracked
# markdown scope resolves to an existing path, relative to the linking file.
# Inline only: a reference definition (`[r]: path`) is not checked at all.
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
# check_links_in runs the other helper once per file: missing, it would
# fail the first file checked and name that file as the unreadable one.
if [ ! -r "$LIB_DIR/strip-code.awk" ]; then
    printf 'check-links: cannot read %s\n' "$LIB_DIR/strip-code.awk" >&2
    exit 2
fi

parse_root check-links "$@"

EXIT_CODE=0

# Report one line and set the exit code for each link in $1 (root-relative)
# whose target does not resolve, relative to $1's own directory.
# shellcheck disable=SC2317 # reached only through handle_file, itself
# invoked indirectly by name via walk_tracked_files's $handler
check_links_in() {
    local file="$1" dir links link target scheme check_target
    # Parameter expansion, not `$(dirname …)`: a command substitution strips
    # a trailing newline from a directory name.
    case "$file" in
    */*) dir="${file%/*}" ;;
    *) dir=. ;;
    esac
    # A code span or a fenced block is not a link, even when its content
    # would otherwise parse as one: scripts/lib/strip-code.awk blanks them
    # before grep sees the file. The file reaches awk by redirection, not as
    # an operand: awk takes an operand shaped `name=value` — a ROOT named
    # `x=y` — as a variable assignment and reads stdin in its place.
    # Only the `](target)` half of an inline link: the link text may hold
    # parentheses or nested brackets, and matching it too would cut the
    # target at the wrong `(` or miss the link outright. Residuals, each
    # reported broken — loud, not silent: a target containing `)`, which
    # CommonMark allows when balanced, cut at its first `)`; a link title
    # (`(b.md "t")`); an angle-bracketed target (`(<b.md>)`).
    # `LC_ALL=C` and `-a`: in a UTF-8 locale a target with a non-UTF-8 byte
    # fails `[^)]` and goes unmatched, and a NUL byte makes grep print
    # "binary file matches" in place of the links, both exit 0 over links
    # never checked.
    # Captured rather than read from `< <(…)`: a process substitution
    # discards the pipeline's status. grep's 1 is no match, folded to 0;
    # under `pipefail` any other failure — an unreadable file, which fails
    # the redirection, awk's own, or grep's 2 — fails the capture and leaves
    # the file unchecked: exit 2, since a bare `set -e` abort would surface
    # as 1 and read as a broken link.
    if ! links=$(LC_ALL=C awk -f "$LIB_DIR/strip-code.awk" <"$ROOT/$file" |
        { LC_ALL=C grep -aoE -e '\]\([^)]*\)' || [ "$?" -eq 1 ]; }); then
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
        # Residual, silent: a target climbing out of ROOT (`../../x`) passes
        # when the host happens to hold that path.
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
