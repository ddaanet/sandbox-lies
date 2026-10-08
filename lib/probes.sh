#!/usr/bin/env bash
# lib/probes.sh — probe_<verdict> functions the hook runs outside the sandbox
# (A-3 contract, docs/design.md FR-4): each probe reads the Bash tool result
# text on stdin, takes the sandbox flag as $1, the payload cwd as $2 and the
# payload's `tool_input.command` as $3 (read by probe_readonly_path only), and
# prints an outcome token on its first line followed by key=value lines; exit
# 0. The key lines per probe:
# - probe_git_lock, probe_config_lock: pid=, bytes=, age=, path=;
# - probe_readonly_path (lib/probes-readonly.sh): path= (none on nopath),
#   then on writable and nopath readfile=, merge=, partial=, target=, match=;
# - probe_resume_lost: none. Its outcome is lost, found or unknown.
# path= is left out when the resolved path holds a newline, which would split
# the line and forge key lines.
#
# set -u as in lib/matchers.sh and lib/verdicts.sh. hooks/annotate.sh sets it
# before sourcing those; bats does not, so setting it here keeps an unset
# variable an error when a test sources this file directly.
set -u

# lib/probes.sh sources lib/probes-readonly.sh by a BASH_SOURCE-relative
# path, so a caller that sources this file alone (the probes*.bats family)
# still gets probe_readonly_path defined; hooks/annotate.sh needs no
# separate source line for it. Sourcing an already-sourced
# lib/probes-readonly.sh just redefines the same functions.
_probes_lib_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd) || return 1
# shellcheck disable=SC1091 # lib/ sits beside this file; path is dynamic
. "$_probes_lib_dir/probes-readonly.sh" || return 1
unset _probes_lib_dir

