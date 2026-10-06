#!/usr/bin/env bash
# Loaded by every hook suite. Copies hooks/ and lib/ under $BATS_TEST_TMPDIR
# so a case can stub a copied lib file without touching the tracked source,
# and builds payload JSON from the Item 1.4 recorded fixtures with jq.
#
# stub_probe and stub_probe_kv (below) are shared by tests/hook-locks.bats
# and tests/hook-candidates.bats: any case that fires a probe-gated detector
# stubs its probe, so no fixture's absolute path reaches the host
# filesystem.

FIXTURES="${BATS_TEST_DIRNAME}/fixtures"

# hook_copy_tree — copies hooks/ and lib/ from beside this helper into
# $HOOK_COPY and sets that variable. annotate.sh sources the lib/ files
# beside its own path (never via CLAUDE_PLUGIN_ROOT), so the copy runs the
# copy's lib, not the tracked one.
hook_copy_tree() {
  local root="${BATS_TEST_DIRNAME}/.."
  HOOK_COPY="$BATS_TEST_TMPDIR/hook-copy"
  mkdir -p "$HOOK_COPY"
  cp -R "$root/hooks" "$HOOK_COPY/hooks"
  cp -R "$root/lib" "$HOOK_COPY/lib"
}

# failure_payload <text> [flag] — prints a PostToolUseFailure payload built
# from the Item 1.4 fixture, its `error` field replaced by <text> and, when
# [flag] is given (true|false), tool_input.dangerouslyDisableSandbox set to it.
failure_payload() {
  local text="$1" flag="${2:-}"
  if [ -n "$flag" ]; then
    jq --arg t "$text" --argjson f "$flag" \
      '.error = $t | .tool_input.dangerouslyDisableSandbox = $f' \
      "$FIXTURES/payload-failure.json"
  else
    jq --arg t "$text" '.error = $t' "$FIXTURES/payload-failure.json"
  fi
}

# post_payload <stdout> [stderr] [flag] — prints a PostToolUse payload built
# from the Item 1.4 fixture, its tool_response.stdout/stderr replaced and,
# when [flag] is given (true|false), the flag set as above.
post_payload() {
  local out="$1" err="${2:-}" flag="${3:-}"
  if [ -n "$flag" ]; then
    jq --arg o "$out" --arg e "$err" --argjson f "$flag" \
      '.tool_response.stdout = $o | .tool_response.stderr = $e
       | .tool_input.dangerouslyDisableSandbox = $f' \
      "$FIXTURES/payload-post.json"
  else
    jq --arg o "$out" --arg e "$err" \
      '.tool_response.stdout = $o | .tool_response.stderr = $e' \
      "$FIXTURES/payload-post.json"
  fi
}

# stub_lib <file> <body> — appends <body> to the copied lib file <file>
# (e.g. verdicts.sh, matchers.sh), overriding a function annotate.sh sources
# from the copy — a later definition wins in bash.
stub_lib() {
  local file="$1" body="$2"
  # A misnamed file would be created fresh and never sourced, leaving the
  # stub silently inert; an unset HOOK_COPY would aim at /lib.
  [ -f "${HOOK_COPY:?hook_copy_tree has not run}/lib/$file" ] || {
    printf 'stub_lib: no copied lib file %s\n' "$file" >&2
    return 1
  }
  printf '%s\n' "$body" >>"$HOOK_COPY/lib/$file"
}

# stub_probe <name> <outcome> — overrides probe_<name> in the copied
# lib/probes.sh with one that drains stdin, prints <outcome>, and touches
# $PROBE_CALLED. A case asserts that file exists: the real probe on a
# fixture's own path would also answer without being reached, so a stub the
# hook never reached would otherwise pass while the real probe stats the
# host path, and so would a verdict defaulting to an outcome with no probe
# call at all.
stub_probe() {
  local name="$1" outcome="$2" called
  PROBE_CALLED="$BATS_TEST_TMPDIR/probe-$name-called"
  called=$(printf '%q' "$PROBE_CALLED")
  stub_lib probes.sh "probe_${name}() { cat >/dev/null; : >${called}; printf '%s\\npath=stub\\n' '${outcome}'; }"
}

# stub_probe_kv <name> <outcome> [line...] — as stub_probe, printing each
# additional <line> after <outcome> instead of the fixed `path=stub`, so a
# case can feed probe key=value lines (pid=, bytes=, age=, path=) through the
# hook. Each line is %q-quoted into the stub, so it may carry any character.
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

# assert_lacks <haystack> <pattern> — <pattern> (fixed string) must not occur
# in <haystack>; a grep exit other than 1 (found, or errored) fails the
# assertion rather than reading as absence. Overwrites $status and $output.
assert_lacks() {
  run bash -c 'printf "%s" "$1" | grep -qF -- "$2"' _ "$1" "$2"
  # shellcheck disable=SC2154 # set by bats' run
  [ "$status" -eq 1 ]
}
