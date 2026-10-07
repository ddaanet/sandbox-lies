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
  - [ ] Phase 3: executor committed. Its review (mutation testing) is running.
    `tests/hook-verdicts.bats` got no BSD case: its code path calls no
    stubbed tool.
  - [x] m-4 (Q6) re-probe observed on CC 2.1.293: `m4-reprobe-evidence.md`
  - [ ] Phases 4 to 6, then the finish (review gate, tdd-audit)

## Open question

- **`CLAUDE.md`'s BSD-stub rule (Q5).** Narrowing the rule edits the
  project's `CLAUDE.md`. The instruction reached this delegate through the
  coordinating agent, not from my human partner directly, so this delegate
  leaves `CLAUDE.md` unedited and asks. Default: apply the narrowing. The
  proposed text replaces "a suite exercising shell code keeps one case re-run
  with `make_bsd_stubs` on `PATH`" with "a suite whose code under test calls a
  stubbed tool (`sed`, `grep`, `mktemp`, `stat`, `wc`) keeps one case re-run
  with `make_bsd_stubs` on `PATH`". NFR-2 in `docs/design.md` is edited to
  match.

## Decisions given

- m-3: a `resume-lost` probe that searches `~/.claude/projects/*/<id>.jsonl`,
  plus doc corrections (D-8, L-2, `sandbox-state.md`, `detectors.md`).
- Q1 to Q6: every default taken. They are recorded in `outline.md`
  §Decisions: no flag policy for `resume-lost`; a `found` verdict; the fixture
  `cat` still fires; m-11 fixed; m-18 over eight suites with the `CLAUDE.md`
  and NFR-2 rule narrowed; m-4 re-probe with `--ignored`, re-observed.

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
