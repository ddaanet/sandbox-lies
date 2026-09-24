#!/usr/bin/env bash
# Shared tracked-file walk and markdown scope for the precommit gate
# scripts (scripts/check-line-limits.sh, scripts/check-links.sh). Sourced,
# not executed: no `set -e` of its own here — the sourcing script's options
# apply.

# True (0) if $1 (root-relative) is in the tracked markdown scope: docs/ at
# any depth, skills/ at any depth, or the root itself; false for markdown
# under a root-level plans/ or plugin-dev/, or anywhere else. Must check
# plans/plugin-dev first: an unanchored `*.md` would otherwise match
# `plans/x.md` too.
markdown_in_scope() {
    case "$1" in
    plans/* | plugin-dev/*) return 1 ;;
    docs/*.md) return 0 ;;
    skills/*.md) return 0 ;;
    */*.md) return 1 ;;
    *.md) return 0 ;;
    *) return 1 ;;
    esac
}

# Validate a lone optional ROOT argument and set $ROOT (default `.`) in the
# caller's shell. A second argument would otherwise be silently ignored and
# the run exit 0 over a tree the caller did not ask for. Sets ROOT directly
# rather than through a command substitution: exit status is lost there,
# and this function's exit 2 must reach the caller's shell.
#
# $1: the program name for diagnostics. $2, $3: the caller's own "$@".
parse_root() {
    local prog="$1"
    if [ "$#" -gt 2 ]; then
        printf '%s: unexpected extra argument: %s\n' "$prog" "$3" >&2
        exit 2
    fi
    # shellcheck disable=SC2034 # consumed by the sourcing script, not here
    ROOT="${2:-.}"
}

# `git ls-files -z` spooled to a temp file, then read back NUL-delimited: a
# `while … done < <(git ls-files -z)` process substitution discards git's
# exit status, so a ROOT that is not a git work tree would read as an empty,
# clean tree instead of failing the run. Explicit mktemp template: BSD
# mktemp has no default one, so a bare `mktemp` is a usage error on macOS. A
# failed `mktemp` leaves the tree unchecked: exit 2, since a bare `set -e`
# abort on the assignment would surface as 1 and read as an overage or a
# broken link. The walk-list variable is deliberately not `local`: the EXIT
# trap that removes it fires after this function has returned, and a local
# would already be unbound by then under `set -u`.
#
# $1: the program name for diagnostics. $2: ROOT, a git work tree. $3: the
# name of a function called once per tracked file, with the root-relative
# path as its only argument.
walk_tracked_files() {
    local prog="$1" root="$2" handler="$3" file
    if ! _tracked_walk_list="$(mktemp "${TMPDIR:-/tmp}/${prog}.XXXXXX")"; then
        echo "$prog: cannot create the walk list temp file" >&2
        exit 2
    fi
    trap 'rm -f "$_tracked_walk_list"' EXIT

    if ! git -C "$root" ls-files -z >"$_tracked_walk_list"; then
        printf '%s: git ls-files failed under %s\n' "$prog" "$root" >&2
        exit 2
    fi

    while IFS= read -r -d '' file; do
        # A symlink, a gitlink's directory, and a path still in the index
        # but deleted from the work tree are not files to check; reading
        # either would fail and exit the run 2. Residual: a file under an
        # unsearchable directory tests absent too, and is skipped rather
        # than failing the run.
        if [ -L "$root/$file" ] || [ ! -f "$root/$file" ]; then
            continue
        fi
        "$handler" "$file"
    done <"$_tracked_walk_list"
}
