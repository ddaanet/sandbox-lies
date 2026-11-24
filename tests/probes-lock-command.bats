#!/usr/bin/env bats
# lib/probes.sh: a relative lock path resolved against a directory the Bash
# command names (`cd <dir>`, `git -C <dir>`) when no lock exists under the
# cwd's repository and one exists there, so a command that runs git in another
# repository has its lock stat'ed in that repository. Every case builds repo A
# (the cwd, no lock unless the case adds one) and repo B (an empty, writable
# `.git/config.lock`), so a probe resolving against the cwd answers gone with
# A's path. A probe that also finds another existing lock prints ambiguous=1.
# Opened as a separate file: tests/probes-config.bats stands at 410 lines.

ROOT="${BATS_TEST_DIRNAME}/.."

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/probes

setup() {
  assert_unescaped_dir "$BATS_TEST_TMPDIR"
  source "$ROOT/lib/probes.sh"
  A="$BATS_TEST_TMPDIR/a"
  B="$BATS_TEST_TMPDIR/b"
  mkdir -p "$A/.git" "$B/.git"
  : >"$B/.git/config.lock"
}

# assert_lock_at <lock> — the last probe run exited 0, quiet on stderr, did
# not answer gone, and named <lock> on its path= line.
assert_lock_at() {
  local want
  # `|| return 1` on each check: a caller may put this on the left of `||`,
  # where errexit is off and a bare failing `[` would not stop the function.
  [ "$status" -eq 0 ] || return 1
  [ -z "$stderr" ] || return 1
  [ "${output%%$'\n'*}" != gone ] || return 1
  # shellcheck disable=SC2030 # LC_ALL=C is for this substitution alone
  want=$(LC_ALL=C; printf 'path=%q' "$1")
  printf '%s\n' "$output" | grep -qxF -- "$want"
}

# assert_cwd_fallback — the last probe run answered gone on A's lock, the
# cwd-based resolution.
assert_cwd_fallback() {
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = gone ]
  printf '%s\n' "$output" | grep -qxF "path=$A/.git/config.lock"
}

# assert_ambiguous / assert_not_ambiguous — the last probe run printed, or
# did not print, the ambiguous=1 line.
assert_ambiguous() {
  printf '%s\n' "$output" | grep -qxF ambiguous=1
}

assert_not_ambiguous() {
  ! printf '%s\n' "$output" | grep -q '^ambiguous='
}

run_config() {
  run_probe_command probe_config_lock false "$A" "$1" \
    "$(config_lock_error .git/config)"
}

# The body of "cd into another repository", shared with its BSD re-run.
cd_other_repo_case() {
  run_config "cd $B && git remote add origin x"
  assert_lock_at "$B/.git/config.lock"
}

@test "cd into another repository" {
  cd_other_repo_case
}

@test "cd into another repository, with BSD sed, stat, wc and grep" {
  local bsd="$BATS_TEST_TMPDIR/bsdtools"
  make_bsd_stubs "$bsd" sed stat wc grep
  PATH="$bsd:$PATH" cd_other_repo_case
}

@test "git -C another repository" {
  run_config "git -C $B config x y"
  assert_lock_at "$B/.git/config.lock"
}

@test "git-lock: git -C another repository" {
  : >"$B/.git/index.lock"
  run_probe_command probe_git_lock false "$A" "git -C $B add f" \
    "$(git_lock_error .git/index.lock)"
  assert_lock_at "$B/.git/index.lock"
}

@test "quoted targets holding a space" {
  local s="$BATS_TEST_TMPDIR/b dir"
  mkdir -p "$s/.git"
  : >"$s/.git/config.lock"

  run_config "cd \"$s\" && git remote add origin x"
  assert_lock_at "$s/.git/config.lock"

  run_config "git -C '$s' config x y"
  assert_lock_at "$s/.git/config.lock"
}

# A relative target joins onto the cwd; B sits under A, so the walk-up from
# the cwd finds A, whose lock is absent.
@test "relative cd target" {
  mkdir -p "$A/sub/b/.git"
  : >"$A/sub/b/.git/config.lock"
  run_config "cd sub/b; git remote add origin x"
  assert_lock_at "$A/sub/b/.git/config.lock"
}

# The walk-up applies to a candidate as to the cwd: a cd into B's
# subdirectory finds B's top-level.
@test "cd into a subdirectory of another repository" {
  mkdir -p "$B/src"
  run_config "(cd $B/src && git remote add origin x)"
  assert_lock_at "$B/.git/config.lock"
}

