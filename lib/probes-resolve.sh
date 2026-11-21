#!/usr/bin/env bash
# Node names cited here (lock-detectors.md) are files of the plugin
# repository's docs/references/, which the plugin does not ship.
# lib/probes-resolve.sh — _probe_resolve_path, the relative lock path
# resolution shared by probe_git_lock and probe_config_lock. Sourced by
# lib/probes.sh, so no other caller needs a source line of its own for it.
#
# set -u as in lib/probes.sh; bats does not set it, so setting it here keeps
# an unset variable an error when a caller sources this file directly.
set -u

# _probe_resolve_path <path> <cwd-arg> [<command>] — <path> resolved against
# a base directory: an absolute or empty <path> prints unchanged. An empty one
# is not joined either, because joined it would name the base itself, a
# directory the holder check would then read as held by whatever sits in it.
# A relative <path> is joined onto the nearest directory at or above the base
# holding a `.git` directory, else onto the base unchanged (_probe_git_top).
# Git prints a relative lock path only from a `.git` directory's top-level;
# from a linked worktree or a submodule, whose `.git` is a file, it prints the
# path absolute, so a `.git` file is walked past. The base is <cwd-arg> (the
# probe's own $2), or the probe's own working directory when <cwd-arg> is
# missing or empty — never `/`; a relative base is taken from that working
# directory too. Lexical, not canonical. Residuals: a base reached through a
# symlink walks the link's parents, not the target's, where git would find the
# top-level; a base inside a gitdir (bare, or `.git` itself), where git prints
# paths relative to that gitdir, resolves against an enclosing worktree when
# one exists.
#
# The Bash <command> may have run git in another repository, so when the
# cwd-based path does not exist (a dangling symlink or a device counts as
# existing), each directory the command names in a `cd <dir>` or `git -C
# <dir>` (_probe_command_dirs) is a candidate base, walked up the same way:
# the last candidate, in command order, under which the joined path exists
# wins; with none, the cwd-based path stands. An existing cwd lock always
# stands, so a lock elsewhere never displaces the one the error most likely
# named. Requiring the lock to exist is what keeps a false candidate (a `cd`
# inside an echoed string) from naming a path nothing holds. Residuals: a
# target in a variable or a substitution names no candidate, nor does a
# recipe or script that runs git elsewhere; chained relative cds each resolve
# against the base, not the previous cd; only the first `-C` after `git` is
# read; a cd after the failing git call wins only if a lock exists there too.
_probe_resolve_path() {
    local base dir _probe_top joined chosen
    case "$1" in
        /* | '')
            printf '%s\n' "$1"
            return
            ;;
    esac
    base="${2:-$PWD}"
    case "$base" in
        /*) ;;
        *) base="$PWD/$base" ;;
    esac
    _probe_git_top "$base"
    chosen="${_probe_top%/}/$1"
    if [ -n "${3-}" ] && [ ! -e "$chosen" ] && [ ! -L "$chosen" ]; then
        local _probe_dirs=()
        _probe_command_dirs "$3"
        for dir in ${_probe_dirs[@]+"${_probe_dirs[@]}"}; do
            case "$dir" in
                /*) ;;
                *) dir="$base/$dir" ;;
            esac
            _probe_git_top "$dir"
            joined="${_probe_top%/}/$1"
            if [ -e "$joined" ] || [ -L "$joined" ]; then
                chosen="$joined"
            fi
        done
    fi
    printf '%s\n' "$chosen"
}

# _probe_git_top <dir> — sets _probe_top (the caller's local) to the nearest
# directory at or above absolute <dir> holding a `.git` directory, else to
# <dir> unchanged. Each step drops one component and the walk ends at `/`,
# one `[ -d ]` per ancestor and no process: a variable, not stdout, so the
# caller pays no command substitution per candidate.
_probe_git_top() {
    local dir="$1"
    _probe_top="$1"
    while :; do
        if [ -d "$dir/.git" ]; then
            _probe_top="$dir"
            return
        fi
        [ "$dir" = / ] && return
        dir="${dir%/*}"
        [ -n "$dir" ] || dir=/
    done
}

# _probe_command_dirs <command> — appends to _probe_dirs (the caller's local
# array), in command order, each directory <command> names as `cd <dir>`
# (cd at a line start or after whitespace or one of `; & | (`) or `git -C
# <dir>` (git after a line start or a byte other than a letter, digit or
# `_`). <dir> is one word: a double-quoted string holding no `$`, backtick or
# backslash, a single-quoted string, or a bare run of none of whitespace,
# `; & | ( ) < > " ' $`, backtick and backslash, then the line end,
# whitespace or one of `; & | )`; anything else (a variable, a substitution,
# a placeholder) names none. A target starting with `-` (`cd -`, an option) is
# skipped. The quotes are stripped; a leading `~` alone or `~/` becomes $HOME,
# and names none when HOME is unset or empty. Validated on 80k recorded
# commands: every cd or -C it missed was a variable, a substitution or prose.
#
# One grep pass keeps the cost linear in the command, which may carry a large
# heredoc; a bash loop consuming the string per match was quadratic. grep -o
# consumes the byte after a word, which may be the only separator before the
# next cd or git (`cd a;cd b`), so a first grep matches a run of such
# directly chained items, with its boundary byte, as one hit, and a second
# splits each run into its items: within a run each item starts the leftmost
# match after the previous one, and no boundary or separator byte is a `c` or
# a `g`. Grep reads line by line: a quoted target spanning a newline names
# none. Bash 3.2 apart from the two greps: the regexes sit in variables, and
# the EREs are ones GNU and BSD grep read alike.
_probe_command_dirs() {
    local q="'" line word
    local w="(\"[^\"\$\`\\]*\"|${q}[^${q}]*${q}|[^[:space:];&|()<>\"${q}\`\$\\]+)"
    local c="cd[[:space:]]+$w" g="git[[:space:]]+-C[[:space:]]+$w"
    local run="((^|[;&|([:space:]])$c|(^|[^[:alnum:]_])$g)"
    run="$run([;&|[:space:]]$c|[;&|)[:space:]]$g)*([;&|)[:space:]]|\$)"
    while IFS= read -r line; do
        [[ $line =~ ^($c|$g)$ ]] || continue
        word="${BASH_REMATCH[2]}${BASH_REMATCH[3]}"
        case "$word" in
            \"*) word="${word:1:${#word}-2}" ;;
            "$q"*) word="${word:1:${#word}-2}" ;;
        esac
        case "$word" in
            \~ | \~/*)
                [ -n "${HOME-}" ] || continue
                word="$HOME${word:1}"
                ;;
            -* | '') continue ;;
        esac
        _probe_dirs+=("$word")
    done < <(printf '%s\n' "$1" | LC_ALL=C grep -aoE -- "$run" |
        LC_ALL=C grep -aoE -- "$c|$g")
}
