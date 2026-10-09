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
