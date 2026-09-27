# TDD Process Review: sandbox-lies

**Date:** 2026-09-27T20:28Z
**Runbook:** plans/sandbox-lies/runbook.md
**Commits analyzed:** e873bf4..0df5864 (186 commits)

**Verdict: compliant with findings.** There are no critical violations: no
GREEN dropped, renamed or relocated a reviewed test, and no commit carries a
later item's work. There are six Important findings and eight Minor ones.

## Executive Summary

Every tdd slice has its reports, and every report resolves to exactly one
adding commit. There were 48 RED → test review → GREEN cycles across Items
2.1–2.4, 4.1–4.3, 6.1 and 8.0. Each RED either failed on assertions or named a
mutation per passing test, and every one of the 48 test reviews found and
fixed at least one weakness in the tests. The per-slice discipline is strong.

The violations are at the edges of that loop:

- Phase 4 put several slices into one commit without revising the runbook.
- Two GREENs edited a test file.
- Commits 0492468 and 01169db left the gate red. The 4.1/7–4.1/9 commits carry
  a suite-green claim that a later run contradicted, and nobody has explained
  the difference.
- Behaviour reached tdd-item code outside any slice: verdict wording commits,
  and code reviews that shipped untested fixes for later slices to pin by
  mutation.

Key recommendations:

- Record every batch or merge as a runbook list revision.
- Route test edits needed at GREEN back through `blocked:`.
- Never commit past a red gate.
- Send behaviour-changing review fixes back through RED.

## Per-Slice Compliance

Key: **red n** means n new tests failed on assertions. **mut n** means n
passing tests were each proven by a named mutation. **TR** is the test review;
"repro" means it reproduced each proof with a different mutation. The slice
commit is the one that adds the GREEN report. For 2.4/11, which has no GREEN,
it is the one that adds the RED report.

