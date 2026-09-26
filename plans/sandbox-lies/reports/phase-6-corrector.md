# Review: Phase 6 checkpoint (Item 6.1, readonly-path verdict)

**Scope**: the committed diff `cafc6a7..HEAD` (Item 6.1 slices 1-4, both list revisions, the post-slice wording commit), plus the uncommitted retirement in the working tree and in the `memory` and `memory/ddaanet` submodules.
**Date**: 2026-09-26
**Mode**: review + fix

Nothing is UNFIXABLE. Nothing is committed or staged. The two staged `.claude/handoff-*.md` entries belong to another session and were not touched.

## Summary

Item 6.1 matches its runbook text:

- It ships three verdicts, and their text is the same in detectors.md, `lib/verdicts.sh` and `tests/verdicts.bats`.
- The flag policy (silent when the flag is true, and the probe is not run) lives in `hooks/annotate.sh` and is tested with both flag values.
- The widened extraction covers every row of slice 1's table, and a near-miss case pins `nopath` for any other unquoted shape.
- The retirement removes exactly the three named sections. It keeps the merge-recovery procedure, cost 3's recipe guidance and both classifier notes. The description and both index lines are byte-identical to each other.

The findings were:

- **FR-6's 400-character claim.** The readonly-path `writable` verdict is under 400 characters only as the suite measures it, with no path. With a real path it goes over.
- **Two stale pointers** still named `lib/probes.sh` as the file that holds `probe_readonly_path`, and one test header still cited a retired test.
- **One residual of the extraction was not recorded.**
- **Small comment and alignment fixes.**

All are fixed.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

1. **FR-6's "under 400 characters" is false for `writable` with any real path**
   - Location: docs/design.md FR-6. The text is in lib/verdicts.sh `verdict_readonly_path`.
   - Problem: `verdicts under 400 chars` runs each row with empty stdin. With no stdin, `writable` opens with "The path" and measures 391. The probe contract always supplies `path=`, and the path goes into the paragraph. So the paragraph is 385 plus the path length, which reaches 400 at a 15-character path (measured: 14 gives 399, 15 gives 400). A 26-character path gave 408. FR-6 stated the bound with no qualification. Every earlier verdict interpolates only short digit values (pid, bytes, age); this is the first one that interpolates an unbounded value. Runbook Item 6.1 ("rewritten under FR-6's 400 characters with the test strings below kept") shows the bound was meant for the text before interpolation, so the fix is to state that, not to rewrite the text.
   - Fix: FR-6 now reads "under 400 characters before a probe value (a path, a pid) is interpolated". Its pinned-by now reads "asserts length with no probe lines on stdin". The changelog entry for the phase records the measurement: 391, and 400 at a 15-character path.
   - **Status**: FIXED

2. **tests/probes-readonly.bats header was stale**
   - Location: tests/probes-readonly.bats:1-8
   - Problem: the header named `lib/probes.sh` as the file under test. It also said "No verdict ships yet (Item 6.1), so the hook never calls this probe", citing `hook silent without a verdict`, which slice 2 retired. And it said every refusal line comes from a cut fixture, but slice 1's cases build theirs around `erofs_message`.
   - Fix: the header now names `lib/probes-readonly.sh`, sourced through `lib/probes.sh` as the hook sources it, and credits Item 6.1 slice 1. It points to `tests/hook-candidates.bats` for the hook's call and names both ways the refusal lines are built.
   - **Status**: FIXED

### Minor Issues

1. **lib/matchers.sh named the wrong file for probe_readonly_path**
   - Location: lib/matchers.sh:136-137 (`_readonly_path_line` comment)
   - Note: the comment said "(lib/probes.sh, sourced there)". The probe moved to `lib/probes-readonly.sh`, which is the file that sources `matchers.sh`. I corrected the comment and rewrapped it to 80 columns.
   - **Status**: FIXED

