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
# one per line, fuser space-padded on one line); nothing when neither tool is
# on PATH or the present one finds no holder. The first of lsof and fuser
# found on PATH decides; the other is never tried. Either tool exits 1 with
# no pid when nothing holds the file, so only the pids decide, not the exit.
#
# The tool's stdout goes straight out through fd 3 while its stderr is held
# in a variable: the probe writes no file (NFR-4, the hook runs with $TMPDIR
# unset). That stderr is passed on unless it is one of two expected shapes:
# - fuser's "<path>:" line, then only access-code letters (psmisc c/e/r/m;
#   other builds use their own): normal operation, not a diagnostic. POSIX
#   has fuser print it on every call; psmisc only when it finds a holder.
# - anything, once the lock is absent: git removed it after the presence
#   test (a holder that exited), the tool reported the missing file, and the
#   stat below reads the vanish as gone.
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
        return 0
    fi
    [ -n "$err" ] || return 0
    rest=${err#"$path:"}
    if [ "$rest" != "$err" ] && [ -z "${rest//[[:alpha:]]/}" ]; then
        return 0
    fi
    if [ ! -e "$path" ] && [ ! -L "$path" ]; then
        return 0
    fi
    printf '%s\n' "$err" >&2
}

probe_git_lock() {
    local flag="$1" text path
    text=$(cat)
    path=$(printf '%s\n' "$text" | _probe_lock_path)

    # Only the literal `true` reads as unsandboxed, as FR-5 reads an absent
    # flag as false. A wrong mask still ends in the right diagnosis (its
    # verdict carries the repeat-failure clause); a wrong gone sends a
    # sandboxed call to retry unchanged.
    if [ ! -e "$path" ] && [ ! -L "$path" ]; then
        if [ "$flag" = true ]; then
            printf 'gone\n'
        else
            printf 'mask\n'
        fi
        printf 'path=%s\n' "$path"
    else
        local pids holder_pid
        # Runs before the size and age reads, so a lock removed while this
        # check runs is absent at the stat below and reads gone, not orphan.
        # The tools see open descriptors only: git closes a lock before it
        # renames or removes it, and `commit -a` leaves index.lock present
        # and closed while its pre-commit hook runs, so a lock in either
        # state reads unheld. A holder exiting just after the tool saw it
        # reads held.
        pids=$(_probe_holder_pids "$path")
        # First pid only (pid= is singular), parsed without word splitting
        # or globbing: drop what precedes the first digit, keep that run.
        pids=${pids#"${pids%%[0-9]*}"}
        holder_pid=${pids%%[!0-9]*}
        if [ -n "$holder_pid" ]; then
            printf 'held\n'
            printf 'pid=%s\n' "$holder_pid"
            printf 'path=%s\n' "$path"
            return 0
        fi

        local mtime bytes='' now age
        # Git removes a lock when its holder exits, so the lock can vanish
        # after the presence test. stat's stderr is captured, not silenced: a
        # failure with the lock now absent is that vanish, and reads as gone
        # under either flag (a real lock existed and git cleaned it); any
        # other failure goes on to stderr and the age line is left out.
        if ! mtime=$(stat -c %Y "$path" 2>&1); then
            if [ ! -e "$path" ] && [ ! -L "$path" ]; then
                printf 'gone\n'
                printf 'path=%s\n' "$path"
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
        printf 'orphan\n'
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
    fi
}

probe_config_lock() {
    cat >/dev/null
}
