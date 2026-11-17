#!/usr/bin/env bash
# Node names cited here (readonly-path.md, detectors.md) are files of the plugin
# repository's docs/references/, which the plugin does not ship.
# lib/probes-readonly.sh — probe_readonly_path, the A-3 contract probe for the
# readonly-path candidate (the plugin repository's docs/design.md FR-4): reads the Bash tool result text
# on stdin, takes the sandbox flag as $1, the payload cwd as $2 and
# tool_input.command as $3, and prints an outcome token on its first line, then
# a path= line (printf %q form) under writable and readonly only (nopath
# prints none), then — under writable and nopath only — the claudeonly=/
# configonly= facts and the
# readfile=/merge=1/partial=1/target=/recover=/repo=/match= facts readonly-path.md's
# readonly-path Probe facts table describes; exit 0. Sourced by
# lib/probes.sh, so
# hooks/annotate.sh needs no source line of its own for it.
#
# set -u as in lib/matchers.sh, lib/verdicts.sh and lib/probes.sh; bats does
# not set it, so setting it here keeps an unset variable an error when a
# caller sources this file directly.
set -u

# probe_readonly_path reuses lib/matchers.sh's own matching-line
# discriminator (_readonly_path_lines) rather than a second copy of the
# pattern, and lib/probes-readonly-facts.sh's _readonly_print_facts, with
# lib/probes-readonly-command.sh's command scan, for its writable/nopath
# tail (each in its own file). hooks/annotate.sh already sources matchers.sh before
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
# extracted), then `path=` in printf %q form under `writable` and
# `readonly` only, then — under `writable` and `nopath` only — the facts of
# _probe_readonly_scope (over every matching line) and of
# _readonly_print_facts (over the result text and <command>). <flag> is
# part of the interface but unread here: whether the hook calls this probe at
# all is the candidate's flag policy (the plugin repository's docs/references/readonly-path.md),
# decided before the probe runs, not inside it.
probe_readonly_path() {
    local cwd="${2-}" command="${3-}" text matched line path target outcome nl='
'
    text=$(cat)
    # grep's 1 on a text with no matching line is caught on its own
    # assignment, and the path pipeline ends in sed, which exits 0, so a
    # caller running under set -e still gets nopath.
    matched=$(printf '%s\n' "$text" | _readonly_path_lines) || matched=
    line=${matched%%"$nl"*}
    path=$(_probe_readonly_line_path "$line" "$cwd")
    target="$path"
    # Absent, a dangling symlink included (`-w` follows the link and would
    # read it unwritable whatever its directory allows): the parent decides,
    # taken after any trailing slash, as mkdir prints its operand, so the
    # parent of `dir/new/` is `dir`, not `dir/new`. Residual: a write
    # through a dangling link lands in the link target's directory, which
    # may not be the link's own.
    if [ -z "$path" ]; then
        outcome=nopath
    else
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
    fi
    printf '%s\n' "$outcome"
    _probe_path_line "$path"
    [ "$outcome" != readonly ] || return 0
    _probe_readonly_scope "$matched" "$cwd" "$path"
    _readonly_print_facts "$text" "$command" "$path" "$cwd"
}

# _probe_readonly_line_path <line> <cwd> — the path <line> names, resolved:
# empty when <line> names none. git names a partial-checkout path, and the
# path of its unlink warning, from the worktree top; the matching line alone
# decides, so another such line in the text does not move a cp refusal's
# join. The walk starts at the probe's working directory for an empty cwd, as
# the unwalked join does. $(...) strips every trailing newline, so a top
# whose name ends in one lost it. The walk's own newline and a trailing x are
# stripped by hand instead: the output ends in "\nx", and removing those two
# characters leaves the name exactly as the walk printed it.
_probe_readonly_line_path() {
    local line="$1" cwd="$2" path base start top
    path=$(printf '%s\n' "$line" | _probe_readonly_path_from_line)
    base="$cwd"
    if _probe_top_relative_line "$line"; then
        start="$cwd"
        [ -n "$start" ] || start="$PWD"
        top=$(_readonly_git_dir "$start" && printf x) && base="${top%?x}"
    fi
    _probe_readonly_resolve "$path" "$base"
}

# _probe_top_relative_line <line> — true when git names <line>'s path from
# the worktree top: a partial-checkout refusal, or git's warning that it
# could not unlink a file, whatever the message after the quoted path. The
# warning's head is built from fragments, so this file holds no refusal whole.
_probe_top_relative_line() {
    local head='warning: unable to'
    head="$head unlink '"
    case "$1" in
        "$head"*) return 0 ;;
    esac
    _probe_partial_checkout_text "$1"
}

