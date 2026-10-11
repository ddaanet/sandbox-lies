# Shared helpers for the tests/probes*.bats suites, tests/hook-candidates.bats,
# tests/hook-locks-pathless.bats and tests/hook-writes.bats: the error
# builders, the `run` wrappers, the tools-only PATH, the lock holder, the
# no-.git precondition, the readonly-path scratch repo, the index mtime
# reader and the no-readfile assertion their probe cases use.

# Self-quiet (FR-11): git's lock error is built from two fragments at run
# time, as lib/matchers.sh match_git_lock builds its follow-on, so no test
# file holds the diagnostic whole. The follow-on sentence is left out
# entirely — the probe does not read it.
git_lock_error() {
  local path="$1" text
  text="fatal: Unable to create '"
  text="${text}${path}': File exists."
  printf '%s\n' "$text"
}

# config_lock_error <path> — git's config-lock error line, built from two
# fragments at run time (self-quiet, FR-11), the same split
# tests/matchers-edges.bats "detect sees past a NUL" uses for match_config_lock's
# own pattern, so no source line here reads "error: could not lock config
# file ...: File exists" whole. <path> names the config file, not the lock:
# the probe appends ".lock" itself.
config_lock_error() {
  local path="$1" text
  text="error: could not lock config file $path: File"
  text="${text} exists"
  printf '%s\n' "$text"
}

# assert_unescaped_dir <dir> — fails, naming <dir>, unless `printf %q` under
# LC_ALL=C leaves it unchanged. The probes print a path= value in %q form
# (lib/probes.sh), and the suites that spell that line with an interpolated
# $BATS_TEST_TMPDIR write only the escapes for the names they add, so a
# tmpdir holding a byte %q escapes (a blank, a quote, a non-ASCII byte) would
# make every such expectation differ for a reason that is not the probe's.
# Called from the setup of tests/probes.bats, tests/probes-config.bats and
# tests/probes-readonly.bats, where it fails loudly instead.
assert_unescaped_dir() {
  local dir="$1"
  [ "$(LC_ALL=C printf %q "$dir")" = "$dir" ] && return 0
  printf 'tmpdir %q holds a byte printf %%q escapes: the path= expectations spell %s unescaped\n' "$dir" "\$BATS_TEST_TMPDIR" >&2
  return 1
}

# erofs_message — the kernel's read-only-filesystem message, built from two
# fragments (self-quiet, FR-11) as git_lock_error builds git's follow-on
# above, so no probes-readonly test source line reads the phrase whole.
erofs_message() {
  local msg='Read-only'
  msg="$msg file system"
  printf '%s' "$msg"
}

# git's partial-checkout lines under a read-only mount, in the shapes git's
# own format strings give them (git 2.47), built from two fragments around
# erofs_message as above: the unlink form single-quotes the path, the create
# form does not, so the first reads writable and the second nopath. The third
# (verified live, git 2.47.3) is a missing directory, its path single-quoted.
# Shared by tests/probes-readonly-facts.bats and
# tests/probes-readonly-resolve.bats.
partial_checkout_unlink_error() {
  local msg='error: unable to unlink '
  msg="${msg}old '$1': $(erofs_message)"
  printf '%s\n' "$msg"
}

partial_checkout_create_error() {
  local msg='error: unable to create '
  msg="${msg}file $1: $(erofs_message)"
  printf '%s\n' "$msg"
}

partial_checkout_mkdir_error() {
  local msg='fatal: cannot create '
  msg="${msg}directory at '$1': $(erofs_message)"
  printf '%s\n' "$msg"
}

# readonly_path_text <fixture> <replacement> — the cut fire-readonly-path-*
# fixture (tests/fixtures/<fixture>.txt) with its first single-quoted path
# replaced by <replacement>, built at run time as git_lock_error is, so this
# file never holds the readonly-path refusal whole (self-quiet, FR-11).
# <replacement> is inserted verbatim: the caller quotes it itself (a path
# under $BATS_TEST_TMPDIR), or passes empty to remove the quoted segment
# entirely, leaving no quoted path on the line. `#` as the sed delimiter,
# since <replacement> is a path and may hold `/`. Residual: a <replacement>
# holding `#`, `&` or a backslash is read by sed, not inserted verbatim.
readonly_path_text() {
  local fixture="$1" replacement="$2"
  sed -E "s#'[^']*'#${replacement}#" "${BATS_TEST_DIRNAME}/fixtures/${fixture}.txt"
}

