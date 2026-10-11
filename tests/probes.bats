#!/usr/bin/env bats
# lib/probes.sh: probe_git_lock and probe_config_lock, the A-3 contract.
#
# Each probe reads the Bash tool result text on stdin, takes the flag as $1
# and the payload cwd as $2, and prints an outcome token on line 1 followed
# by key=value lines. Synthetic fixture trees live under $BATS_TEST_TMPDIR.

ROOT="${BATS_TEST_DIRNAME}/.."

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/locale
load helpers/probes

setup() {
  assert_unescaped_dir "$BATS_TEST_TMPDIR"
  source "$ROOT/lib/probes.sh"
  _probe_holder_pid=
}

teardown() {
  kill_holder
}

# $2 names an unrelated directory, so the path= line can only come from the
# error text. The lock is never created; absence is guarded rather than
# probed, so no tool error reaches stderr.
@test "absent lock, sandboxed, is mask" {
  local repo="$BATS_TEST_TMPDIR/r" cwd="$BATS_TEST_TMPDIR/elsewhere" lock
  mkdir -p "$repo/.git" "$cwd"
  lock="$repo/.git/index.lock"

  run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = mask ]
  printf '%s\n' "$output" | grep -qxF "path=$lock"
}

@test "absent lock, unsandboxed, is gone" {
  local repo="$BATS_TEST_TMPDIR/r" cwd="$BATS_TEST_TMPDIR/elsewhere" lock
  mkdir -p "$repo/.git" "$cwd"
  lock="$repo/.git/index.lock"

  run_probe probe_git_lock true "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = gone ]
  printf '%s\n' "$output" | grep -qxF "path=$lock"
}

# The directory name holds a raw non-UTF-8 byte (octal 351). Run under
# the UTF-8 locale utf8_locale finds: under it GNU sed's "." does not match an
# invalid byte, which is exactly why the extractor forces LC_ALL=C internally.
# The path is asserted byte-exact via an exact-line path= match.
@test "non-UTF-8 byte in the path" {
  local repo cwd lock loc
  repo="$BATS_TEST_TMPDIR/r$(printf '\351')n/r"
  cwd="$BATS_TEST_TMPDIR/elsewhere"
  mkdir -p "$repo/.git" "$cwd"
  lock="$repo/.git/index.lock"
  loc=$(utf8_locale)

  # Precondition: under that UTF-8 locale a locale-aware sed cannot match the
  # path whole. Without the locale installed, sed falls back to byte-wise C and
  # the path= assertion passes whatever the extractor does, so this fails
  # loudly instead (a skip would read as a pass in run-bats.sh's count).
  [ -z "$(printf '%s\n' "$lock" | LC_ALL="$loc" sed -n 's/^.*$/x/p')" ]

  LC_ALL="$loc" run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  printf '%s\n' "$output" | grep -qxF \
    "path=\$'$BATS_TEST_TMPDIR/r\\351n/r/.git/index.lock'"
}

# assert_unescaped_dir (helpers/probes.bash) guards the setup of the suites
# that spell a path= line with an interpolated $BATS_TEST_TMPDIR. Each name
# below is built at run time under the tmpdir and holds one kind of byte %q
# escapes: a blank, a quote, a UTF-8 byte pair, a control byte. A name %q
# leaves alone passes, so the helper is not a constant failure.
@test "assert_unescaped_dir fails for a directory name holding a byte %q escapes" {
  local name
  for name in "a b" "it's" "caf"$'\303\251' "tab"$'\t'"x"; do
    run --separate-stderr assert_unescaped_dir "$BATS_TEST_TMPDIR/$name"
    [ "$status" -eq 1 ] || { printf 'name %q passed\n' "$name" >&2; return 1; }
    [[ $stderr == *"holds a byte printf %q escapes"* ]]
  done

  run --separate-stderr assert_unescaped_dir "$BATS_TEST_TMPDIR/plain-dir_1.d"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
}

