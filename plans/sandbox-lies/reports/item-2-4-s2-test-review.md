# Review: Item 2.4 / slice 2 — test review

**Scope**: the two slice-2 tests in `tests/probes.bats` (`absent lock,
unsandboxed, is gone`; `non-UTF-8 byte in the path`) and the RED report
`item-2-4-s2-red.md`. `lib/probes.sh` was in scope for stub completion only. It
was mutated once for the proof below and restored.
**Date**: 2026-09-25
**Mode**: review + fix (test review, TDD slice)

## Summary

The RED run is sound. `gone` FAILED on its own line-1 assertion. The non-UTF-8
test passed as designed, and it carries a mutation proof, which I reproduced
with a different mutation. I found two gaps and fixed both in the tests:

- `gone` did not assert `path=`, unlike slice 1's same-text test.
- The non-UTF-8 test would pass silently on a box without the `C.UTF-8`
  locale.

`gone` is still red on its assertion.

**Overall Assessment**: Ready

## Mechanical check

I re-ran `scripts/run-bats.sh tests/probes.bats` in the foreground before any
edit:

```text
not ok 2 absent lock, unsandboxed, is gone
#   `[ "${output%%$'\n'*}" = gone ]' failed
bats: 2 passed, 1 failed
```

- `gone`: FAILED on an assertion. `status` is 0 and `stderr` is empty. The
  failure is the token itself, because the stub has no flag-`true` branch.
  There is no ERROR.
- `non-UTF-8 byte in the path`: PASSED. It is a test written after the code
  (slice 1's code review added `LC_ALL=C`), so the RED report's mutation proof
  stands in for a red.
- Self-quiet: `bash lib/matchers.sh < tests/probes.bats` gave no output and
  rc=1, before and after the fixes.

## Mutation proof, reproduced with a different mutation

The RED report removed `LC_ALL=C`. I used a different forbidden
implementation: a probe that "sanitizes" the path to UTF-8 before printing it.

- Replaced the single occurrence of `printf 'path=%s\n' "$path"` with
  `printf 'path=%s\n' "$(printf '%s' "$path" | iconv -f latin1 -t utf-8)"`.
  I used the Edit tool, which does exact-string replacement.
- Ran the suite:

  ```text
  not ok 2 absent lock, unsandboxed, is gone
  not ok 3 non-UTF-8 byte in the path
  #   `printf '%s\n' "$output" | grep -qxF "path=$lock"' failed
  bats: 1 passed, 2 failed
  ```

  The non-UTF-8 test went red on its own `path=` assertion. Slice 1's
  ASCII-path test stayed green, so this test is the only one that catches the
  mutation. The result also shows that `grep -qxF` compares bytes exactly
  under the ambient `C.UTF-8`, and does not fold `\351` into its UTF-8
  transcoding `\303\251`.
- Restored it with the inverse replacement.
- Proved the restore: `grep -c iconv lib/probes.sh` gives 0, and
  `git diff --quiet lib/probes.sh` succeeds, so the file is identical to HEAD.
- Reran the suite: `bats: 2 passed, 1 failed`, and the only failure is `gone`
  on line 1.

## Issues Found

### Critical Issues

None.

### Major Issues

1. **Nothing detected a missing locale in the non-UTF-8 test**
   - Location: tests/probes.bats, `non-UTF-8 byte in the path`
   - Problem: glibc (and possibly macOS) falls back to `C` when `C.UTF-8` is
     not installed. Under `C`, sed's `.` matches the byte, so the test passes
     whatever the extractor does, and nothing says so. On this box
     `locale -a` lists `C.utf8`, and `LC_ALL=C.UTF-8` resolves to it. With an
     uninstalled locale (`xx_YY.UTF-8`), the same sed matches.
   - Fix: added a precondition assertion before the run:
     `[ -z "$(printf '%s\n' "$lock" | LC_ALL=C.UTF-8 sed -n 's/^.*$/x/p')" ]`.
     It fails when the locale is missing, and also when the byte never
     reached the path. I checked both ways:
     - the real fixture path gives empty output;
     - an ASCII path gives `x`;
     - a missing locale gives `x`.

     BSD sed under a UTF-8 locale errors with empty output, so the check
     holds there too. I made it a failure rather than a `skip` because
     `scripts/run-bats.sh` counts `^ok ` lines, so a skip would be reported
     as a pass. The inline comment says so.
   - **Status**: FIXED

### Minor Issues

1. **The `gone` test did not assert `path=`**
   - Location: tests/probes.bats, `absent lock, unsandboxed, is gone`
   - Problem: the slice text is "same text" as slice 1, whose test asserts
     both line 1 and an exact `path=` line. The contract lists `path=` among
     the key lines for every outcome, and detectors.md's outcome table lists
     none as `mask`-specific. Without the assertion, a `gone` branch that
     skips `path=` would pass, and the probe's output would differ between
     the two absent outcomes. The `$2`-unrelated fixture (`elsewhere`) is
     already in place, so the new assertion also pins that the printed path
     comes from the error text.
   - Fix: added `printf '%s\n' "$output" | grep -qxF "path=$lock"` after the
     line-1 assertion, the same form slice 1 uses.
   - **Status**: FIXED

## Wrong-reason hunt: answers to the dispatch

- **Line 1 exact.** Yes. `[ "${output%%$'\n'*}" = gone ]` compares the whole
  first line, and a blank leading line or `gone2` fails it. `path=` is now
  pinned too (Minor 1).
- **A probe printing `gone` for every flag-`true` input, whether or not the
  lock exists.** This passes slice 2, and nothing in slice 2 can exclude it:
  excluding it needs a present lock, which slice 3 introduces. In the current
  list, only slice 5 (a symlink to `/dev/null`, flag `true` → `mask`)
  discriminates, and only for the character-device case. No slice runs a
  present **regular** lock with flag `true`:
  - Slice 3 is flag `false`.
  - Slice 9 repeats slice 3.
  - Slices 4, 6 and 7 do not name a flag.

  So a probe with `flag = true && not a char device → gone` would pass every
  planned slice. The table says flag `true` with a present lock goes to
  `held`, `orphan` or `unknown` ("the flag selects mask versus gone when the
  path is absent"). This is a slice-list gap, not a slice-2 defect. See the
  recommendation below.
- **Does the fixture really hold byte 0xE9?** Yes. `od` of the created
  directory name gives `72 e9 6e`. The precondition assertion now re-checks
  this on every run.
- **Is `C.UTF-8` available?** Yes on this box (`locale -a`: `C`, `C.utf8`,
  `POSIX`). Before the fix, the test would have passed silently without it;
  it now fails loudly (Major 1).
- **Does the locale reach the extractor?** Yes. A bash prefix assignment on a
  function call exports into that call's children. The RED report's
  mutation, which removes `LC_ALL=C`, went red, which shows the outer locale
  reaches `sed`. The prefix does not persist past the call, because bats runs
  bash outside POSIX mode.

## Fixes Applied

- `tests/probes.bats` `absent lock, unsandboxed, is gone`: added an
  exact-line `path=$lock` assertion.
- `tests/probes.bats` `non-UTF-8 byte in the path`: added a commented
  precondition that the fixture path is not matchable whole by sed under
  `C.UTF-8`. It fails when the locale is missing or the byte is absent.
- `lib/probes.sh`: unchanged. It was mutated once and restored, and
  `git diff --quiet` succeeds.

## Final state

- `scripts/run-bats.sh tests/probes.bats`:

  ```text
  not ok 2 absent lock, unsandboxed, is gone
  # (in test file tests/probes.bats, line 63)
  #   `[ "${output%%$'\n'*}" = gone ]' failed
  bats: 2 passed, 1 failed
  ```

  `gone` is red on its line-1 assertion. Slice 1 and the non-UTF-8 test are
  green.
- `shellcheck lib/probes.sh tests/probes.bats`: clean.
- Self-quiet: `bash lib/matchers.sh < tests/probes.bats` gives no output,
  rc=1.
- Nothing was committed.

## Requirements Validation

| Requirement | Status | Evidence |
|---|---|---|
| detectors.md `gone`: flag true, path absent | Pinned (red) | line-1 `= gone` |
| A-3: `path=` line, exit 0, no stderr | Pinned | `status`, `stderr`, `grep -qxF` |
| Path from the error text | Pinned | `$2` is an unrelated dir, and `path=` is asserted |
| Byte-exact path under a UTF-8 locale | Pinned | two independent mutations go red; locale precondition |
| FR-11 self-quiet | Holds | matchers.sh gives no output, rc=1 |

## Recommendations (for the list revision)

- **Present lock with flag `true`.** Run a present unheld lock with flag
  `true` and expect `orphan`: for example, run slice 3 under both flags, as
  slice 5 does. Without it, "`gone` for any non-device flag-`true` input"
  passes the whole list. This contradicts the outcome table, where the flag
  only matters when the path is absent.