# make_scratch_repo <repo> — HEAD at main; branch feat changes a, b, c and
# `e f` against main's content and leaves d as main has it; the working tree
# left as a real partial checkout would: a staged at feat's content, b and
# `e f` unstaged at feat's content, c edited to a third value neither commit
# holds, d untouched. d's working-tree content equals feat's too, so it is
# the decoy for the modified-against-HEAD filter; `e f` holds a blank. Shared
# by tests/probes-readonly-facts.bats, tests/probes-readonly-members.bats,
# tests/probes-readonly-pins.bats, tests/probes-edges.bats and
# tests/hook-writes.bats.
make_scratch_repo() {
  local repo="$1"
  git init -q -b main "$repo"
  git -C "$repo" config user.email test@example.invalid
  git -C "$repo" config user.name test
  git -C "$repo" config commit.gpgsign false
  printf 'a main\n' >"$repo/a"
  printf 'b main\n' >"$repo/b"
  printf 'c main\n' >"$repo/c"
  printf 'd both\n' >"$repo/d"
  printf 'e main\n' >"$repo/e f"
  git -C "$repo" add a b c d 'e f'
  git -C "$repo" commit -q -m main
  git -C "$repo" checkout -q -b feat
  printf 'a feat\n' >"$repo/a"
  printf 'b feat\n' >"$repo/b"
  printf 'c feat\n' >"$repo/c"
  printf 'e feat\n' >"$repo/e f"
  git -C "$repo" add a b c 'e f'
  git -C "$repo" commit -q -m feat
  git -C "$repo" checkout -q main
  printf 'a feat\n' >"$repo/a"
  git -C "$repo" add a
  printf 'b feat\n' >"$repo/b"
  printf 'e feat\n' >"$repo/e f"
  printf 'c other\n' >"$repo/c"
}

# index_mtime <index> — seconds since the epoch. BSD's `stat -f %m` is kept
# only when it reads as digits: on GNU, -f is filesystem mode, and with a file
# operand it prints that filesystem's free-block report, which changes between
# two reads. Else GNU's `stat -c %Y`.
index_mtime() {
  local m
  if m=$(stat -f %m "$1" 2>/dev/null) && [ -n "$m" ] \
    && [ -z "${m//[0-9]/}" ]; then
    printf '%s\n' "$m"
  else
    stat -c %Y "$1"
  fi
}

# run_probe <probe> <flag> <cwd> <text> — the probe under bats' run with
# <text> on stdin: stdout in $output, stderr in $stderr, exit in $status.
# stderr is kept apart so it cannot shift the outcome off line 1. Line 1 is
# read as ${output%%$'\n'*}, never ${lines[0]}: bats drops empty lines from
# lines, so a stray blank first line would pass for the token.
run_probe() {
  run --separate-stderr "$1" "$2" "$3" <<<"$4"
}

# run_probe_command <probe> <flag> <cwd> <command> <text> — as run_probe, but
# also passing <command> as the probe's third argument, as hooks/annotate.sh
# passes tool_input.command to probe_readonly_path.
run_probe_command() {
  run --separate-stderr "$1" "$2" "$3" "$4" <<<"$5"
}

# tools_only_path <dir> — symlinks into <dir> every external tool the
# lock probes call other than the holder tools (lsof, fuser), plus
# mktemp for bats' own `run --separate-stderr` (test_functions.bash), taken
# from this host's own `command -v` so the case runs on any box. A PATH set
# to exactly <dir> can then never see lsof or fuser unless a test writes one
# there itself. The tool list lives here once, so a new probe call site
# updates one place.
tools_only_path() {
  local dir="$1" tool
  mkdir -p "$dir"
  for tool in cat sed head stat wc tr date mktemp; do
    ln -s "$(command -v "$tool")" "$dir/$tool"
  done
}

