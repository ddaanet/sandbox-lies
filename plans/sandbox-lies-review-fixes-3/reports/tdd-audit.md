# TDD Process Review: sandbox-lies-review-fixes-3

**Date:** 2026-10-11T00:54Z
**Hosting file:** plans/sandbox-lies-review-fixes-3/outline.md
**Commits analyzed:** d6d0043..af58339 (tdd groups: 1.1, 1.2, 2.1+3.1,
6.1+6.2; Items 4.1, 5.x, 7.x out of scope)

## Executive Summary

All four groups carry real red evidence: every new test was seen red on an
assertion against unchanged code, or has a per-test mutation proof, and every
test review re-proved with a different mutation. No critical violation: no
reviewed test was dropped between review and the group commit (test counts match
the reports in each commit), GREEN edited no test file except the sanctioned
Item 1.1 slice 5 and Item 1.2 `verdicts.bats` rewrites, and no red commit
exists. The one substantive miss is Item 1.2: the decoder's digit-after-escape
defect, plus two more latent decoder defects, passed the test review, the code
review (three survivors, one seam gap) and the Phase 1 boundary check, and was
found only by a fuzz at the final gate. The cause was a shared blind spot (the
outline's `%b` design, a reference decoder of the same shape, and test inputs
that never put a character after a control byte), not a lapse in mutation
method. The other findings are process: GREEN's test-at-a-time order is
unevidenced in three of four groups, the 6.x code review wrote unrequested
production guards and tested them after the fact, and the gate fix commit mixes
concerns and carries no item marker.

## Per-Slice Compliance

Slices were run grouped (recorded in `delegate-status.md`, not re-litigated).
Each group is one commit carrying its RED, test-review and GREEN reports, so
"one slice commit" is judged per group. Slice counts from the outline: 1.1 = 5,
1.2 = 4, 2.1 = 3, 3.1 = 1, 6.1 = 3, 6.2 = 2 (18; `delegate-status.md` says 17).

| Item/slice | RED evidence | Test review | One slice commit | Tests unmodified | Issues |
|---|---|---|---|---|---|
| 1.1/1-4 | 7 new/rewritten cases plus members case red on assertions; helper move proved by mutation (`C` in `locale.bash`) | 1 weakness fixed (outcome not pinned to line 1); helper move re-proved with `POSIX`; reference-encoder run | yes, 5bfd2e2 (GREEN, tests, 3 reports) | yes (GREEN report: slices 1-4 untouched) | blank-twin literals never seen red on unchanged code (newline twin fails first); covered by reference encoder and CR mutations |
| 1.1/5 | no RED: 15 existing assertions found red by the full-suite run in GREEN | not reviewed by a test review | in 5bfd2e2 | test edits by design (outline slice 5) | rewrites checked only afterward, by CR mutations 6-10 (all red per site); assertions kept or strengthened (diff of `probes-config.bats`) |
| 1.2/1-4 | 7 of 8 red on assertions, 2b by two mutations (one per assertion) | 8 fixed (6 major, 2 minor); 2b re-proved with a raw-newline mutation; 15-variant wrong-decoder matrix | yes, d16cbb5 | yes, except two `verdicts.bats` cases fed `%q` wire (assertions unchanged, per diff) | decoder defects survived (see Review-gate finding) |
| 2.1/1-3 | 4 red on assertions; 3 regressions with one mutation each | 3 fixed (parent-of-cwd satisfied cases 1-3; helper dedup; tmpdir guard); mutations differ from RED's | yes, 1dedc30 | yes | duplicate RED agent (below) |
| 3.1/1 | 2 red (whole chardev pin, untracked opener); two later assertions mutation-proved | three opener mutations, each alone | in 1dedc30 | yes | GREEN edited `docs/references/detectors.md` |
| 6.1/1-3 | 3 red on assertions (2 on exit status of a traceback) | 1 weakness fixed (count 1 vs matched 1 -> two unmatched lines); per-fix isolation runs | yes, 5b9ef00 | yes (counts 3 and 2 match) | none |
| 6.2/1-2 | 2 red (TypeError, AttributeError) | independence of the two fixes shown | in 5b9ef00 | yes | none |

