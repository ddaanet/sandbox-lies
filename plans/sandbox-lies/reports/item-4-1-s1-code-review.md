# Review: Item 4.1 slice 1 — mask outcome through the hook (code review)

**Scope**: `hooks/annotate.sh`, `lib/verdicts.sh` as changed by the slice
commit "Item 4.1/1 — mask outcome through the hook". Tests, slices 2–9, Items
4.2/4.3 and `docs/` are out of scope.
**Date**: 2026-09-25
**Mode**: review + fix

## Summary

The slice adds the flag and cwd to the single jq call, splits them off in
bash, runs `probe_<name>` ahead of `verdict_<name>`, and fills the ten
git-lock/config-lock verdict branches. The wiring matches the Item 4.1
`hook → probe` interface. `mask` and `gone` text matches
`docs/references/lock-detectors.md` byte for byte for both detectors, and the
human lines match. Three robustness defects were found in the hook, each
reproduced against a scratch copy and fixed: a cwd with a newline corrupted the
split, a non-object `tool_input` dropped the whole payload, and an outcome
with no verdict text left a trailing separator in both output fields.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

1. **A cwd containing a newline corrupts the event/flag/cwd/text split**
   - Location: `hooks/annotate.sh:45` (jq `$cwd`), `:62` (bash split)
   - Problem: jq printed the cwd raw, so a cwd `"/a b\nc d"` was cut at its
     first newline. The probe received `/a b` as `$2`, and `c d` was
     prepended to the result text that `detect` and the probe read. The
     comment's claim that "the first three newlines are always the split
     points" held only for a newline-free cwd. Reproduced: the probe recorded
     `false|/a b`.
   - Fix: jq escapes the cwd reversibly (each `\` doubled, then each newline
     written `\n`, both with literal `split`/`join`, no regex). Bash decodes
     with `printf -v cwd '%b'`, which is builtin, bash ≥ 3.1 and writes no
     file. Verified round trips: `/a b⏎c d`, `/x\ny\\z` (literal backslashes),
     a trailing newline, and a non-string cwd (reads empty).
   - **Status**: FIXED

2. **An unknown or empty outcome leaves garbage in the output**
   - Location: `hooks/annotate.sh:106-113` (per-name loop)
   - Problem: a probe that prints nothing, or an outcome token the verdict's
     `case` does not list, makes the verdict print nothing and exit 0. With
     `out=""`, `para` and `line` are empty, and the join still ran:
     `human="${human:+$human }"` appended a trailing space, and the context
     gained a trailing newline. That happens whenever an earlier name emitted
     output. Reproduced with git-lock `mask` then config-lock printing
     nothing: `systemMessage` was `"index.lock — sandbox mask, not a real
     lock "` and `additionalContext` ended in `\n`. When no earlier name
     emitted anything, the hook stayed silent, which is correct.
   - Fix: `[ -n "$out" ] || continue` after the verdict call, so an outcome
     with no text contributes nothing.
   - **Status**: FIXED

### Minor Issues

1. **A non-object `tool_input` dropped the whole payload instead of reading
   the flag as false**
   - Location: `hooks/annotate.sh:43-44`
   - Problem: `.tool_input.dangerouslyDisableSandbox?` on a scalar or array
     `tool_input` yields *empty*, not null. `empty == true` is empty, so the
     `if` and everything piped after it produced nothing, and the hook went
     silent on a valid lock error. The jq call did not error, so FR-3 held.
     The comment, though, said "any other shape reads as false", and FR-5
     says an absent flag means false. Reproduced: `.tool_input = 42` gave no
     output.
   - Fix: `((.tool_input | objects | .dangerouslyDisableSandbox) // false) ==
     true`. `objects` matches the existing `.tool_response | objects` guard,
     and `// false` turns the empty into false. Comment updated. Verified:
     `42`, `[true]` and `{"dangerouslyDisableSandbox":"true"}` read `false`,
     and literal `true` reads `true`.
   - **Status**: FIXED

## Fixes Applied

- `hooks/annotate.sh:13-19` — header comment states the cwd escaping that
  makes the three-newline split hold.
- `hooks/annotate.sh:37-47` — flag expression uses `objects` and `// false`,
  with its comment corrected. The cwd is escaped with `split`/`join` in the
  same jq call, so there is still one jq process and no new failure path.
- `hooks/annotate.sh:64` — `printf -v cwd '%b' …` decodes the cwd.
- `hooks/annotate.sh:111-113` — skip a name whose verdict printed nothing.

`git diff --stat`: `hooks/annotate.sh | 25 +++++++++++++++----------`. The
file is 139 lines. `lib/verdicts.sh` is unchanged.

## Criteria checked with no finding

- **jq cannot error**: after the fixes, `not json`, `42`, `"s"`, `[1]`,
  `null`, and a failure payload with a numeric `error` each exit 0 with empty
  stdout and stderr. A non-boolean flag, a non-string cwd and a scalar
  `tool_input` all complete.
- **NFR-4**: no here-document, here-string or temp file. The probe and
  verdict get stdin through pipes. `printf -v` writes no file.
- **No blanket stderr suppression**: the diff adds no `2>/dev/null`. A
  probe's own stderr, such as the `stat` message in `_probe_lock_at`, passes
  through.
- **Probe failure**: a probe exiting non-zero hits `|| exit 0`, so there is
  no output. This follows the existing verdict-failure pattern.
- **Bash 3.2 / BSD**: `printf -v` (3.1+), `%b`, `declare -F`, `${var%%…}`.
  None depends on GNU tools. The `make_bsd_stubs grep sed` case passes.
- **Verdict text**: `verdict_git_lock` and `verdict_config_lock`, `mask` and
  `gone`, match lock-detectors.md exactly. The config-lock pair omits the
  `GIT_INDEX_FILE` clause, as the runbook requires. `held`/`orphan`/`unknown`
  keep the doc's literal `N`, which is slices 2–3 scope.

## Mutated-SUT run

Mutation, by exact string replacement in `hooks/annotate.sh`:
`probe_out=$(printf '%s\n' "$text" | "$probe_fn" "$flag" "$cwd") || exit 0`
→ `probe_out=mask`. That is the forbidden "verdict defaults to mask, no probe
call" implementation. Result of `bats tests/hook-locks.bats`: all three cases
went red (`not ok 1`, `not ok 2`, `not ok 3`). Restored by the inverse
replacement. `git diff` afterwards shows only the fixes above.

## Refactoring flag

None. No split or new abstraction is needed.

## Recommendations

- **Test coverage for the fixes (tests were out of scope here)**:
  - Slice 4 (`probe receives flag and cwd`) should add a cwd containing a
    newline and a backslash, recorded verbatim.
  - `tests/hook-malformed.bats` or slice 4 should add a lock payload with
    `tool_input` a scalar, expecting the verdict with flag `false`.
  - A case where a stub probe prints an unknown outcome after a verdict that
    did emit, expecting no trailing `; ` or space in `systemMessage` and no
    trailing newline in the context. Slice 9 changes the joiner, so this
    belongs there or before it.
- **Slice 2**: verdicts start reading stdin there. Until then the
  `printf … | "$fn"` pipe feeds a reader that does not read. This is harmless
  at this size and matches the existing `| detect` pattern.

## Precommit

`cd /Users/david/code/sandbox-lies && direnv exec . just precommit`, final
line:

```
precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests
```

It reported `bats: 135 passed, 0 failed`. Nothing was committed.