| Item/slice | RED evidence | Test review | One slice commit | Tests unmodified | Issues |
|---|---|---|---|---|---|
| 2.1/1 | red 2 | still red, 3 fixes | 62c7ecb | yes | none |
| 2.1/2 | red 1 | still red, 2 fixes | 73a85a0 | yes | none |
| 2.1/3 | red 2, mut 1 | repro, still red | 3b7f60f | yes | none |
| 2.1/4 | red 1, mut 5 | repro per test | 32dfb89 | yes | no per-test GREEN sequence (M4) |
| 2.1/5 (5–7) | mut 3, smoke 1 | repro, smoke disposed | d7bca8b | yes | merge recorded (c729f83) |
| 2.2/1 | red 2 | still red | 1387a41 | yes | GREEN one pass (M4); refactor a096d82 separate |
| 2.2/2 | red 1, mut 1 | repro | 1c98418 | yes | none |
| 2.2/3 | red 2, mut 1, guard 1 | guard proven G1–G3 | b30d295 | yes | none |
| 2.2/4 | red 1 | still red | 4d97e12 | yes | none |
| 2.2/5 | mut 8 | repro, suite split | 8981462 | yes | GREEN in session; no CR (test-only) |
| 2.2/6 (6–7) | mut 5 + BSD mut | repro | e9ac99a | yes | GREEN in session; merge recorded (f2b1466) |
| 2.3/1 | red 5, paired negative 1 | still red | 8f5728b | yes | none |
| 2.3/2 | red 3 | still red | 4d382db | yes | GREEN one pass (M4) |
| 2.3/3 | red 1, mut 1 | repro (7 mutants) | 6e25457 | yes | none |
| 2.3/4 (4–5) | mut 3 | repro | 312872c | yes | merge recorded (9ca7778); no CR (test-only) |
| 2.3/6 | red 1, mut 1 | test 2 made genuinely red | 3f9b83a | yes | none |
| 2.3/7 | red 1, boundary 1 | still red, probe table | e708088 | **no** | GREEN edited `tests/hook-cap.bats` (I3) |
| 2.3/8 | red 2, mut 3 | repro | f055e2d | yes | none |
| 2.3/9 | red 1, mut 2 | repro | c15041d | yes | none |
| 2.3/10 | mut 1 | repro (M1–M4) | 0792e22 | yes | GREEN edited runbook.md (M5) |
| 2.4/1 | red 1 | still red | ba86abd | yes | none |
| 2.4/2 | red 1, mut 1 | repro | 24dd64d | yes | none |
| 2.4/3 | red 2, mut 1 | repro | f794592 | yes | none |
| 2.4/4 | red 2 | still red | 7733d5c | yes | none |
| 2.4/5 | red 1, mut 3 | repro | 435bbe4 | yes | none |
| 2.4/6 | red 1, mut 4 | repro | 091abf9 | yes | none |
| 2.4/7 | red 1 | still red | 3beb2f3 | yes | none |
| 2.4/8 | red 3, mut 2 | repro, +3 red | cd14a74 | yes | order 9, 10, 8 recorded (8d6d19f) |
| 2.4/9 | red 1, mut 1 | repro | e75d3b2 | yes | none |
| 2.4/10 | red 1, mut 3 | repro | 57e7277 | yes | none |
| 2.4/11 | mut 3 | repro | 9857dad (RED) | yes | tests only; no GREEN/CR, as expected |
| 4.1/1 | red 5 | still red | 1596bbe | yes | none |
| 4.1/2 (2–3) | red 4 | still red | 333989d | yes | **multi-slice commit, unrecorded (I2)** |
| 4.1/4 (4–6) | red 1, mut 2 | repro | 34362ca | **no** | multi-slice (I2); GREEN edited `tests/verdicts.bats` (I3) |
| 4.1/7 (7–8) | mut 3 | repro | 6e2bf33 | yes | multi-slice (I2); suite-green claim contradicted (I1); follow-up bec03d7 unreported (M1) |
| 4.1/9 | red 5, mut 1 | repro | ccea71a | yes | no code-review report for an implementation change (M2); same I1 question |
| 4.2/1 (1–2) | red 11 | still red | 003bf4e | yes | multi-slice (I2) |
| 4.3/1 | red 4, mut 5, quiet 1 | quiet case pinned | d3d0ca3 | yes | carries 4.2's gaps (recorded, ed3a98d) |
| 4.3/2 (2–5) | red 5, mut 1 | repro | a2d802d | yes | multi-slice (I2); vacuous case missed (M8) |
| 6.1/1 | red 7, mut 2 | repro, per half | 5435c30 | yes | refactor d7a2c2b separate |
| 6.1/2 | red, no pass | still red | fea0fdd | yes | planned retirement of `hook silent without a verdict` |
| 6.1/3 | red 4 | still red | 94cf362 | yes | followed by out-of-slice wording change eddd452 (I4) |
| 6.1/4 | red 1 | still red | 80ba74d | yes | none |
| 8.0/1 | red 6 | still red | 0492468 | yes | **committed with precommit red (I1)**; GREEN one unit (M4); split 89e6824 (M1) |
| 8.0/2 | red 8, mut 1 | repro | 3fcd18b | yes | none |
| 8.0/3 | red 13 | still red, 14th red | 896a212 | yes | CR shipped 4 untested fixes (I5) |
| 8.0/4 | mut 6, outcome pin 1 | split 7 → 12, own mutation each | dcb55ce | yes | 7 of 12 tests carry one proof (I6); CR written by orchestrator |
| 8.0/5 | red 3, mut 1 | repro | c46241e | yes | spec and fixtures ahead in f05d3a8 (M6) |

Code-review commits: every `item-*-code-review.md` is added by exactly one
commit, and each lands after its slice commit. Refactor commits a096d82 and
d7a2c2b land after their slices' code reviews, and neither amends the slice
commit.

## Violations

### Important

- **I1 — commits left the gate red.**
  - `0492468` (8.0/1 GREEN). `item-8-0-s1-green.md` §`just precommit` records
    `oversized-file: tests/verdicts.bats: 468 lines > 400`. The report names
    that as out of GREEN's scope, and the commit went ahead anyway. `89e6824`
    split the suite afterwards.
  - `01169db` (Item 8.1, general). It fired `readonly-path` in `docs.bats`,
    and `45c0316` fixed it (`build-phase-8b.md` §Deviations).
  - `6e2bf33` and `ccea71a`, the Item 4.1 slices 7–9. The GREEN reports
    `item-4-1-s7-green.md` and `item-4-1-s9-green.md` record `147`/`148
    passed`. Against that same `HEAD`, `item-4-2-s1-green.md` §Blocker shows
    `probe reads the result text on stdin` failing: bats' `run` unsets the
    caller's `stderr` local. `build-phase-4.md` says why it passed at its own
    commit "was not established". So either those commits were red, or the
    reported green came from a different bats. Neither was verified.
- **I2 — multi-slice commits with no runbook list revision.**
  - `333989d` covers 4.1 slices 2–3, `34362ca` covers 4–6, and `6e2bf33`
    covers 7–8.
  - `003bf4e` covers 4.2 slices 1–2, and `a2d802d` covers 4.3 slices 2–5.
  - The runbook's Item 4.1–4.3 slice lists still read as one slice per cycle.
    The batching is recorded only in `build-phase-4.md` §Deviations and in
    commit subjects. Item 4.3's extra probe cases are also not in the runbook:
    `relative path resolves against cwd`, `existing file checks the file
    itself`, `first quoted path on the line` and `quoted path off the matching
    line is ignored`.
  - Contrast: the 2.1/5, 2.2/6 and 2.3/4 merges were recorded (c729f83,
    f2b1466, 9ca7778).
