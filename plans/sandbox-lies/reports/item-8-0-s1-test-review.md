# Review: Item 8.0 slice 1 test review — `lock verdicts word the re-run by the flag`

**Scope**: uncommitted changes to `tests/verdicts.bats` and
`tests/hook-locks.bats`, and `plans/sandbox-lies/reports/item-8-0-s1-red.md`.
`lib/` and `hooks/` were not edited.
**Date**: 2026-09-26T17:34:36Z
**Mode**: review + fix (test review)

## Summary

The RED tests fail against the unchanged SUT exactly as the report says. But
one test, the new `lock verdicts word the re-run by the flag`, could never pass.
It asserted "once no sandboxed command is running" for `orphan` and `unknown`
under flag true. lock-detectors.md's *Retry* column words those as "Retry the
command once", and the RED's own interpolation tests pin that wording too, so
no GREEN could satisfy both. That is fixed. Two smaller gaps in the hook-level
config-lock test are fixed as well. A spec-conforming GREEN, built in a
throwaway copy, turns all 25 tests in both files green.

**Overall Assessment**: Ready

## Mechanical first check

Both files were run against the unchanged SUT, before and after the fixes. The
same six tests fail each time, every one on an assertion. None errors on a
missing symbol and none passes by accident.

| Test | Result | Failing assertion (post-fix) |
|---|---|---|
| verdicts 8 `lock verdict text matches lock-detectors.md` | FAILED | line 253, git_lock mask false exact match |
| verdicts 9 `verdict_git_lock held\|orphan\|unknown interpolate probe values` | FAILED | line 330, orphan false exact match |
| verdicts 10 `verdict_config_lock held\|orphan\|unknown interpolate probe values` | FAILED | line 376, orphan false exact match |
| verdicts 11 `lock verdicts word the re-run by the flag` | FAILED | line 416, `text_lacks … 'once no sandboxed'` (mask false) |
| hook-locks 2 `mask paragraph words the re-run by the flag` | FAILED | line 81, `assert_lacks "$ctx_false" 'once no sandboxed'` |
| hook-locks 8 `config-lock mask names config.lock and the settings act by path` | FAILED | line 227, `assert_lacks "$ctx" 'update-config'` |

`verdicts.bats`: 8 pass, 4 fail. `hook-locks.bats`: 11 pass, 2 fail. The
tests that pass are the ones the RED report lists as unaffected.
`shellcheck -x` is clean on both files.

## Transcription check

Each exact-match string was checked against lock-detectors.md's flag table and
Verdicts lists. All of them match: git_lock mask (false and true), config_lock
mask (false and true), the config-lock settings act, and orphan and unknown on
both locks under both flags.

## Issues Found

### Critical Issues

1. **The new flag test demands flag-true wording the spec does not give to
   orphan and unknown**
   - Location: `tests/verdicts.bats`, `lock verdicts word the re-run by the
     flag`, flag-true branch.
   - Problem: the test used `grep -qF 'once no sandboxed command is running'`
     for every outcome under flag true. In lock-detectors.md that phrase is
     *Re-run* (mask only). *Retry* under true is "Retry the command once"
     (orphan and unknown). The interpolation tests in the same file pin
     `… Retry the command once; a second …` and `… Retry the command once.`, so
     no implementation could pass both. The runbook's "under flag true the
     reverse" reads more strictly than the spec. The brief says tests follow
     the docs, so the docs win.
   - Evidence: in a throwaway copy with a spec-conforming GREEN, the original
     line failed on its assertion (`grep -qF 'once no sandboxed command is
     running'`, orphan true). The fixed test passed.
   - Fix: the flag-true positive is now chosen per outcome. Mask expects
     `Re-run the same command once no sandboxed command is running`. Orphan and
     unknown expect `Retry the command once`. The negatives stay the same:
     each flag-true text must lack `dangerouslyDisableSandbox: true` and
     `if it already ran`. The comment now cites the flag table.
   - **Status**: FIXED

### Major Issues

1. **The hook-level test did not show that the hook passes the flag to
   `verdict_config_lock`**
   - Location: `tests/hook-locks.bats`, `config-lock mask names config.lock
     and the settings act by path`.
   - Problem: the slice requires `hooks/annotate.sh` to pass `"$flag"` to
     every probed verdict as `$2`. Only git-lock's mask test checked
     flag-specific wording. The config-lock test ran under both flags but
     asserted nothing that depends on the flag. A GREEN that forwarded the flag
     only for `git-lock` would have passed.
   - Evidence: in the throwaway copy, the hook was mutated to forward the flag
     only when `name = git-lock`. With the new assertion, hook-locks 8 fails on
     `grep -qF -- "$rerun"`. Without it, the whole file stayed green.
   - Fix: for the `.git/config.lock` path, each flag now asserts its *Re-run*
     wording is present and the other flag's wording is absent.
   - **Status**: FIXED

