#!/usr/bin/env bats
# Item 5.5 slice 1's code review, Major 1: hook-level pins for a lock probe
# that prints its outcome alone, with no path= line. The real probe prints none
# when it extracted no path: probe_config_lock finds no config-lock line in
# the text, and an empty path prints no path= line. (A path holding a newline
# still prints, as one encoded line.) A mask or gone output is then the
# outcome alone, with no newline, so annotate.sh takes its no-newline branch and
# the verdict reads one empty stdin line; held keeps its pid= line. Split from
# tests/hook-locks.bats, which sat at 399 of 400 lines.

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/git-env
load helpers/hook
load helpers/probes

setup() {
  hook_copy_tree
}

# run_hook <payload> — invokes the copied annotate.sh, for `run` to capture
# $status and $output (stderr merged in).
run_hook() {
  run bash -c 'printf "%s" "$1" | bash "$2"' \
    _ "$1" "$HOOK_COPY/hooks/annotate.sh"
}

@test "config-lock mask with no path= line keeps Re-run, never update-config" {
  local text flag ctx sys rerun other
  text=$(cat "$FIXTURES/fire-configlock-remote-add.txt")

  for flag in false true; do
    if [ "$flag" = false ]; then
      # shellcheck disable=SC2016 # backticks are literal prose, not expansion
      rerun='Once no sandboxed command is running, re-run the same command with `dangerouslyDisableSandbox: true`'
      other='same command once no sandboxed'
    else
      rerun='Re-run the same command once no sandboxed command is running'
      other='dangerouslyDisableSandbox: true'
    fi
    stub_probe_kv config_lock mask
    rm -f "$PROBE_CALLED"
    run_hook "$(failure_payload "$text" "$flag")"
    [ "$status" -eq 0 ]
    [ -f "$PROBE_CALLED" ]
    ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
    sys=$(printf '%s' "$output" | jq -r '.systemMessage')
    [ "$sys" = 'config.lock — sandbox mask, not a real lock' ]
    printf '%s' "$ctx" | grep -qF -- "$rerun"
    assert_lacks "$ctx" "$other"
    assert_lacks "$ctx" 'update-config'
  done
}

@test "git-lock held with no path= line interpolates the pid" {
  local text sys
  text=$(cat "$FIXTURES/fire-lock-add-commit.txt")
  stub_probe_kv git_lock held 'pid=4242'

  run_hook "$(failure_payload "$text")"
  [ "$status" -eq 0 ]
  [ -f "$PROBE_CALLED" ]
  sys=$(printf '%s' "$output" | jq -r '.systemMessage')
  [ "$sys" = 'index.lock — held by pid 4242' ]
}

@test "real config-lock probe: a newline-bearing cwd forges no settings path" {
  # The 5.4 review's exploit end to end: a relative lock path joins onto a cwd
  # whose name holds a forged path= line. The payload carries real newlines;
  # the hook encodes and decodes them (%b) before the probe sees the cwd. The
  # relative .git/config joins onto the cwd only when the walk up from it finds
  # no .git directory; one above $BATS_TEST_TMPDIR would take the join, no
  # newline would reach the probe, and the case would pass on any code.
  # The lock is absent, so the real probe answers gone, whose flag-false
  # verdict also reads the path= line for the settings act: a forged line
  # would swap in update-config.
  local text cwd ctx sys
  assert_no_git_above "$BATS_TEST_TMPDIR"
  text=$(cat "$FIXTURES/fire-configlock-remote-add.txt")
  cwd="$BATS_TEST_TMPDIR/c"$'\n'"path=$BATS_TEST_TMPDIR/h/.claude/settings.json.lock"$'\n'y

  run_hook "$(failure_payload "$text" | jq --arg c "$cwd" '.cwd = $c')"
  [ "$status" -eq 0 ]
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  sys=$(printf '%s' "$output" | jq -r '.systemMessage')
  [ "$sys" = 'config.lock — absent now, mask or released' ]
  printf '%s' "$ctx" | grep -qF 'No lock exists now'
  assert_lacks "$ctx" 'update-config'
}

@test "config-lock mask with no path= line under BSD stubs" {
  local text bsd sys
  text=$(cat "$FIXTURES/fire-configlock-remote-add.txt")
  stub_probe_kv config_lock mask

  bsd="$BATS_TEST_TMPDIR/bsdtools"
  make_bsd_stubs "$bsd" grep sed
  PATH="$bsd:$PATH" run_hook "$(failure_payload "$text")"
  [ "$status" -eq 0 ]
  [ -f "$PROBE_CALLED" ]
  sys=$(printf '%s' "$output" | jq -r '.systemMessage')
  [ "$sys" = 'config.lock — sandbox mask, not a real lock' ]
}
