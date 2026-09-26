# GREEN: Item 6.1 slice 3 — `readonly and nopath`

**Scope**: `lib/verdicts.sh`'s `verdict_readonly_path`, growing the `readonly`
and `nopath` outcomes. No test file edited.
**Date**: 2026-09-26
**Mode**: GREEN

## Failing batch (from RED + test review)

- `tests/verdicts.bats`: `verdicts under 400 chars` (two new rows
  `readonly_path readonly` / `readonly_path nopath`); `readonly-path readonly
  verdict text matches detectors.md`; `readonly-path nopath verdict text
  matches detectors.md`.
- `tests/hook-candidates.bats`: `readonly outcome through the hook`; `nopath
  outcome through the hook`.

## Implementation

Extended `verdict_readonly_path` with two new `case` arms and factored the
subject (backticked `path=` value, or `The path` with none) into one
`subject` variable computed once, ahead of the `case`, reused by both
`writable` and the new `readonly` arm — same plain-expansion shape the
writable branch already had, no sed or eval on the path.

Added `_verdict_readonly_path_tail`, a private helper printing the writable
paragraph's text from "Re-run" on as one literal. `writable` and `nopath`
both call it, so the shared tail cannot drift between the two paragraphs;
`writable`'s emitted bytes are unchanged (verified by the passing
transcription test pinning the old string).

Updated the function's leading comment to describe all three outcomes and
the shared-tail helper; added a comment for the helper itself.

## Tests made to pass, one at a time

1. `readonly-path readonly verdict text matches detectors.md` — ran alone
   (`scripts/run-bats.sh tests/verdicts.bats -f '...'`) after adding the
   `readonly)` arm: 1 passed.
2. `readonly-path nopath verdict text matches detectors.md` — ran alone
   after adding the `nopath)` arm and the shared-tail helper: 1 passed.
3. `verdicts under 400 chars` — ran alone: 1 passed (both new rows now
   produce two non-empty lines).
4. `readonly outcome through the hook` — ran alone: 1 passed.
5. `nopath outcome through the hook` — ran alone: 1 passed.

No test needed a second attempt.

## Full suite

- `tests/verdicts.bats tests/hook-candidates.bats` together:
  `bats: 18 passed, 0 failed`.
- `just test` (whole suite): `bats: 195 passed, 0 failed`.

## Precommit gate

`direnv exec . just precommit`, foreground, own exit status:

```
exit=0
scripts/run-bats.sh tests/
bats: 195 passed, 0 failed — full log: /tmp/claude-1000/sandbox-lies-bats.jGMEWO
precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests
```

No warnings emitted by any check.

## File sizes

`lib/verdicts.sh`: 164 lines (was 145). Under the 400-line cap.

## Scope

No edits to `hooks/annotate.sh`, `lib/probes*.sh`, `docs/`, `memory/`, or any
test file. `readonly-path`'s flag policy (silent when the flag is true)
stays out of scope for slice 4.
