# Review: Phase 5 checkpoint — Item 5.1 readonly-path live proof

**Scope**: commit 335bc25 (`docs/references/detectors.md` `readonly-path` live
reproduction paragraph; `docs/design.md` FR-4 status line), against the
in-session evidence of 2026-09-26 supplied in the dispatch
**Date**: 2026-09-26
**Mode**: review + fix

**Verdict: Ready**

## Summary

The new paragraph matches the evidence on every checkable point: scratch repo
under `/tmp/claude/`, worktree directly under `/tmp/`, both made unsandboxed; CC
2.1.283 and dash; a sandboxed `sh -c` touch into the worktree failing with
touch's read-only error, its path quoted; the `/tmp` tell in the same call
failing the same way; `detect` naming `readonly-path`; the probe run unsandboxed
printing `writable` and the `path=` line; neither file written; the worktree
removed unsandboxed. It follows the house style of the lock-detectors
live-reproduction paragraphs (bold `Live reproduction (date): outcome.` lead,
placeholders `<root>`, `<worktree>`, versions inline) and keeps self-quiet: it
describes the diagnostic instead of quoting it. The FR-4 status claim is true.
I made two wording fixes. After them, `just precommit` passed.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

None.

### Minor Issues

1. **Why the worktree location reproduces was left implicit**
   - Location: docs/references/detectors.md:156-158
   - Note: The paragraph put the worktree "directly under `/tmp/`" without
     saying that this is what places it outside the sandbox's write allowlist.
     That placement is why the reproduction counts as the sibling-worktree case
     the detector replaces. It is also the premise behind the `/tmp` tell's "so
     that call was sandboxed". The added clause states it.
   - **Status**: FIXED

2. **"naming the file, quoted" was vague on the property the probe depends on**
   - Location: docs/references/detectors.md:159-160
   - Note: The probe extracts the first quoted path, so the quote style
     matters. The evidence shows straight single quotes around the path. The
     text now says "naming the file in straight quotes". It still describes
     the diagnostic rather than quoting it, so self-quiet is unaffected.
   - **Status**: FIXED

3. **The FR-4 status parenthetical listed the verdict, not the hook call, as
   what remains**
   - Location: docs/design.md:84-85
   - Note: FR-4 says the hook runs the probe. The verdict itself belongs to
     FR-6. `hooks/annotate.sh:94` skips a detected name that has no verdict
     function before it reaches the probe call. So the `readonly-path` probe is
     not hook-called yet, and Item 6.1 will wire that call together with the
     verdict. Next to "lock probes proved live and hook-called", the old
     "verdict: Item 6.1" left the missing hook call to inference. The line now
     reads "`readonly-path` probe proved live, hook call with its verdict: Item
     6.1".
   - **Status**: FIXED

## Fixes Applied

- docs/references/detectors.md:156-160: added "outside the sandbox's write
  allowlist" to the worktree clause and replaced ", quoted" with "in straight
  quotes". Reflowed by `rumdl fmt`. The line count is unchanged at 318.
- docs/design.md:85: FR-4 status now names the hook call alongside the
  verdict as Item 6.1's remainder. Still 396 lines.

## Checks performed

- Evidence against paragraph: each claim traced to the dispatch's recorded
  commands and output. `detect` takes no arguments (`lib/matchers.sh:16`), so
  the evidence's `detect false` and the paragraph's bare `detect` agree.
- Command shape: the setup, the sandboxed write, the probe call and the cleanup
  are all recorded. The item's `<cwd>` appears as `<root>`, which is what the
  evidence passed (the project root) and the placeholder lock-detectors.md
  uses.
- Self-quiet: no diagnostic string is quoted. `tests/docs.bats` ran green
  inside `just precommit`.
- Design-doc state layer: the top `Status:` line ("`readonly-path` matcher and
  probe (no verdict yet)") and FR-7 ("without its verdict until Item 6.1") still
  hold and agree with FR-4. The `Now` section and the stamp belong to Item 8.2
  under the runbook. A live proof is evidence, not a design-significant change,
  so it needs no changelog entry.
- Gate: `direnv exec . just precommit` in the foreground printed
  `precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line
  limits, links, tests` (bats 181 passed, 0 failed).

## Requirements Validation

| Requirement | Status | Evidence |
|-------------|--------|----------|
| FR-4 (probe proved live, recorded in `references/`) | Satisfied for `readonly-path` | detectors.md `readonly-path` entry, `Live reproduction (2026-09-26)` paragraph |
| Runbook: status line updated in the item's commit | Satisfied | design.md FR-4 status changed in 335bc25 |
| Line caps (docs ≤ 400) | Satisfied | 318 and 396; line-limits check passed |
| Item 5.1 interface: paragraph that gates Item 6.1 | Satisfied | Heading form `**Live reproduction (YYYY-MM-DD): ...**` present |

**Gaps:** none.

## Positive Observations

- The `/tmp` tell in the same call proves the write ran sandboxed. It uses the
  same reasoning lock-detectors.md relies on, rather than trusting the default
  sandbox.
- The outcome and the `path=` line are both recorded, so Item 6.1's `writable`
  verdict has a live proof for its path substitution as well as for the token.
