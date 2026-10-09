#!/usr/bin/env bash
# lib/probes-readonly.sh — probe_readonly_path, the A-3 contract probe for the
# readonly-path candidate (docs/design.md FR-4): reads the Bash tool result text
# on stdin, takes the sandbox flag as $1, the payload cwd as $2 and
# tool_input.command as $3, and prints an outcome token on its first line, then
# a path= line under writable and readonly only (nopath prints none), then —
# under writable and nopath only — the
# readfile=/merge=1/partial=1/target=/match= facts readonly-path.md's
# readonly-path Probe facts table describes; exit 0. Split out of lib/probes.sh
# to keep that file under the line cap; lib/probes.sh sources this file, so
# hooks/annotate.sh needs no source line of its own for it.
#
# set -u as in lib/matchers.sh, lib/verdicts.sh and lib/probes.sh; bats does
# not set it, so setting it here keeps an unset variable an error when a
# caller sources this file directly.
set -u

# probe_readonly_path reuses lib/matchers.sh's own matching-line
# discriminator (_readonly_path_line) rather than a second copy of the
# pattern, and lib/probes-readonly-facts.sh's _readonly_print_facts, with
# lib/probes-readonly-command.sh's command scan, for its writable/nopath
# tail (each kept in its own file to hold this one, and each other, under
# the line cap). hooks/annotate.sh already sources matchers.sh before
# lib/probes.sh (which sources this file), so this re-source is only
# load-bearing where a caller sources this file, or lib/probes.sh, on its
# own; sourcing twice just redefines the same functions.
_probes_lib_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd) || return 1
# shellcheck disable=SC1091 # lib/ sits beside this file; path is dynamic
. "$_probes_lib_dir/matchers.sh" || return 1
# shellcheck disable=SC1091 # lib/ sits beside this file; path is dynamic
. "$_probes_lib_dir/probes-readonly-facts.sh" || return 1
# shellcheck disable=SC1091 # lib/ sits beside this file; path is dynamic
. "$_probes_lib_dir/probes-readonly-command.sh" || return 1
unset _probes_lib_dir

# probe_readonly_path <flag> <cwd> <command> — A-3 contract for
# readonly-path: line 1 `writable`, `readonly` or `nopath` (no path
# extracted, or the resolved path holds a newline, which is never
# printed), then `path=` under `writable` and `readonly` only, then —
# under `writable` and `nopath` only — the facts _readonly_print_facts
# derives from the result text and <command>. <flag> is part of the
# interface but unread here: whether the hook calls this probe at all is
# the candidate's flag policy (docs/references/readonly-path.md), decided
# before the probe runs, not inside it.
probe_readonly_path() {
    local cwd="${2-}" command="${3-}" text path target outcome
    text=$(cat)
    # One pipeline ending in sed, which exits 0: grep's 1 on a text with no
    # matching line never becomes the assignment's status, so a caller
    # running under set -e still gets nopath.
    path=$(printf '%s\n' "$text" | _readonly_path_line \
        | _probe_readonly_path_from_line)
    path=$(_probe_readonly_resolve "$path" "$cwd")
    if [ -z "$path" ]; then
        printf '%s\n' nopath
        _readonly_print_facts "$text" "$command" "" "$cwd"
        return 0
    fi
    target="$path"
    # Absent, a dangling symlink included (`-w` follows the link and would
    # read it unwritable whatever its directory allows): the parent decides,
    # taken after any trailing slash, as mkdir prints its operand, so the
    # parent of `dir/new/` is `dir`, not `dir/new`. Residual: a write
    # through a dangling link lands in the link target's directory, which
    # may not be the link's own.
    if [ ! -e "$path" ]; then
        while [ "${target%/}" != "$target" ]; do
            target="${target%/}"
        done
        target="${target%/*}"
        [ -n "$target" ] || target=/
    fi
    if [ -w "$target" ]; then
        outcome=writable
    else
        outcome="readonly"
    fi
    printf '%s\n' "$outcome"
    _probe_path_line "$path"
    if [ "$outcome" != readonly ]; then
        _readonly_print_facts "$text" "$command" "$path" "$cwd"
    fi
}

