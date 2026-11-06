#!/usr/bin/env bash
# Shared tracked-file walk and markdown scope for the precommit gate
# script scripts/check-links.sh. Sourced, not executed: no `set -e` of its
# own here — the sourcing script's options apply.

# True (0) if $1 (root-relative) is in the tracked markdown scope: docs/ at
# any depth, skills/ at any depth, or the root itself; false for markdown in
# any other directory, root-level plans/ and plugin-dev/ included, and for
# anything that is not markdown. An allowlist, so those two need no arm of
# their own: `*/*.md` turns them away before `*.md`, which a `case` `*`
# crossing `/` would otherwise let match `plans/x.md`. The root TASK.md and
# TODO.md are out too: the `task-files` recipe checks them through
# `--task-files` (see parse_root), so the cached gates do not read them.
markdown_in_scope() {
    case "$1" in
    docs/*.md) return 0 ;;
    skills/*.md) return 0 ;;
    */*.md) return 1 ;;
    TASK.md | TODO.md) return 1 ;;
    *.md) return 0 ;;
    *) return 1 ;;
    esac
}

# Validate the arguments, `[--task-files] [ROOT]`, and set $ROOT (default `.`)
# and $TASK_FILES (1 after the flag, else 0) in the caller's shell. A further
# argument would otherwise be silently ignored and the run exit 0 over a tree
# the caller did not ask for. Sets the variables directly rather than through
# a command substitution: exit status is lost there, and this function's
# exit 2 must reach the caller's shell.
#
# With TASK_FILES=1 the handler checks the root TASK.md and TODO.md alone,
# whatever markdown_in_scope says.
#
# $1: the program name for diagnostics. $2…: the caller's own "$@", the flag
# first if given, then at most ROOT; more exits 2.
parse_root() {
    local prog="$1"
    shift
    # shellcheck disable=SC2034 # consumed by the sourcing script, not here
    TASK_FILES=0
    if [ "${1-}" = --task-files ]; then
        # shellcheck disable=SC2034 # as above
        TASK_FILES=1
        shift
    fi
    if [ "$#" -gt 1 ]; then
        printf '%s: unexpected extra argument: %s\n' "$prog" "$2" >&2
        exit 2
    fi
    # shellcheck disable=SC2034 # consumed by the sourcing script, not here
    ROOT="${1:-.}"
}

# `git ls-files -z` spooled to a temp file, then read back NUL-delimited: a
# `while … done < <(git ls-files -z)` process substitution discards git's
# exit status, so a ROOT that is not a git work tree would read as an empty,
# clean tree instead of failing the run. Explicit mktemp template: BSD
# mktemp has no default one, so a bare `mktemp` is a usage error on macOS. A
# failed `mktemp` leaves the tree unchecked: exit 2, since a bare `set -e`
# abort on the assignment would surface as 1 and read as a broken link. The
# walk-list variable is deliberately not `local`: the EXIT trap that removes
# it fires after this function has returned, and a local would already be
# unbound by then under `set -u`. That trap replaces any EXIT trap the caller
# set. Exits 2 if `mktemp` or `git ls-files` fails.
#
# $1: the program name for diagnostics. $2: ROOT, a git work tree. $3: the
# name of a function called once per tracked file, with the root-relative
# path as its only argument. It must return 0: it runs under the caller's
# `set -e`, so a non-zero return ends the whole run with that status — a
# trailing `in_scope && check` returns 1 for every out-of-scope file.
walk_tracked_files() {
    local prog="$1" root="$2" handler="$3" file prev=
    if ! _tracked_walk_list="$(mktemp "${TMPDIR:-/tmp}/${prog}.XXXXXX")"; then
        printf '%s: cannot create the walk list temp file\n' "$prog" >&2
        exit 2
    fi
    trap 'rm -f "$_tracked_walk_list"' EXIT

    if ! git -C "$root" ls-files -z >"$_tracked_walk_list"; then
        printf '%s: git ls-files failed under %s\n' "$prog" "$root" >&2
        exit 2
    fi

    while IFS= read -r -d '' file; do
        # Mid-merge, `ls-files` lists an unmerged path once per stage, up to
        # three times in a row; checking it again would repeat its report
        # lines. Not `--deduplicate`: git before 2.31 refuses it.
        if [ "$file" = "$prev" ]; then
            continue
        fi
        prev="$file"
        # A symlink is not a file to check: its target, if tracked, is
        # walked on its own. A gitlink's directory and a path still in the
        # index but deleted from the work tree cannot be read, and reading
        # them would exit the run 2. Residual: a file under an unsearchable
        # directory tests absent too, and is skipped rather than failing
        # the run.
        if [ -L "$root/$file" ] || [ ! -f "$root/$file" ]; then
            continue
        fi
        "$handler" "$file"
    done <"$_tracked_walk_list"
}
