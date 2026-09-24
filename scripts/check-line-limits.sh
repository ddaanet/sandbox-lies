#!/usr/bin/env bash
# Line-count cap gate for tracked source and markdown.
#
# Usage: check-line-limits.sh [ROOT]
#
# ROOT is a git work tree, default `.`. Ported from
# /Users/david/code/edify/scripts/check_line_limits.sh (Item 2.1), without its
# allowlist, walking `git ls-files -z` instead of `find` so `.venv/` and
# gitlinks stay out.
#
# Scope (grows across later slices of this item): markdown under docs/, cap
# 400.
#
# Exit codes: 0 clean, 1 on any overage, 2 on a failure to run.

set -euo pipefail

ROOT="${1:-.}"

EXIT_CODE=0

# Report one line and set the exit code if $1 (root-relative) exceeds $2
# lines.
check_cap() {
    local file="$1" cap="$2" line_count
    # An unreadable file leaves the tree unchecked: exit 2, since a bare
    # `set -e` abort here would surface as 1 and read as an overage. `tr`
    # strips BSD `wc`'s left padding and makes this a pipeline, so the guard
    # depends on `pipefail` (set above): without it the status would be
    # `tr`'s zero and an unreadable file would slip through as line_count="".
    if ! line_count=$(wc -l <"$ROOT/$file" | tr -d ' '); then
        echo "check-line-limits: cannot read $file" >&2
        exit 2
    fi
    if [ "$line_count" -gt "$cap" ]; then
        echo "oversized-file: $file: $line_count lines > $cap"
        EXIT_CODE=1
    fi
}

# `git ls-files -z` spooled to a temp file, read back by the caller's own
# loop: a `while … done < <(git ls-files -z)` process substitution discards
# git's exit status, so a ROOT that is not a git work tree would read as an
# empty, clean tree instead of failing the run. Explicit mktemp template:
# BSD mktemp has no default one, so a bare `mktemp` is a usage error on
# macOS. A failed `mktemp` leaves the tree unchecked: exit 2, since a bare
# `set -e` abort on the assignment would surface as 1 and read as an
# overage.
if ! WALK_LIST="$(mktemp "${TMPDIR:-/tmp}/check-line-limits.XXXXXX")"; then
    echo "check-line-limits: cannot create the walk list temp file" >&2
    exit 2
fi
trap 'rm -f "$WALK_LIST"' EXIT

if ! git -C "$ROOT" ls-files -z >"$WALK_LIST"; then
    echo "check-line-limits: git ls-files failed under $ROOT" >&2
    exit 2
fi

while IFS= read -r -d '' file; do
    case "$file" in
    docs/*.md) check_cap "$file" 400 ;;
    esac
done <"$WALK_LIST"

exit "$EXIT_CODE"
