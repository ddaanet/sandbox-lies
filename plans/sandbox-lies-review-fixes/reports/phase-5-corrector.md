# Review: Phase 5 checkpoint (final) — sandbox-lies-review-fixes

**Scope**: Phase 5 commits f895d72 (5.1), cbab6fb (5.2), 57be39b (5.3),
6a6c7b4 and 6d1251a (5.4/1). Reviewed against the runbook's Phase 5, the
outline's D1 with its 2026-10-05 revision, and the deliverable-review findings
these items claim to fix. Out of scope: the plugin-dev/dogfood commits, `plans/`
(read only), `BRIEF.md`, `memory/`, the lock probes' newline `path=` defect,
and Phases 1–4.
**Date**: 2026-10-05
**Mode**: review + fix

## Summary

Phase 5 does what its items say. The exclusion rule reads the same everywhere it
appears: the skill hub, its four nodes, `docs/design.md`, `docs/references/*`,
`README.md` and the changelog. Each surface says:

- an entry applies only to a call whose every command it covers;
- the call stays sandboxed for git with `-C` or an absolute, `~`-led or
  `..`-bearing path argument;
- the 2.281, 2.288 and 2.289 probes are confounded;
- the CC 2.1.289 bare-`git status` observation is the evidence and the
  re-probe.

No live file contradicts the revised D1. The design.md split keeps every
argument verbatim. Item 5.4's code is correct. I found five minor issues and
fixed all of them: three comment or wording clarity problems, one contract
sentence that disagreed with the code, and one incomplete exception list. None
is critical or major.

**Overall Assessment**: Ready

## Checks performed

- **Cross-surface exclusion rule.** I grepped every tracked file outside
  `plans/`, `plugin-dev/`, `memory/`, `BRIEF.md` and `tests/fixtures/` for
  "where honoured", "not honoured", "unhonoured", "whole-call", "matching
  segment", "decoy", `git:*`, `claude:*` and "honour".
  - All hits that remain are consistent with the revised D1. They fall into
    four groups:
    - records of the confounded probes (`excluded-commands.md` §Earlier probes,
      `lock-detectors.md`);
    - the `git:*` legacy-syntax mentions;
    - the Translation map row, which keeps the memory section's own name and
      adds "corrected: …";
    - test-suite "decoy" fixtures, which have nothing to do with exclusions.
  - `docs/changelog.md:227` ("misses an honoured exclusion") is the dated
    2026-09-27 entry. It is history, and the new 2026-10-05 entry supersedes
    it.
  - Hub and nodes agree on the forfeiting shapes, `git -C`, the path-argument
    exception (with `git config --file` as an observation), the re-ranked cwd
    order (absolute paths and `git -C`, then a subshell, then a trailing
    `cd <root>`), the main-session qualifier, strict mode's key, and the single
    batching rule.
- **design.md split.**
  - `rejected-alternatives.md` holds all eight arguments verbatim. The only
    change is the `PreToolUse` matcher's closing sentence: Item 5.2's planned
    exclusion-wording update, which is in scope.
  - Every name stays in design.md: six in the §Rejected alternatives list, two
    in D-9's *Rejected* line. Each one-line conclusion matches its argument
    (one wording fix: Minor 4).
  - `sandbox-state.md` is old D-8 verbatim plus the clause "one whose every
    command an entry covers". The hub stub does not misstate it.
  - The link gate passes.
- **Item 5.3 comments against code.**
  - `annotate.sh`: `parsed=$(jq …) || exit 0` makes the no-jq path exit 0, as
    the comment says.
  - `$3` is read only by `probe_readonly_path` (`lib/probes-readonly.sh:45`).
  - No code reads `CLAUDE_PROJECT_DIR`.
  - `just --list` prints "Checks that run before every commit."
- **Item 5.4 A-3 wording.**
  - The `nopath` row in `readonly-path.md` and `probe_readonly_path`'s comment
    agree with the code.
  - The file header did not agree (Minor 2).
  - design.md FR-4 lists no readonly outcomes, so it has nothing to disagree
    with.
