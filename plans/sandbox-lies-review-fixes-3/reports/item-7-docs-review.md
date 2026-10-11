# Review: Items 7.1 to 7.7 (docs)

**Scope**: commits b374c3e..3ee82be against lib/, memory/ddaanet/sandbox-effects.md
**Mode**: review + fix (comments only)
**Overall Assessment**: Ready

## Issues Found

### Minor

1. **Comment reflow left a 108-character line** — lib/verdicts.sh
   `verdict_readonly_path` comment (Item 7.7 substitution joined "nopath has no
   path= line under the contract" onto the previous line). **Status**: FIXED
   (rewrapped at 80).
2. **Ragged comment wraps** — lib/probes-readonly.sh header (`prints none), then
   —` / `under writable ... — the` broken short lines) and the
   `probe_readonly_path` contract comment (an 87-character line). **Status**:
   FIXED (rewrapped, text unchanged).

No other defect. Claims checked against the code as built:

- `%q` contract: `_probe_path_line` (probes-readonly.sh) prints nothing for an
  empty path, else `LC_ALL=C printf -v ... %q`. All six lock print sites and the
  readonly site use it; `pathline` and the newline `nopath` arm are gone (grep
  of lib/ finds neither). lock-detectors.md, readonly-path.md, design.md FR-4,
  and the probes.sh, probes-readonly.sh, `_probe_lock_at` comments agree.
- Decoder: `/*` uses `read` without `-r`, `$'*` is checked against the grammar,
  `\'` unescaped, `%b` on an argument, else return 1 ("The path"). Display: raw
  unless `[[:cntrl:]]` under `LC_ALL=C`, then wire form. readonly-path.md's
  paragraph and the changelog state exactly this. The suffix match tests
  `_verdict_path_raw`.
- Partial-checkout rule: code uses the matching line alone,
  `_readonly_git_dir "$cwd"` (nearest ancestor with a `.git` entry, file or
  directory, itself included), falls back to `cwd`; other producers join onto
  `cwd`. readonly-path.md says the same; `git -C` stays a residual. Not stated
  (not a defect, an empty `cwd` falls back to the probe's `$PWD` as before).
- Phantom wording: lib/verdicts.sh chardev and untracked strings, detectors.md
  :83 (chardev) and :111-114 (untracked, by reference) agree; "project root"
  is gone from all three. hook.md's sentence names no location and does not
  quote the wording. Remaining "project root" hits in lib/matchers.sh:93,99
  describe the matcher and the measured mask set, and are true.
- detectors.md :83: no edit needed (already the new wording since Phase 3); the
  dispatch's omission is correct.
- design.md: 394 lines, no 150-character line in the diff. Status carries no
  "Verified against" text; "Dogfooded 2026-09-27 on CC 2.1.283" grounds a
  claim about a run not repeated, so it stays. The legend still defines
  `Partial`, a definition. No `Partial` status remains.
- FR-10 Done is true of memory/ddaanet/sandbox-effects.md: its opening
  paragraph says it keeps two sections, and the leak and zellij sections are
  present (lines 20 and 39). Translation map rows for zellij and the leak say
  "stays in memory". No `Item 8.2` pointer remains outside the changelog.
- Changelog: 31.7 s to 3.5 s matches item-4-1.md; `utf8_locale` and
  `index_mtime` are used in probes.bats; line-cap scope matches
  scripts/check-line-limits.sh header; the three review guards match commit
  c2e7a81 (non-dict JSONL line in both tools, `null` text item). Closed items
  H (five shapes, reason: a path would not change the act) and I (zellij
  detector cannot ship under D-15 with 0 corpus hits, plus the leak) are named
  by description with reasons; the letters themselves are not written, which
  the outline's letters do not need in a user-facing doc.
- The five `nopath` shapes are described in readonly-path.md and the changelog,
  none quoted, consistent with evidence.md.

## Fixes Applied

- lib/verdicts.sh (`verdict_readonly_path` comment) — rewrapped one 108-char line.
- lib/probes-readonly.sh (header, `probe_readonly_path` comment) — rewrapped.

## Mechanical

- `wc -l docs/design.md`: 394. `just format-docs`: tree unchanged beyond the
  two comment fixes. `scripts/run-bats.sh tests/docs.bats`: 2 passed.
  `just precommit` after the fixes: exit 0, 411 passed, 0 failed.

Nothing committed.