# hold_lock <lock> — backgrounds a holder opening <lock> read-only on fd 4
# (any fd but 3), its pid in _probe_holder_pid for the caller's teardown to
# kill, and returns only once the open has happened: the ready file is
# written after it, so the probe never runs ahead of the holder. A holder
# that cannot open the lock never writes the file, and the bounded wait
# fails the test.
#
# fd 3 is closed on the holder: bats duplicates its TAP stream onto fd 3, and
# a background job holding it open keeps the run from returning until the
# 30s sleep exits (seen on this box). The subshell execs sleep, so its pid is
# $! throughout. A finished decoy job runs last, so $! in the test — and in
# the probe's subshell, which inherits it — no longer names the holder: a
# probe printing its own $! cannot pass for one naming the holder.
#
# Shared by tests/probes.bats, tests/probes-edges.bats and
# tests/probes-lock-newline.bats: each file's own setup() resets
# _probe_holder_pid and its own teardown() calls kill_holder.
hold_lock() {
  local ready="$BATS_TEST_TMPDIR/holder-ready" tries=0
  (
    exec 4<"$1"
    : >"$ready"
    exec sleep 30
  ) 3>&- &
  _probe_holder_pid=$!
  until [ -e "$ready" ]; do
    [ "$tries" -lt 50 ] || return 1
    tries=$((tries + 1))
    sleep 0.1
  done
  : &
  wait "$!"
}

# kill_holder — kills the job hold_lock started, if a test started one: every
# other test leaves _probe_holder_pid at setup's empty default. A killed
# job's wait returns 143 and a failing teardown fails the test, and kill
# finds no process when the holder died on its own, so both are tolerated.
kill_holder() {
  if [ -n "${_probe_holder_pid:-}" ]; then
    kill "$_probe_holder_pid" 2>/dev/null || :
    wait "$_probe_holder_pid" 2>/dev/null || :
  fi
}

# assert_no_git_above <dir> — fails unless neither <dir> nor any ancestor up
# to / holds a .git entry, so a case relying on the walk-up finding nothing
# cannot pass because the box's own tree supplied one.
assert_no_git_above() {
  local ancestor="$1"
  while [ "$ancestor" != / ]; do
    [ ! -e "$ancestor/.git" ]
    ancestor=$(dirname "$ancestor")
  done
  [ ! -e "/.git" ]
}

# run_probe_bounded <probe> <flag> <cwd> <text> [<command>] — as run_probe
# (as run_probe_command when <command> is given), but the probe runs
# backgrounded with its streams captured to files and a bounded poll,
# setting $status, $output and $stderr itself. A probe that hangs (a walk-up
# regression, or tests/probes-edges.bats' non-regular-lock case before its
# [ -f ] guard) then fails the test on $status instead of hanging the suite.
# No GNU timeout: this repo's portability target excludes it.
#
# set -m gives the backgrounded job its own process group (pid == pgid), so
# a timeout can kill -- "-$pid" the whole group at once. Killing $pid alone
# leaves a blocked grandchild (a FIFO open several forks down through the
# command substitution that reads it) running as an orphan — and bats' own
# plumbing holds pipe fds that orphan inherits, which then keeps the whole
# run from returning, not just this function. The kill tolerates a group
# that exited since the poll, so errexit cannot end the test before $status
# is set.
#
# The 3 s bound (30 polls of 0.1 s) is load-sensitive: a probe that returns
# correctly but slowly on a loaded box reads as the timeout.
#
# Shared by tests/probes-edges.bats, tests/probes-config.bats and
# tests/probes-readonly-pins.bats.
run_probe_bounded() {
  local out="$BATS_TEST_TMPDIR/bounded-out" err="$BATS_TEST_TMPDIR/bounded-err"
  local rc="$BATS_TEST_TMPDIR/bounded-status" pid tries=0
  set -m
  ("$1" "$2" "$3" ${5+"$5"} <<<"$4" >"$out" 2>"$err"; echo "$?" >"$rc") &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$tries" -ge 30 ]; then
      kill -- "-$pid" 2>/dev/null || :
      wait "$pid" 2>/dev/null || :
      set +m
      status=124
      output=$(cat "$out" 2>/dev/null || :)
      stderr="TIMEOUT: probe did not return within the bound"
      return
    fi
    tries=$((tries + 1))
    sleep 0.1
  done
  wait "$pid" 2>/dev/null || :
  set +m
  # shellcheck disable=SC2034 # read by the calling test, not here
  status=$(cat "$rc")
  # shellcheck disable=SC2034 # read by the calling test, not here
  output=$(cat "$out")
  # shellcheck disable=SC2034 # read by the calling test, not here
  stderr=$(cat "$err")
}

# assert_no_readfile — the last probe run exited 0 with nothing on stderr,
# answered writable (so an empty output cannot pass) and printed no readfile=
# line.
assert_no_readfile() {
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  run ! grep -q '^readfile=' <<<"$output"
}
