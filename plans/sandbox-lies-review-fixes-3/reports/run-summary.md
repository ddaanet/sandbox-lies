# Run summary — sandbox-lies-review-fixes-3

Runner: Sonnet `/build` over `outline.md` (no runbook). Baseline
`d6d0043173f6a692cc5d2e2a74d7e83c0710ab44`. Models per the owner's rule of
2026-10-11: Sonnet for every RED, test review, code review, Item 4.1 and the
docs; Haiku for every GREEN of Phases 2, 3 and 6, for Items 5.1 and 5.2 and for
mutation pins, each pin re-checked by a Sonnet reviewer. Items 0, 1.1 and 1.2
ran before this session (Sonnet, grouped dispatches). All commits below were
made with explicit pathspecs; `.claude/handoff-*.md` stayed staged and out of
every commit.

## Per item

Reports are under `plans/sandbox-lies-review-fixes-3/reports/`.

- **Item 0** bash 3.2.0 build: `item-0-bash32.md`. Rebuilt after `/tmp` was
  cleared: `item-0-bash32-rebuild.md` (committed with Item 4.1).
- **Item 1.1** (commits 5bfd2e2, 37dbf50): `item-1-1-red.md`,
  `item-1-1-test-review.md`, `item-1-1-green.md`, `item-1-1-code-review.md`.
  11 mutations, 1 survivor, pinned.
- **Item 1.2** (d16cbb5, 1c5fd42): `item-1-2-red.md`,
  `item-1-2-test-review.md`, `item-1-2-green.md`, `item-1-2-code-review.md`
  (includes the Phase 1 boundary check). 3 survivors pinned.
- **Items 2.1 + 3.1** (1dedc30, 6f687b3, cb209d4): `item-2-1-red.md` (Sonnet),
  `item-2-1-test-review.md` (Sonnet; deepened two cases, moved three builders
  to `tests/helpers/probes.bash`), `item-2-1-green.md` (Haiku; also made the
  one-sentence `detectors.md` phantom edit the transcription test demands),
  `item-2-1-code-review.md` (8 mutations, 1 survivor: the `|| line=` errexit
  guard), `item-2-1-pin.md` (Haiku), `item-2-1-pin-review.md` (Sonnet; added a
  BSD-stubs re-run).
- **Item 4.1** (13610c0): `item-4-1.md`. Sonnet. One 16384-character word on
  bash 3.2.0: 31.7 s before, 3.5 s after (target under 5 s met); bash 5.2:
  2.8 s to 1.2 s; 1600 short words slightly slower (1.7 s to 2.1 s on 3.2.0).
  Output identical to the old function on 11 tricky inputs on both bashes.
- **Items 5.1, 5.2** (3826e88, 2a8e750): `item-5-1.md`, `item-5-2.md`. Haiku.
  Review of 4.1, 5.1, 5.2 together: `item-4-1-review.md` (Sonnet; 2 equivalent
  or performance-only survivors accepted, 1 real survivor: the fixtures
  exclusion of the line cap and the `justfile`/`.toml` arms), pinned by Haiku
  (`item-5-2-pin.md`, commit 2dba8d4), re-checked (`item-5-2-pin-review.md`,
  one weakness fixed, commit 4b80e0c). `5.1` is "portable by construction,
  unverified on a Mac".
- **Items 6.1 + 6.2** (5b9ef00, c2e7a81, f956dbf): `item-6-1-red.md`,
  `item-6-1-test-review.md` (aggregate count case strengthened),
  `item-6-1-green.md` (Haiku), `item-6-1-code-review.md` (Sonnet; the reviewer
  added three guards beyond the outline, all three mutations survived),
  `item-6-1-pin.md` (Haiku), `item-6-1-pin-review.md` (Sonnet).
- **Items 7.1 to 7.7** (b374c3e, cccb659, 57145b4, b76e76e, 6a1bcb3, be1fb89,
  3ee82be, 4f38048): `item-7-docs.md`, `item-7-docs-review.md` (Sonnet; three
  comment rewraps). `docs/design.md` went from 399 to 394 lines. Two things the
  outline named were not done and are justified in the report: design.md has no
  "Verified against" text to bump, and `detectors.md` :83 already carried the
  new wording.

## Review gate (af58339)

Range `d6d0043..HEAD`, two groups (`memory` pointer excluded, not edited by
this build):

- `review-code.md` (Sonnet, `review-code` group): one major defect, fixed.
  `_verdict_path_read` decoded a digit following a control-byte escape wrongly
  (`printf %b` takes `\0` plus up to three digits, `%q` writes `\0NN`), so wire
  `$'/x/a\0046/f'` decoded to `/x/a&/f`, shown as a plain path. A 600-path fuzz
  found 27 mismatches on bash 5.2 and 3.2.0; after the fix, 0. Fix is a
  per-escape loop plus a test. Everything else clean, including a 400-seed
  tokenizer equivalence fuzz.
- `review-design.md` (Sonnet, `review-design` group): changelog adjusted to the
  decoder fix; no UNFIXABLE.
- Second pass on the decoder fix, `review-code-decoder.md` (Sonnet; the fix
  was written by a reviewer, so it got its own mutation pass): found two latent
  defects (`\"` kept its backslash; grammar-valid escapes `%q` never writes
  reached `%b`), fixed with tests; of 13 mutants, one equivalent survivor (M1),
  two survivors killed by new tests.
- No UNFIXABLE anywhere.

Triage (`triage-feedback.sh`) printed the evidence block (31 files, 27 reports,
review artifact present) and `unrecognised classification: Moderate.` The
`classification.md` label is "Moderate, Production", which the script does not
read; no row was logged in `plans/reports/triage-feedback-log.md`. Not fixed:
edify tooling, outside this repository.

## TDD audit

`tdd-audit.md` (`edify:tdd-auditor`, Sonnet). No critical violation; all four
groups carry real RED evidence or mutation proofs, one green commit each, no
red commit, no dropped test. Substantive finding: the decoder defect passed the
Item 1.2 test review and code review because they shared the outline's
`%b`-over-the-whole-body shape and never crossed a control byte with a
following character; the final gate's fuzz found it. Recommendations left for
the owner (none blocks):

1. A generated byte-by-following-character round trip through the real
   encoder and decoder as a permanent seam test (important).
2. Test-review wrong-implementation matrices should come from the primitive's
   documented semantics, not one reviewer reference.
3. Exercise a design-prescribed decoder over encoder output in the evidence step.
4. Slice 1.1/5 rewrote 15 assertions with no test review (code-review
   mutations checked them afterward, no weakening).
5. Reviewer-authored production code (the three 6.x guards, the decoder fix)
   was tested after the fact.
6. Minor: gate-fix commit mixes concerns; Items 1.1/1.2 subjects omit the job
   name; GREEN of 2.1 edited `detectors.md` (Item 7.4's file); the `|| base=`
   errexit guard has no case.

## Left open

- `cmd_aggregate` in `tests/corpus-eval.py` still raises `ValueError` on a
  verdict line with no tab (seen by the 6.x code review, outside the outline).
- Audit recommendations 1 to 6 above.
- `triage-feedback.sh` classification label mismatch (above).
- Bash 3.2.0 behaviour is verified by report runs; bats suites run on the
  system bash. macOS is unverified (Item 5.1).
- The deliverable review follows the build and was not run:
  `/deliverable-review plans/sandbox-lies-review-fixes-3`, range
  `2309ae6..HEAD`. Nothing pushed, nothing released.

## Final gate

`just precommit` exit status 0; `bats: 413 passed, 0 failed`; recap
`precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line
limits, links, python compile, tests` (re-run below, after this file).