### Minor Issues

1. **A leftover marker file made a probe-called check pass without evidence**
   - Location: `tests/hook-locks.bats`, same test, top of the flag loop.
   - Problem: the first iteration's settings-path run leaves `$PROBE_CALLED`
     in place. In the second iteration, `[ -f "$PROBE_CALLED" ]` after the
     `.git/config.lock` run would pass even if the probe was never reached.
   - Fix: `rm -f "$PROBE_CALLED"` after `stub_probe_kv` at the top of each
     iteration.
   - **Status**: FIXED

2. **"Absent `$2` reads false" was checked for mask only**
   - Location: `tests/verdicts.bats`, `lock verdicts word the re-run by the
     flag`.
   - Problem: the new test checked the absent-flag case only for `mask`, and
     only by a positive grep. The slice asks for absent to read false for the
     verdict as a whole, which includes orphan and unknown.
   - Fix: inside the outcome loop, the text with no second argument must equal
     the explicit-false text, which the loop has just checked is non-empty and
     worded for false. The separate mask-only grep is gone.
   - Evidence: in the throwaway copy, a GREEN mutated so absent reads true
     fails this line (and the transcription test's git_lock mask equality).
   - **Status**: FIXED

## Coverage the slice names

| Slice clause | Covered by |
|---|---|
| both lock names, mask/orphan/unknown under both flags | verdicts 11 (positives and negatives, both names); verdicts 8–10 (exact text) |
| absent `$2` reads false | verdicts 11 (all three outcomes, both names); verdicts 8 (git_lock mask); rows with no flag in the 400-character and quiet tests |
| neither flag contains "if it already ran" | verdicts 11; hook-locks 2 |
| settings act by path, under either flag | verdicts 8 (exact text, both flags); verdicts 11 (update-config present with no Re-run, versus `.git/config.lock` with no update-config, both flags); hook-locks 8 (same pair through the hook) |
| 400-character and quiet tests cover every flag variant | rows() now includes mask, orphan and unknown at flag true for both locks; rows with no flag cover the false text |
| the hook passes the flag to the verdict | hook-locks 2 (git-lock mask); hook-locks 8 (config-lock mask, added in this review) |

Not raised: the settings-act text is not in `all_verdict_text`, so the quiet
and removal tests do not scan it. The slice limits those tests to flag
variants, and verdicts 8 pins the settings-act text exactly, so running it
through them adds nothing.

## Fixes Applied

- `tests/verdicts.bats` `lock verdicts word the re-run by the flag`: the
  flag-true positive is chosen per outcome (`true_wording`); the loop now
  checks absent against explicit false for each outcome; the comment was
  updated.
- `tests/hook-locks.bats` `config-lock mask names config.lock and the settings
  act by path`: flag-specific `$rerun` positive and `$other` negative for the
  `.git/config.lock` path, with a `SC2016` disable on the literal-backtick
  string; `rm -f "$PROBE_CALLED"` at the top of each iteration; the comment
  was updated.

## Post-fix per-test result against unchanged SUT

The same six tests fail on the same assertions as in the table above:
verdicts 8, 9, 10, 11 and hook-locks 2, 8. Everything else passes.

## Satisfiability check

The tracked files were copied to `$TMPDIR` and a minimal GREEN was written
there, following the spec: `_lock_rerun`/`_lock_retry` keyed on
`${2:-false}`/`${3:-false}`, the config-lock mask reads stdin and swaps in the
settings act for a `path=*/.claude/settings.json.lock` line, and the hook
passes `"$flag"` as `$2`. Both files ran 25/25 green. The copy was deleted
afterwards; the tracked `lib/` and `hooks/` were never edited.

## Requirements Validation

| Requirement | Status | Evidence |
|---|---|---|
| D-17 (verdict takes the flag; no condition the script can evaluate is left in the text) | Satisfied by tests | verdicts 8–11, hook-locks 2 and 8 |
| FR-4 (hook passes probe and flag through to the verdict) | Satisfied by tests | hook-locks 2 and 8 |
| FR-6 (verdict text transcribed from the spec) | Satisfied by tests | exact matches checked against lock-detectors.md |

## Positive Observations

- Each negative has a positive over the same text, and the settings-act pair
  differs only in the `path=` line.
- The RED report explains why the hook-level config-lock test had to change
  (GREEN cannot edit tests).
- The interpolation tests keep the out-of-order key=value input and the
  metacharacter path while adding the flag-true cases.
