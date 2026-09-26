# Review: Item 6.1 slice 2 — code review (TDD phase d)

**Scope**: `verdict_readonly_path` and its comment in `lib/verdicts.sh`, as
the commit "Item 6.1/2 — readonly-path writable verdict through the hook"
added them. Tests touched only to pin a fix.
**Date**: 2026-09-26
**Mode**: review + fix

No UNFIXABLE issues.

## Summary

The verdict reads `path=` from the probe's stdin lines with the file's usual
read loop and prints the detectors.md `writable` text byte-exact, with no
sed or eval anywhere near the path. Three of the four points the
orchestrator raised hold and are fixed: the path now renders in backticks,
a missing path gets a subject instead of a broken sentence, and the comment
says what the code does rather than which slice comes next. The FR-6 length
point needs no code change; the measurements are below.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

1. **A missing path left a broken sentence**
   - Location: `lib/verdicts.sh` `verdict_readonly_path`, `writable` branch
   - Problem: with no `path=` line (empty stdin, as the row-driven
     `tests/verdicts.bats` cases call it), or an empty `path=`, line 1
     started with ` is writable outside the sandbox…`: a leading blank and
     no subject. That is outside the probe contract, which always pairs
     `writable` with `path=`, but it was still malformed text sitting on the
     same code path as the real output.
   - Fix: an empty `$path` prints `The path` in its place. This adds no
     claim that detectors.md lacks: the paragraph is about the refused path,
     and the error names exactly one. Kept this short on purpose. `The path
     in this error` (the wording git-lock uses) takes the row-driven
     paragraph to 406 characters and fails the `< 400` length case. `The
     path` is 8 characters, the same as the doc's `` `<path>` ``, so the
     length case now measures exactly the paragraph as detectors.md writes
     it.
   - Pinned: `tests/verdicts.bats` `readonly-path writable verdict text
     matches detectors.md` now also asserts that empty stdin gives
     `The path` followed by the verbatim rest.
   - **Status**: FIXED

### Minor Issues

1. **The path printed bare, not as an identifier**
   - Location: `lib/verdicts.sh` `verdict_readonly_path`
   - Problem: detectors.md writes `` `<path>` ``, and every other verdict
     puts its identifiers in backticks (`` `config.lock` ``, `` `$TMPDIR` ``,
     `` `~/.claude/projects` ``). phantom-gitadd also opens its paragraph
     with a backticked token, `` `git add` aborted… ``. For the agent
     reading `additionalContext`, the backticks mark where the path ends. A
     bare path holding blanks or ` is ` would run straight into ` is writable
     outside…` with nothing to show the boundary.
   - Fix: the path is printed as `` `%s` `` (plain expansion is kept, so the
     output is still byte-exact). The transcription case accepted either
     form, which left the choice unpinned. It now asserts the backticked
     form only, and its comment is updated to match. The hook case's
     `grep -qF '/r/x'` passes unchanged.
   - Residual: a path that contains a backtick breaks the markdown span. The
     agent reads the raw text, so the path is still there in full.
   - **Status**: FIXED

2. **The comment carried plan state and one inaccurate contrast**
   - Location: `lib/verdicts.sh`, the comment above `verdict_readonly_path`
   - Problem: `(Item 6.1)`, `so far` and `until Item 6.1 slices 3-4 add
     them` are plan state that goes stale when slice 3 lands, and slice 4 is
     the flag policy, not verdict text. `unlike the phantom and lock
     verdicts, this one interpolates` is also wrong: `_verdict_lock_present`
     interpolates `pid=`/`bytes=`/`age=`.
   - Fix: the comment was rewritten to state the contract. The path
     interpolated in backticks by plain expansion, byte-exact; `The path`
     when there is no `path=` line or it is empty; an outcome with no text
     prints nothing, as an unmatched lock outcome does.
   - **Status**: FIXED

## FR-6 length (measured, no change)

The length case measures line 1 with empty stdin. Measured under the fixed
code:

| input | line 1 length |
|---|---|
| empty stdin (`The path` + rest) | 392 |
| `path=/r/x` (`` `/r/x` `` + rest) | 390 |
| fixed tail alone (` is writable…first.`) | 384 |
| detectors.md as written (`` `<path>` `` + rest) | 392 |

So an interpolated line is 386 + the path's length. It stays under 400 for
a path of up to 13 characters, and any real absolute path goes over. A
repo-local `.claude/settings.json` path, for example, comes to about 440.

Nothing should change in code. Truncating the path would drop the one piece
of information the agent acts on. Shortening the text means editing
detectors.md, which is the text source and out of scope. The template stays
under 400, as FR-6's wording applies to verdict text. The hook's 2 KB
`additionalContext` cap already bounds the extreme: a paragraph with a path
near `PATH_MAX` is dropped and its human line kept, which is FR-6's own
fallback. See Recommendations.

## Mutated-SUT run (once)

Mutant: exact-string replace of ``printf '`%s`' "$path"`` with
`printf '%s' 'The path' # MUTANT`, so the path is never interpolated (the
plausible-but-wrong implementation that prints the paragraph without the
path it concerns). Ran `tests/verdicts.bats` and
`tests/hook-candidates.bats`:

- `readonly-path writable verdict text matches detectors.md` — not ok
- `writable outcome through the hook` — not ok
- the other 12 — ok, as expected: none of them looks at the path

Restored by the inverse replace. `grep -c MUTANT lib/verdicts.sh` → `0`, and
the original line is back at `lib/verdicts.sh:114`.

## Fixes Applied

- `lib/verdicts.sh` — comment above `verdict_readonly_path` rewritten
  (contract only, no plan state). The `writable` branch prints the path in
  backticks, or `The path` when it is empty. SC2016 disable added on the
  backtick `printf`, as the file's other literal-backtick lines have.
- `tests/verdicts.bats` — `readonly-path writable verdict text matches
  detectors.md`: the assertion is tightened to the backticked form, its
  comment updated, and an empty-stdin assertion for `The path` added.

Files changed: `lib/verdicts.sh`, `tests/verdicts.bats`.

## Verification

- `direnv exec . scripts/run-bats.sh tests/verdicts.bats
  tests/hook-candidates.bats`: 14 passed, 0 failed.
- Full gate, foreground: `exit=0`,
  `bats: 191 passed, 0 failed`,
  `precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl,
  line limits, links, tests`.

## Requirements Validation

| Requirement | Status | Evidence |
|---|---|---|
| FR-4 (verdict names the probe outcome) | Satisfied (`writable`) | `verdict_readonly_path` interpolates `path=`; hook case asserts `/r/x` in context |
| FR-5 (flag policy) | Out of slice | slice 4 (`hooks/annotate.sh`) |
| FR-6 (acts, < 400, lowercase human line, no removal, quiet) | Satisfied for the template | 392 chars as the length case measures it; `verdict text is quiet` and `no removal instruction` pass; interpolated length above |
| detectors.md `writable` text | Satisfied | transcription case pins it verbatim after the backticked path |

`readonly`/`nopath` text: slice 3, out of scope. They print nothing, which
is correct for now.

## Positive Observations

- The path goes through `printf '%s'` with no sed or eval in reach, and the
  transcription fixture `/r/a b&c\1/x` proves it byte-exact.
- The read loop reuses `_verdict_lock_present`'s form, including the
  `|| [ -n "$line" ]` guard that keeps a final line with no newline.
- The function sits in detectors.md's catalogue order, outside the
  outcome-less "shipped candidates" block, so that block's comment stays
  true.

## Recommendations

- FR-6 in `docs/design.md` does not say whether "under 400 characters"
  counts interpolated values. The lock verdicts' digits are bounded, but a
  path is not. One clause there ("measured with placeholders; interpolated
  values are bounded by the 2 KB cap") would settle it. That is a design-doc
  edit, outside this review's scope. Leave it for whoever closes Item 6.1's
  FR-6 status line.

No in-scope refactoring needed.
