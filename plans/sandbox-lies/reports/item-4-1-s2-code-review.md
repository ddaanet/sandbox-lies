# Review: Item 4.1 slices 2-3 — code review (`lib/verdicts.sh`)

**Scope**: `lib/verdicts.sh` as changed by the commit "Item 4.1/2 — held,
orphan and unknown interpolate probe values (slices 2-3)". Tests, slices 4-9,
Items 4.2/4.3 and `docs/` are out of scope.
**Date**: 2026-09-25T21:37+02:00
**Mode**: review + fix

## Summary

The slice made `verdict_git_lock` and `verdict_config_lock` read the probe's
`pid=`/`bytes=`/`age=` lines from stdin and interpolate them into the `held`,
`orphan` and `unknown` text. It was correct when the values were digits. The
text was byte-for-byte what `lock-detectors.md` specifies, absent keys dropped
their clauses, and nothing it wrote passed through a format string or a
pattern replacement. The weak points were the duplication and the missing
input contract. The stdin loop appeared twice, the `held` block twice and the
four-arm size-clause ladder four times. A value that was not digits, a
trailing CR included, went into agent text verbatim. Both are fixed: the three
shared outcomes now live in one helper, and a value that is not all digits is
dropped the same way as a missing key.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

1. **Interpolation logic duplicated six ways across the two lock verdicts**
   - Location: `lib/verdicts.sh`, `verdict_git_lock` and
     `verdict_config_lock`, `held`/`orphan`/`unknown` arms and the stdin
     prologue
   - Problem: The stdin-reading loop appeared twice, the `held` clause block
     twice and the identical 8-line `size_clause` ladder four times (in
     `orphan` and `unknown` of each function). The text of those three
     outcomes differs between the detectors only in the lock file's name:
     `lock-detectors.md` gives config-lock's list as git-lock's "naming
     `config.lock`". A fix to one copy therefore has to be made in all four.
     The GREEN report said a shared helper would need either a subshell or
     dynamic scope. It needs neither: the verdict can pass the lock name and
     the outcome as arguments to a helper that inherits the same stdin.
   - Fix: The three shared outcomes moved into `_verdict_lock_present <lock
     file> <outcome>`, defined after its two callers. It follows the
     `_probe_*` helper convention in `lib/probes.sh`, and the leading
     underscore keeps it out of the `^verdict_` function enumeration in
     `tests/verdicts.bats`. Each lock verdict now keeps only its own
     `mask`/`gone` text and sends every other outcome to the helper with
     `*)`. The size clause is computed once as
     `" (${bytes} bytes${age:+, age ${age}s})"`, falling back to
     `" (age ${age}s)"`. The pid clause is `${pid:+ (pid ${pid})}` in the
     paragraph and `${pid:+ by pid ${pid}}` in the human line. The file went
     from 140 to 95 lines.
   - **Status**: FIXED

### Minor Issues

