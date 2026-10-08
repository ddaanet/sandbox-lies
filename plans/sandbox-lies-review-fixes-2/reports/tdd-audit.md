# TDD Process Review: sandbox-lies-review-fixes-2

**Date:** 2026-10-08 **Runbook:** none. The route is `/build` on
`plans/sandbox-lies-review-fixes-2/outline.md` (§Execution notes: "with no
runbook"). The slice lists are the outline's, regrouped as recorded in
`delegate-status.md` §Build state. **Commits analyzed:** `72e34d7..9bd925e` (13
commits)

**Counts:** Critical 0 · Major 2 · Minor 5

## Executive Summary

The three tdd slices that ran (Item 1.1 Slice A, Item 1.1 Slice B, Item 2.1
slice 1, ten outline slices in all) follow the discipline mechanically. Each has
exactly one GREEN commit carrying its tests, implementation and its RED,
test-review and GREEN reports. Each also has one code-review commit, and no
marker-bearing commit lacks a report. Every test id the test reviews list is
present, unrenamed, in the GREEN commit. Every red was on an assertion, and
every green-on-arrival test carries a mutation proof that a second dispatch
reproduced with a different mutation. Two findings are major:

- A partial-output discard added by the Slice A code review shipped untested for
  six commits, under a report claiming each fix sat behind a red test. The
  end-of-build review caught and pinned it.
- Four Phase 3 BSD re-run cases rest on one executor mutation each. The phase
  review re-mutated three sibling BSD cases and found two of them blind.

The minor findings concern recording: GREENs that went green in one edit,
orchestrator files riding in slice commits, and no recorded suite result for the
final commit.

## Per-Slice Compliance

| Item/slice | RED evidence | Test review | One slice commit | Tests unmodified | Issues |
|------------|--------------|-------------|------------------|------------------|--------|
| 1.1/A (outline 1, 2, 3, 4, 6) | 7 red on assertion against an inert stub; 2 by mutation (tests 2, 9) | Yes: 4 new cases, 3 hook cases moved to `hook-resume.bats`; reproduced with mutations A, B (different); C, D for never-red stderr lines | `3b3e7fc`; code review `2c39e2e` | Yes: all 13 test-review ids in `3b3e7fc`; `hook-candidates.bats` 378 lines as reviewed | Major 1; Minor 1, 2, 4 |
| 1.1/B (outline 5, 7) | 5 red on assertion; test 3 by mutation | Yes: partials split by id order, SC2030/2031 fixed; M1, M2 (different from RED's); G attributes the flag-true reds | `7fb5960`; code review `ccbe59a` | Yes: all 10 hook ids and the verdict case in `7fb5960`; line counts 163/355/185 as reviewed | Minor 1, 2 |
| 2.1/1 (outline 1, 2, 3) | 5 red on assertion; case 5 by mutation | Yes: cases 7 to 10 added for survivors M2, M3, the BSD rule and quoting; M1 reproduces case 5 | `18a3658`; code review `40d1e95` | Yes: all 10 ids in `18a3658`; failing lines 85, 100, 110, 121, 142 match the review | Minor 1, 2, 4, 5 |
| Phase 3 (general, test-only) | Mutation proof per new assertion (`phase-3.md`) | Phase review: 7 of 11 proofs reproduced; 2 cases blind, fixed | `5c8f065`; review `5165cfc` (no marker, general item) | Moved bodies verbatim into shared functions (checked `check-links`, `probes-edges`) | Major 2; Minor 5 |

## Violations

None at critical severity. No GREEN dropped, renamed or relocated a reviewed
test. No GREEN report records a test edit. No commit carries the pre-staged
handoff files or any untracked path the dispatch rules protect:
`git log 72e34d7..9bd925e -- .claude/ inbox/ .gitlore/` is empty.

### Major

1. **An untested fix landed under a claim of test-first coverage (resolved in
   range).**
   - Slice A code review (`2c39e2e`, `reports/item-1-1-sA-code-review.md` §Major
     1). The fix is `ids=$(LC_ALL=C sed …) || ids=`, so a failed `sed` discards
     partial output. The report states that all four defects are fixed "each
     after a test that reds on its assertion against the slice commit".
   - Its two named tests do not reach the discard. "no id extracted" uses a stub
     that prints nothing to stdout. "invalid byte" passes once `LC_ALL=C`
     applies. The end-of-build review (`reports/review-code-tests.md`, mutation
     A2: `|| ids=` to `|| :`) found the mutation survived all 16 probe cases.
   - Impact: from `2c39e2e` to `9bd925e` the probe could print `found` for an id
     it never tested, the exact false claim `unknown` was added to prevent, with
     no test to catch it.
   - Resolved: `9bd925e` adds "a sed failing after printing an id is unknown",
     red under A2. This review predates the mutation-testing instruction, and
     `delegate-status.md` §Mutation testing schedules it for the end-of-build
     review. The process gap is real: a corrector's own "red first" claim did
     not cover every line its fix added.

2. **Four Phase 3 BSD re-run cases rest on a single, unreproduced mutation (open
   risk, no confirmed defect).**
   - `reports/phase-3.md` §Mutation proof gives one mutation each for the
     check-links, hook-malformed, probes-config and probes-readonly-pins BSD
     cases. `reports/phase-3-review.md` §Mutation proof re-mutates only 3.1a,
     3.1b, 3.2, 3.3, docs, hook-cap and probes-edges. `review-code-tests.md`
     §Not mutated says Phase 3 was "not re-mutated".
   - Evidence of elevated risk: of the three BSD cases the phase review did
     re-mutate, two (docs and probes-edges) were blind to what they claimed.
     Both were fixed in `5165cfc`. The docs proof failed because the executor's
     mutation sat in `detect` and so hit every input. The hook-malformed proof
     uses the same `detect`-level shape. The phase review itself notes that
     check-links' `mktemp` stub "adds nothing".
   - Action: re-mutate each of the four with a GNU-only invocation placed in a
     code path that only its case exercises. Do not use `detect`. Either record
     the red, or fix the case as `5165cfc` did for docs.

### Minor

1. **No GREEN made its tests green one at a time.** The reports record this
   openly, so the test-at-a-time discipline cannot be audited from them:
   - `item-1-1-sA-green.md` says the probe "was written whole".
   - `item-1-1-sB-green.md` step 2 turns nine hook cases green with one gate
     edit.
   - `item-2-1-s1-green.md` says the ten cases "turned green together on that
     one edit; they were not grown separately".

   Over-implementation was checked by mutation instead: A10 (`hit` reset) in
   `review-code-tests.md`, M0–M8 in `item-1-1-sB-code-review.md`, and M1–M8 in
   `item-2-1-s1-code-review.md`. Only M0, an equivalent mutant, survived.
2. **Orchestrator files ride in slice commits.**
   - `3b3e7fc` (Slice A GREEN) adds `dispatch-rules.md` and the §Build state
     slice grouping in `delegate-status.md`.
   - `ccbe59a` (Slice B code review) carries +43 lines of `delegate-status.md`,
     the mutation-testing rule.
   - `40d1e95` (Item 2.1 code review) carries +5 lines of it.

   Neither code-review report claims those edits: each says `delegate-status.md`
   was pre-existing dirt it did not touch. No report of another slice rides
   along. The bookkeeping is accurate but blurs what each slice commit holds.
3. **No recorded suite result for `9bd925e`.** It changes `lib/`, `hooks/` and
   `tests/` and bundles four review groups. `review-code-tests.md` §Verification
   lists six per-file runs plus `shellcheck` and `bash -n`. `review-skill.md`
   says only that `just precommit` "runs before the commit". No report shows the
   full suite green at the range's final commit.
4. **Tests added by correctors have a single proof.** Each was shown red or
   mutation-proven by the same dispatch that wrote it, with no second mutation:
   - Slice A code review case 4, "HOME unset, CLAUDE_CONFIG_DIR set, still
     found". The end-of-build table A1–A10 does not target it.
   - Item 2.1 code review case 11, "a glob or $ after < is skipped, lone or
     glued" (M8 only). Item 2.1 was not re-mutated at the end of the build.
   - `9bd925e` "a sed failing after printing an id is unknown" (A2 only).
5. **`just precommit` ran past the foreground rule.** The harness moved it to
   the background at 600 s in the Item 2.1 code review (§Gate) and the Phase 3
   review (§Precommit). `delegate-status.md` line 143 records the orchestrator
   running it with `run_in_background`. Each exit status was read from the
   completed task and was 0. Under `dispatch-rules.md` §Tests ("never
   `run_in_background`") this is a recorded deviation, not a red suite.

## List Revisions

- **Slice grouping:** Item 1.1's seven slices ran as A (1, 2, 3, 4, 6) and B (5,
  7), and Item 2.1's three slices ran as one. The record is `delegate-status.md`
  §Build state, committed in `3b3e7fc`, the first slice commit. `outline.md` was
  not revised: its last commit is `72e34d7`. The divergence is recorded, so it
  is not a gap.
- **Target files:**
  - Item 1.1's hook cases moved from `tests/hook-candidates.bats` to the new
    `tests/hook-resume.bats`, to stay under the 400-line gate
    (`item-1-1-sA-test-review.md` Major 6).
  - Item 2.1's cases went to the new `tests/probes-readonly-globs.bats`, because
    the operands suite was at 373 lines (`item-2-1-s1-red.md`).
  - Outline slice 7's "rewritten" flag-policy case was deleted, and its halves
    were folded into the flag-absent and flag-true hook cases
    (`item-1-1-sB-red.md` §Files).

  All three are recorded in the reports.
- **Interface:** the Slice A code review widened `probe_resume_lost`'s stdout
  from `lost|found` to `lost|found|unknown`. That review's §Hand-offs records it
  for Items 4.1 and 5.2.
- **Mutation-testing rule:** given mid-build, after Slice B's test review, and
  recorded in `delegate-status.md` §Mutation testing (`ccbe59a`). Slice B's code
  review, Item 2.1's test and code reviews, the Phase 3 review and the
  end-of-build review each carry a mutation table. Slice A was covered
  retroactively by `review-code-tests.md`.
- **Deleted committed tests, each with a disposition:**
  - "resume-lost flag policy" (`hook-candidates.bats`) was deleted by Slice B
    RED: Q1 inverts its flag-true half.
  - "transcripts for both ids, no verdict" (`hook-resume.bats`, from `3b3e7fc`)
    was deleted by the Slice B test review, Minor 1. The exact `found` hook case
    subsumes its negative.

## Code Quality Observations

- **Test review did its job on every slice.** Plausible forbidden
  implementations passed RED and were caught before GREEN:
  - Slice A: `last`, `all`, `union`, `onedir`/`sameproj`, `count` and `bsdquiet`
    (`item-1-1-sA-test-review.md` §Forbidden-implementation run).
  - Slice B: M2, a probe testing only the first id.
  - Item 2.1: M2, a skip at the loop head, and M3, whole-command rejection.
- **The evidence matches the commits.** Every failing line a test review cites
  matches the committed file. For example, `tests/probes-readonly-globs.bats` at
  `18a3658` lines 85, 100, 110, 121 and 142 hold the assertions the review
  names. That indicates the GREEN did not touch the tests.
- **Mutation hygiene is consistent.** The reports record single-occurrence
  replacement, `command grep` landing and restore checks, and swapped-string
  restores. The Item 2.1 code review documents one restore incident (M8's
  non-unique string) and how it was proven restored.
- **Slice A RED's two proofs bound to the inert stub.** Test 9's mutation
  appended `sed --version` to the stub, which GREEN then replaced. The proof
  showed the case can see a GNU-ism, not that the shipped probe has none. A8 in
  `review-code-tests.md` re-established it on the real probe.
- **Fixtures came from the cutter.** No file under `tests/fixtures/` and no
  `tests/extract-fixtures.py` change appears in the range. New cases read
  `fire-resume-lost-two-turn.txt` and `fire-readonly-path-cp-tmp`, transformed
  only at run time (a `grep -vF` filter in `probes-resume.bats:87`, and a `\377`
  prefix at `:211`).
- **BSD-stub rule met.** All three new bats files (`probes-resume.bats`,
  `hook-resume.bats`, `probes-readonly-globs.bats`) load `helpers/bsd-stubs`,
  and each has a `make_bsd_stubs` case.
- **RED reports overclaimed twice, and test review corrected both:**
  - Slice B RED said its SC2030/2031 findings were "the same pattern as existing
    cases"; no file under `tests/` had one.
  - Slice B RED said 4c paired with test 3, but they differed in the id.

## Recommendations

### Critical

None.

### Important

1. **Re-mutate the four single-proof Phase 3 BSD cases.**
   - Issue: check-links, hook-malformed, probes-config and probes-readonly-pins
     rest on one executor mutation each, and two of the three siblings
     re-mutated were blind.
   - Action: for each case, place a GNU-only call in a code path only that case
     exercises, then record the red or fix the case.
   - Files: `tests/check-links.bats`, `tests/hook-malformed.bats`,
     `tests/probes-config.bats`, `tests/probes-readonly-pins.bats`.
2. **Make correctors mutate their own fixes.** A code review that adds a branch
   should mutate each added line, not only show its new tests red. The A2 gap
   was a line inside a fix whose tests went red for a neighbouring reason. The
   mutation rule in `delegate-status.md` §Mutation testing now requires this for
   "every behaviour the slice's green diff added"; extend it explicitly to the
   corrector's own diff.

### Minor

1. **Record a full-suite result for the closing commit.** Add the
   `precommit passed:` recap for `9bd925e`'s tree to `review-code-tests.md`, or
   to whatever report the orchestrator writes at commit time.
2. **Keep orchestrator bookkeeping out of slice commits.** Commit
   `delegate-status.md` and `dispatch-rules.md` changes on their own, so that
   `git show <slice commit>` is exactly the slice.
3. **Give corrector-added tests a second proof.** The end-of-build review should
   re-mutate them with a different mutation. Three tests are listed under Minor
   4.

## Process Metrics

- Slices executed: 3 tdd slices, covering 10 outline slices, plus Phase 3's 5
  test-only items. Fully compliant tdd slices: 3 on the per-slice checks. Slice
  A carries Major 1 from its code-review stage.
- Wrong-reason or gap tests caught in review, by mutation or forbidden variant:
  - Slice A test review: 6 variants;
  - Slice B test review: 1;
  - Item 2.1 test review: 2;
  - Phase 3 review: 2;
  - end-of-build review: 1 (A2).

  Equivalent mutants removed: 1 (Slice B M0).
- Dispatches per item:
  - Item 1.1: 8 (4 per slice);
  - Item 2.1: 4;
  - Phase 3: 2 (executor and review);
  - end-of-build code-tests review: 1, shared across the items.
- Marker-bearing commits: 6, each adding exactly one GREEN or code-review
  report. Commits adding each GREEN report: exactly 1 per slice.