Follow-on commits per group, each accounted for by a report: 37dbf50 (1.1 CR +
pin), 1c5fd42 (1.2 CR + 3 pins + seam test), 6f687b3 + cb209d4 (2.1 CR, pin,
pin-review), c2e7a81 + f956dbf (6.x CR, pin, pin-review). No unexplained marker
commit. No refactor report exists; no code review flagged a refactoring.

## Violations

No critical violations. Findings by check:

1. **Check 1 (red, reviewed): holds.** Each RED names the failing assertion line
   and the rival causes; the green-on-unchanged cases (1.1 helper move, 1.2 slice
   2b, 2.1 cases 5-7) each carry one mutation per test and the test review
   reproduced them with a different mutation (1.1 `C` -> `POSIX`; 1.2 subject
   rewrite -> raw-newline span; 2.1 parent-of-cwd, last-line gate, parent
   fallback). Slice 1.1/5 is the exception: it had no RED or test review (see
   Important 4).
2. **Check 2 (one green commit): holds per group.** `git log --diff-filter=A`
   returns exactly one commit for each `*-green.md` (5bfd2e2, d16cbb5, 1dedc30,
   5b9ef00). Subjects use `Item 1.1 —` / `Item 1.2 —` without the job name and
   without `/k` (the grouping makes `/k` moot, but the `<job> Item N.M/k` marker
   the audit matches is absent for Items 1.1 and 1.2; 2.1 and 6.x use
   `review-fixes-3 Items ...`). Every GREEN report records a green suite (375,
   388, 398, 408) and `just precommit` exit 0; no red commit.
3. **Check 3 (dropped tests / GREEN edits): holds, two notes.** Test counts match
   the reports at each commit (lock-newline 7, resolve 7, verdicts 11,
   verdicts-readonly-path 10, verdicts-locks 5, hook-writes 5, corpus-eval 3,
   extract-fixtures 2). GREEN edits to tests: 1.1 slice 5 (15 rewrites, in the
   outline) and 1.2's two `verdicts.bats` cases (`wire` variable added, expected
   text unchanged). GREEN reports in 1.1, 2.1 and 6.1 say the fix went in as one
   edit and the tests were run after, so the recorded test-at-a-time sequence is
   by file or by whole suite, not per test (Important 2).
4. **Check 4 (refactor separation): not triggered.**
5. **Scope:** 1dedc30 (Haiku GREEN) edited `docs/references/detectors.md`, which
   Item 7.4 owns; disclosed in the GREEN report and argued from test 3's
   transcription comment. The 6.x GREEN also did the outline's no-case edits
   (docstring `>`, prefilter comment, `pick()` branch), which the outline lists.

## List Revisions

None. `git log --oneline -- plans/sandbox-lies-review-fixes-3/outline.md` shows
d0efa4e, fa2cabd, d6d0043 only (all before the build baseline); no list-revision
commit in d6d0043..HEAD, and none was needed: the extra test cases (1.1
newline+é, 2.1 case 6, 1.2 forged-value and control-byte cases) are additions
inside slices, not changes to the remaining list. The Phase 1 boundary review the
outline asked for was folded into the 1.2 code review (recorded in
`delegate-status.md`); there is no `phase-1-corrector.md`, and the closing
review is `review-code.md` rather than `final-review.md`.

## Review-gate finding: decoder digit-after-escape defect

**What the gate found.** `review-code.md`: `printf %b` reads `\0` plus up to
three digits, `%q` writes `\001`-`\037` as `\0NN`, so wire `$'/x/a\0046/f' `
(byte 0x04 then `6`) decoded to `/x/a&/f`. The wrong path held no control byte,
so the display rule showed it decoded, as fact. A 600-path fuzz found 27
mismatches on bash 5.2 and 3.2.0. A second pass (`review-code-decoder.md`) of
the rewritten decoder found two more latent defects in d16cbb5: `\"` kept its
backslash, and any escape the grammar admits but `%q` never writes (`\x41`,
`\cA`, short `\12`, `\q`) reached `%b`, producing stderr noise, a 5.2/3.2
disagreement (`\cX`), or a partly decoded prefix that could still match the
`.claude/settings.json.lock` suffix. Fix and tests landed in af58339.

**Why the earlier test review missed it.**
- The design carried it: outline lines 70-73 prescribe `printf -v ... %b` over
  the whole body. The test review checked injection and grammar, which the
  outline names, not `%b`'s escape width, which it does not.
