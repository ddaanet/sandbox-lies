# Review: end-of-build gate, group `code-tests`

**Scope**: `git diff 72e34d7 -- lib hooks tests`, without the justfile and
`tests/corpus-eval.py` (Phase 4, a separate dispatch). That covers
`lib/probes.sh` (`probe_resume_lost`), `lib/verdicts.sh`
(`verdict_resume_lost`), `lib/probes-readonly-command.sh` (the readfile skip),
`hooks/annotate.sh`, and the tests and helpers changed since the baseline.

**Date**: 2026-10-08

**Mode**: review + fix. Nothing committed.

**Counts**: Critical 0 · Major 1 · Minor 4. All five are FIXED.

## Summary

The implementation matches the outline's decisions:

- D-a: the transcript probe, with `unknown` added by the Slice A code review.
- D-b, Q2: the `found` verdict.
- Q1: no flag policy for resume-lost.
- Q4: the glob and `$` skip.
- Q5: BSD-stub cases on seven suites. The `hook-verdicts` skip is justified
  in `phase-3-review.md`.

The Slice A mutations went red on 9 of 10 behaviours. One survived: when `sed`
fails after printing some ids, the probe must discard that partial output.
With the discard removed, a partial extraction checks only the printed ids and
can print `found` for an id it never tested, and every test stayed green. A new
test now goes red under that mutation. The other gap was the verdict row table:
it had no row for the new `found` outcome, so the length, separator and
quietness checks never ran over that text. The rest are comment fixes.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

1. **No test pinned the discard of partial `sed` output**
   - Location: `lib/probes.sh` `probe_resume_lost`, `ids=$(LC_ALL=C sed …) || ids=`.
   - Problem: mutation A2 (`|| ids=` → `|| :`) survived the whole of
     `probes-resume.bats`. The "no id extracted" case uses a stub that prints
     nothing to stdout, so `ids` is empty whether or not the discard is there.
     Without the discard, a `sed` that prints `ID_1` and then fails (BSD at an
     invalid byte) leaves the probe testing `ID_1` alone. It then prints
     `found`, the claim the `unknown` outcome exists to prevent.
   - Fix: added "a sed failing after printing an id is unknown". The stub
     prints `ID_1` on stdout, writes an error to stderr and exits 1. Only
     `ID_1` has a transcript. The case expects `unknown`, with the stub's
     stderr passed through.
   - **Status**: FIXED. Under A2 the case fails on `[ "$output" = unknown ]`.
     With the code unchanged, it passes.

### Minor Issues

1. **The verdict row table had no `resume_lost found` row**
   - Location: `tests/helpers/verdicts.bash` `rows()`. Its header says "one row
     per verdict and outcome".
   - Problem: "verdicts under 400 chars" and "verdict text is quiet" iterate
     the rows. The `found` text was checked only by its exact-text case, never
     for length, the ` — ` separator or self-quietness. The Slice B test review
     noted this and left it.
   - **Status**: FIXED. Added the row. Mutation B1 (the human line's ` — `
     became `:`) made "verdicts under 400 chars" fail at its separator
     assertion. Restored, and `verdicts.bats` passes 10 of 10.
2. **A stale comment in the probe's BSD case**
   - Location: `tests/probes-resume.bats`, "found survives BSD …".
   - Note: it said a GNU-ism leaving no ids gives "a lost default". Since the
     Slice A code review, no ids gives `unknown`.
   - **Status**: FIXED. The comment is reworded.
3. **The test file header listed only `lost` and `found`**
   - Location: `tests/probes-resume.bats:2-5`.
   - **Status**: FIXED. The header now names `unknown` and its two causes.
4. **Two comments promised more than the code does**
   - `lib/probes-readonly-command.sh`: the comment said a candidate is skipped
     as "a glob or an expansion". The code skips only `*`, `?`, `[` and `$`. A
     backtick substitution still becomes the candidate: `` cat `date`.log ``
     gives `` readfile=`date`.log ``, checked by hand. That gap predates this
     job. `readonly-path.md` covers it under "the scan does not parse …
     backticks". So only the comment is fixed, which now says backticks are
     not skipped.
   - `hooks/annotate.sh:12-16`: the stderr exception named only `stat` and the
     holder tool. `probe_resume_lost`'s `sed` stderr also passes through, by
     design: the "no id extracted" case asserts it. The comment now names it.
   - **Status**: FIXED.