# The cwd's name holds a blank, so the resolved lock path is printed in
# printf %q form: the blank escaped by a backslash. The setup's
# assert_unescaped_dir keeps the expected line honest: were BATS_TEST_TMPDIR
# itself to hold a byte %q escapes, the literal below would differ from the
# encoder's output for a reason other than the blank.
@test "a relative lock path under a cwd holding a blank prints path= in %q form" {
  local cwd="$BATS_TEST_TMPDIR/r b"
  mkdir -p "$cwd/.git"

  run_probe probe_git_lock false "$cwd" "$(git_lock_error .git/index.lock)"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = mask ]
  [ "$(printf '%s\n' "$output" | grep '^path=')" \
    = "path=$BATS_TEST_TMPDIR/r\\ b/.git/index.lock" ]
}

# Text with no config-lock line names no path, so the probe answers mask
# alone: an empty path prints no path= line, where it used to print a bare
# `path=`.
@test "probe_config_lock with no config-lock line prints mask and no path=" {
  run_probe probe_config_lock false "$BATS_TEST_TMPDIR" \
    "$(printf 'quiet preamble text\n')"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$output" = mask ]
}

# The directory name holds e-acute as its two UTF-8 bytes, run under a UTF-8
# locale. The encoder pins LC_ALL=C, so each byte prints as an octal escape;
# unpinned on bash 5.2, %q under a UTF-8 locale prints the character raw, and
# the printed form would depend on the hook's locale.
@test "a lock path holding e-acute prints the octal form under a UTF-8 locale" {
  local loc cwd="$BATS_TEST_TMPDIR/caf"$'\303\251'
  loc=$(utf8_locale)
  mkdir -p "$cwd/.git"

  LC_ALL="$loc" run_probe probe_git_lock false "$cwd" \
    "$(git_lock_error .git/index.lock)"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = mask ]
  [ "$(printf '%s\n' "$output" | grep '^path=')" \
    = "path=\$'$BATS_TEST_TMPDIR/caf\\303\\251/.git/index.lock'" ]
}

# The lock holds exactly 7 bytes, no trailing newline. No holder process ever
# opens it, and the holder tool (lsof or fuser) is on the ordinary PATH. Its
# mtime is backdated to 2000 (POSIX touch -t), so an age over a day can only
# come from reading the mtime: a constant 0, or an age taken from the ctime
# or the clock, stays under it.
@test "present unheld lock is orphan" {
  local repo="$BATS_TEST_TMPDIR/r" cwd="$BATS_TEST_TMPDIR/elsewhere" lock age
  mkdir -p "$repo/.git" "$cwd"
  lock="$repo/.git/index.lock"
  printf '1234567' >"$lock"
  touch -t 200001010000 "$lock"

  run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = orphan ]
  printf '%s\n' "$output" | grep -qxF "bytes=7"
  printf '%s\n' "$output" | grep -qE '^age=[0-9]+$'
  age=$(printf '%s\n' "$output" | sed -n 's/^age=//p')
  [ "$age" -gt 86400 ]
  printf '%s\n' "$output" | grep -qxF "path=$lock"

  run_probe probe_git_lock true "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = orphan ]
  printf '%s\n' "$output" | grep -qxF "bytes=7"
  printf '%s\n' "$output" | grep -qE '^age=[0-9]+$'
  age=$(printf '%s\n' "$output" | sed -n 's/^age=//p')
  [ "$age" -gt 86400 ]
  printf '%s\n' "$output" | grep -qxF "path=$lock"
}

# Only the literal true reads as unsandboxed (slice 2's code review): an
# empty flag and a wrong-case TRUE must both still read as sandboxed.
@test "unexpected flag reads as sandboxed" {
  local repo="$BATS_TEST_TMPDIR/r" cwd="$BATS_TEST_TMPDIR/elsewhere" lock
  mkdir -p "$repo/.git" "$cwd"
  lock="$repo/.git/index.lock"

  run_probe probe_git_lock "" "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = mask ]
  printf '%s\n' "$output" | grep -qxF "path=$lock"

  run_probe probe_git_lock TRUE "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = mask ]
  printf '%s\n' "$output" | grep -qxF "path=$lock"
}

