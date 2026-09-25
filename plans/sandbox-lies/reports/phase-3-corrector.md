# Review: Phase 3 — Evidence (Items 3.1 and 3.2)

**Scope**: `git diff abee0f5..HEAD`, restricted to the changed files listed in
the dispatch: `docs/references/detectors.md` (Item 3.1 live reproductions;
Item 3.2 candidate entries), `tests/corpus-eval.py`,
`tests/extract-fixtures.py`, the eleven new `tests/fixtures/{fire,quiet}-*`
files, `tests/matchers.bats`. Report files under `plans/sandbox-lies/reports/`
read for context only.
**Date**: 2026-09-25
**Mode**: review + fix

## Summary

Item 3.1 records `orphan`, `held` (git-lock) and `mask` (config-lock) as dated
`Live reproduction` paragraphs with command shape and probe output. Item 3.2
records, for each of the five candidates, a discriminator precise enough to
implement, one `Corpus.` line with hits, true count, precision, date,
pilot-traffic note and false-positive classes, and a `Decision:` line; four
ship, `zellij-socket` stays a candidate with zero true positives recorded. The
harness gains the flag join and the candidates' prefilter strings; eleven
fixtures are cut, reproduce byte-identically from `tests/extract-fixtures.py`,
and each has an `expected_for` row. Two wording tightenings applied to
`detectors.md`; everything else is as specified.

**Overall Assessment**: Ready

## Verification performed

- `just precommit` before and after the fixes: `plugin.json, hooks.json,
  shellcheck, bash -n, rumdl, line limits, links, tests` — bats 131 passed.
- `python3 tests/extract-fixtures.py <the eleven new names>`: all eleven
  found on their recorded project and day; `git status --short tests/fixtures`
  empty afterwards, so every committed fixture is byte-identical to the corpus
  cut (FR-8).
- The recorded discriminators implemented as regexes (scratch script under
  `$TMPDIR`, not committed) and run over every tracked file, every fixture,
  `memory/ddaanet/sandbox-effects.md` and `memory/ddaanet/MEMORY.md`:
  - `fire-readonly-path-{cp-tmp,python-errno,task-output}` → `readonly-path`
    only; `fire-tmpdir-unset-{redirect,cp-stat}` → `tmpdir-unset` only;
    `fire-resume-lost-two-turn` → `resume-lost` only; `fire-seccomp-init-sed`
    → `seccomp-init` only.
  - Every `quiet-*` fixture, every pre-existing fixture, every tracked file and
    both memory files: no candidate fires. The candidates' shapes as recorded
    keep the repository and the store self-quiet (FR-11 / D-10).
- `python3 -m py_compile tests/corpus-eval.py tests/extract-fixtures.py`:
  clean.
- `just format-docs` after the edits: `detectors.md` unchanged by reflow, 397
  lines (cap 400).

## Issues Found

### Critical Issues

None.

### Major Issues

None.

### Minor Issues

1. **readonly-path Python form omits the separator after the exception name**
   - Location: `docs/references/detectors.md:234-236` (readonly-path
     `Matcher.`)
   - Note: the shell form spells out "a colon and a space" after the tool
     prefix; the Python form went from "an exception name ending in `Error`"
     straight to "errno 30 or 16 in brackets", leaving the `: ` between them to
     be inferred. Item 4.3 implements `match_readonly_path` from this
     paragraph, so the separator is part of the anchor.
   - **Status**: FIXED

2. **zellij-socket `Corpus.` line has a bare count with no noun**
   - Location: `docs/references/detectors.md:331-332`
   - Note: "unanchored and case-blind, 67, all quoting the store" — the 67 is
     the unanchored match count, contrasted with the 0 hits; the sentence did
     not say so.
   - **Status**: FIXED

