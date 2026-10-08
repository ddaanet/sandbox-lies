# Review: Phase 5 docs (group `docs`), commit 8b10631 against baseline 72e34d7

**Scope**: `CLAUDE.md`, `docs/design.md`, `docs/changelog.md` (last entry, with
the skill paragraph f5ddf6d added), `docs/references/detectors.md`,
`docs/references/lock-detectors.md`, `docs/references/readonly-path.md`,
`docs/references/sandbox-state.md`; the one `README.md` passage. Every claim
checked against `lib/`, `hooks/`, `tests/`, the two evidence files and
`skills/` (for the changelog's skill paragraph only). OUT: `skills/**`, code and
tests, m-7, m-8, `plans/**`.
**Date**: 2026-10-08
**Mode**: review + fix

Counts: critical 0 · major 0 · minor 3 (2 FIXED, 1 DEFERRED).

## Summary

Phase 5 lands Items 5.1 to 5.4 as the outline specifies: the Status line, §Now
Focus, FR-3, FR-4 (four probes, family lists), NFR-2 (Q5 wording), NFR-4, D-8 and
L-2 in `design.md`; a Probe paragraph, no flag policy (Q1), both verdicts
verbatim and the E1–E5 reproduction in `detectors.md`; the D-8 tradeoff rewritten
per D-a/D-d in `sandbox-state.md`; the glob/`$` skip rule and the quoted-literal
residual in `readonly-path.md`; the `--ignored` re-probe with the CC 2.1.293
observation in `lock-detectors.md`; one changelog entry; the `CLAUDE.md` rule
narrowed. The verdict texts match `lib/verdicts.sh` byte for byte, the probe
description matches `probe_resume_lost`, the `readonly-path.md` examples each
have a case in `tests/probes-readonly-globs.bats`, and the lock re-probe
paragraph matches `m4-reprobe-evidence.md`. `docs/design.md` is at 399 lines.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

None.

### Minor Issues

1. **`README.md` describes `resume-lost` by its `lost` verdict only**
   - Location: `README.md:57-58`
   - Note: "a `claude --resume` whose transcript the sandbox never let persist"
     no longer covers the `found` verdict (Q2, `verdict_resume_lost found`).
     Rewritten to name the refusal, the out-of-sandbox existence check, and
     both outcomes, in the shape of the `git-lock` and `readonly-path` bullets.
     `detect` over the new text is quiet.
   - **Status**: FIXED

2. **`detectors.md` §resume-lost understates the `unknown` outcome's `HOME` case**
   - Location: `docs/references/detectors.md:203-205`
   - Note: the bullet said `unknown` arises with "both it and `HOME` unset".
     `lib/probes.sh` computes `root=${HOME:+$HOME/.claude}`, so an empty `HOME`
     also gives an empty root and `unknown`. Now reads "or it unset and `HOME`
     unset or empty".
   - **Status**: FIXED

3. **FR-5's flag-pairing suite list lags `tests/hook-resume.bats`**
   - Location: `docs/design.md:101-103`
   - Note: `tests/hook-resume.bats` pairs each fixture with the flag absent and
     `true` (its "flag true" cases at `:145-160`), so FR-5's three-suite list is
     incomplete. Adding the name was tried: after `just format-docs` the file
     went from 399 to 400 lines, which the dispatch forbids (no net line, no
     cramming). Reverted to the committed text; `docs/design.md` is unchanged
     from HEAD.
   - **Status**: DEFERRED — costs a net line in a file at 399/400; the FR-4
     family offset is spent. A later edit that frees a line in `design.md`
     should name `tests/hook-resume.bats` in FR-5, or replace the list with a
     rule ("the `hook-*.bats` suites whose policy depends on the flag").

## Fixes Applied

- `README.md:57-59` — `resume-lost` bullet rewritten to cover the `lost` and
  `found` verdicts; reflowed by `just format-docs`.
- `docs/references/detectors.md:203-205` — `unknown` bullet: `HOME` "unset or
  empty", matching `${HOME:+…}` in `probe_resume_lost`; reflowed.

## Deferred Items

The following items were identified but are out of scope:

- **FR-5 pinned-by list naming `tests/hook-resume.bats`** — Reason: the dispatch
  allows the fix only at no net line in `docs/design.md`; it costs one.

## Requirements Validation

| Requirement | Status | Evidence |
|-------------|--------|----------|
| m-1 (stale state layer) | Satisfied | `design.md:8` Verified against `d8a8591` (2026-10-08), the last code commit; `:19` Focus "closing the review-fixes jobs". |
| m-3 (D-8 mitigation false) | Satisfied | `sandbox-state.md:14-32` drops "the probes cover the verdicts where it matters", states the case is live, costs per detector per D-a/D-d; `design.md:283-288` D-8 and `:383-384` L-2 state the no-flag case; `detectors.md:193-245` Probe, "Flag policy. None", both verdicts, E1–E5 (CC 2.1.292) matching `resume-probe-evidence.md`. |
| m-4 (`--ignored` re-probe) | Satisfied | `lock-detectors.md:111-119`: CC 2.1.289 observation kept, CC 2.1.293 contrast added (bare covered form no mask name; `true && command git status --porcelain --ignored` sandboxed by a refused `/tmp/<name>` write, 20 `??` and one `!!`), re-probe now `git status --porcelain --ignored`, reason stated. Matches `m4-reprobe-evidence.md` calls 2 and 3. |
| m-6 (pinned-by lag) | Satisfied | FR-3 names `hook-malformed.bats`'s "probe or verdict that dies mid-run" (cases at `tests/hook-malformed.bats:184,200,218`); FR-4 names the `tests/probes*.bats` and `tests/hook-*.bats` families, which cover `hook-locks-pathless.bats`, `probes-resume.bats`, `hook-resume.bats`. FR-5 lag: see Minor 3 (DEFERRED). |
| m-11 (glob `readfile=`) | Satisfied | `readonly-path.md:68-73` rule (`*`, `?`, `[`, `$` skipped; name after the last `<` tested) matches `lib/probes-readonly-command.sh:236-239` (`${word##*<}` against `*[*?[\$]*`); examples `grep pat *.log x.err` → `x.err`, `cat $OUT.log` → none, `grep 'err.*'<x.log` → `x.log` each have a case in `tests/probes-readonly-globs.bats:76-137`; quoted-literal residual `:123-125` has its case at `:115-122`. |
| m-16 (`check-jq` spy) | Satisfied | NFR-4 `design.md:198-199` "`tests/check-jq.bats` the `SessionStart` check with a `mktemp` spy"; `tests/check-jq.bats:99-106` has `make_spy … mktemp` and asserts no log. |
| m-18 (BSD-case rule, Q5) | Satisfied | `CLAUDE.md:22-24` and NFR-2 `design.md:177-180` name the five stubbed tools; `tests/helpers/bsd-stubs.bash` stubs exactly `sed`, `mktemp`, `grep`, `stat`, `wc`; every bats file loads `bsd-stubs` (`grep -L` finds none). |
| FR-4 (reproduction recorded in `references/`) | Satisfied | `detectors.md:224-245`. |
| Item 5.4 changelog | Satisfied | One entry; every claim in it and in the f5ddf6d skill paragraph traced: strict mode ignores the flag (`SKILL.md:74`), background session and `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB` (`:78-79`), allow rule as mitigation (`escapes-and-costs.md:67-70`), CC 2.1.293 and 2.1.292 versions as in the evidence files, `just precommit` Python compile step (`justfile:44-46`). |

**Gaps:** none blocking. The FR-5 list is the one known lag (DEFERRED above).

## Checks on the dispatch's known items

- **README passage** — fixed (Minor 1).
- **FR-5 list** — tried, cost a line, reverted, DEFERRED (Minor 3).
- **Corpus sentence on the all-zero id** (`detectors.md:247-251`) — stated as a
  conditional ("with none, it would read `lost`, a false positive, since no
  transcript was meant to exist"), not as a measured result; the 2-hit,
  100% figure keeps its 2026-09-25 date and the policy it was measured under.
  Accurate as written; no change.
- **Status line** `d8a8591` (2026-10-08) — accepted per dispatch.
- **Q5 wording** — matches `tests/helpers/bsd-stubs.bash`'s five tools.

## Verification run

`just format-docs` rc=0 (reflowed `README.md:57`, `detectors.md:203`);
`rumdl fmt --check -q --no-cache` rc=0; `scripts/check-line-limits.sh` rc=0
(`docs/design.md` 399 lines); `scripts/check-links.sh` rc=0. `detect` from
`lib/matchers.sh` run directly over `README.md`, `docs/design.md` and
`docs/references/detectors.md`: quiet. No bats file and no `just precommit`
run, per the dispatch. Nothing committed; `docs/design.md` has no diff against
HEAD.

## Positive Observations

- Both verdict texts in `detectors.md` match `lib/verdicts.sh` exactly, human
  lines included, and no live file quotes the refusal line.
- The E1–E5 bullets carry only what `resume-probe-evidence.md` records, with the
  self-proving write test and the untested cases (`--continue`, the picker)
  named.
- `sandbox-state.md` states the accepted tradeoff as current truth with the cost
  per detector, with no narration of what it used to say.
- `lock-detectors.md` keeps the CC 2.1.289 observation and adds the 2.1.293
  one as a grounded re-observation, giving the `--ignored` reason in one clause.
- The FR-4 family lists stop the enumeration from lagging, as m-6 asked.

## Recommendations

- When any later `design.md` edit frees a line, spend it on FR-5's list
  (`tests/hook-resume.bats`) or convert that list to a family rule.
