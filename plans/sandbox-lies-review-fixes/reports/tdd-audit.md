# TDD Process Review: sandbox-lies-review-fixes

**Date:** 2026-10-06
**Runbook:** plans/sandbox-lies-review-fixes/runbook.md
**Commits analyzed:** 0a5dc8e (Item 4.1/1 GREEN) .. 93c4020 (Item 5.5/1 pins). Build baseline `a7ff5e5`. The range also holds general-phase commits (Items 5.1-5.3) and the main session's plugin-dev commits; these were not audited.

## Executive Summary

Nine tdd slices ran (4.1/1-4, 4.2/1, 4.3/1-2, 5.4/1, 5.5/1). Every slice has all four reports. Every RED, test-review and GREEN report for a slice rides one commit, and every code-review report rides its own commit. No reviewed test was dropped or renamed by a GREEN. Six slices are fully compliant. Three carry findings, none critical. Slice 4.2/1's GREEN edited existing test files (runbook-sanctioned migration). Slice 4.3/2's GREEN report records no full-suite result. Slice 5.5/1's GREEN was dispatched while its test review was still finishing, and its test file moved to a file the runbook does not name, with no recorded revision. Recommendations: record the migration case in the GREEN contract, require a suite line in every GREEN report, and record file-placement changes as list revisions.

## Per-Slice Compliance

Slice commit means the commit adding the GREEN report (RED report where no GREEN exists; none was needed). Each carries RED, test-review and GREEN reports, tests and implementation. Each also has exactly one separate code-review commit.