# The repo directory name holds a single quote and a space (slice 1's code
# review): pins the greedy .lock capture and quoting through the size and
# mtime reads. Not the holder check's quoting: a split path has no holder
# either, so it still reads orphan. The lock holds 12 bytes, not 7, so a
# constant bytes=7 cannot pass every lock test.
@test "quote and space in the lock path" {
  local repo="$BATS_TEST_TMPDIR/it's here/r" cwd="$BATS_TEST_TMPDIR/elsewhere" lock
  mkdir -p "$repo/.git" "$cwd"
  lock="$repo/.git/index.lock"
  printf '0123456789ab' >"$lock"

  run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = orphan ]
  printf '%s\n' "$output" | grep -qxF \
    "path=$BATS_TEST_TMPDIR/it\\'s\\ here/r/.git/index.lock"
  printf '%s\n' "$output" | grep -qxF "bytes=12"
  printf '%s\n' "$output" | grep -qE '^age=[0-9]+$'
}

# hold_lock is defined in helpers/probes.bash, shared with probes-edges.bats.

# Exactly one pid= line: a holder query wider than the lock (a whole mount,
# the directory) would list the holder among other pids. The flag only
# selects mask or gone for an absent lock, so both flags read held.
@test "held lock names the holder" {
  local repo="$BATS_TEST_TMPDIR/r" cwd="$BATS_TEST_TMPDIR/elsewhere" lock
  mkdir -p "$repo/.git" "$cwd"
  lock="$repo/.git/index.lock"
  printf '1234567' >"$lock"
  hold_lock "$lock"

  run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = held ]
  printf '%s\n' "$output" | grep -qxF "pid=$_probe_holder_pid"
  [ "$(printf '%s\n' "$output" | grep -c '^pid=')" -eq 1 ]

  run_probe probe_git_lock true "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = held ]
  printf '%s\n' "$output" | grep -qxF "pid=$_probe_holder_pid"
  [ "$(printf '%s\n' "$output" | grep -c '^pid=')" -eq 1 ]
}

# Same holder, under the quote-and-space path: the only case in this list
# pinning the holder tool's own quoting (slice 3's reviews). An unquoted
# lsof/fuser invocation gets two nonexistent paths, finds no holder and
# reports the misses on stderr (fuser does so, checked on this box).
@test "held lock under a quoted, spaced path" {
  local repo="$BATS_TEST_TMPDIR/it's here/r" cwd="$BATS_TEST_TMPDIR/elsewhere" lock
  mkdir -p "$repo/.git" "$cwd"
  lock="$repo/.git/index.lock"
  printf '1234567' >"$lock"
  hold_lock "$lock"

  run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = held ]
  printf '%s\n' "$output" | grep -qxF "pid=$_probe_holder_pid"
  [ "$(printf '%s\n' "$output" | grep -c '^pid=')" -eq 1 ]
}

# A symlink to /dev/null keeps the ordinary lock shape under extraction (the
# path still ends in index.lock), so this pins the character-device rule
# rather than the path parse. /dev/null typically has many open holders
# (every redirected stdio on the box), so a probe with no character-device
# rule reads this as held, not mask. The control first: a symlink to a 7-byte
# regular file stats as a regular file and reads orphan, so a rule keyed on
# the symlink itself rather than on what it resolves to fails there.
@test "character device is mask" {
  local repo="$BATS_TEST_TMPDIR/r" cwd="$BATS_TEST_TMPDIR/elsewhere" lock
  mkdir -p "$repo/.git" "$cwd"
  lock="$repo/.git/index.lock"
  printf '1234567' >"$repo/.git/target"
  ln -s "$repo/.git/target" "$lock"

  run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = orphan ]
  printf '%s\n' "$output" | grep -qxF "bytes=7"

  rm "$lock"
  ln -s /dev/null "$lock"

  run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = mask ]
  printf '%s\n' "$output" | grep -qxF "path=$lock"

  run_probe probe_git_lock true "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = mask ]
  printf '%s\n' "$output" | grep -qxF "path=$lock"
}

