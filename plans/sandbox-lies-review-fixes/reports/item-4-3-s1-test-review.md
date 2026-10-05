# Review: Item 4.3 slice 1 — test review (RED → GREEN)

**Scope**: `tests/check-jq.bats` (new), the `tests/hook.bats` case "hooks.json
names the three events", the RED report, and the stub `hooks/check-jq.sh` (stub
completion only). **Date**: 2026-10-05. **Mode**: review + fix.

## Summary

The RED tests are red on assertions and neither is vacuous. Two gaps are fixed.
The `check-jq.bats` case ran from the checkout, so it could not catch a script
that depends on its cwd. The `hook.bats` case left the `SessionStart` matcher
and timeout unpinned, so GREEN could choose them without any test noticing. Both
cases are still red on assertions.

**Overall Assessment**: Ready

## Mechanical first check

`bats tests/check-jq.bats tests/hook.bats` (foreground, after the fixes):

- `check-jq.bats` "jq present: the registered SessionStart command is silent":
  FAILED at the command-string guard (extracted value is `null`). This is an
  assertion failure, not an error.
- `hook.bats` "hooks.json names the three events": FAILED at
  `[ "$status" -eq 0 ]`. The `jq -e` filter evaluates to false (status 1)
  because the keys still name two events. This is not a jq parse error: the same
  filter passes against the candidate registration below.
- The other 12 `hook.bats` cases pass. The stub needed no completion: it is
  inert and nothing errors.

## Issues Found

### Major Issues

1. **SessionStart matcher and timeout unpinned**
   - Location: `tests/hook.bats` "hooks.json names the three events".
   - Problem: the case pinned the entry count, hook count, type and command, but
     not the matcher and not the timeout. GREEN could add `"matcher": "*"` (or
     `startup`, which would drop the re-check after a clear or a compact) or
     leave out the timeout, and the suite would stay green. Per the
     `plugin-dev:hook-development` schema, `matcher` is optional on
     `SessionStart` (sources: startup/resume/clear/compact) and `timeout` is
     optional (the command-hook default is 60 s). A SessionStart hook that
     stalls delays the session start. The two existing entries pin
     `timeout: 10`, and `docs/design.md` NFR-3 states "hook timeout 10 s",
     pinned by the `hooks.json` timeout. Leaving `SessionStart` unbounded
     departs from both.
   - Decision: no matcher, so the check fires on every start source. A clear or
     a compact drops the injected `additionalContext`, and re-firing restores
     it. `timeout == 10`, matching the annotate entries.
   - Fix: the case now asserts `.hooks.SessionStart[0] | keys == ["hooks"]` (no
     matcher),
     `.hooks.SessionStart[0].hooks[0] | keys == ["command", "timeout", "type"]`,
     and `.timeout == 10`. The comment states both choices. The two existing
     events are pinned exactly as before: `one()` is unchanged and the keys
     check only gains `SessionStart`.
   - **Status**: FIXED. The RED report's "No `timeout` pinned … GREEN may omit
     it" is superseded. GREEN registers `"timeout": 10` and no matcher.

2. **Command not run from a cwd outside the checkout**
   - Location: `tests/check-jq.bats`, the `run` line.
   - Problem: bats runs from wherever it is invoked, normally the checkout.
     Claude Code runs a hook with the session's project as cwd, not the plugin
     root. A script that reads `hooks/…` relative to cwd passed this test. Shown
     in a scratch copy: a stub that writes to stderr unless `hooks/check-jq.sh`
     exists relative to cwd stayed green without the `cd`.
   - Fix: `cd "$BATS_TEST_TMPDIR"` before `run`, with a comment naming how
     Claude Code runs the command. The same scratch mutant now reds at
     `[ -z "$stderr" ]`.
   - **Status**: FIXED

### Minor Issues

1. **`CLAUDE_PLUGIN_ROOT` carried a `..` segment**
   - Location: `tests/check-jq.bats:6`.
   - Note: `ROOT="${BATS_TEST_DIRNAME}/.."` gave the script a non-canonical
     root, unlike the absolute path Claude Code exports. It is now
     `ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"`, as `tests/shim.bats` does.
   - **Status**: FIXED

