# Review of 31df412: pin for the `a b f r v` letter arm

Verdict: no defect. The case is evidence for the arm; no fix made.

## Checks on the case

- File `tests/verdicts-readonly-path.bats` is 310 lines, under 400.
- Encoder: the wire comes from the production `_probe_path_line`
  (sourced from `lib/probes-readonly.sh`), not a hand-written escape. The
  case also asserts the wire holds `\<letter>`.
- Bytes: the loop sets 007 (a), 010 (b), 014 (f), 015 (r) and 013 (v) with
  `$'\a' $'\b' $'\f' $'\r' $'\v'`.
- Assertion: `[ "$out" = "rc=0 raw=$real" ]` pins rc=0 and the exact decoded
  path. The failure message names the letter and the wire.
- State that fails it: the decoder returns 1 on a letter escape the encoder
  writes. Nothing else produces `rc=1 raw=` for these inputs, because the
  encoder-side check runs first and fails with a different message.

## Mutation proof

Every mutation was an exact once-occurring replacement of
`\\[abEefnrtv]) printf` in `lib/verdicts.sh` line 197 (script
`/tmp/claude/rev/mut.py` asserts one occurrence), landed-checked with
`command grep -n`, and restored by the swapped replacement.

1. Drop all of `a b f r v` (`[Eent]`). Run over `tests/verdicts*.bats`,
   `tests/probes-readonly*.bats`, `tests/hook-writes.bats`: 157 passed, 1
   failed. The one failure is the new case (`ok`/`not ok` 21), at its
   round-trip assertion, `letter \a: wire $'/x/a\az/f' gave: rc=1 raw=`. No
   other case fails.
2. One letter dropped at a time, run over `tests/verdicts-readonly-path.bats`
   (16 cases each):

   | Dropped | Result | Failure message |
   | ------- | ------ | --------------- |
   | a | 15 passed, 1 failed | `letter \a: wire $'/x/a\az/f' gave: rc=1 raw=` |
   | b | 15 passed, 1 failed | `letter \b: wire $'/x/a\bz/f' gave: rc=1 raw=` |
   | f | 15 passed, 1 failed | `letter \f: wire $'/x/a\fz/f' gave: rc=1 raw=` |
   | r | 15 passed, 1 failed | `letter \r: wire $'/x/a\rz/f' gave: rc=1 raw=` |
   | v | 15 passed, 1 failed | `letter \v: wire $'/x/a\vz/f' gave: rc=1 raw=` |

   Each failure is the new case on its own round-trip assertion, naming the
   dropped letter. All five mutants are killed.
3. Restore proof: after each restore the mutant text count was 0 and
   `command grep -c abEefnrtv lib/verdicts.sh` gave 1. After the last one
   the file is green, 16 passed, 0 failed, and `git diff --stat -- lib` is
   empty.

Note: the five-mutant loop ran past the 120 s foreground limit and the
harness backgrounded it; it was still one bats process at a time.