- **I3 — GREEN edited a test file.**
  - `34362ca`: `tests/verdicts.bats` +1 −1, the config-lock `mask`
    transcription. The test review recommended the edit
    (`item-4-1-s4-test-review.md` §Recommendations). The GREEN report lists
    `tests/verdicts.bats` among its three edited places and also says "No test
    file edited", so the report contradicts itself. The same GREEN also edited
    the spec (`docs/references/lock-detectors.md`).
  - `e708088`: `item-2-3-s7-green.md` §Test-file fix restored `load
    helpers/bsd-stubs`, which the test review had removed.
  - Both edits are benign in content. The prohibition is absolute, though, and
    each should have gone back as `blocked:` or into the test review.
- **I4 — behaviour changed in tdd-item code outside any slice.**
  - `eddd452` rewords `verdict_readonly_path` and its transcription test in one
    commit, between 6.1/3 and 6.1/4. It has no RED, test review or code review.
  - `09179d3` is the Phase 7 verdict rework. It changes `lib/verdicts.sh`, the
    transcription tests and `hook-candidates.bats`. Its premise suite
    (`tests/verdict-premises.bats`) is recorded red-first in
    `build-phase-7.md`, but the verdict text change has no RED.
  - Both are recorded in phase reports (`build-phase-6.md` item 10,
    `build-phase-7.md` §Verdict rework), not as runbook items or slices.
- **I5 — code reviews ship untested behaviour, and later slices pin it by
  mutation.**
  - Eight of the 48 cycles are wholly mutation-proven: 2.1/5, 2.2/5, 2.2/6,
    2.3/4, 2.3/10, 2.4/11, 4.1/7 and 8.0/4. Most of them pin fixes an earlier
    code review already committed (e.g. 2.1/1 CR `6b3e7c6` → 2.1/4–5; 2.2/1
    CR `6a348da` → 2.2/5; 2.3/6–8 CRs → 2.3/8–9; 2.4/8 CR `6e5501c` →
    2.4/11).
  - The largest is `b56fe5b` (8.0/3 CR). It adds
    `lib/probes-readonly-command.sh` (+234) and rewrites
    `lib/probes-readonly-facts.sh` (+162 −253), fixing four defects GREEN's
    tests missed.
  - The pins that followed were weaker than a red would have been. The 8.0/4
    test review found that RED's central pin (index untouched) could not red
    on the defect it named (`item-8-0-s4-test-review.md` Critical 1).
- **I6 — 8.0/4 lacks a second, independent proof for 7 of its 12 tests.**
  - RED proved 7 tests with 6 mutations. Its test 3 bundled four cases, and its
    mutation redded only the tag-on-a-tree case. Its test 6 bundled three, and
    only fetch↵merge redded.
  - The test review split these and proved every one of the 12, but with the
    only proof for several:
    - tag on a blob, missing gitdir, unborn HEAD, heredoc body, cat↵rm;
    - `git pull`, where RED had no mutation;
    - test 1, whose RED proof the test review showed never reached the defect.
  - Every test is non-vacuous. The "different mutation, per named test"
    reproduction is missing for these seven.

### Minor

- **M1 — marker commits with no report of their own.** `bec03d7` (`Item
  4.1/7`, a test-local rename) has no report. `89e6824` (`Item 8.0/1`, suite
  split) is described by `item-8-0-s1-split.md`, but that report rides
  `67a4c6e`, the code-review commit, not the commit it describes.
- **M2 — no code-review report for a slice that changed implementation.**
  `ccea71a` (4.1/9) changes `hooks/annotate.sh`. `build-phase-4.md` records a
  self-review with no report. The test-only slices have no code-review report
  either: 2.2/5, 2.3/4, 2.4/11 and 4.1/7. 8.0/4, by contrast, wrote a
  stand-in report (`002f674`).
- **M3 — orchestrator ran GREEN in session.** This happened for 2.2/5, 2.2/6,
  2.3/4, 4.1/7 and 4.1/9. Four were test-only. 2.2/6 wired the justfile and
  had a code review; 4.1/9 had none (M2).
