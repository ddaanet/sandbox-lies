#!/usr/bin/env bats
# Item 4.1's hook cases: git-lock and config-lock verdicts through the hook.
# Split from tests/hook.bats (at 378 of 400 lines) rather than added there.
#
# Every case here stubs the probe: fire-lock-add-commit.txt names an absolute
# path on the machine that recorded it, and the fixture's path must never
# reach the host filesystem — the stub, not the real probe, answers.

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/hook

setup() {
  hook_copy_tree
}

# run_hook <payload> — invokes the copied annotate.sh, for `run` to capture
# $status and $output (stderr merged in, as hook.bats's run_hook does).
run_hook() {
  run bash -c 'printf "%s" "$1" | bash "$2"' \
    _ "$1" "$HOOK_COPY/hooks/annotate.sh"
}

# stub_probe <name> <outcome> — overrides probe_<name> in the copied
# lib/probes.sh with one that drains stdin, prints <outcome>, and touches
# $PROBE_CALLED. A case asserts that file exists: the real probe_git_lock on
# this fixture's lock path also answers mask when the path is absent, so a
# stub the hook never reached would otherwise pass while the real probe
# stats the host path, and so would a verdict defaulting to mask with no
# probe call at all.
stub_probe() {
  local name="$1" outcome="$2" called
  PROBE_CALLED="$BATS_TEST_TMPDIR/probe-$name-called"
  called=$(printf '%q' "$PROBE_CALLED")
  stub_lib probes.sh "probe_${name}() { cat >/dev/null; : >${called}; printf '%s\\npath=stub\\n' '${outcome}'; }"
}

# assert_lacks <haystack> <pattern> — <pattern> (fixed string) must not occur
# in <haystack>; a grep exit other than 1 (found, or errored) fails the
# assertion rather than reading as absence.
assert_lacks() {
  run bash -c 'printf "%s" "$1" | grep -qF -- "$2"' _ "$1" "$2"
  [ "$status" -eq 1 ]
}

# stub_probe_kv <name> <outcome> [line...] — as stub_probe, printing each
# additional <line> after <outcome> instead of the fixed `path=stub`, so a
# case can feed probe key=value lines (pid=, bytes=, age=) through the hook.
# Each line is %q-quoted into the stub, so it may carry any character.
stub_probe_kv() {
  local name="$1" outcome="$2" called line body
  shift 2
  PROBE_CALLED="$BATS_TEST_TMPDIR/probe-$name-called"
  called=$(printf '%q' "$PROBE_CALLED")
  body="probe_${name}() { cat >/dev/null; : >${called}; printf '%s\\n' $(printf '%q' "$outcome")"
  for line in "$@"; do
    body="${body} $(printf '%q' "$line")"
  done
  body="${body}; }"
  stub_lib probes.sh "$body"
}

@test "mask outcome through the hook" {
  stub_probe git_lock mask
  local text payload ctx sys
  text=$(cat "$FIXTURES/fire-lock-add-commit.txt")
  payload=$(failure_payload "$text")

  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -f "$PROBE_CALLED" ]
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  sys=$(printf '%s' "$output" | jq -r '.systemMessage')
  printf '%s' "$ctx" | grep -qF 'Re-run the same command with'
  printf '%s' "$ctx" | grep -qF 'GIT_INDEX_FILE'
  [ "$sys" = 'index.lock — sandbox mask, not a real lock' ]
}

