# Review: Item 4.1 slices 4-6 — test review (batched)

**Scope**: the uncommitted additions to `tests/hook-locks.bats` (`git
diff`): `probe receives flag and cwd` (slice 4), `config-lock mask names
config.lock and update-config` (slice 5), `piped lock failure on a success
payload` (slice 6), plus the RED report `item-4-1-s4-red.md`. OUT:
implementation, docs, slices 7-9, Items 4.2/4.3.
**Date**: 2026-09-25
**Mode**: review + fix

## Summary

The three tests are correctly placed, reuse the file's helpers, and stub
every probe. Two of them could pass for the wrong reason. Slice 4's recorder
could not tell `"$flag" "$cwd"` apart from an extra argument or unquoted
(word-split) arguments. In slice 5, the `config.lock` grep could be satisfied
by the human line leaking into the context. Both are fixed and each fix is
proven by mutation. Slice 6 holds as written. After the fixes, slices 4 and
6 are proven by mutation and slice 5 reds genuinely on its `config.lock`
assertion.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

1. **Slice 4 recorder conflates argument splits**
   - Location: `tests/hook-locks.bats`, `probe receives flag and cwd`
   - Problem: the stub recorded `printf "%s %s\n" "$1" "$2"`. That output
     ignores `$3` and loses argument boundaries, and the `/x` cwd has no
     whitespace to split. Two mutations of `hooks/annotate.sh` line 96,
     applied against the unfixed test, both stayed **green**:
     - `"$probe_fn" "$flag" "$cwd" extra`
     - `"$probe_fn" $flag $cwd` (unquoted)

     Swapped arguments were already caught (`/x true`), as were a single
     joined argument (trailing space) and a dropped cwd. Nothing in the suite
     pinned the hook's cwd escape-and-decode round trip (`printf %b`, line
     64).
   - Fix: the recorder brackets every argument (`printf "[%s]" "$@"`), so
     the expected values are `[true][/x]` and `[false][/x]`. A third run
     sends the cwd `/a  b\c` (a run of spaces plus a backslash that `%b`
     would read as `\c` if the hook did not double it) and expects
     `[false][/a  b\c]`. A comment above the test says what it
     discriminates.
   - **Status**: FIXED

2. **Slice 5 `config.lock` grep satisfiable by the human line**
   - Location: `tests/hook-locks.bats`, `config-lock mask names config.lock
     and update-config`
   - Problem: the human line `config.lock — sandbox mask, not a real lock`
     names the file. A hook that let the human line into
     `additionalContext` would satisfy the `config.lock` grep without the
     paragraph naming the file. The mutation `para=${out%%"$nl"*}` →
     `para=$out` (annotate.sh line 114) turned today's red test **green**.
     So after GREEN, the assertion would not show that the paragraph names
     `config.lock`.
   - Fix: added `assert_lacks "$ctx" 'sandbox mask, not a real lock'` ahead
     of the two independent greps, with a one-line reason. Under the same
     mutation the test now reds on that guard. Unmutated, it still reds on
     the `config.lock` grep, which is the genuine slice 5 red.
   - **Status**: FIXED

### Minor Issues

None.

## Wrong-reason hunt (the dispatch's questions)

- **Slice 4.** Before the fix, the test distinguished swapped arguments but
  not an extra argument or a whitespace split (Major 1). After the fix it
  distinguishes all of them, and a missing `%b` decode too. The runbook's
  `true /x` / `false /x` pair holds as `[true][/x]` / `[false][/x]`. "Flag
  absent" really is absent: `tests/fixtures/payload-failure.json` has no
  `dangerouslyDisableSandbox`. Its fixture cwd `/tmp/scratch` differs from
  `/x`, so the payload cwd is what is being read.
- **Slice 5.** The two strings are asserted independently, one grep each.
  `[ -f "$PROBE_CALLED" ]` shows the probe was reached. The fixture fires
  only `config-lock` (checked with `detect`), so no real `probe_git_lock`
  runs on the host path. `update-config` appears only in the config-lock
  paragraphs, so it identifies the verdict. The remaining hole was the
  human-line leak (Major 2).
- **Slice 6.** The test runs as a `PostToolUse` success payload:
  `payload-post.json` has `hook_event_name: "PostToolUse"` and no `error`
  field. `post_payload` puts the text in `tool_response.stdout` and sets
  `stderr` to `""`, so the text can reach the hook by one route only. It
  would red if the hook read only the failure event. RED showed this with
  `PostToolUseX`. My own mutation removed `.stdout` from the PostToolUse
  branch, and the test redded on `[ -f "$PROBE_CALLED" ]`. The
  `GIT_INDEX_FILE` assertion also reds on its own (see below).
  `GIT_INDEX_FILE` does not appear in the human line, so the "another line
  satisfies it" shape does not apply. No change needed.

## Mechanical check

`direnv exec . bats tests/hook-locks.bats` (foreground), after the fixes:

```
1..10
ok 1 mask outcome through the hook
ok 2 mask paragraph is flag-neutral under flag true
ok 3 mask outcome through the hook under BSD stubs
ok 4 held interpolates the pid
ok 5 orphan and unknown interpolate size and age
ok 6 orphan with neither bytes nor age interpolates no empty value
ok 7 probe receives flag and cwd
not ok 8 config-lock mask names config.lock and update-config
# (in test file tests/hook-locks.bats, line 224)
#   `printf '%s' "$ctx" | grep -qF 'config.lock'' failed
ok 9 piped lock failure on a success payload
ok 10 orphan with one of bytes and age interpolates that one alone
```

Slice 5 fails on its assertion, not an error. Slices 4 and 6 pass unmutated
and are proven below.

## Mutation proof (reviewer's own mutations)

Each mutation below was an exact-string replace that must match exactly
once, run with `direnv exec . bats -f '<name>' tests/hook-locks.bats`, and
restored by the inverse replace.

| Slice | File: mutation | Red at |
|---|---|---|
| 4 | annotate.sh:96 `"$probe_fn" "$flag"` (cwd dropped) | `[ ... = '[true][/x]' ]` |
| 4 | annotate.sh:96 `... "$flag" "$cwd" extra` | `[ ... = '[true][/x]' ]` |
| 4 | annotate.sh:96 `... $flag $cwd` (unquoted) | `[ ... = '[false][/a  b\c]' ]` |
| 4 | annotate.sh:96 `... "$cwd" "$flag"` (swapped) | `[ ... = '[true][/x]' ]` |
| 4 | annotate.sh:64 `printf -v cwd '%s'` (no decode) | `[ ... = '[false][/a  b\c]' ]` |
| 5 | annotate.sh:114 `para=$out` (human line leaks) | `assert_lacks ... 'sandbox mask, not a real lock'` |
| 6 | annotate.sh:52 PostToolUse branch reads `.stderr` only | `[ -f "$PROBE_CALLED" ]` |
| 6 | verdicts.sh:32 git-lock `mask` paragraph without `GIT_INDEX_FILE` | `grep -qF 'GIT_INDEX_FILE'` |

Restore proof:

- `grep -nF` finds each original string at its line: annotate.sh 96
  (`"$probe_fn" "$flag" "$cwd")`), 64 (`printf -v cwd '%b'`), 114
  (`para=${out%%"$nl"*}`) and 52 (`(.stdout | strings), (.stderr |
  strings))`).
- `grep -cF` for all five annotate.sh mutant strings together → `0`.
- The `GIT_INDEX_FILE` clause in verdicts.sh counts `1`.
- `git diff --stat hooks/ lib/` is empty.
- The full suite gives the output above: 9 pass, and only slice 5 reds.

## Self-quiet

`direnv exec . bats tests/docs.bats` → `ok 1 no tracked file outside the
fixtures fires a detector`. The added strings are verdict text and a
synthetic cwd, and none is a diagnostic. `shellcheck tests/hook-locks.bats`
is clean. The file is 275 lines, under the 400-line cap.

## Fixes Applied

- `tests/hook-locks.bats`, `probe receives flag and cwd`:
  - The recorder brackets each argument (`printf "[%s]" "$@"`).
  - Expected values are now `[true][/x]` and `[false][/x]`.
  - Added a third run with the cwd `/a  b\c` (two spaces), which expects
    `[false][/a  b\c]`.
  - Added a comment saying what the test discriminates.
  - Updated the shellcheck disable reason.
- `tests/hook-locks.bats`, `config-lock mask names config.lock and
  update-config`: added `assert_lacks "$ctx" 'sandbox mask, not a real
  lock'` with a one-line reason, ahead of the two greps.
- Slice 6's test is unchanged.

## Requirements Validation

| Requirement | Status | Evidence |
|---|---|---|
| Slice 4: `true /x`; flag absent `false /x` | Satisfied | `[true][/x]`, `[false][/x]`, plus the spaced-cwd run |
| Slice 5: context contains `config.lock` and `update-config` | Satisfied (red until GREEN) | two independent greps, probe-reached check, human-line guard |
| Slice 6: `PostToolUse`, text in `tool_response.stdout`, context contains `GIT_INDEX_FILE` | Satisfied | `post_payload` stdout, mutation-proven |

## Positive Observations

- Every case stubs its probe, and the fixtures were checked to fire only
  their own detector, so no host path is touched.
- Slice 5's two greps are independent, and the RED report correctly notes
  that `update-config` goes unexercised only because the earlier grep
  aborts first.
- RED's mutation proofs were real exact-string round trips with grep
  restores.

## Recommendations (for GREEN, out of this review's scope)

- `tests/verdicts.bats` (around line 143) pins the config-lock `mask`
  paragraph verbatim. GREEN's edit, `The lock in this error` → ``The
  `config.lock` in this error``, must update that row in the same commit,
  or `verdicts.bats` goes red.
- The edited paragraph measures 368 characters, against 359 now. That is
  under FR-6's 400 and `verdicts under 400 chars`.
