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

## Carry list

- Scratch transcripts from the m-3 probe stay on the host:
  `~/.claude/projects/-tmp-claude-resume-probe-A/` and `…-B/`. They hold
  session `9835c8f4-cc22-40b4-8b5b-19712e4bcef1` and are harmless. They were
  left in place because they sit in my human partner's config directory,
  outside this repo. My human partner may delete them.