@test "tilde target" {
  HOME="$BATS_TEST_TMPDIR" run_config "cd ~/b && git remote add origin x"
  assert_lock_at "$B/.git/config.lock"
}

@test "tilde target with HOME empty yields no candidate" {
  HOME='' run_config "cd ~/b && git remote add origin x"
  assert_cwd_fallback
}

@test "a variable target yields no candidate" {
  run_config "cd \"\$B\" && git remote add origin x"
  assert_cwd_fallback
  run_config "cd \$B/x && git remote add origin x"
  assert_cwd_fallback
}

@test "a target glued to a quote or substitution yields no candidate" {
  run_config "cd $B\"x\" && git remote add origin x"
  assert_cwd_fallback
  run_config "cd $B\$(pwd) && git remote add origin x"
  assert_cwd_fallback
}

@test "the last candidate holding a lock wins" {
  local c="$BATS_TEST_TMPDIR/c"
  mkdir -p "$c/.git"

  run_config "cd $B && git remote add origin x; cd $c && git status"
  assert_lock_at "$B/.git/config.lock"

  assert_not_ambiguous

  # B's lock is still there beside the winner, so the path is ambiguous.
  : >"$c/.git/config.lock"
  run_config "cd $B && git remote add origin x; cd $c && git status"
  assert_lock_at "$c/.git/config.lock"
  assert_ambiguous
}

# A cwd lock that exists is the one the error most likely named: a lock left
# in a directory the command also names does not displace it.
@test "an existing cwd lock stands over a candidate's" {
  : >"$A/.git/config.lock"
  run_config "cd $B && git remote add origin x"
  assert_lock_at "$A/.git/config.lock"
  assert_ambiguous
}

# The rm the config-lock verdict hands the user must not name A's lock when
# the failing call may have met B's: either lock present beside the other
# makes the path ambiguous, by `cd` or by `git -C`.
@test "a cwd lock and a candidate's both present are ambiguous" {
  : >"$A/.git/config.lock"
  run_config "git -C $B config x y"
  assert_lock_at "$A/.git/config.lock"
  assert_ambiguous
  run_config "cd $B && git config x y"
  assert_lock_at "$A/.git/config.lock"
  assert_ambiguous
}