## Wrong-reason hunting

Each test, the state of the world that fails it, and what else could produce its
observable. Each candidate was probed in a scratch copy under `$TMPDIR`
(`hooks/ lib/ scripts/ tests/`, never the checkout), one variant at a time:

| Variant (scratch copy) | `check-jq.bats` | `hook.bats` case |
| --- | --- | --- |
| Candidate GREEN: one entry, no matcher, `timeout: 10`, inert script | green | green |
| `matcher: "*"` added | green | RED |
| `timeout` omitted | green | RED |
| `timeout: 60` | green | RED |
| two SessionStart entries | green | RED |
| script prints to stdout with `jq` present | RED | green |
| script writes to stderr | RED | green |
| script exits 1 | RED | green |
| script reads a cwd-relative path | RED | green |
| script file absent | RED | green |

- **Vacuous `null` / `bash -c ''`**: closed. The equality guard on the extracted
  string runs before `run`. An absent registration yields `null`, which fails
  the guard. A registered string pointing elsewhere also fails it. A missing
  script file reds (status 127, stderr).
- **Run as Claude Code runs it**: `bash -c` on the string read from the tracked
  `hooks.json`, with `CLAUDE_PLUGIN_ROOT` exported by `env`. Since the fix, it
  runs from a cwd outside the checkout with stdin at EOF (stdin is ignored per
  the interface).
- **Bare negative**: "silent with `jq` present" also passes for an inert script.
  Its pairing positive, the same command string with `jq` absent, is slice 2
  (scope OUT). Until slice 2 lands, this case is evidence of the registration
  and of the script being reached cleanly, not of the check. The test name
  claims only silence, which is accurate.
- **`jq` present precondition**: the test resolves the command with `jq` from
  the same `PATH`, so `jq` is on the `PATH` the script sees.

## Fixes Applied

- `tests/hook.bats` "hooks.json names the three events": added assertions that
  the SessionStart entry has keys `["hooks"]` (no matcher), that the hook has
  keys `["command","timeout","type"]`, and that `timeout == 10`. Rewrote the
  comment's matcher and timeout rationale.
- `tests/check-jq.bats`: canonical absolute `ROOT`; `cd "$BATS_TEST_TMPDIR"`
  before running the command, with a comment.
- `shellcheck -x tests/check-jq.bats tests/hook.bats hooks/check-jq.sh`: clean.
  Line counts: `check-jq.bats` 26, `hook.bats` 390 (cap 400).
- Edits went through a Python script under `/tmp/claude-1000/sl/` (the Edit tool
  got no classifier verdict). Scratch copies were removed. Nothing staged or
  committed.

## Requirements Validation

| Requirement | Status | Evidence |
| --- | --- | --- |
| Slice 1: registered command, `jq` present, silent, status 0 | Satisfied (red pending GREEN) | `tests/check-jq.bats` |
| Slice 1: three event keys; SessionStart one command hook with the named command | Satisfied (red pending GREEN) | `tests/hook.bats` case |
| FR-1: no PreToolUse | Satisfied | exact `keys` equality |
| NFR-3 timeout bound | Satisfied (added) | `timeout == 10` |
| bsd-stubs rule | Partial (scope OUT) | file loads `helpers/bsd-stubs`; the `make_bsd_stubs` re-run is slice 2 |

## Notes for GREEN

- Register `SessionStart` as one entry with no `matcher`, holding
  `{"type":"command","command":"bash \"${CLAUDE_PLUGIN_ROOT}/hooks/check-jq.sh\"","timeout":10}`.
- The script must not depend on cwd.
- `docs/design.md`'s Architecture line and NFR-3 name only the annotate entries.
  Item 5.2 / `docs/references/hook.md` should state the SessionStart timeout and
  the no-matcher choice (scope OUT here).

## Positive Observations

- The RED's command-string guard was already the right defence against a `null`
  or empty command.
- `--separate-stderr` keeps the stdout and stderr assertions distinct.
- The existing `one()` pinning of the two Bash events is untouched.