# PATH set to a directory holding only the tools probe_git_lock itself calls,
# built from this host's own binaries: neither lsof nor fuser is there, so
# the case never depends on which of the two (if either) the host provides.
@test "no holder tool is unknown" {
  local repo="$BATS_TEST_TMPDIR/r" cwd="$BATS_TEST_TMPDIR/elsewhere" lock
  local toolsdir="$BATS_TEST_TMPDIR/tools-only"
  mkdir -p "$repo/.git" "$cwd"
  lock="$repo/.git/index.lock"
  printf '1234567' >"$lock"
  tools_only_path "$toolsdir"

  PATH="$toolsdir" run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = unknown ]
  printf '%s\n' "$output" | grep -qxF "bytes=7"
}

# The error text names the lock relative to git's cwd (".git/index.lock").
# The probe runs from an unrelated directory holding a 3-byte decoy lock at
# that same relative path (slice 2's code review): a probe resolving against
# its process cwd, even only as a first try before $2, reads the decoy, so
# bytes=7 and the absolute path= can only come from $2. $2 reaches the repo
# through a symlink, and path= keeps it as given rather than canonicalised,
# as every other case prints the path the error text gave.
@test "relative path resolves against cwd" {
  local repo="$BATS_TEST_TMPDIR/r" unrelated="$BATS_TEST_TMPDIR/elsewhere"
  local link="$BATS_TEST_TMPDIR/link"
  mkdir -p "$repo/.git" "$unrelated/.git"
  ln -s "$repo" "$link"
  printf '1234567' >"$repo/.git/index.lock"
  printf 'abc' >"$unrelated/.git/index.lock"
  cd "$unrelated"

  run_probe probe_git_lock false "$link" "$(git_lock_error .git/index.lock)"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = orphan ]
  printf '%s\n' "$output" | grep -qxF "bytes=7"
  printf '%s\n' "$output" | grep -qxF "path=$link/.git/index.lock"
}

# Slice 3's present-unheld-lock case again, this time with the stat stub on
# PATH that refuses -c as BSD does (the mtime read must use `stat -f %m`)
# and the wc stub that left-pads its count as BSD does (pinning the strip
# that removes the padding). real_mtime is read with the real stat before
# the stub goes on PATH, so the age assertion is exact rather than a loose
# lower bound. Only the mtime is backdated (touch -m): the atime and ctime
# stay at the write, so an age read from either lands decades short of the
# window rather than inside it.
@test "BSD stat" {
  local repo="$BATS_TEST_TMPDIR/r" cwd="$BATS_TEST_TMPDIR/elsewhere" lock
  local stubdir="$BATS_TEST_TMPDIR/bsd-stubs" real_mtime now age
  mkdir -p "$repo/.git" "$cwd"
  lock="$repo/.git/index.lock"
  printf '1234567' >"$lock"
  touch -m -t 200001010000 "$lock"
  real_mtime=$(index_mtime "$lock")
  make_bsd_stubs "$stubdir" stat wc

  PATH="$stubdir:$PATH" run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = orphan ]
  printf '%s\n' "$output" | grep -qxF "bytes=7"
  printf '%s\n' "$output" | grep -qE '^age=[0-9]+$'
  age=$(printf '%s\n' "$output" | sed -n 's/^age=//p')
  now=$(date +%s)
  [ "$age" -ge $((now - real_mtime - 60)) ]
  [ "$age" -le $((now - real_mtime + 60)) ]
  printf '%s\n' "$output" | grep -qxF "path=$lock"
}