- **M4 — test-at-a-time not evidenced.** Three GREEN reports state one-pass
  growth: `item-2-2-s1-green.md`, `item-2-3-s2-green.md` and
  `item-8-0-s1-green.md` ("grown as one unit"). `item-2-1-s1-green.md`,
  `-s2-` and `-s4-` record no per-test sequence. Each one-pass report gives a
  shared-code-path reason.
- **M5 — GREEN edited planning or spec artefacts.** `0792e22` (2.3/10) edits
  `runbook.md` slice text, which is the orchestrator's list-revision duty.
  `34362ca` edits `lock-detectors.md` (see I3).
- **M6 — tests committed outside a slice.** `f05d3a8` (8.0/5 spec) adds two
  `tests/matchers.bats` fixture cases that are green on arrival and have no
  mutation proof. They are fixture-coverage expectations and low risk.
  `f7b3d4b` (Item 8.1, a general item) adds `tests/shim.bats` together with the
  shim.
- **M7 — refactor signals folded into later GREENs.** Two refactors went into
  GREEN commits rather than getting commits of their own. The 2.3/1 CR's
  jq-read fold went into 2.3/6 GREEN `3f9b83a`. The 2.4/5 CR's shared-helper
  lift went into 2.4/8 GREEN `cd14a74`, as recorded in the runbook Item 2.4
  slice 8 text.
- **M8 — a vacuous test passed RED and test review.** `hook silent without a
  verdict` (`a2d802d`) was green when nothing fired. It was caught by the
  Phase 4 corrector (`phase-4-corrector.md` Major 1) and fixed in `a1d1c44`.

## List Revisions

The runbook's history holds these list-revision commits, each after the named
slice:

- **2.1:** 0311db1 (/1), cdc1006 (/2), 7190467 (/3), c729f83 (/4 — merged
  5–7), eb4e0ee (/5), db8832b.
- **2.2:** 2d431a2 (before /1), 920300f (/1), cbb3f07 (/2), 0b12b3c (/3),
  c03d05a (/4), f2b1466 (/5 — merged 6–7), e59e960 (/6).
- **2.3:** 23da2d3 (/1), 59aff40 (/2), 9ca7778 (/3 — merged 4–5), 2328cf4
  (/6), c342ca5 (/7), f44b5b9 and ce00027 (/8). `0792e22` edits slice 10's
  text inside the GREEN commit (M5).
- **2.4:** ccbf26a (/1), 08b6f36 (/2), da5dde2 (/3), 7cf0107 and 23534ed
  (/4), e3a3885 (/5), 31124cf (/6), 1aaac7f (/7), b8d216a (/9), 8d6d19f (gate
  answered), 2a0f04b (/8 — slice 11 added), e263bbd (checkpoint).
- **4.1:** 686eea2 (before /1). The five-cycle batching is not recorded (I2).
- **4.3:** ed3a98d (before /1). The 2–5 batching is not recorded (I2).
- **6.1:** 38dd85c (before /1), 36f642e (/1 — verdict rows split so 6.1/3
  keeps a red).
- **8.0:** d44a360 (spec), 2e4d287 (/1), 8162344 (formatter undo), 7a7fd4d
  (/3 — slice 4 added), f05d3a8 (slice 5 added).

The Phase 4 and Phase 6 memory-retirement deferrals depart from the runbook's
"same commit" rule. They are recorded in `build-phase-4.md` and
`build-phase-6.md`, not in the runbook.

## Code Quality Observations

- **Tests.** The reviews show uniform rigour:
  - exact-output assertions under `run --separate-stderr`;
  - every bare negative paired with a positive control (e.g.
    `item-8-0-s4-test-review.md` Major 3, `item-2-2-s5-test-review.md`
    finding 2);
  - probe tables of plausible wrong implementations (`item-2-3-s7-test-review.md`,
    `item-2-4-s5-test-review.md`);
  - a `git diff --quiet` restore proof after every mutation;
  - self-quiet diagnostic text built from fragments.
- **Test-review catches that changed the outcome.**
  - A decorative index pin (8.0/4).
  - A symlink-keyed `mask` probe passing the chardev test (2.4/5 Major 1).
  - An unanchored exclusion passing 2.1/4's fixtures.
  - A `mktemp`-with-fallback GREEN passing both temp-dir tests (2.3/8 F1).
  - A self-quiet breach in `tests/hook-locks.bats` (4.1/7 Critical 1).
- **Bats hazard.** A local named `stderr` is unset by `run`. It is fixed in
  `bec03d7`; no guard prevents it from recurring.
- **Suite growth against the cap.** Several splits were forced mid-slice:
  - `tests/check-links-edges.bats` (2.2/5);
  - `tests/probes-edges.bats`, `-tools`, `-config` (2.4);
  - `tests/verdicts-locks.bats` (8.0/1);
  - `tests/probes-readonly-pins.bats` (8.0/4).

  The 8.0/1 split is the one that reached a commit over the cap.

