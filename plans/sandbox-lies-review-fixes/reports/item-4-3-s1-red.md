# Item 4.3 slice 1 — RED

Files (uncommitted): `hooks/check-jq.sh` (inert stub, exit 0),
`tests/check-jq.bats` (new), `tests/hook.bats` (case extended and renamed).
`hooks/hooks.json` untouched.

## Per-test output

- `check-jq.bats` "jq present: the registered SessionStart command is
  silent": fails at `[ "$cmd" = 'bash "${CLAUDE_PLUGIN_ROOT}/hooks/check-jq.sh"' ]`
  (extracted command is `null`; the guard stops a vacuous `bash -c null`).
  An assertion failure, not an error.
- `hook.bats` "hooks.json names the three events" (was "names both events"):
  fails at `[ "$status" -eq 0 ]` after `jq -e` returns 1 (keys are still two
  events). Assertion failure.
- All other `hook.bats` cases pass (12 ok of 14 total).

## Choices

- No `matcher` on SessionStart: it is optional there (filters source
  startup/resume/clear/compact) and the check should run on every start.
  Not asserted in the test beyond comment; the entry is pinned by length and
  hook shape only.
- No `timeout` pinned: the script only tests for `jq`; default applies.
  Test does not assert a timeout, so GREEN may omit it.
- Case renamed to "hooks.json names the three events"; comment updated.
- `make_bsd_stubs` re-run case pending for slice 2 (noted in file header).
- shellcheck -x on the bats file and stub: clean (one SC2016 disable with
  reason, for the literal `${CLAUDE_PLUGIN_ROOT}` text).
