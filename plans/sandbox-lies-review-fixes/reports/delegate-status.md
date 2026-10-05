# Delegate status — sandbox-lies-review-fixes

## Phase reached

Planning done: outline and runbook approved at `/proof` (2026-10-04). Build
running (`/edify:build plans/sandbox-lies-review-fixes`), baseline `a7ff5e5`
(in `.git/build-baseline`; `tmp/` is not gitignored in this repo, so the
baseline lives under `.git/`).

## Build progress

- Phase 1 — Item 1.1 done (`reports/item-1-1.md`); phase-1 corrector
  `reports/phase-1-corrector.md`.
- Phase 2 — Items 2.1–2.5 done (`reports/item-2-{1..5}.md`); phase-2
  corrector `reports/phase-2-corrector.md` (Ready; it ran faults for the
  assertions the item reports left unrecorded, fixed three minors).
- Phase 3 — Items 3.1–3.4 done (`reports/item-3-{1..4}.md`); phase-3
  corrector `reports/phase-3-corrector.md` (Ready; ran the missing faults for
  3.4's `path=` positives, fixed the paste stub's missing-argument message and
  `git-env.bash`'s `setup_file` fallback).
- Phase 4 — Item 4.1 slices 1 and 2 done (RED, test review, GREEN, code
  review each; `reports/item-4-1-s{1,2}-*.md`), slice-2 refactor
  (`reports/item-4-1-s2-refactor.md`: the operand-rule cases moved to
  `tests/probes-readonly-operands.bats`), list revision committed in
  `runbook.md`. Slice 3 done (`reports/item-4-1-s3-*.md`; the code review
  fixed a `<`-in-argument-slot regression), list revision committed in
  `runbook.md` (a pin for it in slice 4; four docs-step residuals). Slice 4
  done (`reports/item-4-1-s4-*.md`; the code review fixed four missed uniq
  operands, pinned afterwards by a test-only dispatch with one mutation per
  run, `reports/item-4-1-s4-pins.md`); list revision after slice 4: none.
  Docs step done (`reports/item-4-1-docs.md`). Item 4.1 complete.
- Phase 4 — Item 4.2 done: slice 1 (`reports/item-4-2-s1-*.md`; hook case in
  `tests/hook-writes.bats`), code review folding in the main session's
  security finding (a newline in the repository root split `match=` lines and
  forged key lines: guarded, pinned red-first) plus a trailing-slash `//` fix,
  pinned by `item-4-2-s1-pins`; docs step `reports/item-4-2-docs.md`.
- Phase 4 — Item 4.3 done: slices 1 and 2 (`reports/item-4-3-s{1,2}-*.md`;
  `SessionStart` entry with no matcher and a 10 s timeout), docs step
  `reports/item-4-3-docs.md`. Phase-4 corrector `reports/phase-4-corrector.md`
  (Ready; six minor fixes, faults A–F run). Phase 5 and the finish (review
  gate, tdd-audit) remain.

## Build decisions

- Entry and post-item gates run `verify-step.sh` with an env-only git exclude
  (`GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.excludesFile
  GIT_CONFIG_VALUE_0=/tmp/claude-1000/sl/build-exclude`, file holding
  `/.claude/gitlore-memory-message`): that untracked file is sanctioned by the
  dispatch brief and is the gate's only dirt. Nothing in the repo changes.
- Dispatches run unnamed (brief), one at a time; report paths still follow the
  build skill's dispatch names.
- From slice 4.1/1's code review on, the harness sometimes refuses a
  subagent's report Write ("Subagents should return findings as text"). That
  is a reasoned refusal, not the no-verdict gap, so it is not routed around:
  every dispatch is told to reply with the full report ending `END OF
  REPORT` when refused, and the orchestrator saves it to the assigned path
  (noting so at its top) and commits it with the slice. A GREEN refused its
  report commits without it.
- Item 4.1's docs step ran as one opus dispatch after slice 4.
- Slice 3: GREEN implemented only the tested `-e`/`-f` forms; clustered and
  long forms became docs-step residuals (orchestrator's call, recorded in the
  test-review report).
- A code-review fix with no test is pinned before the next step: by the next
  slice's list revision where one remains (slice 3), else by a test-only
  dispatch proving each pin by mutation (slice 4, `item-4-1-s4-pins`).

## Deferrals (in the outline's OUT list)

- m-1 quadratic tokenizer, m-7 line-cap gate coverage, m-8 corpus-eval
  idempotency, m-9 extract-fixtures robustness, Unchosen host (dispatch
  scope).
- Tests m-6 Linux-only suite: portability work, not a mechanical fix.
- `build-finish.md` §Carry-forward (dispatch scope).

## Notes for the main session

- Item 3.1 adds a BSD `paste` stub and a shim case to `tests/shim.bats`; the
  saved `.bin/claude` patch re-applied after the build must keep it green.

## RCA follow-ups

- Item 2.2 first committed a shellcheck failure: `just precommit`'s
  `tracked()` lists files with `git ls-files`, so a new untracked `.bats` or
  `.sh` skips shellcheck and `bash -n` (bats still runs it). Remedied by a
  follow-up commit; every later dispatch is told to `git add` new files before
  the gate. The gate gap itself (`--others --exclude-standard`) is out of this
  job's scope — proposed for my human partner.

## Open question for my human partner

- Pre-existing, same class as the `match=` newline finding: a relative
  refused path joined onto a newline-bearing payload cwd makes the probe's
  `path=` line forge key lines (`reports/item-4-2-s1-code-review.md`,
  Recommendations 1, verified there). The fix must choose what the probe
  reports for a path it cannot print (`nopath`, or an outcome with no `path=`
  line), which changes the A-3 contract. Not fixed; to be asked before the
  finish.

## Carry list

- Precommit lints only tracked files (RCA above) — not fixed here.
- `tests/hook-candidates.bats` is at 374 lines; Item 4.2's hook case goes in
  `tests/hook-writes.bats` if it runs past ~24 lines.
- The outline's OUT list (above).
- Simplifier note: `readonly-path.md`, `hook.md`, `detectors.md` and
  `lib/matchers.sh` are each edited by more than one item (accepted at runbook
  proof).

## Resume

- **Last commit:** the one adding this section (after `1b81266`, Item 4.1
  list revision after slice 2).
- **Exact step:** `/edify:build` §4.3, Item 4.1 slice 3 — next dispatch is
  the slice-3 RED (`edify:test-driver`, sonnet, Mode RED), tests in
  `tests/probes-readonly-operands.bats` per the revised runbook text
  (includes the per-segment reset pin). Then test review, GREEN, code review,
  commit the review, `verify-step.sh` (with the env-only exclude above), list
  revision; slice 4 the same; then the docs step; then Items 4.2 (one slice)
  and 4.3 (two slices); then `phase-4-corrector`.
- **Why stopped:** the delegate's context reached the ~200k cap from the
  dispatch brief.
- **Decisions given:** runbook approved as committed at `/proof` (2026-10-04);
  no item verdicts. Earlier planning decisions as in the outline (D1–D5).
- **Phase-boundary reports so far:** `reports/phase-{1,2,3}-corrector.md`, all
  Ready.
- **Carry list:** as above (precommit lints tracked files only;
  `hook-candidates.bats` at 374 lines for Item 4.2's hook case, which goes in
  `hook-writes.bats` if long; Item 4.1 docs-step residuals; the outline's OUT
  list; the simplifier's multi-item files note).