- **Runbook bullets.** All bullets of 5.1–5.4 are satisfied. The deliverable
  review's Major 1 and Major 2 doc halves are fixed, along with:
  - Stale comments (4 of 4).
  - Docs minors: mv target form, NFR-4 read scope, payload cwd/persisted cd,
    main-session qualifier, batching contradiction, auto-allow exceptions,
    strict-mode key, platform scope, NFR-1 re-measurement, two hit counts, D-3
    and NFR order, FR-8 qualifier, CLAUDE.md wording.
  - I checked that every cited report and evaluation file exists at the path
    given.
- **Line caps.** design.md: 399 after `just format-docs`, so my fixes are net
  zero. SKILL.md: 185 of 200.
- **Lifecycle.** No `MERGE_HEAD`, `CHERRY_PICK_HEAD` or `REBASE_HEAD`. No
  `*.lock` under `.git/`. Nothing staged. Apart from the files I was told to
  leave alone, the only untracked or ignored entries are caches (`.rumdl_cache`,
  `__pycache__`, `.venv`) and `dist/plugin/`, the dogfood copy. No scratch files
  are left in `tests/` or `lib/`.

## Issues Found

### Critical Issues

None.

### Major Issues

None.

### Minor Issues

1. **`annotate.sh` header comment: a 130-column line and a tangled sentence**
   - Location: `hooks/annotate.sh:9-23` (Item 5.3)
   - Note: Item 5.3 put a long parenthetical, about bash printing a
     command-not-found line when jq is missing, between "cannot error on any
     input, so the hook writes nothing to stderr while jq is on PATH" and the
     colon that introduces the `-Rs`/`fromjson?` explanation. The result was a
     130-column comment line. The colon also no longer pointed at the
     explanation it introduced.
   - Fix: the comment now states the no-jq case first, then "With jq, the hook
     writes nothing to stderr: one jq call … cannot error on any input." The
     paragraph is reflowed to 80 columns, with no content change.
   - **Status**: FIXED
2. **`lib/probes-readonly.sh` file header contradicted the A-3 `nopath`
   contract**
   - Location: `lib/probes-readonly.sh:2-11`
   - Note: The header said the probe prints "an outcome token …, then a path=
     line" for every outcome. Under `nopath`, including Item 5.4's
     newline-bearing case, there is no `path=` line. The function comment and
     the `readonly-path.md` row already say this; this header did not.
   - Fix: "then a path= line under writable and readonly only (nopath prints
     none)". Reflowed.
   - **Status**: FIXED
3. **detectors.md Conventions: "Open with it:" does not read as English**
   - Location: `docs/references/detectors.md:21` (Item 5.2)
   - Note: The phrase was meant to introduce the open question about whether
     the payload `cwd` follows a persisted `cd`.
   - Fix: "A related question is open:". Reflowed by `just format-docs`.
   - **Status**: FIXED
4. **D-9's *Rejected* line attributes "the wrong trigger axis" to both homes**
   - Location: `docs/design.md:298-300` (Item 5.2 split)
   - Note: The argument in `rejected-alternatives.md` gives the trigger axis as
     `craft`'s problem only. `prohibitions` is rejected because it forbids
     actions. "— the wrong trigger axis, and `prohibitions` forbids …" read as
     both homes having the trigger-axis problem.
   - Fix: "a home in `craft` (the wrong trigger axis) or `prohibitions` (it
     forbids actions; this enriches results)". The line count is unchanged
     (399).
   - **Status**: FIXED
5. **Exception list incomplete in two places**
   - Location 1: `docs/references/rejected-alternatives.md:11-12`.
     - Problem: it said git stays sandboxed with "`-C` or an absolute path
       argument". Every other surface says "absolute, `~`-led or `..`-bearing".
     - Fix: aligned to the full exception.
   - Location 2: `docs/design.md` NFR-4.
     - Problem: "(else the payload `cwd`'s)" followed "rather than the call's",
       so it read as an alternative to the call's repository. The code
       (`_readonly_print_facts`: `start="$path"`, else `$cwd`) means: when
       there is no refused path, the payload cwd's repository is read.
     - Fix: reworded to "possibly a sibling worktree rather than the call's, or
       with no path the payload `cwd`'s". Line count is net zero.
   - **Status**: FIXED

