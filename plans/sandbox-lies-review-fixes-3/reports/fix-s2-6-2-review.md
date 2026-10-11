# Review of pins 6.2/1 and 6.2/2 (commits 9b0ef52, 008f433)

Verdict: no defect. Only this report is committed.

## Checks

- Odd line carries the matching call. 6.2/1: a dated Bash tool_use `m1`
  (`git commit --amend --no-edit`) plus a tool_result line for `m1` with
  `timestamp: null` and the lock text, so `day` is computed on the result line
  that yields the output. 6.2/2: a Bash tool_use `m1` whose `input` is the JSON
  string of the exact command, plus a dated result for `m1` with the lock text
  (helpers `corpus_use_raw_input`, `corpus_result`). Both would cut under the
  mutant, so behaviour is observed, not just the cut landing.
- Asserted behaviour matches `iter_calls`: `day = (timestamp or "")[:10]`
  and `pick` skips when `day and d != day`; a non-dict input gives `c = None`,
  so the id is never recorded and the result is not paired. Entry
  `fire-lock-commit-amend` pins day 2026-08-13, so the mutant's fixed day
  matches it.
- Assertions: status 1, `NOT FOUND: fire-lock-commit-amend`, no cut file.
  The other two cases cut the same call successfully, ruling out a broken
  cutter or corpus path.
- No hand-made fixture: both corpora are built at run time under
  `$BATS_TEST_TMPDIR`; `git log` over `tests/fixtures` shows neither commit
  touched it. `tests/extract-fixtures.bats` is 93 lines.

## Mutation proof

6.2/1: `day = (e.get("timestamp") or "")[:10]` to `... or "2026-08-13")...`.
Landed (`command grep -c` 1). Run: `not ok 1 a null timestamp reads as no day,
so a dated entry does not take its call`, failed at line 51
`[ "$status" -eq 1 ]`; `3 passed, 1 failed`, no other case red. Restored by
swapped replacement: grep count 0.

6.2/2: `... isinstance(inp, dict) else None` to `... else inp`. Landed (grep
count 1). Run: `not ok 2 a string tool_use input reads as no command, so its
matching call is not taken`, failed at line 64 `[ "$status" -eq 1 ]`;
`3 passed, 1 failed`, no other case red. Restored by swapped replacement:
grep count 0, `bats: 4 passed, 0 failed`, and
`git diff --quiet -- tests/extract-fixtures.py` exits 0.

## Residual

Status 1 plus the NOT FOUND text would also come from an unreadable corpus
directory; the sibling cases that cut the same call from a dated, well-formed
line pass, which rules that out.
