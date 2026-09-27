# Item 8.0/5 test review — the no-target merge clause needs git's error

**Scope**: uncommitted test changes in `tests/probes-readonly-facts.bats`,
`tests/verdicts-readonly.bats`, `tests/hook-candidates.bats`, and
`reports/item-8-0-s5-red.md`. Implementation (`lib/`, `hooks/`) out of scope
except the restored mutation below.
**Date**: 2026-09-27
**Mode**: review + fix

## Summary

The three new-behaviour tests each red on an assertion against unchanged code,
and the guard test's mutation proof reproduces with a different mutation. Three
findings, all fixed in the tests: the hook test's negative half could pass on
an empty hook output, the guard test was a bare negative, and the probe test's
cases did not pin exit status, stderr or outcome. After the fixes the same three
tests still red on their behaviour assertions.

**Overall Assessment**: Ready

## Mechanical check (against unchanged `lib/`, `hooks/`)

| Test | How it redded | Assertion |
|---|---|---|
| `partial=1 fires with merge=1 for each of git's three partial-checkout errors, not for another tool's refusal` (probes-readonly-facts) | failed assertion; the unchanged probe never prints `partial=1` | `grep -qxF 'partial=1'` on the unlink case (line 218 after fixes) |
| `readonly-path merge alone with no partial=1 states the act alone, capitalised` (verdicts-readonly) | failed assertion; the unchanged verdict writes the restore-them clause for `merge=1` alone | `[ "$line1" = "$baseline1" ]` (line 133) |
| `the no-target merge clause needs git's own partial-checkout error, not any refused write` (hook-candidates) | failed assertion; the unchanged code gives the config-busy fixture a restore clause | before fixes: `run ! grep -qF 'restore'` (line 198); after fixes: the exact act-alone `ctx` equality (line 204) |
| `readonly-path merge with target, partial=1 and no match still states the act alone` (verdicts-readonly) | guard; green on unchanged code as the RED report states, so it rests on a mutation proof | reproduced below |

None passed and none errored. I also checked the RED report's side claim by
hand: the unchanged probe, given the third needle (git's directory-creation
error) under `just sync`, prints the outcome and `path=` but no `merge=1`, so
the mkdir case in the probe test would also red on its `merge=1` line.

## Reproduced mutation (guard test)

- Mutation, different from the RED report's (which flipped the `-n "$target"`
  guard): in `lib/verdicts.sh`'s stdin parse,
  `target=*) target=${line#target=} ;;` → `target=*) ;;`. That string is
  unique in the file, and the change drops every `target=` fact. The effect is
  the implementation the guard exists to rule out: `partial=1` with no visible
  target gets the restore-them clause.
