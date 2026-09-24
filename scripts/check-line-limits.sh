#!/usr/bin/env bash
# Line-count cap gate for tracked source and markdown.
#
# Usage: check-line-limits.sh [ROOT]
#
# ROOT is a git work tree, default `.`. Ported from edify's
# scripts/check_line_limits.sh (Item 2.1), without its allowlist, walking
# `git ls-files -z` instead of `find` so `.venv/` and gitlinks stay out.
#
# Scope, in root-relative paths, where a `case` `*` crosses `/`: markdown
# at any depth under docs/, cap 400; under skills/, cap 200 for a
# `skills/*/SKILL.md` and 400 for any other; at the root itself (no `/` in
# the path), cap 400. A script (`.sh`, `.bash`, `.bats`, `.py`) at any
# depth, cap 400. Nothing under a root-level `plans/` or `plugin-dev/`.
#
# Exit codes: 0 clean, 1 on any overage, 2 on a failure to run.

set -euo pipefail

# shellcheck source=scripts/lib/tracked.sh
source "${BASH_SOURCE[0]%/*}/lib/tracked.sh"

parse_root check-line-limits "$@"

EXIT_CODE=0

# Report one line and set the exit code if $1 (root-relative) exceeds $2
# lines.
# shellcheck disable=SC2317 # reached only through handle_file, itself
# invoked indirectly by name via walk_tracked_files's $handler
check_cap() {
    local file="$1" cap="$2" line_count
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

# Dispatch one tracked file to its cap, or leave it out of scope. Root-level
# plans/ and plugin-dev/ are excluded for every file type; must precede the
# script arm below (a script there would otherwise be capped by it) and
# needs no help from `markdown_in_scope`, which excludes them itself.
# SKILL.md's own 200 cap must precede the markdown fallback below: both
# would otherwise match a SKILL.md, and `case` takes the first.
# shellcheck disable=SC2317 # invoked indirectly by name via
# walk_tracked_files's $handler
handle_file() {
    local file="$1"
    case "$file" in
    plans/* | plugin-dev/*) ;;
    skills/*/SKILL.md) check_cap "$file" 200 ;;
    *.sh | *.bash | *.bats | *.py) check_cap "$file" 400 ;;
    *)
        if markdown_in_scope "$file"; then
            check_cap "$file" 400
        fi
        ;;
    esac
}

walk_tracked_files check-line-limits "$ROOT" handle_file

exit "$EXIT_CODE"
