# Delegate status — sandbox-lies-review-fixes

## Phase reached

Outline approved at `/proof` (2026-10-04: approve all, D3 absolute paths, D4
as written); D1 updated with the CC 2.1.289 observation. `/edify:runbook`:
`runbook.md` written and checkpointed; runbook-corrector running; then
simplifier, then the runbook `/proof` gate.

## Commits

- `d2a53e5` outline + classification, approved at proof
- `9d1a587` runbook pre-review checkpoint

## Gates hit

- Outline `/proof` — approved 2026-10-04. After approval: commit outline + classification, then
  `/edify:runbook` (route-to-execution: Phase 2 pins must precede Phase 3's
  code changes, a build-verify ordering, and phase-boundary correctors only
  run from a runbook), then `/edify:build`.

## Deferrals (in the outline's OUT list)

- m-1 quadratic tokenizer, m-7 line-cap gate coverage, m-8 corpus-eval
  idempotency, m-9 extract-fixtures robustness, Unchosen host (dispatch
  scope).
- Tests m-6 Linux-only suite: portability work, not a mechanical fix.
- `build-finish.md` §Carry-forward (dispatch scope).

## Notes for the main session

- Item 2.6 adds a BSD `paste` stub and a shim case to `tests/shim.bats`; the
  saved `.bin/claude` patch re-applied after the build must keep it green.