# The ids come from the refusal lines in the text, in the shape
# match_resume_lost anchors on (_RESUME_LOST_LINE, lib/matchers.sh). Each is
# tested for a regular file <config dir>/projects/*/<id>.jsonl by glob; the
# ids are hex digits and hyphens, so safe in one. Residual: archived/ and
# subagents/ sit below the glob's depth and are not searched. The transcript
# is never opened.
#
# The config dir is CC's own resolution (2.1.292): CLAUDE_CONFIG_DIR when
# set, even empty, else homedir/.claude. An empty one names a cwd-relative
# projects/ and an unset HOME a passwd lookup, neither of which the probe
# locates; those, a root whose projects/ is missing or cannot be listed, an
# id not found while a project directory cannot be listed (the transcript
# may sit in it), and a sed that fails or extracts no id, print unknown, an
# outcome the verdict has no text for, rather than a found or lost nothing
# checked.
# LC_ALL=C as in _probe_lock_path: BSD sed under a UTF-8 locale exits on an
# invalid byte anywhere in the text. The body is a subshell so failglob and
# noglob are unset here whatever the caller's shell options: failglob makes
# an id with no transcript an expansion error, and noglob leaves the pattern
# unexpanded, so every id reads as missing. A no-match leaves the pattern
# literal, which fails the [ -f ] test: no nullglob is needed.
probe_resume_lost() (
    local ids id root verdict=found d hit blind=
    shopt -u failglob
    set +f
    if [ "${CLAUDE_CONFIG_DIR+set}" = set ]; then
        root=$CLAUDE_CONFIG_DIR
    else
        root=${HOME:+$HOME/.claude}
    fi
    ids=$(LC_ALL=C sed -nE "s/$_RESUME_LOST_LINE/\\1/p") || ids=
    if [ -z "$root" ] || [ -z "$ids" ] \
        || [ ! -d "$root/projects" ] || [ ! -r "$root/projects" ] \
        || [ ! -x "$root/projects" ]; then
        printf '%s\n' unknown
        return 0
    fi
    while IFS= read -r id; do
        hit=
        for d in "$root"/projects/*/; do
            [ -d "$d" ] || continue
            [ -f "$d$id.jsonl" ] && { hit=1; break; }
            { [ -r "$d" ] && [ -x "$d" ]; } || blind=1
        done
        [ -n "$hit" ] || verdict=lost
    done < <(printf '%s\n' "$ids")
    if [ "$verdict" = lost ] && [ -n "$blind" ]; then
        verdict=unknown
    fi
    printf '%s\n' "$verdict"
)

probe_git_lock() {
    local flag="$1" text path
    text=$(cat)
    path=$(printf '%s\n' "$text" | _probe_lock_path)
    path=$(_probe_resolve_path "$path" "${2-}")
    _probe_lock_at "$flag" "$path"
}

probe_config_lock() {
    local flag="$1" text path
    text=$(cat)
    path=$(printf '%s\n' "$text" | _probe_config_lock_path)
    # Empty means no config-lock line in the text: it stays empty, the
    # pathless case, rather than becoming ".lock", a relative path
    # _probe_resolve_path would join onto the base, naming a file no error
    # named.
    if [ -n "$path" ]; then
        path="$path.lock"
    fi
    path=$(_probe_resolve_path "$path" "${2-}")
    _probe_lock_at "$flag" "$path"
}

# _probe_lock_at <flag> <path> — the A-3 contract once a probe has extracted
# and resolved its own lock path: presence, character-device-ness, the
# holder, size and mtime, then the outcome and its key=value lines. Shared by
# probe_git_lock and probe_config_lock, which differ only in how <path> is
# extracted from their own error shape. A <path> holding a newline (a relative
# path joined onto a newline-bearing cwd) decides the outcome as any other,
# but its path= line is left out: printed, it would split and forge key lines.
_probe_lock_at() {
    local flag="$1" path="$2" pids holder_status=0 holder_pid mtime bytes=''
    local now age outcome pathline=1

    if [[ $path == *$'\n'* ]]; then
        pathline=
    fi

    # Only the literal `true` reads as unsandboxed, as FR-5 reads an absent
    # flag as false. A wrong mask still ends in the right diagnosis (its
    # verdict carries the repeat-failure clause); a wrong gone sends a
    # sandboxed call to retry unchanged.
    if [ ! -e "$path" ] && [ ! -L "$path" ]; then
        if [ "$flag" = true ]; then
            printf '%s\n' gone ${pathline:+"path=$path"}
        else
            printf '%s\n' mask ${pathline:+"path=$path"}
        fi
        return 0
    fi

    # A character device is a /dev/null sandbox mask, which unsandboxed
    # readers have seen while another session's sandbox was live
    # (docs/references/hook.md, "Why the hook can see"), never a lock git
    # wrote: mask under either flag. Tested before the holder tool, stat or
    # wc touches the path: /dev/null is open in many processes and would
    # read held. `[ -c ]`
    # follows a symlink, so a link to a device masks too.
    if [ -c "$path" ]; then
        printf '%s\n' mask ${pathline:+"path=$path"}
        return 0
    fi

    # Runs before the size and age reads, so a lock removed while this
    # check runs is absent at the stat below and reads gone, not orphan.
    # The tools see open descriptors only: git closes a lock before it
    # renames or removes it, and `commit -a` leaves index.lock present
    # and closed while its pre-commit hook runs, so a lock in either
    # state reads unheld. A holder exiting just after the tool saw it
    # reads held.
    # Status taken on `||` so a caller running under set -e survives the 2.
    pids=$(_probe_holder_pids "$path") || holder_status=$?
    # First pid only (pid= is singular), parsed without word splitting
    # or globbing: drop what precedes the first digit, keep that run.
    pids=${pids#"${pids%%[0-9]*}"}
    holder_pid=${pids%%[!0-9]*}
    if [ -n "$holder_pid" ]; then
        printf '%s\n' held "pid=$holder_pid" ${pathline:+"path=$path"}
        return 0
    fi

    # The mtime, BSD's `stat -f %m` first, GNU's `stat -c %Y` otherwise;
    # each value is used only on exit 0 and once it reads as seconds. On
    # GNU, -f is filesystem mode and %m a file operand: the attempt fails,
    # or with a file named %m in the cwd exits 0 printing filesystem
    # reports. Provoking that is the selection mechanism, so its stderr is
    # discarded (no-stderr-suppression exception 1 of 2). Residual: on BSD
    # a -f failure other than a vanish loses its own message, and stderr
    # carries BSD's refusal of -c instead.
    #
    # Git removes a lock when its holder exits, so the lock can vanish
    # after the presence test. The GNU form's stderr is captured, not
    # silenced: a failure with the lock now absent is that vanish, and
    # reads as gone under either flag (a real lock existed and git cleaned
    # it). Any other failure, or a value that is not seconds, goes on to
    # stderr and the age line is left out.
    if mtime=$(stat -f %m "$path" 2>/dev/null) \
        && _probe_is_seconds "$mtime"; then
        :
    elif ! mtime=$(stat -c %Y "$path" 2>&1) \
        || ! _probe_is_seconds "$mtime"; then
        if [ ! -e "$path" ] && [ ! -L "$path" ]; then
            printf '%s\n' gone ${pathline:+"path=$path"}
            return 0
        fi
        printf '%s\n' "$mtime" >&2
        mtime=''
    fi
    # Size only of a readable regular file, else the bytes line is left
    # out: reading a FIFO blocks until the hook times out, and a
    # directory, an unreadable file or a dangling symlink errors.
    # Residual: a lock vanishing between this test and the read still
    # prints the shell's redirect error.
    if [ -f "$path" ] && [ -r "$path" ]; then
        # BSD wc left-pads its count with spaces; strip before printing.
        bytes=$(wc -c <"$path" | tr -d '[:space:]')
    fi
    # Nonzero: no holder tool on PATH, or the holder check errored. Zero: a
    # tool ran and named no holder.
    if [ "$holder_status" -ne 0 ]; then
        outcome=unknown
    else
        outcome=orphan
    fi
    printf '%s\n' "$outcome"
    if [ -n "$bytes" ]; then
        printf 'bytes=%s\n' "$bytes"
    fi
    if [ -n "$mtime" ]; then
        now=$(date +%s)
        age=$((now - mtime))
        # An mtime in the future (clock skew) reads as just written.
        if [ "$age" -lt 0 ]; then
            age=0
        fi
        printf 'age=%s\n' "$age"
    fi
    if [ -n "$pathline" ]; then
        printf 'path=%s\n' "$path"
    fi
}

# Prints the lock path from git's "Unable to create '<path>.lock': <reason>"
# line on stdin, first such line only; empty when there is none. Git quotes
# the path without escaping, so the capture runs to the last `.lock': ` on
# the line rather than stopping at the first single quote: a path holding a
# quote survives, one holding `.lock': ` itself would not. The leading U is
# case-insensitive, as in lib/matchers.sh match_git_lock. LC_ALL=C: under a
# UTF-8 locale GNU sed's `.` does not match an invalid byte and BSD sed exits
# with "illegal byte sequence", so either loses a path a byte-wise match keeps.
_probe_lock_path() {
    LC_ALL=C sed -n "s/.*[Uu]nable to create '\(.*\.lock\)': .*/\1/p" \
        | head -n 1
}