1. **Values that are not digits, trailing CR included, went into the text
   verbatim**
   - Location: `lib/verdicts.sh` stdin loop (both functions before the fix)
   - Problem: The probe contract says `pid=`, `bytes=` and `age=` carry
     digits, but the verdict accepted anything. For example, `age=12\r`
     produced `age 12\rs` in `additionalContext`, and `pid=abc` produced
     `(pid abc)`. Metacharacters were safe: `&`, `\`, `/`, `%` and spaces
     reach `printf` only as a `%s` argument and never as the format, and no
     `${var//…}` replacement is involved, so bash 5.2's `patsub_replacement`
     does not apply. Probing `pid=12&3\%s/x` printed it literally. The gap was
     the input contract, not injection.
   - Fix: The first arm of the loop is now `*=*[!0-9]*) ;;`, which drops any
     key=value line whose value contains a character that is not a digit.
     This uses the `[!0-9]` idiom that `lib/probes.sh` already uses. A
     rejected value then follows the existing absent-key path, so the clause
     disappears rather than showing a foreign value. Checked by hand: `pid=`,
     `pid=4242\r`, `pid=1=2` and `pid=12&3\%s` all give `A process holds the
     lock.`; `age=12\r` with `bytes=7` gives `(7 bytes)`; `pid=4242` gives
     `(pid 4242)`. The helper's comment states the rule.
   - **Status**: FIXED

2. **Lock verdicts read stdin for outcomes that never use it**
   - Location: `lib/verdicts.sh`, prologue of both functions before the fix
   - Problem: `mask` and `gone` drained stdin they had no use for. Called
     directly without a redirect, for example from a terminal, they blocked
     waiting for input. This was a regression from slice 1, where they did
     not read stdin.
   - Fix: Resolved by the Major 1 restructure. Only the helper reads stdin,
     so `mask`/`gone` are back to their slice-1 behaviour. The hook's
     `printf … | "$fn"` is unaffected, since pipeline status is the
     verdict's.
   - **Status**: FIXED

## Checks with no finding

- **Text vs `lock-detectors.md`**: The `held`, `orphan` and `unknown`
  paragraphs and human lines for both detectors match the reference with N
  substituted. `tests/verdicts.bats` cases 4-6 and `tests/hook-locks.bats`
  11-14 pass after the refactor.
- **FR-6 400-character bound under realistic maxima**: The longest paragraph
  is `orphan`. With `bytes=18446744073709551615` (the 2^64-1 ceiling) and
  `age=99999999999` (above any epoch age), it is 204 characters. `held` with
  a 7-digit Linux `pid_max` pid is 64, and `unknown` is 149. There is ample
  headroom.
- **bash 3.2 / BSD**: The code uses only `read -r`, `${var#pre}`,
  `${var:+word}` with a nested expansion, `case` globs and `printf '%s\n'`.
  It has no arrays, `[[ ]]`, `${var,,}` or external commands, so there is no
  BSD surface. No bash 3.2 binary is installed on this host; this is judged
  from the constructs used, not run.
- **NFR-4**: No here-document, temp file or command substitution in the
  file.
- **stderr**: No redirects of any kind.
- **Missing trailing newline**: `|| [ -n "$line" ]` keeps a last line that has
  no newline. `printf 'age=5' | verdict_git_lock unknown` gives `(age 5s)`.

## Mutated-SUT run

A single run with one exact-string replacement in `lib/verdicts.sh`. The
plausible-but-forbidden implementation is the reference template with values
substituted unconditionally:

- `if [ -n "$bytes" ]; then` / `size=" (${bytes} bytes${age:+, age
  ${age}s})"` → `if true; then` / `size=" (${bytes} bytes, age ${age}s)"`

I ran `bats tests/verdicts.bats tests/hook-locks.bats` against it:

- `orphan with neither bytes nor age interpolates no empty value`: red
- `orphan with one of bytes and age interpolates that one alone`: red
- The all-values cases (`held interpolates the pid`, `orphan and unknown
  interpolate size and age`, both `verdicts.bats` interpolation cases): green,
  as expected, since every value is present there.

I restored the file by the inverse exact-string replacement. `grep -c 'if
true'` returns 0 and the original `size=` line is back at line 77.

(A first attempt with `perl` failed to compile and changed nothing. That run
was an unmutated baseline and all 14 cases were green.)

## Fixes Applied

- `lib/verdicts.sh` `verdict_git_lock`, `verdict_config_lock`: dropped the
  stdin prologue and the `held`/`orphan`/`unknown` arms; `*)` now delegates to
  the helper with the lock file's name.
- `lib/verdicts.sh` `_verdict_lock_present` (new, end of file): reads stdin
  once, drops values that are not digits, builds the size clause once, and
  prints the three shared outcomes with `${lock}` substituted.
- Gate: `direnv exec . just precommit`, run in the foreground, printed
  `bats: 141 passed, 0 failed` and `precommit passed: plugin.json,
  hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests`. Nothing
  was committed.

## Recommendations

- **Untested behaviour (tests are out of scope here):** The suite does not
  pin two things this review added or measured.
  - Dropping a value that is not digits (for example `pid=4242` plus a CR,
    expecting the `held` paragraph with no pid clause).
  - The FR-6 bound with values present. `verdicts under 400 chars` runs every
    row with empty stdin, so it measures only the shortest form.

  A later slice's RED, or the orchestrator, can add a row for each.
- No `REFACTOR-NEEDED`: the refactor that was in scope has been applied.