3. **design.md FR-4 status line still names Item 3.1 as pending**
   - Location: `docs/design.md:77-78`
   - Note: "Partial (live proof: Item 3.1; hook call: Item 4.1;
     `readonly-path`: Item 4.3)". The lock probes' live proof is now recorded
     (`orphan`, `held`, config-lock `mask`; git-lock `mask` accepted by
     composition), so the first clause is stale. `design.md` is at 400/400 and
     is not to be edited here.
   - Proposed in-place rewrite, verified on a temp copy to reflow to the same
     two lines and keep the file at 400 lines:
     - old: `` `PATH`. Partial (live\nproof: Item 3.1; hook call: Item 4.1; `readonly-path`: Item 4.3). ``
     - new: `` `PATH`. Partial (lock\nprobes proved live; hook call: Item 4.1; `readonly-path`: Item 4.3). ``
   - FR-7 (`Planned`) and NFR-1 (`Partial (harness promoted)`) stay accurate:
     no candidate matcher exists yet, and the harness is still the arbiter of
     nothing shipped beyond the pilot five.
   - **Status**: DEFERRED — design.md status lines are scope OUT for this
     review; rewrite proposed for the orchestrator.

## Fixes Applied

- `docs/references/detectors.md:234-237` — readonly-path `Matcher.`, Python
  form: inserted "a colon and a space," between the exception name and the
  bracketed errno, so the anchor reads `<Name>Error: [Errno 30|16] <message>: `
  end to end. Reflowed; the paragraph keeps its line count.
- `docs/references/detectors.md:332` — zellij-socket `Corpus.`: "67," →
  "67 matches,". Same line count.

`just precommit` after the fixes: passed, bats 131/131.

## Requirements Validation

| Requirement | Status | Evidence |
|-------------|--------|----------|
| FR-4 | Satisfied (Phase 3 share) | `detectors.md:92-100` orphan and held with date, command shape, probe output; `:136-147` config-lock mask likewise. git-lock `mask` by composition — scope OUT. |
| FR-7 / D-15 | Satisfied | Each of the five candidates carries one `Corpus.` line (hits, true, precision, date, pilot-traffic note, FP classes) and a `Decision:` line (`:262-271`, `:291-295`, `:312-316`, `:331-334`, `:352-355`). `zellij-socket` recorded at zero true positives, stays a candidate. Every FP is self-reference or a named residual per D-15. |
| FR-8 | Satisfied | Eleven SPEC entries in `tests/extract-fixtures.py:82-118`; re-cut reproduces every fixture byte-identically; names letters and hyphens only; `expected_for` has all eleven rows and the coverage cases pass. |
| NFR-1 | Satisfied | Harness under `tests/` (`corpus-eval.py` flag join and prefilter extension; `extract-fixtures.py` name filter). Figures dated, pilot-traffic noted per candidate. |
| Self-quiet | Satisfied | `detectors.md` describes every candidate string; regex implementation of the recorded discriminators fires on no tracked file and neither memory file. |
| Line cap | Satisfied | `detectors.md` 397/400 after `just format-docs`. |

**Gaps:** none in scope.

## Deferred Items

The following items were identified but are out of scope:

- **design.md FR-4 status line** — Reason: design.md status lines are scope
  OUT (file at 400/400); exact rewrite given under Minor Issues 3.

## Positive Observations

- The `readonly-path` prefix definition excludes pipes and colons from the
  prefix run, which is exactly what keeps the store's `| … |` symptom table and
  `grep -n` output (`48:- …`) quiet; the quiet fixtures exercise both.
- `tmpdir-unset`'s "one component under `/`" plus the deeper-path near-miss
  fixture pins the discriminator against the obvious over-match.
- `corpus-eval.py` reads a manifest written before the flag join as flag unset,
  the same reading the hook gives an absent flag — the old scratch manifests
  keep working without a re-extract.
- `extract-fixtures.py`'s name filter, with its unknown-name refusal, lets a
  later run add fixtures without re-picking the committed ones as the corpus
  grows — the docstring names the drift it guards against.
- The `expected_for` comments name which item flips each row and why the rows
  expect nothing now, so the Phase 4 red is legible from the suite alone.

## Recommendations

- When Item 4.2/4.3 land the matchers, add the live memory file and the memory
  index to the candidates' quiet set the way `git-lock` does (the "live memory
  file still fires nothing" case already covers every matcher in
  `matchers.sh`, so this happens by construction once the functions exist).