| Item/slice | RED evidence | Test review | One slice commit | Tests unmodified | Issues |
|---|---|---|---|---|---|
| 4.1/1 | 2 tests red on assertion; the 3rd (`awk -vout=`) added by review, red | Ready; still-red table; 2 scratch mutations | 0a5dc8e (review 45504f6) | Yes, all 3 ids present | none |
| 4.1/2 | 3 red on assertion; guard `sed s/a/b/ in.log still gives the input` passes by design | Ready; 3 majors, 3 new red cases; 8-variant scratch table | 095260b (review 300bb10) | Yes, all 7 ids present | Guard passes with no mutation proof; the test-review disposition ("guard passes as intended") is its only cover (minor) |
| 4.1/3 | 3 red (test 16's named form cannot red, a glued run does); test 17 passes, mutation-proven | Ready; test 17 re-proven with a different mutation; new two-`-f` run added | feabde8 (review 9fa5495) | Yes, all 4 ids present | GREEN made tests 14-16 pass "together" (one edit); no per-test sequence |
| 4.1/4 | Test 18 red; test 19 passes, mutation-proven | Ready; test 19 re-proven with a different mutation, 2 more proofs after review fixes; test 18 positive proven | b5a5ac8 (review b7e97db, pins f268236) | Yes, both ids present; test 18 renamed at review, GREEN report still cites the old title | none |
| 4.2/1 | 2 red on assertion | Ready; 2 majors fixed; 5-mutant table | f415d82 (review 040ba39, pins 2079d07) | New tests unedited; GREEN edited existing test files (migration) | GREEN edited four test files (see V1) |
| 4.3/1 | 2 red on assertion | Ready; 2 majors fixed (matcher/timeout pinned, cwd) | bed3d89 (review ee75f23) | Yes, both ids present | none |
| 4.3/2 | 3 red on assertion | Ready; 2 majors + 2 minors fixed; 8-candidate table | 88a6612 (review 65bd612) | Yes, all 3 ids present | GREEN report has no full-suite or gate result (see V2); cases made to pass together |
| 5.4/1 | 1 test red (one assertion; its blank half passes within the same test) | Ready; major fixed (absolute-path half kills a cwd-keyed guard) | 6a6c7b4 (review 6d1251a) | Yes, id present | none |
| 5.5/1 | 4 red on `<b>` assertions; test review grew it to 6, all red | Ready; 5 gaps fixed; 8 wrong GREENs each red | 07627d4 (review 120a7de, pins 93c4020) | Yes, all 6 ids present | Test review still running when GREEN dispatched (V3); test file not the runbook's (V4) |

## Violations

None critical. Each finding below is traced to a commit or report.

- **V1 (Important), Item 4.2/1, check 3: GREEN edited test files.** `reports/item-4-2-s1-green.md` records migrating existing assertions to `"match=$repo/<name>"` (negatives included) in `tests/probes-readonly-facts.bats`, `tests/probes-readonly-pins.bats` and `tests/probes-readonly-members.bats`. Commit f415d82 diff: probes-readonly-facts.bats (18 lines), probes-readonly-pins.bats (10), probes-readonly-members.bats (30). Under the audit's strict reading this is a violation: the report "records that it edited a test file". Mitigations: the runbook (Phase 4, Item 4.2 slice 1) says "In the same GREEN every existing probe-output `match=` assertion moves to the absolute form", and the test review gave the exact migration list. The two new reviewed tests were left unedited, and the only renamed id is the pre-existing `git switch feat in a scratch repo gives target=feat and an absolute match=`, planned in the review's migration list. The tension is that the test review could not migrate the old assertions without turning the suite red before GREEN, so the migration fell to GREEN.
- **V2 (Minor), Item 4.3/2, check 2: no suite result in the GREEN report.** `item-4-3-s2-green.md` records only `bats tests/check-jq.bats: 4/4 ok` and shellcheck. The two other GREEN reports whose suite line is thinly worded (4.2/1, 4.3/1) at least carry a trailing "Precommit: exit 0" or "Full suite" line. Nothing in the 4.3/2 report confirms the suite was green at commit 88a6612. The delegate status notes that a refused GREEN report Write can drop a report, but this report exists. The suite is confirmed green only indirectly, by the next commit's gate (65bd612's review report records a passing `just precommit`).
- **V3 (Important), Item 5.5/1, sequencing: GREEN dispatched during the test review.** Recorded by the orchestrator in `delegate-status.md` (2026-10-06 bullet): the test review "was still running final checks when GREEN was dispatched"; the test file was 174 lines in both runs, and 07627d4 carries a 174-line `tests/probes-lock-newline.bats`. I could not verify unchangedness from git, since the reviewed test is first committed in GREEN. The report-to-commit evidence is consistent: all six test-review ids are present in the commit. The violation is of ordering (test review gates GREEN), not of content.
- **V4 (Minor), Item 5.5/1, list revisions: unrecorded file-placement divergence.** The runbook text names `tests/probes-config.bats` for Item 5.5. The tests went to the new `tests/probes-lock-newline.bats`, because `probes-config.bats` is 313 lines and would pass 400 (`item-5-5-s1-red.md`). `grep` for `probes-lock-newline` in `runbook.md` finds nothing, and the runbook's history ends with a3cd736 (Item 5.5 added). The pin dispatch also created `tests/hook-locks-pathless.bats`. Item 4.2's equivalent placement change was recorded (list revision at the Phase 4 checkpoint, commit 43c1711); this one was not.
- **V5 (Minor), Item 4.1/2 refactor, check 4: a new test inside a refactor commit.** 335d82e (`item-4-1-s2-refactor.md`) is separate and lands after the slice and code-review commits, as required. It also adds a new case, "the operand rule survives BSD grep, sed, stat and wc", with no RED or mutation record; the report counts it in "22 across both files". A refactor commit should not add behaviour-pinning tests. The case was a CLAUDE.md BSD-stubs obligation for the new file.
- **V6 (Minor), test-at-a-time not evidenced.** Slices 4.1/3 (tests 14-16), 4.3/2 (cases 2-4) and 5.5/1 (all six) record that the tests went green together from one edit. The reports give reasons (one rule, one guard, six print sites). Git cannot show intermediate steps. Not a content violation, but the discipline is unauditable here.