2. **The extraction residual left out a case**
   - Location: docs/references/detectors.md `readonly-path` Probe paragraph; lib/probes-readonly.sh `_probe_readonly_path_from_line` comment
   - Note: the straight-quote rule runs before the curly and unquoted rules. So a curly-quoted or unquoted path that holds two straight quotes is read as whatever lies between them. Measured: `‘/tmp/x'a'b’` gave `path=/cwd/a`, and bash's `line 4: /tmp/it's a 'b':` gave `path=/cwd/s a`. The recorded residual covered only a quoted path holding its own closing quote. Both texts now also record this case. I left the code alone: reordering the rules only moves the misread onto straight-quoted paths that hold curly quotes, and handling both would add a first-quote-style test to the sed script for a rare filename shape.
   - **Status**: FIXED (residual recorded)

3. **Narration in lib/probes.sh comment**
   - Location: lib/probes.sh:13-18
   - Note: "the same BASH_SOURCE-relative pattern used for matchers.sh before the split" told the history of the split. The comment now states only the constraint.
   - **Status**: FIXED

4. **Broken comment line in stub_probe_kv**
   - Location: tests/helpers/hook.bash (`stub_probe_kv` comment)
   - Note: when the helper moved, "hook." ended up on a line of its own. I joined it with the next sentence.
   - **Status**: FIXED

5. **Architecture map column**
   - Location: docs/design.md Architecture block, `lib/probes-readonly.sh` line
   - Note: the new line's `(layer 3)` sat one column to the right of `lib/probes.sh`'s. I aligned it.
   - **Status**: FIXED

6. **phase-6-retirement.md described a tree that had moved on**
   - Location: plans/sandbox-lies/reports/phase-6-retirement.md (untracked; it rides the retirement commit)
   - Note: the report says detectors.md is unchanged, that judgement call 5's sentence was dropped, that there is no changelog entry, and that the Architecture map is untouched. The working tree has all four done. I appended an `## Applied after this report` section saying so and did not rewrite the dispatch's own account.
   - **Status**: FIXED

7. **Scratch files left in `$TMPDIR` by the slices**
   - Location: /tmp/claude-1000/impl.txt, /tmp/claude-1000/old-verdicts.sh (a copy of lib/verdicts.sh), /tmp/claude-1000/pc2.out (a gate log)
   - Note: all three came from Phase 6 slices (15:53-16:32; their contents are readonly-path verdict code and a sandbox-lies gate run), and no report refers to them. I deleted them. There is no stray state inside the repo: no worktree, no stash, no untracked file other than the retirement report and the sandbox masks. Two things I left alone. `/tmp/claude-1000/cfgprobe` belongs to another session's git-config work. The `sandbox-lies-bats.*` logs are what `scripts/run-bats.sh` produces by design.
   - **Status**: FIXED

## Fixes Applied

Repository files changed (all unstaged):

- docs/design.md — FR-6 bound and pinned-by wording (Major 1). rumdl re-filled the paragraph and the file is 397 lines. Architecture map column (Minor 5).
- docs/changelog.md — one sentence added to the 2026-09-26 readonly-path entry recording the FR-6 measurement (Major 1), re-filled by rumdl.
- docs/references/detectors.md — the `readonly-path` Probe residual now also covers the two-straight-quotes case (Minor 2).
- lib/probes-readonly.sh — the same residual in the `_probe_readonly_path_from_line` comment (Minor 2).
- lib/matchers.sh — `_readonly_path_line` comment names `lib/probes-readonly.sh`, rewrapped (Minor 1).
- lib/probes.sh — narration removed from the sourcing comment (Minor 3).
- tests/helpers/hook.bash — `stub_probe_kv` comment joined (Minor 4).
- tests/probes-readonly.bats — header (Major 2). The file is 386 lines.
- plans/sandbox-lies/reports/phase-6-retirement.md — appended `## Applied after this report` (Minor 6).

Memory files changed: none. The retirement edits in memory/MEMORY.md, memory/ddaanet/MEMORY.md and memory/ddaanet/sandbox-effects.md are as the retirement left them.

Outside the repo: I deleted three scratch files from `$TMPDIR` (Minor 7).

Gate, run in the foreground and read by its own exit status:

```
$ cd /Users/david/code/sandbox-lies && direnv exec . just precommit > "$TMPDIR/pc.out" 2>&1; echo "exit=$?"; tail -3 "$TMPDIR/pc.out"
exit=0
scripts/run-bats.sh tests/
bats: 196 passed, 0 failed — full log: /tmp/claude-1000/sandbox-lies-bats.x0hor3
precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests
```

## Requirements Validation

| Requirement | Status | Evidence |
|---|---|---|
| Item 6.1: three verdicts from detectors.md | Satisfied | lib/verdicts.sh `verdict_readonly_path`. `tests/verdicts.bats` has one text case per outcome, and the `writable` tail literal is written once in the code and once in the test. |
| Item 6.1: flag policy (silent when true) | Satisfied | hooks/annotate.sh adds `readonly-path:true` to the policy `case`. `tests/hook-candidates.bats` `readonly-path flag policy` runs one fixture twice: with the flag absent the verdict and the probe call happen, and with it true there is empty stdout and no probe call. |
| Slice 1: widened extraction | Satisfied | Curly quotes, `mv`'s target, and the four unquoted forms each have a case in tests/probes-readonly.bats, and every path holds blanks and `: `. There are regression cases for touch and ln, and a near-miss loop (rm, BSD touch, dash words under another prefix) that asserts the matcher fires and the probe returns `nopath`. There is a BSD-stub case for the curly form and one unquoted form. |
| Command-output-read clause (Item 4.3 revision) | Satisfied | Present in `writable`, and in `nopath` through the shared tail. The hook cases assert `compare modified files against the target` for both. |
| FR-4 Probes | Satisfied | Live proof is in detectors.md (2026-09-26). The hook's call is pinned in tests/hook-candidates.bats. The status line reads Done. |
| FR-5 Sandbox-state awareness | Satisfied | As above. The status line reads Done. |
| FR-6 Verdict text | Satisfied (after Major 1) | Measured with no path: writable 391, readonly 176, nopath 376. All three together through `detect`: exit 1, no output. `tests/docs.bats` passed in the gate. Human lines are one lowercase clause each, with an em dash. |
| FR-7 Catalogue | Satisfied | Status reads Done (four candidates shipped; `zellij-socket` stays a candidate under D-15). The runbook maps FR-7 to Items 3.2, 4.2, 4.3 and 6.1, all done. |
| FR-10 Retirement | Satisfied | The removed sections are exactly the runbook's three. The table rows went with them, and one row was added for the kept `Interrupted merge` remainder. The description and both index lines are byte-identical (shell compare). `detect` over the memory file gives exit 1. None of the six inbound `[[sandbox-effects]]` links points into deleted text. The translation-map rows are true. The status line is Partial, with the rest left to 7.1 and 8.2. |
| Design header status | Satisfied | Reads "the `readonly-path` verdicts with the hook's call to their probe". |

**Gaps:** none.

## Positive Observations

- The verdict joins the path with plain expansion only. It is tested with `/r/a b&c\1/x`, so a path holding `&`, `\1` or a blank goes into the paragraph unchanged.
- An unquoted path is anchored at the tool's own prefix and runs to the last `: `. The tests make every path hold its form's own words and `: `, so a capture that starts or ends at the wrong occurrence fails.
- The curly-quote block avoids byte-class exclusion, and its test puts an em dash, which shares bytes with the curly quotes, into both the prefix and the path.
- Each hook-case positive is distinct from the others: the `sys` lines are exact, and no context substring from one outcome appears in another outcome's text.
- The nopath near-miss test asserts that the matcher accepts the line first, so the test would fail if the matcher, not the extractor, were what refused the line.

## Recommendations

- The `writable` verdict leaves 9 characters of headroom before interpolation. If paragraph length is meant to bound what the agent actually reads, shortening that text is my human partner's call, because the wording was revised deliberately in "compare before re-running".
- Pre-existing and not flagged: detectors.md `## Translation map` says the audit "is a Phase 6 step". That is the outline's numbering, and the runbook item for the audit is 8.2. Item 8.2 may want to fix it when it runs the audit.