@test "mask paragraph is flag-neutral under flag true" {
  # A character device under flag true is still mask (a mask visible outside
  # the sandbox where re-running unsandboxed is a no-op); the wording holds
  # rather than taking the flag as an argument (lock-detectors.md's git-lock
  # Flag policy paragraph). Pinned as: flag true yields the same context and
  # human line as flag false, and that context carries the clause for the
  # flag-true case.
  stub_probe git_lock mask
  local text ctx_false sys_false ctx_true sys_true
  text=$(cat "$FIXTURES/fire-lock-add-commit.txt")

  run_hook "$(failure_payload "$text" false)"
  [ "$status" -eq 0 ]
  ctx_false=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  sys_false=$(printf '%s' "$output" | jq -r '.systemMessage')

  rm -f "$PROBE_CALLED"
  run_hook "$(failure_payload "$text" true)"
  [ "$status" -eq 0 ]
  [ -f "$PROBE_CALLED" ]
  ctx_true=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  sys_true=$(printf '%s' "$output" | jq -r '.systemMessage')

  printf '%s' "$ctx_true" | grep -qF 'once no sandboxed command is running'
  [ "$ctx_true" = "$ctx_false" ]
  [ "$sys_true" = "$sys_false" ]
}

@test "mask outcome through the hook under BSD stubs" {
  stub_probe git_lock mask
  local text payload bsd sys
  text=$(cat "$FIXTURES/fire-lock-add-commit.txt")
  payload=$(failure_payload "$text")

  bsd="$BATS_TEST_TMPDIR/bsdtools"
  make_bsd_stubs "$bsd" grep sed
  PATH="$bsd:$PATH" run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -f "$PROBE_CALLED" ]
  sys=$(printf '%s' "$output" | jq -r '.systemMessage')
  [ "$sys" = 'index.lock — sandbox mask, not a real lock' ]
}

@test "held interpolates the pid" {
  stub_probe_kv git_lock held 'pid=4242' "$LOCK_PATH_LINE"
  local text payload ctx sys
  text=$(cat "$FIXTURES/fire-lock-add-commit.txt")
  payload=$(failure_payload "$text")

  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -f "$PROBE_CALLED" ]
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  sys=$(printf '%s' "$output" | jq -r '.systemMessage')
  printf '%s' "$ctx" | grep -qF 'pid 4242'
  [ "$sys" = 'index.lock — held by pid 4242' ]
}

@test "orphan and unknown interpolate size and age" {
  stub_probe_kv git_lock orphan 'bytes=7' 'age=12' "$LOCK_PATH_LINE"
  local text payload ctx
  text=$(cat "$FIXTURES/fire-lock-add-commit.txt")
  payload=$(failure_payload "$text")

  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -f "$PROBE_CALLED" ]
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  printf '%s' "$ctx" | grep -qF '7 bytes'
  printf '%s' "$ctx" | grep -qF 'age 12s'

  stub_probe_kv git_lock unknown 'bytes=7' 'age=12' "$LOCK_PATH_LINE"
  run_hook "$payload"
  [ "$status" -eq 0 ]
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  printf '%s' "$ctx" | grep -qF '7 bytes'
  printf '%s' "$ctx" | grep -qF 'age 12s'
  printf '%s' "$ctx" | grep -qF 'no holder check is available'
}

@test "orphan with neither bytes nor age interpolates no empty value" {
  # Item 2.4 slice 3's code review: a probe may omit bytes= (non-regular or
  # unreadable lock) or age= (stat failed). Neither given, the paragraph must
  # read as a plain sentence — no empty interpolation and no literal N
  # placeholder left over from the un-interpolated text.
  stub_probe_kv git_lock orphan "$LOCK_PATH_LINE"
  local text payload ctx
  text=$(cat "$FIXTURES/fire-lock-add-commit.txt")
  payload=$(failure_payload "$text")

  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -f "$PROBE_CALLED" ]
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  printf '%s' "$ctx" | grep -qF 'no process holds it'
  assert_lacks "$ctx" ' bytes'
  assert_lacks "$ctx" 'age s'
  assert_lacks "$ctx" '()'
  assert_lacks "$ctx" '(,'
  assert_lacks "$ctx" 'N bytes'
  assert_lacks "$ctx" 'age Ns'
}

