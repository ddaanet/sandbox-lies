# Fix S2 gate: letter escapes `a b f r v` decode

Finding: Minor 2 of `reports/deliverable-review.md` (surviving mutant "gate fix,
`a b f r v` dropped"). The decoder was rewritten in da7db9d; the letter set in
`_verdict_path_read` (`lib/verdicts.sh`) is now `abEefnrtv`.

## Test added

`tests/verdicts-readonly-path.bats`, case
"_verdict_path_read decodes the letter escapes %q writes for control bytes a b f r v".

For each letter in `a b f r v` (bytes 007, 010, 014, 015, 013) it builds the path
`/x/a<byte>z/f`, encodes it with the production `_probe_path_line`, asserts the
wire holds `\<letter>`, and decodes it with `_verdict_path_read`. It asserts
`rc=0 raw=<the exact path>`. A failure names the letter.

State that fails it: the decoder treats one of the five letter escapes as an
unknown escape and returns 1 with no path. Other causes that could also produce
the failure: a broken encoder (covered by the wire-contains check and the
round-trip), or a wrong byte in the test's path (the round-trip compares against
the same bytes that were encoded, so a mis-chosen byte would fail the wire check
or the comparison, not pass silently).

## Verification

- Current code: `scripts/run-bats.sh tests/verdicts-readonly-path.bats`:
  16 passed, 0 failed.
- The file is 311 lines (was 291), well under 400.

## Mutation proof

1. Mutant: in `lib/verdicts.sh`, the exact once-occurring string
   `\\[abEefnrtv]) printf` (line 197) replaced by `\\[Eent]) printf`, dropping
   `a b f r v`. Before the edit, `command grep -c abEefnrtv` gave 1.
2. Landed: `command grep -n 'Eent\]) printf' lib/verdicts.sh` shows line 197
   with the mutant text.
3. Red on its own assertion: the suite gave 15 passed, 1 failed. The failing
   check is the round-trip `[ "$out" = "rc=0 raw=$real" ]` at the test's line
   308, with `letter \a: wire $'/x/a\az/f' gave: rc=1 raw=`.
4. Restored by the swapped replacement `\\[Eent]) printf` to
   `\\[abEefnrtv]) printf`. `command grep -c 'Eent\]'` gave 0, and
   `command grep -n abEefnrtv` shows line 197 restored.
5. Restore proof: the suite is green again, 16 passed, 0 failed.
