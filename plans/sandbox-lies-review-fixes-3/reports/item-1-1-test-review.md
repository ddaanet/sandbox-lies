# Review: Item 1.1 tests (slices 1-4), RED output

**Scope**: uncommitted changes to `tests/probes.bats`,
`tests/probes-lock-newline.bats`, `tests/probes-readonly-members.bats`,
`tests/hook-cap.bats`, new `tests/helpers/locale.bash`, and
`reports/item-1-1-red.md`. `lib/` untouched (a read-only reference copy was
used in a scratch directory outside the repo, removed afterwards).
**Mode**: test review + fix

## Summary

All new and changed tests fail on assertions against the unchanged `lib/`.
Against a scratch reference encoder (a `_probe_path_line` using
`LC_ALL=C printf %q`, both newline guards removed) every new test passes, so
the expected literals are correct and satisfiable; only the slice 5 sites
(`non-UTF-8 byte`, `quote and space`) fail. One weakness found and fixed.

**Overall Assessment**: Ready (after the fix below).

## Mechanical check (unchanged lib/)

| Suite | Result |
| --- | --- |
| `probes.bats` | 12 pass; new cases 4, 5, 6 fail at line 93 (path= literal), 106 (`= mask`), 125 (path= literal) |
| `probes-lock-newline.bats` | 7 of 7 fail inside `assert_lines` / `orphan_twins`, on the newline twin |
| `probes-readonly-members.bats` | case 6 fails at line 158, the whole-output equality |
| `hook-cap.bats` | 7 pass (helper move, behaviour preserving) |
| `docs.bats` | 2 pass; `shellcheck tests/helpers/locale.bash` clean |

No test errored, none passed.

## Issues Found

### Major

1. **`assert_lines` did not pin the outcome to line 1**
   - Location: `tests/probes-lock-newline.bats`, `assert_lines`
   - Problem: it checked the path= line and the set of other lines, not their
     position. An encoder printing `path=` ahead of the outcome token passed
     all seven cases (shown with a scratch mutant: no failures in this file),
     yet the reader and `probes.bats` take line 1 as the outcome. The old
     whole-output equality pinned order.
   - Fix: added `[ "${output%%$'\n'*}" = "$1" ]` (first non-path line is
     line 1), header comment updated. With the same mutant, cases 1, 6 and 7
     now fail. The mutant covered the absent-lock print sites only; the other
     sites are covered by the same helper.
   - **Status**: FIXED

## Mutation hunt (scratch copy with reference encoder)

| Wrong implementation | Caught by |
| --- | --- |
| Reference encoder, correct | all new tests pass |
| `%q` without `LC_ALL=C` | `probes.bats` e-acute case, and the newline-plus-e-acute case (so the extra case does discriminate the pin, in the `$'..'` branch) |
| `$'..'` only for newlines, blanks raw | `probes.bats` blank case, all six `probes-lock-newline` blank-twin assertions, members case |
| Empty path left as bare `path=` | `probes.bats` `no config-lock line` case |
| `path=` printed before the outcome | only the line-1 check added by the fix |

Reading the expected literals: all are written out (`good_wire`, `bad_wire`,
inline `\\ `, `\\303\\251`). `%q` appears only in the precondition that
`BATS_TEST_TMPDIR` holds no byte it escapes, which is a guard on the fixture,
not an expectation. The extra newline-plus-e-acute case is sound: the
directory is created with the exact bytes, the expected line is
`r\n\303\251`, and it justifies the `locale` load in that suite by
discriminating the pin on the `$'..'` path.

## Helper move: mutation proof (different from the RED report's)

- Test: `the 2 KB cap counts bytes, not characters` (`hook-cap.bats`).
- Mutation in `tests/helpers/locale.bash`: `printf '%s\n' "$loc"` replaced by
  `printf '%s\n' POSIX` (the RED report used `C`). Landed: `command grep`
  found line 14.
- Result: `not ok 1`, failing at `hook-cap.bats:182`
  (`LC_ALL="$loc" wc -m ... -le 2048`).
- Restored by swapping the strings: `command grep -c POSIX` is 0, line 14 reads
  `printf '%s\n' "$loc"` again, test `ok 1`.

## Judgement: newline twin first

Sound. bats stops at the first failing assertion, so the newline twin first
makes the RED report show the newline behaviour (no `path=` line) instead of
blank escaping. The cost, blank-twin literals unproven until GREEN, is covered
above: the reference run passes them and the newline-only mutant fails on them.

## Fixes Applied

- `tests/probes-lock-newline.bats` — `assert_lines` pins line 1; comment
  updated. Re-ran: still 7 of 7 red on assertions against the unchanged lib/.

## Requirements Validation

| Requirement | Status | Evidence |
| --- | --- | --- |
| Slice 1 (`r\ b` literal, tmpdir precondition, empty path no `path=`) | Satisfied | probes.bats 4, 5 |
| Slice 2 (five sites, literals, no forged line, outcome and non-path lines identical) | Satisfied | lock-newline 1-6 |
| Slice 3 (writable plus one `$'..'` line, renamed) | Satisfied | members case 6 |
| Slice 4 (e-acute octal under `utf8_locale`, helper moved, three suites load) | Satisfied | locale.bash, probes.bats 6, lock-newline 7 |

Slice 5 and `_probe_path_line` correctly left for GREEN. The fixed
`non-UTF-8 byte`, `quote and space` and `pathless text never names the base`
sites are the GREEN dispatch's to rewrite.
