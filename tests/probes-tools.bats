#!/usr/bin/env bats
# lib/probes.sh: probe_git_lock cases pinning what its external tools do or
# fail to do — a holder check that errored rather than found nothing, and
# the stat dialect selection's digit check. Opened by Item 2.4 slice 10
# (slice 6's test review): tests/probes.bats and tests/probes-edges.bats are
# both near the 400-line cap.

ROOT="${BATS_TEST_DIRNAME}/.."

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/probes

setup() {
  source "$ROOT/lib/probes.sh"
}

# Item 2.4 slice 6's code review, major 2: a holder tool present but erroring
# has not shown the lock unheld, so it must not read as orphan, which carries
# the retry-authorizing verdict (A-4). The positive comes first: a stub
# printing only fuser's own "<path>:" line (POSIX prints it on every call),
# no pid, exit 1, is a check that found no holder and stays a quiet orphan —
# every other holder-tool stub with stderr also prints a pid, so without this
# a probe reading any holder-tool stderr as unknown would pass. The first
# negative differs only in its stderr line: a permission error naming the
# path, the ordinary shape a restricted fuser gives. The second's shebang
# names an interpreter that does not exist, an exec failure rather than the
# tool's own refusal, read the same way: any failed check is errored, not
# absent. The shell's exec-failure message names the stub (bash 5 "cannot
# execute: required file not found", 127; bash 3.2 "bad interpreter", 126).
@test "errored holder check is unknown" {
  local repo="$BATS_TEST_TMPDIR/r" cwd="$BATS_TEST_TMPDIR/elsewhere" lock
  local toolsdir="$BATS_TEST_TMPDIR/tools-only"
  mkdir -p "$repo/.git" "$cwd"
  lock="$repo/.git/index.lock"
  printf '1234567' >"$lock"
  tools_only_path "$toolsdir"
  cat >"$toolsdir/fuser" <<'STUB'
#!/bin/sh
printf '%s:\n' "$1" >&2
exit 1
STUB
  chmod 755 "$toolsdir/fuser"

  PATH="$toolsdir" run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = orphan ]
  printf '%s\n' "$output" | grep -qxF "bytes=7"

  cat >"$toolsdir/fuser" <<STUB
#!/bin/sh
printf 'fuser: cannot stat %s: Permission denied\n' "\$1" >&2
exit 1
STUB
  chmod 755 "$toolsdir/fuser"

  PATH="$toolsdir" run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ "${output%%$'\n'*}" = unknown ]
  printf '%s\n' "$output" | grep -qxF "bytes=7"
  [ "$(printf '%s\n' "$output" | grep -c '^pid=')" -eq 0 ]
  [ "$stderr" = "$(printf 'fuser: cannot stat %s: Permission denied' "$lock")" ]

  printf '#!/nonexistent/interpreter\n' >"$toolsdir/fuser"
  chmod 755 "$toolsdir/fuser"

  PATH="$toolsdir" run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ "${output%%$'\n'*}" = unknown ]
  printf '%s\n' "$stderr" | grep -qF "$toolsdir/fuser"
}

# Item 2.4 slice 9's code review: the BSD branch's digit check has a real use
# on GNU too. With a file literally named %m in the cwd, GNU `stat -f %m
# <path>` treats %m as a second file operand and exits 0 printing filesystem
# reports for both operands, not an mtime — no stub can provoke this, only
# the real, unstubbed GNU stat this box ships. Proven by mutation: dropping
# the digit check lets that filesystem-report text reach the age arithmetic.
@test "a file named %m in the cwd" {
  local repo="$BATS_TEST_TMPDIR/r" cwd="$BATS_TEST_TMPDIR/elsewhere" lock
  local mdir="$BATS_TEST_TMPDIR/mdir"
  mkdir -p "$repo/.git" "$cwd" "$mdir"
  lock="$repo/.git/index.lock"
  printf '1234567' >"$lock"
  : >"$mdir/%m"
  cd "$mdir"
  # The fixture reaches the branch: without the %m file GNU's -f fails here.
  stat -f %m "$lock" >/dev/null

  run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = orphan ]
  printf '%s\n' "$output" | grep -qxF "bytes=7"
  printf '%s\n' "$output" | grep -qE '^age=[0-9]+$'
}

# Item 2.4 slice 9's code review, major 1: the GNU fallback's value is
# captured with 2>&1, so a wrapper stat that succeeds while also writing to
# stderr must not reach the age arithmetic unchecked either. The stub fails
# -f (as an ordinary GNU stat does with no %m file in the cwd) and answers
# -c with non-digit stdout plus a stderr line, exit 0.
@test "non-seconds stat output is dropped" {
  local repo="$BATS_TEST_TMPDIR/r" cwd="$BATS_TEST_TMPDIR/elsewhere" lock
  local stubdir="$BATS_TEST_TMPDIR/stat-stub"
  mkdir -p "$repo/.git" "$cwd" "$stubdir"
  lock="$repo/.git/index.lock"
  printf '1234567' >"$lock"
  cat >"$stubdir/stat" <<'STUB'
#!/bin/sh
case "$1" in
  -f) exit 1 ;;
  -c) printf '12 junk\n'; printf 'warn\n' >&2 ;;
esac
STUB
  chmod 755 "$stubdir/stat"

  PATH="$stubdir:$PATH" run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ "${output%%$'\n'*}" = orphan ]
  printf '%s\n' "$output" | grep -qxF "bytes=7"
  [ "$(printf '%s\n' "$output" | grep -c '^age=')" -eq 0 ]
  [ "$stderr" = "$(printf '12 junk\nwarn')" ]
}

# Item 2.4 slice 9's code review, checked by hand there: the vanish reached
# by the removing wrapper (tests/probes-edges.bats "vanished lock is gone")
# reads the same way when the wrapper execs the make_bsd_stubs stat instead
# of the real one — BSD's own "illegal option -- c" refusal in place of
# GNU's "No such file or directory". The gone check keys on the filesystem,
# not the error text, so either dialect's refusal reads as gone once the
# path is confirmed absent.
@test "vanished lock is gone under BSD stat" {
  local repo="$BATS_TEST_TMPDIR/r" cwd="$BATS_TEST_TMPDIR/elsewhere" lock
  local stubdir="$BATS_TEST_TMPDIR/stat-stub" bsddir="$BATS_TEST_TMPDIR/bsd-stat" realbsd
  mkdir -p "$repo/.git" "$cwd" "$stubdir"
  lock="$repo/.git/index.lock"
  make_bsd_stubs "$bsddir" stat
  realbsd="$bsddir/stat"
  cat >"$stubdir/stat" <<STUB
#!/bin/sh
for a; do path=\$a; done
rm -f "\$path"
exec "$realbsd" "\$@"
STUB
  chmod 755 "$stubdir/stat"

  printf '1234567' >"$lock"
  PATH="$stubdir:$PATH" run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$output" = "$(printf 'gone\npath=%s' "$lock")" ]

  printf '1234567' >"$lock"
  PATH="$stubdir:$PATH" run_probe probe_git_lock true "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$output" = "$(printf 'gone\npath=%s' "$lock")" ]
}
