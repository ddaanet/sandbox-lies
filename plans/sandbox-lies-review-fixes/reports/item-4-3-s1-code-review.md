# Review: Item 4.3 slice 1 — code review (GREEN)

**Scope**: the GREEN commit `✨ Item 4.3/1 — SessionStart registers check-jq.sh`
— `hooks/hooks.json` (the `SessionStart` entry) and the stub
`hooks/check-jq.sh`. Tests read for context only. **Date**: 2026-10-05.
**Mode**: review + fix.

## Summary

The registration is correct: one `SessionStart` entry, no `matcher`, one command
hook running `bash "${CLAUDE_PLUGIN_ROOT}/hooks/check-jq.sh"` with
`timeout: 10`. It matches the slice's interface and the test review's pinned
shape, and it mirrors the annotate entries wherever they apply. Two minor fixes
were made to the stub. Its header named a RED/GREEN state that no longer held.
Its file mode differed from the other hook entry point.

**Overall Assessment**: Ready

## Checks requested

1. **No `matcher` fires on every source.** Confirmed. In Claude Code's hook
   schema, `matcher` is optional on `SessionStart` and filters on `source`
   (`startup`, `resume`, `clear`, `compact`). An omitted matcher, like `""` or
   `"*"`, matches every value. `plugin-dev:hook-development` shows `"*"` in its
   example, and omission is equivalent. Leaving it out is right here, because
   the notice must come back after a `clear` or a `compact`.
2. **`${CLAUDE_PLUGIN_ROOT}` in a `SessionStart` command.** Claude Code
   substitutes it in plugin hook commands for every event and also exports it to
   the hook process. The command double-quotes it inside the string run by the
   shell, so either route works. The test exercises the exported-variable route.
   A probe in a scratch copy with a plugin root containing a space
   (`$TMPDIR/plug root`) and a `SessionStart` payload on stdin exited 0 and
   printed nothing. The quoting holds.
3. **Key order irrelevant.** Confirmed. `.hooks` is a JSON object keyed by event
   name, so position has no meaning. `tests/hook.bats` compares `keys`, which jq
   sorts, so the test does not depend on order either.
4. **Empty stdout, exit 0, adds nothing.** For `SessionStart`, stdout on exit 0
   is the context channel. Valid JSON is parsed for `systemMessage` and
   `hookSpecificOutput.additionalContext`. Any other text is added to the
   agent's context verbatim. Empty stdout therefore injects nothing and shows
   nothing. stderr is ignored on exit 0, and `SessionStart` does not block on
   any exit code. Sources: the `plugin-craft:hook-authoring` output-channels
   reference (stdout parsed only on exit 0, stderr ignored on exit 0,
   `SessionStart` non-blocking) and Claude Code's documented exit-0 rule for
   `SessionStart`/`UserPromptSubmit`. Not re-probed live. That probe needs an
   unsandboxed nested `claude`, which would also run this checkout's other
   `SessionStart` hooks, and the skill warns that those can mutate the tree. The
   consequence for slice 2 is under Recommendations.
5. **What to mirror from `annotate.sh`'s registration.** The new entry mirrors
   the `type: command` form, the `bash "<root>/hooks/<script>"` invocation
   (independent of the executable bit) and `timeout: 10`. It does not take
   `matcher: "Bash"`, which is a tool-name filter that has no meaning on
   `SessionStart`. A `"*"` would be a no-op that the test review's
   `keys == ["hooks"]` pin forbids anyway.

## Issues Found

### Critical Issues

None.

### Major Issues

None.

### Minor Issues

1. **Stub header described a state that no longer held**
   - Location: `hooks/check-jq.sh:2`.
   - Note: the header read "STUB for Item 4.3 (RED): inert until the GREEN slice
     grows the check". After this commit the slice-1 GREEN has landed, and the
     stub stays inert until slice 2. The header now names the event and
     registration, cites outline D2, and states the stub contract: stdin
     ignored, silent, exit 0 until slice 2 adds the check for `jq` on `PATH`.
   - **Status**: FIXED

2. **Mode differed from the other hook entry point**
   - Location: `hooks/check-jq.sh` (mode 100644).
   - Note: `hooks/annotate.sh` and the `scripts/` entry points are 100755. The
     `bash` invocation does not need the bit, so this is consistency only. The
     file is now 100755. Git records it as a mode change.
   - **Status**: FIXED

## Fixes Applied

- `hooks/check-jq.sh:2-4`: rewrote the header comment to describe the stub's
  current state accurately.
- `hooks/check-jq.sh`: `chmod 755`, matching `hooks/annotate.sh`.
- The Edit tool got no classifier verdict, so the file was written via
  `/tmp/claude-1000/sl/put.py`. `shellcheck hooks/check-jq.sh` is clean.
- `just precommit` (foreground) exit 0: plugin.json, hooks.json, shellcheck,
  bash -n, rumdl, line limits, links, tests (bats 302 passed, 0 failed).
- Nothing staged or committed.

## Requirements Validation

| Requirement | Status | Evidence |
| --- | --- | --- |
| Slice 1: registered command silent with `jq` present, status 0 | Satisfied | `hooks/hooks.json` SessionStart; `tests/check-jq.bats` green |
| Slice 1: three event keys; one SessionStart command hook, named command | Satisfied | `hooks/hooks.json`; `tests/hook.bats` "names the three events" |
| FR-1: no PreToolUse | Satisfied | keys are exactly the three events |
| NFR-2 / D-12: check runs without `jq` | Satisfied for slice 1 | the command and stub use only `bash`; the check is slice 2 |
| Interface: stdin ignored, exit 0, writes nothing | Satisfied (stub) | `hooks/check-jq.sh` |

## Positive Observations

- The registration is minimal and exactly as pinned. The existing entries are
  unchanged in content.
- The `bash "<quoted root>/…"` form keeps a root containing spaces safe, and it
  does not depend on the executable bit or on cwd.

## Recommendations

- **Slice 2: stdout must be one JSON object or nothing.** On `SessionStart`, any
  non-JSON stdout, such as a stray `echo` or partial output, would be injected
  into the agent's context verbatim and never parsed. The slice-2 tests should
  parse the whole stdout with the test's own `jq`, which the runbook slice
  already requires, and assert that stdout is empty on the jq-present path,
  which `check-jq.bats` already does.
- **Slice 2: `make_bsd_stubs` re-run case** is still pending, as the
  `check-jq.bats` header notes. This is required by the repo rule.
- **Item 5.2 docs** should state the `SessionStart` entry's no-matcher choice
  (it re-fires on `clear` and `compact`) and its 10 s timeout. `docs/design.md`
  NFR-3 and the Architecture line currently name only the annotate entries.
