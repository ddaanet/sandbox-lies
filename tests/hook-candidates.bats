#!/usr/bin/env bats
# The candidate detectors through the hook: the flag policy of the shipped
# verdict-only candidates (tmpdir-unset, resume-lost, seccomp-init, Item 4.2)
# and readonly-path's probed verdicts (Item 6.1). First file
# to exist for candidate hook cases (runbook Phase 4 preamble), so it also
# carries the one BSD-portability case any such file owes.

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/git-env
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

# Each flag-policy case runs one fixture twice, differing only in the flag, so
# the silent half can only be the policy: the fires-with half shows the matcher
# and verdict fire on the same text.

@test "tmpdir-unset flag policy" {
  # Fires only when the flag is true.
  local text payload ctx sys
  text=$(cat "$FIXTURES/fire-tmpdir-unset-redirect.txt")

  payload=$(failure_payload "$text" true)
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -n "$output" ] \
    || { echo "no verdict emitted, flag true" >&2; return 1; }
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  printf '%s' "$ctx" | grep -qF '/tmp/claude/'
  sys=$(printf '%s' "$output" | jq -r '.systemMessage')
  # shellcheck disable=SC2016 # $TMPDIR is literal prose, not expansion
  [ "$sys" = '$TMPDIR — expanded empty, path collapsed to /' ]

  payload=$(failure_payload "$text")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "resume-lost flag policy" {
  # Fires only when the flag is false.
  local text payload ctx sys
  text=$(cat "$FIXTURES/fire-resume-lost-two-turn.txt")
  # The real probe reads the config dir; an empty one keeps it off the host's.
  mkdir -p "$BATS_TEST_TMPDIR/cfg-empty"
  export CLAUDE_CONFIG_DIR="$BATS_TEST_TMPDIR/cfg-empty"

  payload=$(post_payload "$text")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -n "$output" ] \
    || { echo "no verdict emitted, flag absent" >&2; return 1; }
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  printf '%s' "$ctx" | grep -qF 'one unsandboxed call'
  sys=$(printf '%s' "$output" | jq -r '.systemMessage')
  [ "$sys" = '--resume — transcript not persisted in sandbox' ]

  payload=$(post_payload "$text" "" true)
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "seccomp-init flag policy" {
  # Silent when the flag is true.
  local text payload ctx sys
  text=$(cat "$FIXTURES/fire-seccomp-init-sed.txt")

  payload=$(failure_payload "$text")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -n "$output" ] \
    || { echo "no verdict emitted, flag absent" >&2; return 1; }
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  printf '%s' "$ctx" | grep -qF 'Retry the identical command once'
  sys=$(printf '%s' "$output" | jq -r '.systemMessage')
  [ "$sys" = 'sandbox init failed — transient, retry' ]

  payload=$(failure_payload "$text" true)
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "readonly-path flag policy" {
  # Silent when the flag is true, and the probe is not run.
  local text payload sys
  text=$(cat "$FIXTURES/fire-readonly-path-cp-tmp.txt")
  stub_probe readonly_path writable

  payload=$(failure_payload "$text")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -n "$output" ] \
    || { echo "no verdict emitted, flag absent" >&2; return 1; }
  [ -f "$PROBE_CALLED" ]
  sys=$(printf '%s' "$output" | jq -r '.systemMessage')
  [ "$sys" = 'read-only — sandbox allowlist, writable outside' ]

  rm -f "$PROBE_CALLED"
  payload=$(failure_payload "$text" true)
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -f "$PROBE_CALLED" ]
}

@test "writable outcome through the hook" {
  # The probe's fact lines after the outcome reach the verdict's stdin: the
  # merge=1 and partial=1 lines select the no-target merge clause.
  stub_probe_kv readonly_path writable 'path=/r/x' 'merge=1' 'partial=1'
  local text payload ctx sys
  text=$(cat "$FIXTURES/fire-readonly-path-cp-tmp.txt")
  payload=$(failure_payload "$text")

  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -f "$PROBE_CALLED" ]
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  sys=$(printf '%s' "$output" | jq -r '.systemMessage')
  printf '%s' "$ctx" | grep -qF '/r/x'
  printf '%s' "$ctx" | grep -qF 'is writable outside the sandbox'
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  printf '%s' "$ctx" | grep -qF 'restore them from HEAD, then re-run the whole call with `dangerouslyDisableSandbox: true`.'
  [ "$sys" = 'read-only — sandbox allowlist, writable outside' ]
}

