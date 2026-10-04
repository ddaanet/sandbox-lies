# Delegate status — sandbox-lies-review-fixes

## Phase reached

Outline approved at `/proof` (2026-10-04: approve all, D3 absolute paths, D4
as written); D1 updated with the CC 2.1.289 observation. `/edify:runbook`:
`runbook.md` written, corrected (23 fixes, `reports/runbook-review.md`,
Ready), simplified (no consolidations, `reports/runbook-simplify.md`). At the
runbook `/proof` gate.

## Commits

- `d2a53e5` outline + classification, approved at proof
- `9d1a587` runbook pre-review checkpoint
- `26df82e` runbook-corrector fixes
- (this commit) simplifier report, Resume section

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

## Resume

- **Last commit:** the one adding this section (simplifier report + Resume).
- **Exact step:** `/edify:runbook` step 7 — `/edify:proof` on `runbook.md`,
  Orientation presented to my human partner, no item verdicts yet. After
  approval and batch-apply: commit, then `/edify:build plans/sandbox-lies-review-fixes`
  from its entry gate (`verify-step.sh` with `dangerouslyDisableSandbox: true`).
- **Why stopped:** context near the ~200k cap after design + runbook; the
  runbook skill itself routes execution to a fresh session. A fresh delegate
  should run `/build`.
- **Decisions given:** scope as in the brief; outline approved (D3 absolute
  `<repo>/<name>`, D4 as written); D1 records 2.288 (`git:*`) and 2.289
  (`git *`, after restart) single-writer probes both sandboxed — exclusions
  observed not honoured under either syntax, the every-command rule kept as
  CC's documented mechanism.
- **Environment:** `--plugin-dir .` session: a Write/Edit in the checkout may
  give no verdict — write via a Python script under `/tmp/claude-1000/`
  (`/tmp/claude-1000/sl/put.py <src> <dst>` exists); put that instruction in
  every dispatch prompt. Do not touch `.bin/claude`.
- **Carry list:** the outline's OUT list; simplifier's note that
  `readonly-path.md`, `hook.md`, `detectors.md` and `lib/matchers.sh` are each
  edited by more than one item (docs and comments, not agentic prose; accepted
  so far, pending runbook proof).