# Prints the config file named in git's "error: could not lock config file
# <file>: File exists" line on stdin, first such line only; empty when there
# is none. Anchored at line start as lib/matchers.sh match_config_lock is, so
# a quoted copy of the error earlier in the text is not the line read.
# probe_config_lock appends ".lock" itself: git names the config file, never
# the lock. Unlike the git-lock shape, the file is not quoted, so the capture
# runs to the last ": File exists" on the line, mirroring the git-lock
# extractor's own last-occurrence capture. LC_ALL=C for the same byte-safety
# reason as _probe_lock_path.
_probe_config_lock_path() {
    LC_ALL=C sed -n 's/^error: could not lock config file \(.*\): File exists.*/\1/p' \
        | head -n 1
}

# Resolves <path> against a base directory: an absolute or empty <path>
# prints unchanged. An empty one is not joined either, because joined it
# would name the base itself, a directory the holder check would then read
# as held by whatever sits in it. A relative <path> is joined onto the
# nearest directory at or above the base holding a `.git` directory, else
# onto the base unchanged. Git prints a relative lock path only from a
# `.git` directory's top-level; from a linked worktree or a submodule, whose
# `.git` is a file, it prints the path absolute, so a `.git` file is walked
# past. The base is <cwd-arg> (the probe's own $2), or the probe's own
# working directory when <cwd-arg> is missing or empty — never `/`; a
# relative base is taken from that working directory too, so each step
# drops one component of an absolute path and the walk ends at `/`, one
# `[ -d ]` per ancestor and no process. Lexical, not canonical. Residuals: a
# base reached through a symlink walks the link's parents, not the target's,
# where git would find the top-level; a base inside a gitdir (bare, or
# `.git` itself), where git prints paths relative to that gitdir, resolves
# against an enclosing worktree when one exists.
_probe_resolve_path() {
    local base dir
    case "$1" in
        /* | '')
            printf '%s\n' "$1"
            return
            ;;
    esac
    dir="${2:-$PWD}"
    case "$dir" in
        /*) ;;
        *) dir="$PWD/$dir" ;;
    esac
    base="$dir"
    while :; do
        if [ -d "$dir/.git" ]; then
            base="$dir"
            break
        fi
        [ "$dir" = / ] && break
        dir="${dir%/*}"
        [ -n "$dir" ] || dir=/
    done
    printf '%s/%s\n' "${base%/}" "$1"
}

# Prints the pids holding <path> open as the holder tool prints them (lsof -t
# one per line, fuser space-padded on one line); nothing when it finds no
# holder. The first of lsof and fuser found on PATH decides; the other is
# never tried. Either tool exits 1 with no pid when nothing holds the file, so
# the tool's exit is ignored: its pids and its stderr decide. Returns 2 when
# neither tool is on PATH, printing nothing, and when the tool's stderr was
# unexpected, an exec failure's included: that stderr is passed on, and any
# pids the tool printed have already gone out, so a holder it named still
# reads held. An empty output alone cannot tell either case from a check that
# found no holder.
#
# The tool's stdout goes straight out through fd 3 while its stderr is held
# in a variable: the probe writes no file (NFR-4, the hook runs with $TMPDIR
# unset). That stderr is passed on unless it is one of two expected shapes:
# - fuser's "<path>:" line, then only access-code letters (psmisc c/e/r/m;
#   other builds use their own): normal operation, not a diagnostic
#   (no-stderr-suppression exception 2 of 2). POSIX has fuser print it on
#   every call; psmisc only when it finds a holder.
# - anything, once nothing the tool can stat is at the path: either git
#   removed the lock after the presence test (a holder that exited) and the
#   probe's stat reads the vanish as gone, or the lock is a dangling symlink,
#   which no process can hold open.
# lsof runs with -w: its warnings are about other mounts it cannot stat
# (/proc, FUSE), printed on every call on hosts that have such mounts; an
# error about <path> itself is not a warning and still arrives. Residual:
# the suite runs the lsof branch against a stub; the real lsof, and so what
# -w keeps out, only on hosts that have it.
_probe_holder_pids() {
    local path="$1" err rest
    if command -v lsof >/dev/null; then
        { err=$(lsof -w -t "$path" 2>&1 >&3 3>&-); } 3>&1
    elif command -v fuser >/dev/null; then
        { err=$(fuser "$path" 2>&1 >&3 3>&-); } 3>&1
    else
        return 2
    fi
    [ -n "$err" ] || return 0
    rest=${err#"$path:"}
    if [ "$rest" != "$err" ] && [ -z "${rest//[[:alpha:]]/}" ]; then
        return 0
    fi
    if [ ! -e "$path" ]; then
        return 0
    fi
    printf '%s\n' "$err" >&2
    return 2
}

# True when <value> is whole seconds since the epoch as stat prints an
# mtime: digits, after one leading minus for a pre-1970 mtime. Anything
# else must stay out of $(( )), which evaluates a variable's text as an
# expression.
_probe_is_seconds() {
    local digits="${1#-}"
    [ -n "$digits" ] && [ -z "${digits//[0-9]/}" ]
}