## Fixes Applied

- `tests/probes-resume.bats`: one new case, plus the two comment fixes (Minor
  2 and 3).
- `tests/helpers/verdicts.bash`: added the `resume_lost found` row.
- `lib/probes-readonly-command.sh:136-139`: the comment scopes the skip to a
  `$` expansion and states that backticks are not skipped.
- `hooks/annotate.sh:12-16`: the stderr exception names
  `probe_resume_lost`'s `sed`.

`git diff --stat` also lists `skills/sandbox-lies/SKILL.md`,
`references/escapes-and-costs.md` and `references/excluded-commands.md`. This
dispatch did not touch them: another session made those edits, and I left
them alone. `lib/probes.sh` and `lib/verdicts.sh` show no diff, so every
mutation was restored.

## Mutation table

Every mutation replaced one exact string that occurs once in the file, using a
script that refuses any other count. `command grep -cF` returned 1 after each
mutation and 0 after each restore. Each restore applied the same replacement
with the strings swapped, and the case passed again. Only the named case or
file ran, one process at a time, in the foreground.

| Behaviour | Mutation | Result |
| --- | --- | --- |
| A1 `unknown` when no id is extracted | `if [ -z "$root" ] \|\| [ -z "$ids" ]; then` → `if [ -z "$root" ]; then` | red: "no id extracted is unknown" at `[ "$output" = unknown ]` (output was `lost`) |
| A2 partial `sed` output discarded on failure | `        \|\| ids=` → `        \|\| :` | survived all 16 cases; fixed by the new case "a sed failing after printing an id is unknown", which then went red at `[ "$output" = unknown ]` |
| A3 `HOME` unset or empty under `set -u` | `root=${HOME:+$HOME/.claude}` → `root=${HOME-}/.claude` | red: "HOME and CLAUDE_CONFIG_DIR both unset is unknown" at `[ "$output" = unknown ]`; also red through the hook, "no config root to search, silent", at `[ -z "$output" ]` |
| A4 empty `CLAUDE_CONFIG_DIR` is not the fallback | `if [ "${CLAUDE_CONFIG_DIR+set}" = set ]; then` → `if [ -n "${CLAUDE_CONFIG_DIR-}" ]; then` | red: "CLAUDE_CONFIG_DIR set but empty is unknown" at `[ "$output" = unknown ]` |
| A5 empty-root guard | `if [ -z "$root" ] \|\| [ -z "$ids" ]; then` → `if [ -z "$ids" ]; then` | red: both "both unset is unknown" and "set but empty is unknown" at `[ "$output" = unknown ]` |
| A6 `failglob` unset inside the probe | `    shopt -u failglob` → `    : shopt -u failglob` | red: "a caller's failglob does not abort the glob" at `[ "$status" -eq 0 ]` |
| A7 hook wiring of `lost` | `\|\| verdict=lost` → `\|\| verdict=Lost` | red: `hook-resume.bats` "no transcript, today's verdict" at its "no verdict emitted" assertion |
| A8 BSD re-run (hook and probe) | `ids=$(LC_ALL=C sed -nE \` → `ids=$(LC_ALL=C sed --regexp-extended -n \` (the BSD stub refuses long options) | red: hook BSD case at `[ "$output" = "$plain" ]`; probe BSD case at `[ "$output" = found ]` |
| A9 `LC_ALL=C` on `sed` | `ids=$(LC_ALL=C sed -nE \` → `ids=$(sed -nE \` | red: "an invalid byte under a UTF-8 locale" at `[ "$output" = lost ]` |
| A10 per-id `hit` reset (a branch added in GREEN, not named in RED) | `        hit=` → `        hit=${hit-}` | red: "one id without a transcript is lost" at `[ "$output" = lost ]` |
| B1 `found` row in the verdict table (new) | `'--resume — transcript exists, not the sandbox'` → `'--resume: transcript exists, not the sandbox'` | red: "verdicts under 400 chars" at the ` — ` assertion |

Not mutated:

- **The subshell body of `probe_resume_lost`.** Switching `( … )` to `{ … }`
  takes two replacements. The only effect would be `shopt -u failglob` leaking
  to the caller. The hook calls the probe inside `$( … )`, so no production
  caller could see that leak, and no test could fail on it. A6 already covers
  `failglob` inside the probe.
- **Slice B.** Every Slice B test that `item-1-1-sB-red.md` does not show red
  was mutation-proven under the rule in `item-1-1-sB-code-review.md`. The flag
  gate (M3) red all four flag-true cases. M7 and M8 red the second-only and
  first-only partials under both flag values. That covers the fixtures split
  by the test review. The found text was red in RED, and the test review's N1
  and N2 near-miss mutations also red it. `tests/hook-resume.bats` has not
  changed since 7fb5960. The only later edits to `lib/probes.sh` and
  `hooks/annotate.sh` are comments. So that evidence still applies.
- **Item 2.1 and Phase 3.** As the dispatch instructed, these were reviewed
  for correctness and consistency only, not re-mutated.

## Wrong-reason hunt, per test

- **"a sed failing after printing an id is unknown"** (new).
  - Fails when the probe keeps partial output (prints `found`) or does not map
    a failure to `unknown`.
  - Could anything else produce `unknown`? An empty root could, but
    `CLAUDE_CONFIG_DIR` is set and its `projects/-p` exists.
- **"no config root to search, silent"** (hook). It is a bare negative.
  - Its positive twin is "no transcript, today's verdict": the same text with
    a root present.
  - A3 shows it fails when the probe invents a root under an unset `HOME`.
- **The hook BSD case.** Under A8 it fails on the `sed` refusal merged into
  `$output`. If that stderr were silenced, `[ -n "$output" ]` would still
  fail, because a probe with no ids prints `unknown` and the hook stays
  silent.
- **A5's reds** rest on the host having no `/projects/*/<id>.jsonl`. If one
  existed, the output would be `found`, which still fails `= unknown`, so the
  case fails either way.

## Correctness and consistency (Item 2.1, Phase 3, wiring)

- **The readfile skip** (`*[*?[\$]*` on `${word##*<}`) matches Q4, and every
  test the outline asked for is present. Each negative is paired with a
  positive that has the same shape but no metacharacter. The bracket
  expression is literal under bash 3.2. A glob ahead of a glued `<` correctly
  keeps the redirected name.
- **Phase 3:**
  - The Major 1 pair, the m-14 guard and the m-16 spy are present as the
    outline specifies.
  - The "shared by" lists in `tests/helpers/probes.bash` and `hook.bash` match
    a whole-tree grep, including the `hold_lock` setup and teardown claim.
  - Each of the seven BSD re-runs reuses its plain case's body. A
    `PATH=… func` prefix is temporary and exported for the call under
    non-POSIX bash.
- **Hook gate:** `resume-lost` is out of the flag `case` statement, and the
  comment states that it has no policy (Q1).
- **No new `2>/dev/null`** in `lib`, `hooks` or `tests`. Every changed bats
  file loads `helpers/bsd-stubs`.
- **The probe:** it is whitespace-safe, with the root quoted inside the glob.
  It needs nothing newer than bash 3.2, and its `sed -nE` and `[[:space:]]`
  work with BSD `sed`. It writes nothing (NFR-4): no here-string, no temporary
  file.

## Verification

- `shellcheck -x` passes, and `bash -n` passes on both edited scripts.
- Suites run after the fixes, each in the foreground, one at a time:
  - `probes-resume` 17/17
  - `verdicts` 10/10
  - `hook-resume` 10/10
  - `probes-readonly-globs` 12/12
  - `docs` 2/2
  - `verdicts-locks` 4/4

## Requirements Validation

| Requirement | Status | Evidence |
| --- | --- | --- |
| m-3 / D-a probe (`lost`, `found`, `unknown`) | Satisfied | `lib/probes.sh` `probe_resume_lost`; A1–A10 |
| m-3 / D-b `found` verdict (Q2) | Satisfied | `lib/verdicts.sh`; `verdicts.bats` exact text; B1 |
| Q1 no flag policy | Satisfied | `hooks/annotate.sh` gate; sB M3 |
| m-11 readfile skip (Q4) | Satisfied | `lib/probes-readonly-command.sh:236-239`; `probes-readonly-globs.bats` |
| Major 1 | Satisfied | `matchers-edges.bats` pair |
| m-14 | Satisfied | `hook-candidates.bats` `assert_no_git_above` |
| m-15, m-17 | Satisfied | helper comments match grep |
| m-16 | Satisfied | `check-jq.bats` mktemp spy |
| m-18 (Q5 rule) | Satisfied | 7 suites with a re-run case; `hook-verdicts` skip justified |

**Gaps:** none.