- The reviewer's reference decoder ("read without `-r`; regex grammar; `\'`
  swap; `%b`") had the same single-`%b` shape. All 15 wrong-decoder variants
  were perturbations of that shape (eval, loose grammar, no `\'` swap, `read
  -r`, format-string `printf`), so the matrix could not expose a defect the
  reference shared. 15 kills measured completeness against the reference, not
  against the encoder.
- Test inputs never put a character after a control byte. The control-byte case
  used `a<byte>b` for `\001 \t \033 \037 \177 \200 \377`; the round-trip list
  put `\1`, `\n` (literal backslash-n) and `%s%d&` next to `é`, never `\0NN`
  followed by a digit. `d16cbb5`'s `verdicts-readonly-path.bats` confirms it.
- The control-byte test asserts the wire form is shown, so for exactly the
  inputs where the defect lives the decoded value was never observed; only the
  suffix match read it.

**Why the 1.2 code review missed it.**
- Mutation testing probes mutants of the code present. The defect is a
  behaviour `%b` does not have; no mutant of `%b "$body"` is the right decoder.
  `%b` -> `%s` and `%b` -> format were killed, so the table looked complete.
- Its own seam check (Phase 1 boundary: "encoder and decoder were run against
  each other, 12+ hostile paths") was the right check on a narrow input set: the
  same sets as the test review, no cross product of special byte x following
  character.
- It leaned on the test review ("test review's decoder matrix already killed 15
  wrong decoders") so a correlated blind spot was counted as independent
  coverage. Its 3.2.0 run compared 3.2 against 5.2 on fixed values, which
  cannot find a defect both bashes share.
- The reviewer pinned its own survivors and no one re-checked them (pre-rule).

**What would have caught it.** A generated round trip (every byte 1-31, 127,
128, 195, 255 crossed with digits and letters, through the real `%q` encoder
into the real decoder, compared as hex). That is a property test at the seam
Item 1.1 and Item 1.2 share; each item's slices saw only its own side
(1.1 literals, 1.2 hand-spelled or encoder-built wires over short lists). The
gate's fuzz found it in one run, with the same method that the 1.2 code review
described but did not apply.

**Process note on the gate fix.** The digit test was shown red before the fix
(`wire $'/x/a\0046/f' decoded to /x/a&/f`). The second-pass test (`\"`, forged
escapes) was shown red by re-introducing four mutants (M7, M10, M12, M13), not
by running against the unfixed d16cbb5 decoder; acceptable but weaker. Fix,
tests, changelog and three reports are one commit (af58339) with subject
`review-fixes-3 Review gate`, no `Item 1.2` marker.

## Code Quality Observations

- Test literals are written out, not built by `%q`, and open with a guard that
  `BATS_TEST_TMPDIR` holds no byte `%q` escapes (1.1, 2.1 `setup()`); this
  avoided a tautology the reviews checked for.
- Sentinel tests (1.2) assert the directory is writable and the sentinel absent
  before and after; the test review upgraded them so an `eval` decoder is
  caught (only the forged case caught `eval-slash` before).
- 1.2 red-before-green was stepwise in the GREEN report (reader with `/` arm,
  then `$'` arm, then display, then locks); the best evidence of
  test-at-a-time in the set.
- 1.1 CR mutation 4e: the vanish-mid-probe `gone` site survived all tests; the
  header had called it a residual with "no deterministic trigger", disproved by
  a stub `stat` (37dbf50).
- 2.1: the pin added a `set -e` case for `|| line=`; the pin review found it
  lacked the CLAUDE.md BSD-stubs re-run and added one, itself unmutated. The
  sibling `base=$(_readonly_git_dir ...) || base="$cwd"` guard has no errexit
  case and no mutation evidence (the pin review noted it was not exercised).
- 6.x CR deferred one defect: `cmd_aggregate` `line.split("\t", 1)` raises
  `ValueError` on a tab-less verdict line (outside the outline's slice 2).
- The decoder's behaviour on bash 3.2.0 is verified by report runs only; the
  bats suites run on the system bash (NFR-2 evidence is manual).

## Recommendations

### Critical

None.

### Important

1. **Add a generated round trip at the encoder/decoder seam** — the missed
   defect class is a cross of special byte x following character. Action: keep
   the `review-code.md` case in `tests/verdicts-readonly-path.bats` and extend it
   to the full byte x {digit, letter} cross with hex comparison; for any future
   encode/decode pair, require the test review to include a seam property case.
   Section: test-review prompt and `tdd-auditor` Item-level checklist.
2. **Do not seed a test review's wrong-implementation matrix from one reference
   written by the reviewer.** Action: have the reviewer derive variants from the
   primitive's documented semantics (here `%b` width and `\0` handling) and from
   the encoder's actual output set, and say which design assumption each variant
   challenges. Section: test-review dispatch template.
3. **Check design-prescribed primitives empirically at outline time.** The
   outline's `%b` instruction at lines 70-73 was never exercised against `%q`
   output. Action: for a design that borrows a decoder, run it over the encoder
   outputs in the evidence step (`evidence.md`) before slicing.
4. **Give test rewrites inside GREEN an independent check.** Slice 1.1/5 rewrote
   15 assertions with no RED or test review; the CR mutation rows 6-10 caught
   them afterward and found no weakening, so no harm here. Action: run slices of
   this kind through a short test review before the GREEN commit, or record in
   the outline that the CR mutation pass is the review.
5. **Reviewer-authored production code needs the same discipline.** The 6.x code
   review added three `isinstance`/`or ""` guards beyond the outline (M6, M9,
   M10) and no test existed until the pin; the pin review re-checked the tests
   but nobody reviewed the guards. Action: a code review reports the defect and
   a RED test shape; the pinner (or GREEN) writes the guard after the red.
6. **Record per-test order or declare it moot.** GREEN reports in 1.1, 2.1 and
   6.1 say one edit covered all tests. The grouped dispatch makes that natural;
   the build should state once in `dispatch-rules.md` that test-at-a-time is
   replaced by test-review satisfiability runs (as 6.x shows) and the audit
   will accept that.

### Minor

7. **Gate fix commits take an item marker and a split.** af58339 mixes the
   decoder fix, tests, changelog and three reports under no `Item 1.2` marker.
   Action: commit the fix as `review-fixes-3 Item 1.2 — ...` and the changelog
   and reports separately.
8. **Commit subjects:** Items 1.1 and 1.2 omit the job name (`Item 1.1 —`);
   use `<job> Item N.M` consistently.
9. **A stalled RED agent and its replacement wrote the same files** (2.1):
   the second report overwrote the first; the second ran its own mutations, so
   the evidence is sound. Action: the orchestrator confirms the first agent is
   stopped before redispatch.
10. **GREEN touched `docs/references/detectors.md`** (1dedc30). Disclosed and
    justified, but Item 7.4 owns that file; note it in the GREEN scope list or
    leave to 7.4.
11. **Mutate the unmutated additions:** the 2.1 BSD errexit case and the
    `|| base=` errexit guard.
12. **Dispatch status dates:** reports for 1.1/1.2 ran on 2026-10-09 before the
    2026-10-11 restated model rule; their pins were written by the Sonnet
    reviewer with no one-rung-above recheck. The 2.1 and 6.x pins follow the
    rule (Haiku pin, Sonnet recheck, with a different mutation).

## Process Metrics

- Slices executed: 18 across 4 groups; groups with sound red evidence: 4 of 4;
  groups with no check violation after the grouping deviation is set aside: 1.1
  (slice 5 caveat), 2.1+3.1, 6.1+6.2 compliant on checks 1-3; 1.2 compliant on
  checks 1-3 but with a post-hoc defect.
- Weaknesses fixed at test review: 13 (1.1: 1; 1.2: 8; 2.1: 3; 6.x: 1). Wrong-
  reason tests caught: 4 (1.1 line-1 position; 1.2 sentinel unable to detect
  eval, malformed set unable to catch trailing-quote stripping, suffix on wire;
  2.1 parent-of-cwd satisfying cases 1-3).
- Mutation survivors at code review: 1.1: 1 (pinned); 1.2: 3 plus 1 seam gap
  (pinned); 2.1: 1 (pinned, Haiku, rechecked); 6.x: 3, all in reviewer-added
  guards (pinned, Haiku, rechecked). Gate: 1 real defect plus 2 latent, 3
  survivors (M7, M10 plus equivalent M1).
- Dispatches per item: 1.1: 4 (RED, test review, GREEN, CR); 1.2: 4; 2.1+3.1: 7
  (RED x2 with the stalled agent, test review, GREEN, CR, pin, pin review);
  6.1+6.2: 6 (RED, test review, GREEN, CR, pin, pin review).