@test "probe receives flag and cwd" {
  # The stub brackets every argument it receives, so an extra argument, a
  # dropped one, or a cwd split on whitespace records differently from the
  # two the interface names. The last cwd carries a run of spaces and a
  # backslash, which the hook escapes through jq and undoes with printf %b:
  # `\c` left undecoded, or decoded twice, changes what the probe sees.
  local text recorded body
  recorded="$BATS_TEST_TMPDIR/probe-git_lock-args"
  # shellcheck disable=SC2016 # "$@" is literal, expanded when the stub runs
  body='probe_git_lock() { cat >/dev/null; printf "[%s]" "$@" >'"$(printf '%q' "$recorded")"'; printf "%s\n" mask; }'
  stub_lib probes.sh "$body"
  text=$(cat "$FIXTURES/fire-lock-add-commit.txt")

  run_hook "$(failure_payload "$text" true | jq '.cwd = "/x"')"
  [ "$status" -eq 0 ]
  [ "$(cat "$recorded")" = '[true][/x]' ]

  rm -f "$recorded"
  run_hook "$(failure_payload "$text" | jq '.cwd = "/x"')"
  [ "$status" -eq 0 ]
  [ "$(cat "$recorded")" = '[false][/x]' ]

  rm -f "$recorded"
  run_hook "$(failure_payload "$text" | jq --arg c '/a  b\c' '.cwd = $c')"
  [ "$status" -eq 0 ]
  [ "$(cat "$recorded")" = '[false][/a  b\c]' ]
}

@test "config-lock mask names config.lock and update-config" {
  stub_probe config_lock mask
  local text payload ctx
  text=$(cat "$FIXTURES/fire-configlock-remote-add.txt")
  payload=$(failure_payload "$text")

  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -f "$PROBE_CALLED" ]
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  # The human line also names config.lock: context carrying it would satisfy
  # the first grep without the paragraph naming the file.
  assert_lacks "$ctx" 'sandbox mask, not a real lock'
  printf '%s' "$ctx" | grep -qF 'config.lock'
  printf '%s' "$ctx" | grep -qF 'update-config'
}

@test "piped lock failure on a success payload" {
  stub_probe git_lock mask
  local text payload ctx
  text=$(cat "$FIXTURES/fire-lock-piped-tail.txt")
  payload=$(post_payload "$text")

  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -f "$PROBE_CALLED" ]
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  printf '%s' "$ctx" | grep -qF 'GIT_INDEX_FILE'
}

@test "orphan with one of bytes and age interpolates that one alone" {
  # The probe omits bytes= and age= independently (see the case above), so
  # each may arrive alone: the one given is interpolated, the other leaves
  # no empty value behind.
  stub_probe_kv git_lock orphan 'bytes=7' "$LOCK_PATH_LINE"
  local text payload ctx
  text=$(cat "$FIXTURES/fire-lock-add-commit.txt")
  payload=$(failure_payload "$text")

  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -f "$PROBE_CALLED" ]
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  printf '%s' "$ctx" | grep -qF '7 bytes'
  printf '%s' "$ctx" | grep -qF 'no process holds it'
  assert_lacks "$ctx" 'age s'
  assert_lacks "$ctx" 'age Ns'
  assert_lacks "$ctx" ', )'
  assert_lacks "$ctx" ',)'

  stub_probe_kv git_lock orphan 'age=12' "$LOCK_PATH_LINE"
  run_hook "$payload"
  [ "$status" -eq 0 ]
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  printf '%s' "$ctx" | grep -qF 'age 12s'
  printf '%s' "$ctx" | grep -qF 'no process holds it'
  assert_lacks "$ctx" ' bytes'
  assert_lacks "$ctx" '(,'
  assert_lacks "$ctx" '( '
}

# The real probe ends every held/orphan/unknown answer with a path= line, and
# the path comes from the error text, so it may hold spaces, digits and the
# characters a sed replacement or an eval would act on. The stubs carry one.
LOCK_PATH_LINE='path=/tmp/lock 99/a&b\1/.git/index.lock'