@test "readonly outcome through the hook" {
  stub_probe_kv readonly_path readonly 'path=/r/y'
  local text payload ctx sys
  text=$(cat "$FIXTURES/fire-readonly-path-cp-tmp.txt")
  payload=$(failure_payload "$text")

  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -f "$PROBE_CALLED" ]
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  sys=$(printf '%s' "$output" | jq -r '.systemMessage')
  printf '%s' "$ctx" | grep -qF '/r/y'
  printf '%s' "$ctx" | grep -qF 'not a sandbox effect'
  [ "$sys" = 'read-only — real' ]
}

@test "nopath outcome through the hook" {
  # The probe contract gives no path= line for nopath.
  stub_probe_kv readonly_path nopath
  local text payload ctx sys
  text=$(cat "$FIXTURES/fire-readonly-path-cp-tmp.txt")
  payload=$(failure_payload "$text")

  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -f "$PROBE_CALLED" ]
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  sys=$(printf '%s' "$output" | jq -r '.systemMessage')
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$ctx" = "The sandbox's write allowlist most likely refused this write. Re-run the whole call with \`dangerouslyDisableSandbox: true\`." ]
  [ "$sys" = 'read-only — probably the sandbox, path not checked' ]
}

@test "the no-target merge clause needs git's own partial-checkout error, not any refused write" {
  # The real probe, not stubbed (setup's hook_copy_tree copies the tracked
  # lib/ as is): the two cut fixtures under their own recorded commands, cwd
  # overridden to a writable scratch dir, onto which the probe joins the
  # mkdir fixture's relative path, so it reads writable.
  local text payload ctx sys cmd_mkdir cmd_busy

  # positive control: the git-mkdir fixture's own line is one of git's three
  # partial-checkout needles, so partial=1 leads the restore-them clause.
  cmd_mkdir='git -C /tmp/sl8c-wt checkout feat2 2>&1'
  text=$(cat "$FIXTURES/fire-readonly-path-git-mkdir.txt")
  payload=$(failure_payload "$text" | jq --arg c "$cmd_mkdir" \
    --arg d "$BATS_TEST_TMPDIR" '.tool_input.command = $c | .cwd = $d')
  run_hook "$payload"
  [ "$status" -eq 0 ]
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  sys=$(printf '%s' "$output" | jq -r '.systemMessage')
  [ "$sys" = 'read-only — sandbox allowlist, writable outside' ]
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$ctx" = "\`$BATS_TEST_TMPDIR/newdir2\`"' is writable outside the sandbox, whose allowlist refused it. The merge or checkout left the files it wrote with HEAD unmoved, blocking a re-run: restore them from HEAD, then re-run the whole call with `dangerouslyDisableSandbox: true`.' ]

  # negative: the git-config-busy fixture's refusal is another write's own,
  # not one of git's three needles, so no restore clause leads even though
  # the recorded command's own checkout still gives merge=1. The verdict
  # must still fire, as the act alone: an empty hook output has no restore.
  # shellcheck disable=SC2016 # $WT is the recorded command's literal text
  cmd_busy='cd /Users/david/code/micro/micro && git checkout -q display-golden-tests && git branch -f softwrapcolumn2 swc2-rebuild && git branch -D swc2-rebuild && git tag -d DGT_FINAL && WT="/tmp/claude-1000/-Users-david-code-micro/e0c3e94a-77e1-4c01-9ced-db2811d297d7/scratchpad/verify-wt" && git worktree remove --force "$WT" && echo "=== final status ===" && git status --short && echo "clean-if-empty" && echo "=== branches ===" && git branch | cat'
  text=$(cat "$FIXTURES/fire-readonly-path-git-config-busy.txt")
  payload=$(failure_payload "$text" | jq --arg c "$cmd_busy" \
    --arg d "$BATS_TEST_TMPDIR" '.tool_input.command = $c | .cwd = $d')
  run_hook "$payload"
  [ "$status" -eq 0 ]
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  sys=$(printf '%s' "$output" | jq -r '.systemMessage')
  [ "$sys" = 'read-only — probably the sandbox, path not checked' ]
  [ "$ctx" = "The sandbox's write allowlist most likely refused this write. Re-run the whole call with \`dangerouslyDisableSandbox: true\`." ]
}

@test "every probe receives tool_input.command byte-exact" {
  # A stub probe records its own $@: a dropped or garbled third argument
  # records differently from the byte-exact command the hook must pass, and a
  # non-string tool_input.command, none at all, or a tool_input that is not
  # an object must read as empty rather than being dropped or silencing the
  # hook. The command holds a leading `-`, a newline, and the backslash
  # sequences `\n` and `\\` that `printf %b` would rewrite unless each
  # backslash is doubled as the cwd's are.
  local text recorded body cmd payload
  recorded="$BATS_TEST_TMPDIR/probe-readonly_path-args"
  # shellcheck disable=SC2016 # "$@" is literal, expanded when the stub runs
  body='probe_readonly_path() { cat >/dev/null; printf "[%s]" "$@" >'"$(printf '%q' "$recorded")"'; printf "%s\n" writable; }'
  stub_lib probes.sh "$body"
  text=$(cat "$FIXTURES/fire-readonly-path-cp-tmp.txt")
  cmd=$'-n a\\nb \\\\ c\nz'

  payload=$(failure_payload "$text" | jq --arg c "$cmd" '.tool_input.command = $c')
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ "$(cat "$recorded")" = "[false][/tmp/scratch][$cmd]" ]

  rm -f "$recorded"
  payload=$(failure_payload "$text" | jq '.tool_input.command = 42')
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ "$(cat "$recorded")" = '[false][/tmp/scratch][]' ]

  rm -f "$recorded"
  payload=$(failure_payload "$text" | jq 'del(.tool_input.command)')
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ "$(cat "$recorded")" = '[false][/tmp/scratch][]' ]

  rm -f "$recorded"
  payload=$(failure_payload "$text" | jq '.tool_input = "cp a /tmp/x"')
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  [ "$(cat "$recorded")" = '[false][/tmp/scratch][]' ]

  # A lock probe takes the same third argument: the hook passes it to every
  # probe, not to readonly-path's alone.
  recorded="$BATS_TEST_TMPDIR/probe-git_lock-args"
  # shellcheck disable=SC2016 # "$@" is literal, expanded when the stub runs
  body='probe_git_lock() { cat >/dev/null; printf "[%s]" "$@" >'"$(printf '%q' "$recorded")"'; printf "%s\n" mask; }'
  stub_lib probes.sh "$body"
  text=$(cat "$FIXTURES/fire-lock-add-commit.txt")
  payload=$(failure_payload "$text" | jq --arg c "$cmd" '.tool_input.command = $c')
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ "$(cat "$recorded")" = "[false][/tmp/scratch][$cmd]" ]
}

@test "tmpdir-unset flag policy survives BSD grep and sed" {
  local text payload bsd ctx sys
  text=$(cat "$FIXTURES/fire-tmpdir-unset-redirect.txt")
  payload=$(failure_payload "$text" true)

  bsd="$BATS_TEST_TMPDIR/bsdtools"
  make_bsd_stubs "$bsd" grep sed
  PATH="$bsd:$PATH" run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -n "$output" ] \
    || { echo "no verdict emitted under BSD stubs, flag true" >&2; return 1; }
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  printf '%s' "$ctx" | grep -qF '/tmp/claude/'
  sys=$(printf '%s' "$output" | jq -r '.systemMessage')
  # shellcheck disable=SC2016 # $TMPDIR is literal prose, not expansion
  [ "$sys" = '$TMPDIR — expanded empty, path collapsed to /' ]
}

# The sweeps below follow hook-locks.bats's "every lock fixture yields its
# verdict": a fixture whose first line is an Exit code line goes into a failure
# payload's error, any other into a success payload's tool_response.stdout;
# misses collect across every fixture and flag value into one string asserted
# empty, so one red names every broken fixture.

# flag_payload <text> [flag] — the payload for a fixture's text per the sweep
# rule above.
flag_payload() {
  case "$1" in
    "Exit code"*) failure_payload "$1" "${2:-}" ;;
    *)            post_payload "$1" "" "${2:-}" ;;
  esac
}

@test "every tmpdir-unset fixture is silent unflagged and fires flagged" {
  local f text payload sys flag misses="" count=0 expected
  # shellcheck disable=SC2016 # $TMPDIR is literal prose, not expansion
  expected='$TMPDIR — expanded empty, path collapsed to /'
  for f in "$FIXTURES"/fire-tmpdir-unset-*.txt; do
    count=$((count + 1))
    text=$(cat "$f")
    for flag in '' true; do
      payload=$(flag_payload "$text" "$flag")
      run_hook "$payload"
      if [ "$status" -ne 0 ]; then
        misses="${misses}$(basename "$f") (flag ${flag:-absent}): exit $status"$'\n'
        continue
      fi
      if [ -z "$flag" ]; then
        [ -z "$output" ] \
          || misses="${misses}$(basename "$f") (flag absent): not silent"$'\n'
      else
        sys=$(printf '%s' "$output" | jq -r '.systemMessage')
        [ "$sys" = "$expected" ] \
          || misses="${misses}$(basename "$f") (flag true): got '${sys}'"$'\n'
      fi
    done
  done
  [ "$count" -gt 0 ]
  [ -z "$misses" ] || { printf '%s' "$misses" >&2; return 1; }
}

@test "every readonly-path fixture fires unflagged with the probe and is silent flagged without it" {
  # The stub answers writable, so the unflagged run must reach it; the flagged
  # run is silent and must not.
  local f text payload sys flag misses="" count=0 expected
  expected='read-only — sandbox allowlist, writable outside'
  stub_probe readonly_path writable
  for f in "$FIXTURES"/fire-readonly-path-*.txt; do
    count=$((count + 1))
    text=$(cat "$f")
    for flag in '' true; do
      payload=$(flag_payload "$text" "$flag")
      rm -f "$PROBE_CALLED"
      run_hook "$payload"
      if [ "$status" -ne 0 ]; then
        misses="${misses}$(basename "$f") (flag ${flag:-absent}): exit $status"$'\n'
        continue
      fi
      if [ -z "$flag" ]; then
        [ -f "$PROBE_CALLED" ] \
          || misses="${misses}$(basename "$f") (flag absent): probe not reached"$'\n'
        sys=$(printf '%s' "$output" | jq -r '.systemMessage')
        [ "$sys" = "$expected" ] \
          || misses="${misses}$(basename "$f") (flag absent): got '${sys}'"$'\n'
      else
        [ ! -f "$PROBE_CALLED" ] \
          || misses="${misses}$(basename "$f") (flag true): probe reached"$'\n'
        [ -z "$output" ] \
          || misses="${misses}$(basename "$f") (flag true): not silent"$'\n'
      fi
    done
  done
  [ "$count" -gt 0 ]
  [ -z "$misses" ] || { printf '%s' "$misses" >&2; return 1; }
}

@test "dangerouslyDisableSandbox as the string true reads as false" {
  # FR-5: only the boolean true counts. The same text fires with the boolean
  # and is silent with the string, which the tmpdir-unset policy reads as an
  # unflagged call.
  local text payload sys
  text=$(cat "$FIXTURES/fire-tmpdir-unset-redirect.txt")

  payload=$(failure_payload "$text" true)
  run_hook "$payload"
  [ "$status" -eq 0 ]
  sys=$(printf '%s' "$output" | jq -r '.systemMessage')
  # shellcheck disable=SC2016 # $TMPDIR is literal prose, not expansion
  [ "$sys" = '$TMPDIR — expanded empty, path collapsed to /' ]

  payload=$(failure_payload "$text" | jq \
    '.tool_input.dangerouslyDisableSandbox = "true"')
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
