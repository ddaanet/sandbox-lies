# Delegate status — sandbox-lies-review-fixes-2

Fix job for `plans/sandbox-lies-review-fixes/reports/deliverable-review.md`.
Scope: Major 1, m-1 to m-6, m-9 to m-18. Out: m-7, m-8 (fixed upstream).

## Progress

- [x] Job directory created
- [x] `/edify:design`: classified Moderate (`classification.md`), code read
- [x] m-3 empirical probe run and recorded (`resume-probe-evidence.md`)
- [x] Outline written (`outline.md`)
- [x] Outline approved: my human partner took every default (Q1 to Q6)
- [ ] `/edify:build plans/sandbox-lies-review-fixes-2` (the outline routes to
      `/build` with no runbook)
  - [x] Phase 1, Item 1.1: Slice A (probe) and Slice B (`found` verdict, no
        flag policy), each with RED, test review, GREEN and code review
        committed
  - [x] Phase 2, Item 2.1 (m-11): one slice, committed with its code review
  - [x] Phase 3: executor and review (mutation testing) committed.
    `tests/hook-verdicts.bats` got no BSD case: its code path calls no
    stubbed tool.
  - [x] m-4 (Q6) re-probe observed on CC 2.1.293: `m4-reprobe-evidence.md`
  - [x] Phase 4: done in session, self-reviewed, committed
  - [x] Q5 answered (approved): `CLAUDE.md` BSD-stub rule narrowed
  - [x] Phase 5 (Items 5.1 to 5.4): one opus dispatch,
        `reports/item-5.md`, committed
  - [x] Phase 6 (Item 6.1): one opus dispatch, `reports/item-6-1.md`,
        committed
  - [x] Review gate, four groups, committed with their fixes:
    - `reports/review-code-tests.md` (opus; Slice A test and code review
      and Slice B test review under the mutation rule): major 1, minor 4,
      all fixed. One Slice A mutation survived (partial `sed` output not
      discarded) and is now pinned by a test shown red.
    - `reports/review-phase-4.md` (fable): minor 1, deferred to the
      code-tests hunk on the same comment. The `python compile` step
      shown red on a syntax error in each of its two files.
    - `reports/review-docs.md` (fable): minor 3, 2 fixed, 1 deferred
      (FR-5's flag-pairing list omits `tests/hook-resume.bats`).
    - `reports/review-skill.md` (fable, report-only): major 2, minor 6,
      all fixed in session. `SKILL.md` now sits at its 200-line cap.
  - [ ] tdd-audit

## Decisions given

- m-3: a `resume-lost` probe that searches `~/.claude/projects/*/<id>.jsonl`,
  plus doc corrections (D-8, L-2, `sandbox-state.md`, `detectors.md`).
- Q1 to Q6: every default taken. They are recorded in `outline.md`
  §Decisions: no flag policy for `resume-lost`; a `found` verdict; the fixture
  `cat` still fires; m-11 fixed; m-18 over eight suites with the `CLAUDE.md`
  and NFR-2 rule narrowed; m-4 re-probe with `--ignored`, re-observed.
- Q5 `CLAUDE.md` edit: approved. My human partner answered "defaults" after
  being told that default edits `CLAUDE.md`. The rule now reads "a suite whose
  code under test calls a stubbed tool (`sed`, `grep`, `mktemp`, `stat`,
  `wc`)", the list read from `make_bsd_stubs` in `tests/helpers/bsd-stubs.bash`.
  NFR-2 in `docs/design.md` matches (Item 5.1).

## Build state

- Baseline: the outline-approval commit (`📝 Record outline approval …`).
- Entry gate: `verify-step.sh` reads the pre-staged handoff files and the
  untracked entries this job must not touch as dirt. A filtered equivalent
  ignores exactly those entries and still runs `just precommit`.
- Shared dispatch rules: `dispatch-rules.md`, cited by path in every prompt.
- Subagents launch unnamed. The report path carries the dispatch name.

### Slice grouping (plan as executed)

Item 1.1's seven slices run as two:

- **Slice A** (outline slices 1, 2, 3, 4 and 6) covers the probe, the wiring,
  an outcome-aware `lost` verdict and the BSD re-run. Against an inert probe
  stub every probe-level case reds on its assertion. The hook `lost` and BSD
  cases are proven by mutation.
- **Slice B** (outline slices 5 and 7) covers the `found` verdict and the
  dropped flag gate.

Item 2.1's three slices run as one. The over-skip guard (slice 3) is proven by
mutation.

Why: four dispatches per slice over eleven slices would not fit one delegate's
context budget. Each test still carries a red or a mutation proof.

### Mutation testing in per-slice reviews

My human partner's instruction, given mid-build (after Slice B's test review),
binding on every per-slice corrector or review dispatch from then on. The
corrector runs mutation tests, one mutation per behaviour, over:

- every behaviour the slice's green diff added that no RED report names: extra
  branches, guards and fallbacks the implementer wrote beyond the red tests;
- every test written after its code (pins and regression cases such as
  Major 1, m-14 and m-16), which have no red phase;
- any behaviour whose fixture changed between red and green.

It skips a behaviour whose RED report already shows the test failing on its
assertion against the unchanged code, with the fixture unchanged since.

Procedure:

- Run only the slice's own bats files, one process at a time, in the
  foreground, never the full suite per mutation. Expect about 3–5 mutations
  per slice.
- Mutate the subject in place and prove the mutation landed. Run the test, then
  restore by reversing the edit, not from a backup copy. Before reporting,
  confirm with `git diff` that only the intended changes remain.
- A surviving mutation gets its fixture or test fixed by the corrector. The same
  mutation going red proves the fix.
- The slice report carries a table: behaviour | mutation | red or survived (and
  fixed).

Reviewed before the instruction, not redone. The end-of-build review covers
them:

- Slice A (Item 1.1/A): test review and code review. The code review added the
  `unknown` outcome, the `set -u`/`HOME` handling, the empty
  `CLAUDE_CONFIG_DIR` handling and the `failglob` subshell, each behind a test
  shown red.
- Slice B (Item 1.1/B): test review only. Its code review runs under the
  instruction.

## Carry list

- `probe_resume_lost` has a third outcome, `unknown` (nothing checkable: no id
  extracted, or no locatable config dir), and the hook is silent on it. Item
  4.1 (`lib/probes.sh` header) and Item 5.2 (`detectors.md` Probe paragraph)
  must document it.

- Scratch transcripts from the m-3 probe stay on the host:
  `~/.claude/projects/-tmp-claude-resume-probe-A/` and `…-B/`. They hold
  session `9835c8f4-cc22-40b4-8b5b-19712e4bcef1` and are harmless. They were
  left in place because they sit in my human partner's config directory,
  outside this repo. My human partner may delete them.

## Resume

Phases 1 to 6 and the review gate are committed. Next: the tdd-audit
(`edify:tdd-auditor`, dispatch name `tdd-audit`, report
`reports/tdd-audit.md`) over the slice reports of Items 1.1 (Slices A and B)
and 2.1, then the run summary. Build baseline: 72e34d7 (the outline-approval
commit). The follow-up after the build is `/deliverable-review
plans/sandbox-lies-review-fixes-2` (opus, fresh session).

Build mechanics: `just precommit` runs unsandboxed with `run_in_background`
and exceeds 600 s; read its own `precommit passed:` line. Every dispatch cites
`dispatch-rules.md` and names its report under `reports/`. Subagents launch
unnamed.

Carry list: §Carry list above (the `unknown` outcome is now documented in
`lib/probes.sh` and `detectors.md`; the m-3 scratch transcripts on the host
remain for my human partner to delete).
