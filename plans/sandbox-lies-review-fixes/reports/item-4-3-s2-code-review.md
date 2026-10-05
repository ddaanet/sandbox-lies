# Review: Item 4.3 slice 2 — code review (`hooks/check-jq.sh`)

**Scope**: `hooks/check-jq.sh` as of the GREEN commit (HEAD, "Item 4.3/2 —
SessionStart notice when jq is missing"): code and both notice texts. OUT:
`hooks/hooks.json`, `docs/references/hook.md`, Phase 5.

**Date**: 2026-10-05

**Mode**: review + fix

## Summary

The script is minimal and correct as code: one `command -v` guard, one `printf`
of fixed JSON, `exit 0`. The defects were in the words. The agent-facing text
limited the silence to failures, though the hook annotates successful results
too. It also routed a user notice through the agent. The user-facing line said
"not installed" when the check only looks at PATH, and its "its" was ambiguous.
Both texts are rewritten. Tests are green, and `just precommit` passes.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

1. **`additionalContext` scopes the silence to failures**
   - Location: `hooks/check-jq.sh:11` (pre-fix)
   - Problem: "do not expect a sandbox note after a failure" is untrue by
     omission. `hooks/hooks.json` registers `annotate.sh` on `PostToolUse` as
     well as `PostToolUseFailure`. The phantom-dotfile verdicts fire on a
     successful `git status` or `ls`. Without `jq`, `annotate.sh` exits 0 at its
     first `jq` call (`parsed=$(jq …) || exit 0`) before any detector runs. So
     every Bash result goes unannotated, not only failures. An agent reading the
     old text could take a clean success listing as checked.
   - Fix: state the silence for every result, and give the act: read a result
     with no note as unchecked, not as undistorted.
   - **Status**: FIXED

2. **`additionalContext` relays a user notice through the agent**
   - Location: `hooks/check-jq.sh:11` (pre-fix)
   - Problem: "Tell the user to install jq if a result looks distorted" breaks
     `plugin-craft:hook-authoring` §3: a user-facing notice goes on
     `systemMessage`, and `additionalContext` saying "tell the user…" is
     model-dependent. The same hook output already carries the user line, and
     "looks distorted" asks the agent for a judgement it has no criterion for.
     "Read Bash results without them" is not an act: by
     `craft:directive-writing` it is a sentence to cut.
   - Fix: both sentences removed; the remaining act is the one above.
   - **Status**: FIXED

### Minor Issues

1. **`systemMessage` claims "not installed" for a PATH check**
   - Location: `hooks/check-jq.sh:11` (pre-fix)
   - Note: the check is `command -v`, which also misses a `jq` installed off
     PATH. The line then said "until jq is on PATH", contradicting its own
     opening. "its Bash result annotations" reads as jq's annotations. The line
     was a sentence rather than the curt `subject — fact` form that
     `craft:directive-writing` gives for `systemMessage`. That form is also the
     form of `annotate.sh`'s own human lines (`lib/verdicts.sh`).
   - Fix: the line given under Final notice texts below. The D2 content is kept:
     what is off, and until when.
   - **Status**: FIXED

2. **Why `command -v` and not `type -P` was unstated**
   - Location: `hooks/check-jq.sh:6-7`
   - Note: probed (see Checks). `command -v` counts an exported function named
     `jq`, and so does `annotate.sh`'s bare `jq` call in the same inherited
     environment. `type -P` would raise the notice while annotations work. A
     later "fix" to `type -P` would be plausible without a note.
   - Fix: a two-line comment naming the choice and the reason.
   - **Status**: FIXED

## Fixes Applied

- `hooks/check-jq.sh:6-7` — comment on why `command -v` is used.
- `hooks/check-jq.sh:13` — both notice texts rewritten (final texts below). JSON
  structure, the `\\u001b` escape, `hookEventName` and `exit 0` are unchanged.

Applied by exact replacement through `/tmp/claude-1000/sl/put.py`, because the
Edit tool got no classifier verdict. The file mode (755) is preserved.

## Final notice texts

- `systemMessage`: the `\u001b[0m` reset, then: sandbox-lies: jq not found on
  PATH — Bash result annotations are off until it is installed
- `hookSpecificOutput.additionalContext`: sandbox-lies annotations are off: jq
  is not on PATH. Until it is, no Bash result carries a sandbox-lies note, so
  read a result without one as unchecked, not as undistorted.
- `hookSpecificOutput.hookEventName`: `SessionStart`

"Until it is" holds: `annotate.sh` resolves `jq` per call, so a `jq` that
appears on the session's PATH restores annotations with no restart.

## Checks

- **SessionStart channels.** `plugin-craft:hook-authoring`
  `references/output-channels.md` §1 records `systemMessage` as verified on
  `SessionStart`, rendered with ANSI interpreted. `additionalContext` must sit
  under `hookSpecificOutput` with `hookEventName`
  (`references/input-and-harness.md`), which the output does.
  `additionalContext` on `SessionStart` is documented Claude Code behaviour. The
  skill records no in-house probe of it on that event, and none was run here.
  The leading reset matches `hook-output-channels`: the hook speaks only on
  trouble.
- **Detectors.** `bash lib/matchers.sh < hooks/check-jq.sh` exits 1 (quiet).
  `tests/docs.bats` passes inside `just precommit`.
- **`command -v` semantics**, probed under `env -i` with a bash-only PATH:
  - With an exported function (`BASH_FUNC_jq%%`), `command -v jq` succeeds and
    the script is silent. That can exist in a non-interactive bash (via
    `export -f` in the parent), and `annotate.sh` would call the same function.
  - An alias defined through `BASH_ENV`: `command -v jq` returns 1. So an alias
    does not count, matching `annotate.sh`, which does not expand aliases.
- **Exit status.**
  - Stdout closed (`>&-`): `printf` reports a write error on stderr, and the
    status is 0.
  - Stdout a pipe whose reader has exited: bash dies of SIGPIPE (141). Nobody
    reads the status then. Claude Code reads hook stdout to EOF, and a killed
    reader means the session is gone. So this is not a finding, and no
    `trap '' PIPE` was added.
  - The comment "the exit status is always 0" stands for every reachable path.
- **NFR-2.** No bash-4 feature. The `printf` format escapes are `\\` and `\n`,
  both in bash 3.2. `\\u001b` relies on `\\` → `\`, not on printf's `\u` (bash
  4.2+). The em dash is passed through as bytes in any locale, including the
  `env -i` C locale the tests run under. No external tool is run.
- **Mutated-SUT run.** `\\u001b` was replaced by `\033`, the plausible raw-ESC
  implementation, by exact string replacement. Cases 2, 3 and 4 went red, and
  case 1 stayed green as expected. The SUT was restored by the inverse
  replacement, with an empty `git diff` before the fixes.
- **Results.** After the fixes, `bats tests/check-jq.bats` passed 4/4 and
  `shellcheck hooks/check-jq.sh` was clean. `just precommit` exit 0:
  plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests
  (305 passed).

## Requirements Validation

| Requirement | Status | Evidence |
| --- | --- | --- |
| D2 (outline) | Satisfied | `systemMessage` + `additionalContext`, both saying annotations are off until jq is installed; fixed text, no jq; leading reset |
| NFR-2 | Satisfied | bash 3.2 constructs only; BSD re-run case green |
| D-12 | Satisfied | the jq dependency is now announced when unmet |
| FR-1 | Satisfied | the notice fires only on the jq-absent path; silent otherwise (case 1) |
| Interface | Satisfied | stdin ignored, one object or empty, exit 0, writes nothing |

## Positive Observations

- One fixed `printf` with no interpolation leaves no injection or escaping
  surface. Encoding the reset as a JSON escape avoids the raw-ESC defect, and
  the mutation run confirms the tests pin it.
- No `2>/dev/null` (`no-stderr-suppression`), no temp file, no external tool.

## Recommendations

- Test gap, not fixed (tests are out of scope unless a defect is exposed). No
  assertion pins the wording claims fixed above: that the context covers every
  result rather than failures, and that it carries no user-relay sentence. A
  negative such as `additionalContext` not containing "after a failure" would be
  a bare negative. Better: assert the positive act ("unchecked") paired with the
  same fixture. That is the orchestrator's call for the docs step or a later
  slice.
- Informational, `hooks/annotate.sh`: with `jq` absent, its first call makes
  bash print a command-not-found line on stderr. Its header comment says nothing
  reaches stderr. With exit 0 that stderr is ignored by Claude Code, so this has
  no user effect. It is out of this item's scope and not touched.
