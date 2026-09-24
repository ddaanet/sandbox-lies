#!/usr/bin/env bash
# Line-count cap gate for tracked source and markdown.
#
# Usage: check-line-limits.sh [ROOT]
#
# ROOT is a git work tree, default `.`. Ported from edify's
# scripts/check_line_limits.sh (Item 2.1), without its allowlist, walking
# `git ls-files -z` instead of `find` so `.venv/` and gitlinks stay out.
#
# Scope (grows across later slices of this item), in root-relative paths,
# where a `case` `*` crosses `/`: markdown at any depth under docs/, cap
# 400; under skills/, cap 200 for a `skills/*/SKILL.md` and 400 for any
# other; at the root itself (no `/` in the path), cap 400. A script
# (`.sh`, `.bash`, `.bats`, `.py`) at any depth, cap 400, except under a
# root-level `plans/` or `plugin-dev/`.
#
# Exit codes: 0 clean, 1 on any overage, 2 on a failure to run.

set -euo pipefail

# One optional ROOT: a second argument would otherwise be ignored and the run
# exit 0 over a tree the caller did not ask for.
if [ "$#" -gt 1 ]; then
    printf 'check-line-limits: unexpected extra argument: %s\n' "$2" >&2
    exit 2
fi
ROOT="${1:-.}"

EXIT_CODE=0

# Report one line and set the exit code if $1 (root-relative) exceeds $2
# lines.
check_cap() {
    local file="$1" cap="$2" line_count
    # What the port's `find -type f` skipped: a symlink, a gitlink's
    # directory, and a path still in the index but deleted from the work tree
    # are not files to count. Residual: a file under an unsearchable
    # directory tests absent too, and is skipped rather than failing the run.
    if [ -L "$ROOT/$file" ] || [ ! -f "$ROOT/$file" ]; then
        return
    fi
    # An unreadable file leaves the tree unchecked: exit 2, since a bare
    # `set -e` abort here would surface as 1 and read as an overage. `awk`'s
    # NR, not `wc -l`: `wc` counts newlines, so a last line with no
    # terminating newline would go uncounted and a cap+1-line file pass.
    if ! line_count=$(awk 'END { print NR }' <"$ROOT/$file"); then
        printf 'check-line-limits: cannot read %s\n' "$file" >&2
        exit 2
    fi
    if [ "$line_count" -gt "$cap" ]; then
        printf 'oversized-file: %s: %s lines > %s\n' "$file" "$line_count" "$cap"
        EXIT_CODE=1
    fi
}

# `git ls-files -z` spooled to a temp file, read back by the loop below: a
# `while … done < <(git ls-files -z)` process substitution discards git's exit
# status, so a ROOT that is not a git work tree would read as an empty, clean
# tree instead of failing the run. Explicit mktemp template: BSD mktemp has no
# default one, so a bare `mktemp` is a usage error on macOS. A failed `mktemp`
# leaves the tree unchecked: exit 2, since a bare `set -e` abort on the
# assignment would surface as 1 and read as an overage.
if ! WALK_LIST="$(mktemp "${TMPDIR:-/tmp}/check-line-limits.XXXXXX")"; then
    echo "check-line-limits: cannot create the walk list temp file" >&2
    exit 2
fi
trap 'rm -f "$WALK_LIST"' EXIT

if ! git -C "$ROOT" ls-files -z >"$WALK_LIST"; then
    printf 'check-line-limits: git ls-files failed under %s\n' "$ROOT" >&2
    exit 2
fi

while IFS= read -r -d '' file; do
    case "$file" in
    # Must precede the script arm below: `case` takes the first match, and a
    # script under a root-level `plans/` or `plugin-dev/` would otherwise be
    # capped by it. Root-anchored: an unadorned `plans/*` only matches a path
    # that starts with it, so a nested `tools/plans/x.sh` still reaches the
    # script arm.
    plans/* | plugin-dev/*) ;;
    docs/*.md) check_cap "$file" 400 ;;
    # Must precede the general skills/ arm below: `case` takes the first
    # match, and a SKILL.md is also `skills/*.md`.
    skills/*/SKILL.md) check_cap "$file" 200 ;;
    skills/*.md) check_cap "$file" 400 ;;
    # Markdown under any other directory (`lib/`, `.claude/skills/`) is out
    # of scope. This arm only exists to keep it from the root arm below,
    # which a `case` `*` would otherwise let cross `/`; it names `.md` so an
    # arm for another file type works in any position.
    */*.md) ;;
    *.md) check_cap "$file" 400 ;;
    *.sh | *.bash | *.bats | *.py) check_cap "$file" 400 ;;
    esac
done <"$WALK_LIST"

exit "$EXIT_CODE"