Not violations (checked):

- **One green commit per slice:** each `git log --diff-filter=A` on a GREEN report returned exactly one hash. No GREEN report is missing.
- **Marker accounting:** every `Item N.M/k` commit in the range is accounted for by a report: GREEN, code-review, refactor (4.1/2) or pins (4.1/4, 4.2/1, 5.5/1). Pre-job commits (e.g. 34362ca "Item 4.1/4", from an earlier job's numbering) share the marker string. The audit range was limited to commits after the build baseline to avoid that collision.
- **Code-review fixes with no test:** 4.1/3 (pinned by test 19 under the slice-4 list revision, mutation-proven), 4.1/4 (pinned by f268236, four mutations), 4.2/1 trailing slash (pinned by 2079d07, mutation) and 5.5/1 Major 1 (pinned by 93c4020, four mutations). Code-review fixes in 4.1/1, 4.1/2 and 4.2/1 (newline) carry tests written red-first inside the code-review commit.
- **Suite red at any commit:** none indicated by any GREEN report or commit message, apart from V2's missing evidence.
- **Scope compliance:** no later item's work product appears in an earlier commit. Item 5.4 and 5.5 GREEN commits carry the item's own docs and changelog edits, as each item's `Docs (same item)` line directs.
- **Mutation proofs counted per test:** 4.1/3 test 17 (RED mutation: delete `pat=0`; review: self-assign `pat=$pat`). 4.1/4 test 19 (RED: `2:*'<'*)` arm; review: `${word#<}` and `x${word%%<*}`). Every test passing at RED has a proof, or a guard disposition (4.1/2 test 15; 4.1/4 test 18's positive half, which the review proves with the `uniq:-c` mutation).

## List Revisions

- 4.1: revision after slice 2 (1b81266: slices 3-4 tests go to `probes-readonly-operands.bats`) and after slice 3 (bd3f4c1: reset pin in slice 3; `<` redirection pin in slice 4; docs residuals). Both are in the runbook history. After slice 4: none, per delegate-status.
- 4.2: placement of the hook case in `hook-writes.bats`, recorded at the Phase 4 checkpoint (43c1711).
- 4.3: revisions after slice 1 (e0caf2a: no matcher, 10 s timeout) and after slice 2 (5b0f750).
- 5.4: none (single slice). 5.5: none recorded, but placement diverged (V4).
- 4.1/1 and 4.1/2's GREEN did not change the remaining list. 4.1/3 GREEN (implemented only the tested `-e`/`-f` forms) moved clustered and long forms to docs residuals; recorded in the runbook.

## Code Quality Observations

- **Test review is doing real work.** It found a wrong-reason or narrow-GREEN gap in 9 of 9 slices (counts below). Typical shape: a plausible narrow GREEN (cwd-keyed guard, skip-by-position, per-command instead of per-segment reset) passed the RED tests. Reviews proved this with scratch-copy variant tables (4.1/2, 4.2/1, 4.3/2, 5.5/1) rather than assertion by reading.
- **Whole-output equality** in 5.4 and 5.5 (`[ "$output" = ... ]`) rules out forged lines by construction; the blank twin (`<g>` vs `<b>`) kills over-broad guards. This is strong test design.
- **RED reports are honest about vacuity.** 4.1/2 swapped a vacuous `awk /x.log/` case; 4.2/1 recorded a vacuous first needle; 5.5 pins recorded a vacuous first draft of case 3 (literal backslash-n).
- **Stale name in a report.** `item-4-1-s4-green.md` cites test 18 by its pre-review title; the committed title is "uniq with a second operand is a writer, uniq in.log is not". Cosmetic, but a name-based audit must follow the test-review report, as this one did.
- **Residual unpinned site:** 5.5's `gone` print after a vanish between the presence test and `stat` (lib/probes.sh, site 120) has no deterministic trigger; the runbook records it as a residual covered by the one guard.
- **Load flake:** the delegate status notes `probes-readonly-pins.bats` "nopath with a relative cwd" timing out once under load; not a process defect.
- **BSD re-run obligation** was met in every new file (check-jq.bats, probes-lock-newline.bats, hook-locks-pathless.bats, probes-readonly-operands.bats).

## Recommendations

### Critical

None.

### Important

1. **Settle who migrates old assertions when GREEN changes an output format.** Issue: V1. Impact: the runbook mandates a GREEN edit that the TDD rules forbid, so every such item reads as a violation. Action: either have the test review perform the migration against the unchanged SUT (assertions that the SUT cannot yet satisfy stay red, forming part of RED), or state in the runbook and the GREEN prompt that "migration of pre-existing assertions named in the runbook is the single permitted test edit, listed in the GREEN report". Section: runbook Item 4.2 slice 1; `plugin/skills/build/references` GREEN prohibition.
2. **Never dispatch GREEN before the test-review report is final.** Issue: V3. Action: the orchestrator waits for the review's handback (not the report file's existence) before dispatching GREEN; where a report file appears early, verify with a content hash of the test file taken at review completion and again at GREEN dispatch.

### Minor

3. **Require a suite result line in every GREEN report.** Issue: V2 (`item-4-3-s2-green.md`), and 4.2/1, 4.3/1 which say "see result line below". Action: make "Full suite: N passed, 0 failed; gate line" a mandatory field, written by the GREEN agent, so the audit's red-suite check never rests on a later commit.
4. **Record file-placement changes as list revisions.** Issue: V4. Action: when a test lands in a file other than the runbook's, commit a one-line `runbook.md` revision as 4.1 and 4.2 did. Section: Item 5.5, Tests line.
5. **Keep refactor commits test-free.** Issue: V5. Action: put the BSD-stubs re-run for a moved file in the slice's own test review, or cover it as a distinct pin dispatch with its own mutation proof.
6. **Record per-test order where tests are made green one at a time is possible.** Issue: V6. Action: where several tests fall to one edit, the GREEN report should say which test would fail first if the edit were split; at minimum keep the current explicit rationale.
7. **Name the final test titles in GREEN reports** (see the stale title in `item-4-1-s4-green.md`).

## Process Metrics

- Slices executed: 9; fully compliant: 6 (4.1/1, 4.1/2, 4.1/3, 4.1/4, 4.3/1, 5.4/1). Slice 4.1/3 carries only the V6 caveat.
- Slices with findings: 4.2/1 (V1), 4.3/2 (V2), 5.5/1 (V3, V4). The 4.1/2 refactor commit carries V5.
- Wrong-reason or narrow-GREEN gaps caught at test review (distinct findings): 4.1/1: 1 major + 2 minor; 4.1/2: 3 major; 4.1/3: 1 major; 4.1/4: 2 major + 2 minor; 4.2/1: 2 major + 1 minor; 4.3/1: 2 major + 1 minor; 4.3/2: 2 major + 2 minor; 5.4/1: 1 major + 1 minor; 5.5/1: 4 major + 1 minor. Totals: 18 major, 11 minor.
- Code-review commits that also changed behaviour: 4.1/1, 4.1/2, 4.1/3, 4.1/4, 4.2/1, 4.3/1 (stub), 4.3/2 (notice text), 5.4/1 (header comment); 5.5/1 changed only the changelog.
- Test-only pin dispatches after code review: 3 (4.1/4, 4.2/1, 5.5/1), each with per-pin mutation proof.
- Dispatches per slice (RED, test review, GREEN, code review, plus extras): 4.1/1: 4; 4.1/2: 5 (refactor); 4.1/3: 4; 4.1/4: 5 (pins); 4.2/1: 5 (pins); 4.3/1: 4; 4.3/2: 4; 5.4/1: 4; 5.5/1: 5 (pins). Plus one docs dispatch each for Items 4.1, 4.2 and 4.3.
