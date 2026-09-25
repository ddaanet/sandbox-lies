#!/usr/bin/env bash
# lib/probes.sh — probe_<verdict> functions the hook runs outside the sandbox
# (A-3 contract, docs/design.md FR-4): each probe reads the Bash tool result
# text on stdin, takes the sandbox flag as $1 and the payload cwd as $2, and
# prints an outcome token on its first line followed by key=value lines
# (pid=, bytes=, age=, path=); exit 0.
#
# set -u as in lib/matchers.sh and lib/verdicts.sh. hooks/annotate.sh sets it
# before sourcing those; bats does not, so setting it here keeps an unset
# variable an error when a test sources this file directly.
set -u

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

# Prints the pids holding <path> open as the holder tool prints them (lsof -t
# one per line, fuser space-padded on one line); nothing when it finds no
# holder. The first of lsof and fuser found on PATH decides; the other is
# never tried. Either tool exits 1 with no pid when nothing holds the file, so
# the tool's exit is ignored and only the pids decide. Returns 2, printing
# nothing, when neither tool is on PATH: the empty output alone cannot tell
# that from a check that found no holder.
#
# The tool's stdout goes straight out through fd 3 while its stderr is held
# in a variable: the probe writes no file (NFR-4, the hook runs with $TMPDIR
# unset). That stderr is passed on unless it is one of two expected shapes:
# - fuser's "<path>:" line, then only access-code letters (psmisc c/e/r/m;
#   other builds use their own): normal operation, not a diagnostic. POSIX
#   has fuser print it on every call; psmisc only when it finds a holder.
# - anything, once nothing the tool can stat is at the path: either git
#   removed the lock after the presence test (a holder that exited) and the
#   stat below reads the vanish as gone, or the lock is a dangling symlink,
#   which no process can hold open.
# lsof runs with -w: its warnings are about other mounts it cannot stat
# (/proc, FUSE), printed on every call on hosts that have such mounts; an
# error about <path> itself is not a warning and still arrives. Residual:
# the lsof branch runs in the suite only on hosts that have lsof.
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
}

# Prints a relative <path> joined onto <base> with one `/` separator, <base>
# used as given, not canonicalised. An absolute <path> prints unchanged, and
# so does an empty one (text with no lock line): joined, it would name <base>
# itself, a directory the holder check reads as held by whatever has it as
# its cwd. The probe passes its own $2 (the payload cwd) as <base>, so
# resolving against another directory is an edit to that argument alone.
_probe_resolve_path() {
    case "$1" in
        /* | '') printf '%s\n' "$1" ;;
        *) printf '%s/%s\n' "$2" "$1" ;;
    esac
}

probe_git_lock() {
    local flag="$1" text path pids holder_status=0 holder_pid mtime bytes=''
    local now age outcome
    text=$(cat)
    path=$(printf '%s\n' "$text" | _probe_lock_path)
    path=$(_probe_resolve_path "$path" "${2-}")

    # Only the literal `true` reads as unsandboxed, as FR-5 reads an absent
    # flag as false. A wrong mask still ends in the right diagnosis (its
    # verdict carries the repeat-failure clause); a wrong gone sends a
    # sandboxed call to retry unchanged.
    if [ ! -e "$path" ] && [ ! -L "$path" ]; then
        if [ "$flag" = true ]; then
            printf '%s\n' gone "path=$path"
        else
            printf '%s\n' mask "path=$path"
        fi
        return 0
    fi

    # A character device is a sandbox mask (a /dev/null bind, which
    # unsandboxed readers have seen while another session's sandbox was
    # live), never a lock git wrote: mask under either flag. Tested before
    # the holder tool, stat or wc touches the path: /dev/null is open in
    # many processes and would read held. `[ -c ]` follows a symlink, so a
    # link to a device masks too.
    if [ -c "$path" ]; then
        printf '%s\n' mask "path=$path"
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
        printf '%s\n' held "pid=$holder_pid" "path=$path"
        return 0
    fi

    # Git removes a lock when its holder exits, so the lock can vanish
    # after the presence test. stat's stderr is captured, not silenced: a
    # failure with the lock now absent is that vanish, and reads as gone
    # under either flag (a real lock existed and git cleaned it); any
    # other failure goes on to stderr and the age line is left out.
    if ! mtime=$(stat -c %Y "$path" 2>&1); then
        if [ ! -e "$path" ] && [ ! -L "$path" ]; then
            printf '%s\n' gone "path=$path"
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
    # Status 2: no holder tool on PATH. Otherwise a tool ran and named no
    # holder.
    if [ "$holder_status" -eq 2 ]; then
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
    printf 'path=%s\n' "$path"
}

probe_config_lock() {
    cat >/dev/null
}
