# Review: review-fixes-3 docs group (Items 7.1 to 7.7)

**Scope**: `git diff d6d0043..HEAD -- docs` against the code as built, including
the per-escape decoder change from the code review gate.
**Mode**: review + fix. Requirements context: FR-4, FR-6, FR-10, NFR-5.

## Summary

The docs state the code as built. One gap: the changelog described the decoder
as a single `printf %b` pass and did not mention the per-escape decode the code
gate introduced. Fixed. Everything else verified.

**Overall Assessment**: Ready

## Issues Found

### Minor Issues

1. **Changelog decoder sentence predates the per-escape decode**
   - Location: docs/changelog.md, review-fixes-3 entry.
   - Problem: omitted that the `$'...'` form is decoded one escape at a time so
     a digit after a control byte's octal escape stays a digit
     (`lib/verdicts.sh` `_verdict_path_read`).
   - Fix: added that clause. `readonly-path.md` says only that the decoder
     never evaluates the value and shows raw unless a control byte is present;
     both remain true, no edit needed.
   - **Status**: FIXED

## Verification

- Stale-contract grep over docs/ (newline exception, "project root" phantom
  wording, `nopath` meaning, "Item 8.2", "Partial"): no stale statement. The
  remaining "project root" hits are probe-reproduction narrative, not verdict
  wording; "Partial" survives only in the status legend; the `readfile=`/
  `match=`/`target=` newline skips in readonly-path.md match the changelog.
- Phantom wording: `lib/verdicts.sh` verdicts name no location; detectors.md
  and hook.md agree.
- `path=` in `printf %q` form: design.md FR-4, lock-detectors.md,
  readonly-path.md and the changelog agree; `nopath` means "no path extracted".
- FR-10 Done is true of `memory/ddaanet/sandbox-effects.md` (read only): it
  keeps exactly the phantom-leak and zellij sections the translation map names.
- Line cap: `scripts/check-line-limits.sh` covers `*.awk`, `*.toml`, justfile,
  `*.json` as the changelog states.
- docs/design.md 394 lines (under 400, shrank). `just format-docs` rewrapped
  only the edited changelog paragraph. `scripts/run-bats.sh tests/docs.bats`:
  2 passed, 0 failed.
- Changelog is one entry covering code, tests and Python tools, naming closed
  items H (five `nopath` shapes) and I (Item 8.2 remainder) with reasons.

## Fixes Applied

- docs/changelog.md — decoder clause added; reflowed by `just format-docs`.
