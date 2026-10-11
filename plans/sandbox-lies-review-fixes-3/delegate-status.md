# Delegate status — sandbox-lies-review-fixes-3

Runner: Sonnet `/build` over `outline.md` (no runbook). Baseline for the review
gate: `d6d0043173f6a692cc5d2e2a74d7e83c0710ab44` (`tmp/build-baseline`).
Review range for the deliverable review is `2309ae6..HEAD` (outline Provenance).

## Dispatch plan (decisions given)

- Model rule from my human partner: runner and every reviewer Sonnet; Haiku
  implements well-defined items; Sonnet implements judgment items; a reviewer is
  never below its implementer; a stuck Haiku moves up, not retried.
- Slices run grouped per Item: one RED, one test review, one GREEN and one code
  review per Item (4 dispatches), not per slice. Reason: 17 slices x 4 would
  not fit the runner's context budget (same call as review-fixes-2). Every
  test still carries a red run or a mutation proof; per-slice mutation testing
  is binding on the test and code reviews.
- Prompts give item text by outline path and line range rather than pasted:
  the agent Reads the same bytes.
- Agents launch unnamed (human partner's rule), so reports are named by path.
- Entry gate: `verify-step.sh` is not in this repo and reads the modified
  `.claude/handoff-todo.md` and untracked entries as dirt; the equivalent used
  is `git status --porcelain` filtered of those entries plus `just precommit`.
- Phase boundary: the outline asks for a Phase 1 boundary review (Sonnet
  corrector); later phases are covered by the final review.

- **Model rule restated by my human partner on 2026-10-11; it supersedes the
  table below and the "both items are Haiku rows" clause of the regrouping
  wherever they differ.** The runner is Sonnet. The runner dispatches Sonnet
  for prose and for tests: every RED, every test review, every code review and
  the Phase 7 docs. It dispatches Haiku for tdd coding loops and for mutation
  killing: every GREEN of a tdd item (Phases 2, 3 and 6), and the loop that
  pins a mutation a code review found surviving. A Sonnet reviewer re-checks
  each Haiku pin, so the reviewer stays above the implementer. Phases 4 and 5
  are general items the restated rule does not name: Item 4.1 stays Sonnet
  (judgment), Items 5.1 and 5.2 stay Haiku. A stuck Haiku still moves up.

| Item | Implementer model | Reason |
| --- | --- | --- |
| 0 bash 3.2.0 build | Sonnet | network and build debugging |
| 1.1 | Sonnet | cross-suite assertion rewrite, locale helper move |
| 1.2 | Sonnet | `printf %q` decoder, grammar, 3.2 behaviour |
| 2.1 | RED Sonnet, GREEN Haiku | fixed rule, one function branch |
| 3.1 | RED Sonnet, GREEN Haiku | string edit |
| 4.1 | Sonnet | tokenizer, outlined as judgment |
| 5.1, 5.2 | Haiku | two-line and one-arm edits |
| 6.1, 6.2 | RED Sonnet, GREEN Haiku | guards fixed by the outline |
| 7.1 to 7.7 | Sonnet | prose with a hard line cap |

## Progress

- [x] Entry gate: tree clean apart from the exempt entries, precommit green
      (371 bats passed)
- [x] Recall: `recall-artifact.md` written
- [x] Item 0: bash 3.2.0 built at `/tmp/claude/bash32/bash` (`reports/item-0-bash32.md`)
- [x] Item 1.1 (Sonnet, grouped slices 1-4 RED + slice 5 in GREEN): RED
      `item-1-1-red.md`, test review `item-1-1-test-review.md` (one weakness
      fixed), GREEN `item-1-1-green.md` (commit 5bfd2e2, 15 tests rewritten),
      code review `item-1-1-code-review.md` (11 mutations, 1 survived and
      pinned; commit 37dbf50)

## Regrouping decided at the context budget

Small items are paired so each pair runs one RED, one test review, one GREEN and
one code review: Items 2.1 + 3.1; Items 6.1 + 6.2. Items 4.1, 5.1 and 5.2 run as
one general dispatch pair (Sonnet implementer, Sonnet review); Items 7.1 to 7.7
as one docs dispatch with a review. Models as in the table above, except that
GREEN of a pair runs Haiku only where both items are Haiku rows.
- [x] Item 1.2 (Sonnet): RED `item-1-2-red.md`, test review
      `item-1-2-test-review.md`, GREEN `item-1-2-green.md` (commit d16cbb5),
      code review plus Phase 1 boundary check in one dispatch
      `item-1-2-code-review.md` (three survivors pinned; commit 1c5fd42).
      Phase 1 is done.
- [x] Items 2.1 + 3.1 (paired group): RED Sonnet `item-2-1-red.md`, test review
      Sonnet `item-2-1-test-review.md` (helpers moved, cases deepened), GREEN
      Haiku `item-2-1-green.md` (commit 1dedc30), code review Sonnet
      `item-2-1-code-review.md` (8 mutations, 1 survivor), Haiku pin
      `item-2-1-pin.md` (commit 6f687b3), Sonnet pin re-check
      `item-2-1-pin-review.md` (one BSD-stubs case added)
- [x] bash 3.2.0 rebuilt (`item-0-bash32-rebuild.md`); Item 4.1 Sonnet
      `item-4-1.md` (3.2.0: 31.7 s to 3.5 s; commit 13610c0); Items 5.1, 5.2
      Haiku `item-5-1.md`, `item-5-2.md` (commits 3826e88, 2a8e750); Sonnet
      review of all three `item-4-1-review.md` (2 equivalent mutants, 1 real
      survivor), Haiku pin `item-5-2-pin.md` (commit 2dba8d4), Sonnet re-check
      `item-5-2-pin-review.md`
- [x] Items 6.1 + 6.2: RED Sonnet `item-6-1-red.md`, test review Sonnet
      `item-6-1-test-review.md`, GREEN Haiku `item-6-1-green.md` (commit
      5b9ef00), code review Sonnet `item-6-1-code-review.md` (3 survivors, all
      in guards the reviewer added), Haiku pin `item-6-1-pin.md` (commit
      c2e7a81), Sonnet re-check `item-6-1-pin-review.md`
- [x] Items 7.1 to 7.7: docs dispatch and review done (`item-7-docs.md`,
      `item-7-docs-review.md`)
- [x] Review gate (`review-code.md`, `review-design.md`,
      `review-code-decoder.md`), triage, tdd audit (`tdd-audit.md`), run
      summary (`run-summary.md`). Build complete; the deliverable review is next
      and is not part of this run.

Minor pass complete; see `reports/minor-pass-summary.md`.
