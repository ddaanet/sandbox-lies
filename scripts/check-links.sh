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

# One optional ROOT: a second argument would otherwise be ignored and the run
# exit 0 over a tree the caller did not ask for.
if [ "$#" -gt 1 ]; then
    printf 'check-links: unexpected extra argument: %s\n' "$2" >&2
    exit 2
fi
ROOT="${1:-.}"

EXIT_CODE=0

# Report one line and set the exit code for each link in $1 (root-relative)
# whose target does not resolve, relative to $1's own directory.
check_links_in() {
    local file="$1" dir link target
    dir=$(dirname "$file")
    while IFS= read -r link; do
        [ -n "$link" ] || continue
        target="${link#*(}"
        target="${target%)}"
        if [ ! -e "$ROOT/$dir/$target" ]; then
            printf 'broken-link: %s -> %s\n' "$file" "$target"
            EXIT_CODE=1
        fi
    done < <(grep -oE '\[[^]]*\]\([^)]*\)' "$ROOT/$file")
}

# `git ls-files -z` spooled to a temp file, read back by the loop below: a
# `while … done < <(git ls-files -z)` process substitution discards git's exit
# status, so a ROOT that is not a git work tree would read as an empty, clean
# tree instead of failing the run. Explicit mktemp template: BSD mktemp has no
# default one, so a bare `mktemp` is a usage error on macOS. A failed `mktemp`
# leaves the tree unchecked: exit 2, since a bare `set -e` abort on the
# assignment would surface as 1 and read as an overage.
if ! WALK_LIST="$(mktemp "${TMPDIR:-/tmp}/check-links.XXXXXX")"; then
    echo "check-links: cannot create the walk list temp file" >&2
    exit 2
fi
trap 'rm -f "$WALK_LIST"' EXIT

if ! git -C "$ROOT" ls-files -z >"$WALK_LIST"; then
    printf 'check-links: git ls-files failed under %s\n' "$ROOT" >&2
    exit 2
fi

while IFS= read -r -d '' file; do
    case "$file" in
    docs/*.md)
        # What the port's `find -type f` skipped: a symlink, a gitlink's
        # directory, and a path still in the index but deleted from the work
        # tree are not files to scan.
        if [ -L "$ROOT/$file" ] || [ ! -f "$ROOT/$file" ]; then
            continue
        fi
        check_links_in "$file"
        ;;
    esac
done <"$WALK_LIST"

exit "$EXIT_CODE"