- Filtered run of the guard test: `not ok`, failing at `[ "$line1" =
  "$baseline1" ]` (line 150, before this review's added positive).
- Restored by the inverse Edit (`target=*) ;;` →
  `target=*) target=${line#target=} ;;`). `command grep -cF 'target=*) ;;'
  lib/verdicts.sh` prints `0`, `git diff --stat -- lib hooks` is empty, and a
  filtered re-run gives 1 passed.

## Issues Found

### Major Issues

1. **Hook test's negative half passes on an empty or absent verdict**
   - Location: `tests/hook-candidates.bats`, the new test's config-busy half
     (was line 198).
   - Problem: the half asserted only `run ! grep -qF 'restore' <<<"$ctx"`. If
     the hook emitted nothing (a matcher or probe regression, or a GREEN that
     broke the nopath composition), `jq -r` would yield `null` or empty and the
     negative would pass. This is a bare negative. The positive half also
     checked only a substring and never pinned the outcome the brief says the
     fixture must read (`writable` through a relative path under the overridden
     cwd).
   - Fix: both halves now pin `systemMessage` (`writable` and `nopath`
     respectively) and the exact `additionalContext`. The positive expects
     `` `$BATS_TEST_TMPDIR/newdir2` `` followed by the restore-them clause. The
     negative expects the nopath sentence plus the capitalised act alone, so
     the verdict must fire, with no clause. This also pins the "act alone,
     capitalised" half of the spec through the hook.
   - **Status**: FIXED. It still reds against unchanged code, on the negative's
     exact `ctx` equality (line 204). The positive half passes on unchanged
     code, which confirms setup is not what causes the red.

### Minor Issues

1. **Guard test is a bare negative**
   - Location: `tests/verdicts-readonly.bats`,
     `readonly-path merge with target, partial=1 and no match still states the act alone`.
   - Problem: it compared the composition to the no-facts baseline with no
     positive over the same facts. It also left one composition unpinned:
     `merge=1 partial=1 target=… match=…`. That is the shape a real partial
     checkout gives when its target resolves. A GREEN that let `partial=1`
     suppress or pre-empt the match clause would pass the whole suite, because
     every existing match-clause test feeds no `partial=1`.
   - Fix: added a paired positive, with the same facts plus `match=a`, that
     expects the exact match-clause line. The negative follows unchanged.
   - **Status**: FIXED. The guard is green on unchanged code as intended, and
     the reproduced mutation still reds it. With the positive now first, the
     mutation would red it at the positive's equality instead.

2. **Probe test's cases don't pin exit status, stderr or outcome**
   - Location: `tests/probes-readonly-facts.bats`, the new `partial=1` test's
     three positive cases.
   - Problem: the sibling test in this file (`merge=1 fires for a git
     merge-style command segment`) asserts `status` 0 and empty `stderr`, and
     the slice-3 partial test asserts the outcome line. The new cases asserted
     neither. A GREEN probe that printed `partial=1` and then died under
     `set -u`, or wrote to stderr, would pass.
   - Fix: each positive case now asserts `status` 0, empty `stderr`, and its
     outcome line: `writable` for unlink and mkdir (single-quoted paths),
     `nopath` for create (unquoted).
   - **Status**: FIXED. It still reds at the first `partial=1` assertion (line
     218), and the new lines pass on unchanged code ahead of it.

## Hunted and clear

- **Real probe through the hook**: the new hook test calls no `stub_probe*`,
  and setup's `hook_copy_tree` copies the tracked `lib/` unmodified. A manual
  drive of `hooks/annotate.sh` on both payloads gives `writable` +
  `path=<cwd>/newdir2` + `merge=1` (mkdir) and `nopath` + `merge=1`
  (config-busy).
- **cwd and sandbox**: both payloads set `.cwd` to `$BATS_TEST_TMPDIR`, which
  is writable sandboxed and unsandboxed and sits under no repository. So no
  `target=` resolves, and the no-target clause is the one being tested. The
  recorded commands' `-C /tmp/sl8c-wt` and `cd /Users/david/…` are never
  followed (the repo comes from the path, else the cwd). No test writes
  outside `$BATS_TEST_TMPDIR`.
- **An implementation that ignores `partial=1` for the no-target clause**
  (restores on `merge=1` alone) reds the verdict negative and the hook
  negative. **One that never gives the no-target clause** reds the verdict
  positives and the hook positive. **One that does not recognise the third
  needle** reds the probe's mkdir case and the hook positive, since the mkdir
  fixture holds only that needle.
- **An implementation that also requires `partial=1` for the `match=` clause**
  reds the existing `merge with target and match restores the named files then
  acts`, the second and third cases of `merge clause leads lowercase…`, and the
  capped-list tests, all of which feed `match=` without `partial=1`.
- **An implementation where `partial=1` pre-empts `target=`** reds the guard
  negative. **One where `partial=1` suppresses the match clause** reds the new
  guard positive.
- **The probe's negative control** (`git merge feat` with another tool's
  refusal) is paired in the same output with `merge=1`, so `partial=1` absence
  is not vacuous. **Printing `partial=1` whenever `merge=1` prints** reds it.
- **Length and quiet coverage of `merge=1 partial=1`**: covered by
  `merge alone restores…` (length and matchers quiet), the new negative
  test's positive control (length), and the combined
  `compositions drop the old tail wording…` text (restore-them grep and D-7
  no-remove). The longest composition is still the capped match list with
  the update-config act. Restore-them plus update-config is shorter.
- **Edited existing tests**: each `merge=1`-without-`target=` case expecting
  restore-them gained `partial=1`. A grep of `tests/` for `restore them` and
  `merge=1` outside the two slice files finds no other dependent.
- **Self-quiet**: `partial_checkout_mkdir_error` builds git's line from two
  fragments around `erofs_message`. The review's own additions quote no
  diagnostic.

## Fixes Applied

- `tests/hook-candidates.bats`, new hook test: `sys` added to locals; the mkdir
  half pins `systemMessage` and exact `additionalContext`; the config-busy half
  pins `systemMessage` and the exact nopath act-alone line (replacing the bare
  `run ! grep restore`). Comment reworded.
- `tests/verdicts-readonly.bats`, guard test: paired positive
  `merge=1 partial=1 target=main match=a` → exact match-clause line.
- `tests/probes-readonly-facts.bats`, `partial=1` test: `status`, `stderr` and
  outcome assertions on each positive case.

## Final red state (unchanged `lib/`, `hooks/`)

- `scripts/run-bats.sh tests/probes-readonly-facts.bats`: 14 passed, 1 failed.
  The failure is the `partial=1` test, line 218, `grep -qxF 'partial=1'`.
- `scripts/run-bats.sh tests/verdicts-readonly.bats`: 13 passed, 1 failed.
  The failure is `merge alone with no partial=1…`, line 133, baseline
  equality.
- `scripts/run-bats.sh tests/hook-candidates.bats`: 9 passed, 1 failed. The
  failure is the hook test, line 204, the negative's exact `ctx` equality.
- `shellcheck` on the three files reports only the pre-existing SC1091 info on
  `probes-readonly-facts.bats` line 22. Line counts are 362, 287 and 276, all
  under the cap.
- Nothing committed.