## Recommendations

### Important

1. **Record batching as a list revision.**
   - Issue: Phase 4 batched slices without touching the runbook (I2).
   - Impact: the runbook no longer describes what ran, and one-commit-per-slice
     cannot be audited from it.
   - Action: before a batched cycle, commit a runbook revision naming the batch
     and the reason, as c729f83 and 9ca7778 did.
   - Where: build skill orchestration step for slice dispatch; runbook Items
     4.1–4.3 retroactively.
2. **Never commit past a red gate.**
   - Issue: 0492468 and 01169db (I1).
   - Action: a GREEN whose precommit fails on a test-file concern (line cap,
     self-quiet) returns `blocked:`. The orchestrator then splits or fixes the
     tests before the GREEN commit, as the 4.2/1 GREEN did correctly.
   - Where: GREEN dispatch contract in the build skill.
3. **Settle suite-count discrepancies.**
   - Issue: the 4.1/7 and 4.1/9 green claims were contradicted by 4.2/1 (I1).
   - Action: the GREEN report records the bats binary and version it ran. When
     a later dispatch finds a test red at `HEAD`, re-run the earlier commit's
     tree to settle whether that commit was red.
   - Where: `build-phase-4.md` open item; GREEN report template.
4. **Route test edits through the test side.**
   - Issue: I3.
   - Action: when a test review foresees that GREEN must change a test, it
     makes the edit itself, or the RED changes the spec and transcription
     first. A GREEN that needs one returns `blocked:`.
   - Where: test-review report "Recommendations for GREEN" sections; GREEN
     contract.
5. **Behaviour-changing review fixes go back through RED.**
   - Issue: I5.
   - Action: a code-review finding that changes behaviour becomes a follow-up
     slice whose RED is written before the fix. Otherwise the reviewer commits
     the failing test first.
   - Impact: this turns eight mutation-only cycles into genuine reds and
     avoids pins like 8.0/4's first index test.
   - Where: code-review dispatch contract.
6. **Changes to tdd-item code after the item closes run as slices.**
   - Issue: eddd452 and 09179d3 (I4).
   - Action: add them as runbook slices, as Phase 8 did with Item 8.0.

### Minor

1. Every marker-bearing commit gets its own report added in that commit
   (bec03d7 has none; `item-8-0-s1-split.md` rode the wrong commit) (M1).
2. Always write a code-review report. Where no implementation changed, write
   the 8.0/4 stand-in; a one-line change still gets a dispatched review
   (4.1/9) (M2).
3. When a test review splits bundled tests, it proves each resulting test.
   RED's proof for the bundle does not carry over. Where only one proof
   exists, say so (8.0/4) (I6).
4. GREEN reports record the per-test order, or state the shared-path reason
   for growing in one pass (M4).
5. Keep runbook and spec edits out of GREEN commits (M5).
6. Give refactor signals their own refactor commit even when the refactor is
   deferred (M7).

## Process Metrics

- Slices executed: 48 RED/review/GREEN cycles covering 60 planned slices.
  - 2.1: 5 cycles over 7 slices. 2.2: 6 over 7. 2.3: 9 over 10. 2.4: 11.
  - 4.1: 5 over 9. 4.2: 1 over 2. 4.3: 2 over 5.
  - 6.1: 4. 8.0: 5.
- Fully compliant cycles: 39 of 48. The nine that are not: 2.3/7, 4.1/2,
  4.1/4, 4.1/7, 4.1/9, 4.2/1, 4.3/2, 8.0/1 and 8.0/4.
- Cycles proven wholly by mutation: 8 (2.1/5, 2.2/5, 2.2/6, 2.3/4, 2.3/10,
  2.4/11, 4.1/7, 8.0/4).
- Wrong-reason tests caught at test review: all 48 test reviews fixed at least
  one test weakness. Each finding is in the review's Findings or Issues
  section.
- Reports per item (RED / GREEN / code review / refactor):
  - 2.1: 5/5/5/0. 2.2: 6/6/5/1. 2.3: 9/9/8/0. 2.4: 11/10/10/0.
  - 4.1: 5/5/3/0. 4.2: 1/1/1/0. 4.3: 2/2/2/0.
  - 6.1: 4/4/4/1. 8.0: 5/5/5/0.
  - Each cycle also has a test-review report.
- GREEN run in session by the orchestrator: 5 (2.2/5, 2.2/6, 2.3/4, 4.1/7,
  4.1/9).