# _probe_path_line <path> — the path= line: <path> in printf %q form, so a
# blank, a quote or a newline cannot split the line or forge a key line.
# LC_ALL=C keeps a UTF-8 byte in octal, as bash 5.2 under a UTF-8 locale would
# print it raw. Nothing for an empty <path>.
_probe_path_line() {
    local quoted
    if [ -n "$1" ]; then
        LC_ALL=C printf -v quoted %q "$1"
        printf 'path=%s\n' "$quoted"
    fi
}

# _probe_readonly_resolve <path> <cwd> — joins a relative <path> onto <cwd>
# (or the probe's own working directory when <cwd> is missing or empty, as
# _probe_resolve_path falls back for the lock probes); an absolute or empty
# <path> is unchanged. Never walks up to a .git directory: readonly-path's
# producers (cp, mv, touch, bash, Python) resolve a relative path against
# their own process cwd, not against git's own convention for a lock path.
_probe_readonly_resolve() {
    local path="$1" cwd="${2:-$PWD}"
    case "$path" in
        /* | '')
            printf '%s\n' "$path"
            return
            ;;
    esac
    case "$cwd" in
        /*) ;;
        *) cwd="$PWD/$cwd" ;;
    esac
    printf '%s/%s\n' "${cwd%/}" "$path"
}

# Prints the path extracted from stdin (one line), nothing when none of the
# recognised shapes apply. Quoted, it is the first single-quoted segment,
# ASCII or the UTF-8 curly pair a UTF-8 locale prints (mkdir), except that
# mv's "inter-device move failed: '<src>' to '<dst>'" names <dst>, tried
# first so the generic rule never sees the source. Each curly quote is three
# bytes under LC_ALL=C, so a bracket class would exclude them one by one and
# stop at any character sharing one (an em dash shares two): the curly block
# replaces the first opening quote, then the first closing quote after it,
# with a newline, the one byte a line cannot hold, and keeps what lies
# between. Unquoted, the path is read in four fixed forms, each anchored at
# the line start on the tool's own colon-free prefix (as the matcher
# requires) and the words it prints there: bash's "line N:", dash's digit
# locator then "cannot create" (a bare "cannot create" would also catch cp's
# and mkdir's own wording with their quotes stripped), git's "error: could
# not lock config file" and "fatal: cannot mkdir". Anchored there, the same
# words inside the path cannot move the capture's start, and the capture
# runs to the last ": ", as the kernel message after it holds none: an
# unquoted path is read whole, blanks and ": " included. LC_ALL=C for the
# same byte-safety reason as _probe_lock_path. Residual: a quoted path
# holding its own closing quote, which GNU prints double-quoted or as
# `'it'\''s'` when straight and as a backslash-escaped quote when curly,
# yields nopath or the piece before that quote; a curly-quoted or unquoted
# path holding two straight quotes yields the piece between them, since the
# straight rule is tried first.
_probe_readonly_path_from_line() {
    local nl='
'
    LC_ALL=C sed -n \
        -e "s/^[^:]*: inter-device move failed: '[^']*' to '\([^']*\)'.*/\1/p" \
        -e "t end" \
        -e "s/^[^']*'\([^']*\)'.*/\1/p" \
        -e "t end" \
        -e "/‘.*’/{" \
        -e "s/‘/\\$nl/" \
        -e "s/^.*\\n//" \
        -e "s/’/\\$nl/" \
        -e "s/\\n.*//p" \
        -e "b end" \
        -e "}" \
        -e "s/^[^:]*: line [0-9][0-9]*: \(.*\): .*/\1/p" \
        -e "t end" \
        -e "s/^[^:]*: [0-9][0-9]*: cannot create \(.*\): .*/\1/p" \
        -e "t end" \
        -e "s/^error: could not lock config file \(.*\): .*/\1/p" \
        -e "t end" \
        -e "s/^fatal: cannot mkdir \(.*\): .*/\1/p" \
        -e ":end"
}