# _probe_readonly_scope <matched> <cwd> <path> — the facts read off every
# line the matcher accepts (<matched>, the first resolved to <path> already),
# not just the first: claudeonly=1 when any such line names a path that,
# resolved as _probe_readonly_line_path resolves it, has a .claude
# component, the last one not followed by worktrees (Claude Code's own
# worktrees sit there, and their project files run no code), the path
# normalised lexically first so ., .. and empty segments land where they
# point; configonly=1
# when each is git's config-file write refusal. A line naming no path is not
# under .claude. A path is read only from a line that, with the cwd, holds
# .claude somewhere, since a join onto the cwd or its worktree top cannot
# gain that component otherwise; the scan stops once claudeonly=1 holds and
# configonly=1 cannot.
_probe_readonly_scope() {
    local matched="$1" cwd="$2" path="$3" line claude=no config=yes head
    local first=yes
    [ -n "$matched" ] || return 0
    head='error: could not write'
    head="$head config file "
    while IFS= read -r line; do
        case "$line" in
            "$head"*) ;;
            *) config=no ;;
        esac
        case "$claude/$line/${cwd:-$PWD}" in
            no/*.claude*)
                [ "$first" = yes ] || path=$(_probe_readonly_line_path "$line" "$cwd")
                path=$(_probe_lexical_path "$path" && printf x)
                path="${path%x}"
                case "$path" in
                    */.claude) claude=yes ;;
                    */.claude/*)
                        case "${path##*/.claude/}" in
                            worktrees | worktrees/*) ;;
                            *) claude=yes ;;
                        esac
                        ;;
                esac
                ;;
        esac
        first=no
        [ "$claude" = no ] || [ "$config" = yes ] || break
    done < <(printf '%s\n' "$matched")
    [ "$claude" = no ] || printf '%s\n' claudeonly=1
    [ "$config" = no ] || printf '%s\n' configonly=1
}

# _probe_path_line <path> — the path= line: <path> in printf %q form, so a
# blank, a quote or a newline cannot split the line or forge a key line.
# LC_ALL=C keeps a UTF-8 byte in octal, as bash 5.2 under a UTF-8 locale would
# print it raw. Set by plain assignment and put back: bash 3.2 ignores a
# temporary LC_ALL= before a builtin. Nothing for an empty <path>.
_probe_path_line() {
    local quoted saved=${LC_ALL-} had=${LC_ALL+x}
    if [ -n "$1" ]; then
        LC_ALL=C
        printf -v quoted %q "$1"
        if [ -n "$had" ]; then LC_ALL=$saved; else unset LC_ALL; fi
        printf 'path=%s\n' "$quoted"
    fi
}

# _probe_partial_checkout_text <text> — true when some line of <text> opens
# with one of git's three partial-checkout messages, each with its own prefix
# ("error: " for the two unable-to lines, "fatal: " for the directory one), or
# follows a carriage return on its line (git's own progress fragment, "Updating
# files: N%", ends in one and the message follows with no newline). Anchored,
# so a cp or mv refusal naming a path that holds one of the phrases does not
# qualify, nor does a git line another program prefixed or indented. Each
# needle is matched after a newline prepended to <text>, with `case` alone: no
# loop, no process, and no here-string, which bash spools through a temp file
# (always before 5.1, above the pipe size after) and NFR-4 forbids, as
# hooks/annotate.sh says of the here-document. The phrases are built from
# fragments, so this file holds none whole, and they live here alone.
_probe_partial_checkout_text() {
    local text needle nl cr
    nl='
'
    cr=$'\r'
    text="$nl$1"
    needle='error: unable to unlink'
    needle="$needle old"
    case "$text" in
        *"$nl$needle"* | *"$cr$needle"*) return 0 ;;
    esac
    needle='error: unable to create'
    needle="$needle file"
    case "$text" in
        *"$nl$needle"* | *"$cr$needle"*) return 0 ;;
    esac
    needle='fatal: cannot create'
    needle="$needle directory at"
    case "$text" in
        *"$nl$needle"* | *"$cr$needle"*) return 0 ;;
    esac
    return 1
}

# _probe_readonly_resolve <path> <cwd> — joins a relative <path> onto <cwd>
# (or the probe's own working directory when <cwd> is missing or empty, as
# _probe_resolve_path falls back for the lock probes); an absolute or empty
# <path> is unchanged. It does not walk to a .git entry itself: the caller
# passes the worktree top for a partial-checkout path or an unlink warning's,
# and cwd for every other producer (cp, mv, touch, bash, Python), which
# resolve against their own process cwd.
# _probe_lexical_path <path> — <path> with its empty and . segments dropped
# and each .. taking off the segment before it, printed with no trailing
# newline; empty stays empty. Lexical only: a .. after a symlink lands where
# the string says, not where the kernel would.
_probe_lexical_path() {
    local rest="$1" seg out=''
    [ -n "$rest" ] || return 0
    while [ -n "$rest" ]; do
        seg="${rest%%/*}"
        case "$rest" in
            */*) rest="${rest#*/}" ;;
            *) rest='' ;;
        esac
        case "$seg" in
            '' | .) ;;
            ..) out="${out%/*}" ;;
            *) out="$out/$seg" ;;
        esac
    done
    printf '%s' "${out:-/}"
}

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
# between. Unquoted, the path is read in five fixed forms, each anchored at
# the line start on the tool's own colon-free prefix (as the matcher
# requires) and the words it prints there: bash's "line N:", dash's digit
# locator then "cannot create" (a bare "cannot create" would also catch cp's
# and mkdir's own wording with their quotes stripped), git's "error: could
# not lock config file", "fatal: cannot mkdir" and "error: unable to create
# file". Anchored there, the same
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
        -e "t end" \
        -e "s/^error: unable to create file \(.*\): .*/\1/p" \
        -e ":end"
}
