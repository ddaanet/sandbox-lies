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
- [ ] Item 4.1 + 5.1 + 5.2: bash 3.2.0 rebuild first

## Resume

Stopped at my human partner's request ("enough for now"). Last commit:
`1c5fd42` (Item 1.2 code-review fixes and Phase 1 boundary review). Done:
entry gate, recall, Item 0, Items 1.1 and 1.2 with all four dispatches each.

**In flight: the paired group Items 2.1 + 3.1, at the test-review step.** The RED
tests are uncommitted in the tree, by design (RED commits nothing):

- `tests/probes-readonly-resolve.bats` (new, untracked) and the Item 3.1 edit in
  `tests/verdicts.bats`;
- the RED report `plans/sandbox-lies-review-fixes-3/reports/item-2-1-red.md`
  (untracked). Four Item 2.1 cases and two Item 3.1 cases fail on their
  assertions against the unchanged `lib/`; three regression cases are green and
  carry mutation proofs. `lib/` is unchanged and no `# MUT` edit remains.

A stalled first RED agent and its replacement both wrote this group: the second
agent's report overwrote the first's, and it left the first's two test files in
place. The test review should read both files whole.

Next steps, in order, for the group (the regrouping above holds):

1. Test review (Sonnet `edify:corrector`, report `item-2-1-test-review.md`).
2. GREEN (Haiku `edify:test-driver`, both items' lib changes: section B in
   `lib/probes-readonly.sh`, section C in `lib/verdicts.sh:16,22`), one commit,
   reports `item-2-1-green.md`; stage the RED and test-review reports with it.
3. Code review with mutation testing (Sonnet), report `item-2-1-code-review.md`.
4. Items 4.1, 5.1, 5.2 as one general dispatch pair (4.1 needs the bash 3.2.0
   binary at `/tmp/claude/bash32/bash`; rebuild per `evidence.md` if `/tmp` was
   cleared), then Items 6.1 + 6.2 (RED, review, GREEN, review), then Items 7.1
   to 7.7 (one Sonnet docs dispatch plus a review; `docs/design.md` must not
   grow past 400 lines).
5. Review gate over `git diff --name-only d6d0043173f6a692cc5d2e2a74d7e83c0710ab44`
   (baseline in `tmp/build-baseline`; `tmp/` is excluded locally through
   `.git/info/exclude`), triage feedback, then `edify:tdd-auditor` over the
   slice reports, then the run summary.

Decisions given: the model rule and grouping in the plan above; the Phase 1
boundary review was folded into the Item 1.2 code review. Dispatch lesson: a
subagent can stall silently on a classifier prompt (no file change for an hour);
check file mtimes and the agent's output-file mtime, then `SendMessage` it or
dispatch a replacement. A background wait is
`/tmp/claude/wait-report.sh <report-name>` (recreate if `/tmp` was cleared: poll
for the report file, then print it).

State on 2026-10-11, before the build resumed: `/tmp` was cleared, so
`/tmp/claude/bash32/bash` and `/tmp/claude/wait-report.sh` are both gone. Rebuild
the binary before Item 4.1 (recipe in `evidence.md`; the source comes from
`ftp.gnu.org`, which the rebuilding Bash call lists in `allowed_domains`).

Carry list: the `memory/ddaanet/sandbox-effects.md` opening-paragraph reword is
done (the file keeps its leak and zellij sections), so the Item 7.1 FR-10
rewrite of `docs/design.md` can rely on it; nothing under `memory/` is edited by
this build. The
deliverable review follows the build: `/deliverable-review
plans/sandbox-lies-review-fixes-3`, range `2309ae6..HEAD`.
