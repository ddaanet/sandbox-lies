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

# Prints the first pid holding <path> open; empty when neither holder tool
# is present on PATH, or the present one finds no holder. The first of
# lsof -t / fuser found on PATH decides, and the other is never tried:
# lsof is absent on this box, so that branch cannot be exercised here and is
# kept minimal (lsof -t already prints bare pids, one per line, nothing
# when unheld, so no further shaping should be needed).
_probe_holder_pid() {
    local path="$1"
    if command -v lsof >/dev/null; then
        lsof -t "$path" | head -n 1
        return 0
    fi
    if command -v fuser >/dev/null; then
        _probe_fuser_pid "$path"
    fi
}

# fuser exits 0 with the holder pid(s) on stdout when <path> is held, 1 with
# nothing on either stream when it is not: that exit is the no-holder
# result, not an error. fuser also writes "<path>:" to stderr on every call
# that resolves the path, whether or not a holder is found — normal
# operation, not a diagnostic — so that exact line is captured and dropped;
# any other stderr (for example an unquoted path splitting into words that
# each fail to resolve) is passed through unfiltered.
_probe_fuser_pid() {
    local path="$1" out err_file first
    err_file=$(mktemp)
    out=$(fuser "$path" 2>"$err_file")
    if [ "$(cat "$err_file")" != "$path:" ]; then
        cat "$err_file" >&2
    fi
    rm -f "$err_file"
    first=''
    for first in $out; do
        break
    done
    [ -n "$first" ] && printf '%s' "$first"
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
        local holder_pid
        # Runs before the size and age reads: a holder that exits during
        # this check leaves no trace here (fuser/lsof just report no
        # holder), and falls through to the stat-based vanished-lock check
        # below, which reads that as gone rather than orphan.
        holder_pid=$(_probe_holder_pid "$path")
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
