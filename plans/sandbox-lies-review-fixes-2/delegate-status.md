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

## Carry list

- Scratch transcripts from the m-3 probe stay on the host:
  `~/.claude/projects/-tmp-claude-resume-probe-A/` and `…-B/`. They hold
  session `9835c8f4-cc22-40b4-8b5b-19712e4bcef1` and are harmless. They were
  left in place because they sit in my human partner's config directory,
  outside this repo. My human partner may delete them.