# The chain the hook runs: a mask-shaped lock at the cwd (empty, mode 0444)
# and B's lock beside it; the config-lock verdict on the probe's lines hands
# over no rm of A's lock.
@test "a mask at the cwd beside a candidate's lock gets no rm" {
  local cmd line1 rest
  : >"$A/.git/config.lock"
  chmod 0444 "$A/.git/config.lock"
  for cmd in "git -C $B config x y" "cd $B && git config x y"; do
    run_config "$cmd"
    [ "${output%%$'\n'*}" = mask ]
    assert_ambiguous
    rest=${output#*$'\n'}
    # shellcheck disable=SC1091 # lib/verdicts.sh sits beside lib/probes.sh
    IFS= read -r line1 < <(printf '%s\n' "$rest" \
      | ( . "$ROOT/lib/verdicts.sh"; verdict_config_lock mask false ))
    [ "If it refuses again${line1##*If it refuses again}" = 'If it refuses again, it is a real file: report its path to the user and leave it in place.' ]
  done
}

# A candidate inside the cwd's own repository names the same lock, spelled
# the same after the walk-up (a subdirectory) or not (`.`).
@test "a candidate naming the cwd's own lock is not ambiguous" {
  : >"$A/.git/config.lock"
  mkdir -p "$A/src"
  run_config "cd $A/src && git config x y"
  assert_lock_at "$A/.git/config.lock"
  assert_not_ambiguous
  run_config "cd . && git -C . config x y"
  assert_lock_at "$A/.git/config.lock"
  assert_not_ambiguous
}

@test "a single candidate lock is not ambiguous" {
  run_config "cd $B && git config x y"
  assert_lock_at "$B/.git/config.lock"
  assert_not_ambiguous
}

# git's global options before -C, and cd's options before its target, are
# skipped; each spelling names B.
@test "options before the target still name a candidate" {
  local cmd
  while IFS= read -r cmd; do
    run_config "$cmd"
    assert_lock_at "$B/.git/config.lock" || {
      printf 'missed: %s\n' "$cmd" >&2
      return 1
    }
  done <<CASES
git -c k=v -C $B config x y
git -c 'k=a b' --no-pager -C $B config x y
git --no-pager -C $B config x y
git --git-dir $B/.git -C $B config x y
cd -- $B && git config x y
cd -P $B && git config x y
cd -L $B && git config x y
cd -P -- $B && git config x y
CASES
}

# A word not starting with `-` ends git's global options: `-C` after a
# subcommand is that subcommand's option.
@test "-C after a subcommand names no candidate" {
  run_config "git log -C $B && git config x y"
  assert_cwd_fallback
}

# A single separator byte between two items is both the first one's follower
# and the second one's boundary.
@test "items chained by one separator byte each name a candidate" {
  local c="$BATS_TEST_TMPDIR/c"
  mkdir -p "$c/.git"
  run_config "cd $c;cd $B&&git remote add origin x"
  assert_lock_at "$B/.git/config.lock"
  run_config "cd $c;git -C $B config x y"
  assert_lock_at "$B/.git/config.lock"
}

# probe_cpu_seconds <command> — CPU seconds (user + system) a fresh bash
# spends sourcing lib/probes.sh and running probe_config_lock with cwd A on
# <command>: the least of three runs. CPU time, not wall time, as
# verdicts-path-read.bats's decode_seconds: sibling suites share the cores
# under `just precommit`, and a descheduled run inflates wall time but not CPU
# time. python3's resource module is the clock: bash 3.2 has no EPOCHREALTIME
# and BSD date no %N. The trailing `wait` makes the shell reap the greps behind
# the probe's process substitution, whose CPU RUSAGE_CHILDREN otherwise misses
# (checked on bash 5.2: a 0.65 s burner behind `< <(...)` reads 0.00 s
# without it). Bash before 4.4 cannot `wait` on a process substitution, so
# under Apple's bash 3.2 the greps may go uncounted and the case bounds the
# shell alone.
probe_cpu_seconds() {
  local text
  text=$(config_lock_error .git/config)
  # shellcheck disable=SC2016 # the Python source holds $1..$4 for bash -c
  python3 -I -c '
import resource, subprocess, sys
best = None
for _ in range(3):
    r0 = resource.getrusage(resource.RUSAGE_CHILDREN)
    subprocess.run(["bash", "-c", ". \"$1\"; probe_config_lock false \"$2\" \"$3\" <<<\"$4\" >/dev/null; wait", "_"] + sys.argv[1:], check=True)
    r1 = resource.getrusage(resource.RUSAGE_CHILDREN)
    dt = (r1.ru_utime - r0.ru_utime) + (r1.ru_stime - r0.ru_stime)
    best = dt if best is None else min(best, dt)
print("%.4f" % best)
' "$ROOT/lib/probes.sh" "$A" "$1" "$text"
}

# The scan is linear in the command: a large heredoc ahead of the cd took the
# former per-match prefix strip past the hook's 10 s timeout. The linear scan
# measured 0.10 s of CPU on the 4-vCPU dev box under bash 5.2, bash start-up
# and both greps included (see probe_cpu_seconds), so the bound of 2 s leaves
# a 20-fold margin for a slower host while sitting far under the quadratic
# time.
@test "a cd after an 80 KB heredoc resolves in linear time" {
  local body cmd t
  body=$(head -c 80000 /dev/zero | tr '\0' x)
  cmd=$(printf 'cat >f <<EOF\n%s\nEOF\ncd %s && git config x y' "$body" "$B")
  run_config "$cmd"
  assert_lock_at "$B/.git/config.lock"
  t=$(probe_cpu_seconds "$cmd")
  printf 'cpu=%s s\n' "$t" >&2
  python3 -I -c 'import sys; sys.exit(0 if float(sys.argv[1]) < 2 else 1)' "$t"
}

@test "no candidate holding a lock keeps the cwd resolution" {
  rm "$B/.git/config.lock"
  run_config "cd $B && git -C $B remote add origin x"
  assert_cwd_fallback
}

@test "cd - and an option target yield no candidate" {
  run_config "cd - && git -C -x config x y"
  assert_cwd_fallback
  run_config "cd -- -x && git config x y"
  assert_cwd_fallback
}

@test "an absolute lock path ignores the command" {
  run_probe_command probe_config_lock false "$A" "cd $B && git config x y" \
    "$(config_lock_error "$A/.git/config")"
  assert_cwd_fallback
}
