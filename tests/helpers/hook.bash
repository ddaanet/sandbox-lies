#!/usr/bin/env bash
# Loaded by every hook suite. Copies hooks/ and lib/ under $BATS_TEST_TMPDIR
# so a case can stub a copied lib file without touching the tracked source,
# and builds payload JSON from the Item 1.4 recorded fixtures with jq.

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