## Deferred Items

The following items were identified but are out of scope:

- **Lock probes' newline `path=` forgery** (`lib/probes.sh` `_probe_lock_at`).
  Reason: Scope OUT. It is already reported in `item-5-4-s1-code-review.md` and
  waits on my human partner's decision.

## Fixes Applied

- `hooks/annotate.sh:9-23`: header paragraph reworded and reflowed (Minor 1;
  comment only).
- `lib/probes-readonly.sh:2-11`: file header's `path=` clause scoped to
  `writable`/`readonly` (Minor 2; comment only).
- `docs/references/detectors.md:21`: "Open with it:" → "A related question is
  open:" (Minor 3).
- `docs/design.md:298-300`: D-9 *Rejected* line (Minor 4).
- `docs/design.md:194-196`: NFR-4 read-scope sentence (Minor 5).
- `docs/references/rejected-alternatives.md:11-12`: full git path exception
  (Minor 5).
- Verification:
  - `just format-docs` was run; design.md is at 399 lines.
  - `just precommit` was run in the foreground and exited 0. Its line: "299
    passed, 0 failed; precommit passed: plugin.json, hooks.json, shellcheck,
    bash -n, rumdl, line limits, links, tests". The `tests/docs.bats` self-quiet
    sweep is included.

## Requirements Validation

| Requirement | Status | Evidence |
|-------------|--------|----------|
| 5.1 hub: §Tell, §Writing, §Leaving, §Keeping per revised D1 | Satisfied | `SKILL.md:18-25`, `:40-59`, `:63-77`, `:84-96` |
| 5.1 nodes: excluded-commands, escapes-and-costs, masks-and-gates, recipes-and-claude | Satisfied | retitle; §Observed on CC 2.1.289; §Earlier probes; strict key; three auto-allow exceptions; one batching rule; `claude *` |
| 5.2 lock-detectors, detectors, readonly-path, hook.md | Satisfied | confounded probes restated; cwd open question; re-measurement credited; 41/57 corpora named; mv inter-device form; D-1 pilot reading |
| 5.2 design.md (NFR-4 scope, platform, D-3, NFR order, FR-8, D-5, exclusion wording, FR-1/Architecture/D-12, pinned-by) | Satisfied | design.md at 399; split per option (a′) |
| 5.2 README, CLAUDE.md, changelog | Satisfied | §Install jq + platform; skill blurb; exemption wording; one 2026-10-05 entry |
| 5.3 four comment/help-text fixes | Satisfied | header comment wording fixed under Minor 1 |
| 5.4 nopath for a newline-bearing resolved path; docs and header | Satisfied | `probe_readonly_path` guard on the resolved `$path`; three-half case; file header fixed under Minor 2 |
| Deliverable review Major 1 (skill/doc halves), Major 2 (doc half), stale-comment and doc minors in scope | Satisfied | see Checks performed |

## Positive Observations

- The skill hub stays at 185 lines by sending the full forfeiting list, the
  hedged "seen beyond the documented list" shapes and the confounded probes to
  the node. Each surface states the evidence status the same way, and none
  promises more than the probes showed: the `git:*`-on-2.288 question is left
  open, and `2>&1` is hedged.
- `lock-detectors.md` explains why each recorded sandboxed run was sandboxed by
  its own shape (an `sh` head, a `cd`, `git -C`). It does not assume an ignored
  exclusion.
- Item 5.4 guards the resolved value rather than the cwd. The test's middle half
  kills the cwd-keyed mutant.

## Recommendations

- None beyond the deferred lock-probe decision.

## Verdict

**Ready.**

Files changed:

- `hooks/annotate.sh`
- `lib/probes-readonly.sh`
- `docs/design.md`
- `docs/references/detectors.md`
- `docs/references/rejected-alternatives.md`
- `plans/sandbox-lies-review-fixes/reports/phase-5-corrector.md` (this report)
