# Runbook Review: sandbox-lies first build

**Artifact**: plans/sandbox-lies/runbook.md
**Design**: docs/design.md, docs/references/detectors.md
**Outline**: plans/sandbox-lies/outline.md
**Date**: 2026-09-23
**Mode**: review + fix-all

## Summary

All FR-1 to FR-11, NFR-1 to NFR-5 and D-16 trace to items. The five planner
decisions hold against the design. The review found no critical issues but
found fourteen major ones. Most are execution blockers the text would have
hit mid-build: a test that cannot pass with the design's own verdict text,
two commits turned red by the plan's own sequencing, and live reproductions
placed where the sandbox does not produce the symptom. Several tests were
also vacuous. All fourteen are fixed in the runbook. One design question is
left open, and one size risk now has an explicit stop condition. The
runbook grew from 534 to 681 lines. The simplifier pass follows.

**Overall Assessment**: Ready (after fixes)

## Requirements Coverage

| Requirement | Phase | Items | Coverage | Notes |
|---|---|---|---|---|
| FR-1 | 2, 8 | 2.3, 8.1 | Complete | key set asserted; hooks.json both events now asserted |
| FR-2 | 1 | 1.1 | Complete | |
| FR-3 | 1, 2, 4 | 1.4, 2.3, 4.1 | Complete | 1.4 and 4.1 added to table |
| FR-4 | 2–6 | 2.4, 3.1, 4.1, 4.6, 5.1, 6.1 | Complete | |
| FR-5 | 1, 2, 4, 6 | 1.4, 2.3, 4.1–4.5, 6.1 | Complete | lock fixture sweep added (4.1/7) |
| FR-6 | 2, 4, 6 | 2.3, 4.1–4.5, 6.1 | Complete | cap tested with a stub, not an all-verdicts fixture (see Minor 9) |
| FR-7 | 3, 4, 6 | 3.2, 4.2–4.6, 6.1 | Complete | |
| FR-8 | 1, 3 | 1.1, 3.2 | Complete | |
| FR-9 | 7 | 7.1, 7.2 | Complete | |
| FR-10 | 2, 4, 6, 7, 8 | 2.3, 4.1–4.5, 6.1, 7.1, 8.2 | Complete | |
| FR-11 | 1, 8 | 1.1, 1.3, 8.2 | Complete | |
| NFR-1 | 1, 3, 4 | 1.1, 3.2, 4.2–4.6 | Complete | shipped matcher re-measured |
| NFR-2 | 1, 2 | 1.1, 2.1–2.4 | Complete | one BSD-stubbed case per suite |
| NFR-3 | 2 | 2.3 | Complete | verdict-path wall time added |
| NFR-4 | 2 | 2.3 | Complete | |
| NFR-5 | 1, 2 | 1.2, 2.1, 2.2 | Complete | |
| D-16 | 8 | 8.1 | Complete | |

## Planner decisions checked

1. **Eight phases, conditional 4.2–4.6/5.1/6.1.** This holds: each live
   reproduction (3.1, 5.1) comes before the verdict it gates (4.1, 6.1).
2. **rumdl in Item 1.2.** This holds (markdown-formatter-choice,
   uv-direnv-venv). The one gap was the direnv session effect (Major 13).
3. **The pilot README is deleted.** This holds.
4. **`mktemp` is removed from `detect` (2.3 slice 8).** This holds. The
   hook-level test was vacuous (Major 6).
5. **Length.** No prose was shaved to hit the cap. The growth comes from
   the fixes.

## Review Findings

### Critical Issues

None.

### Major Issues

1. **The verdict test contradicts the design text.**
   - Location: 2.3 slice 1, `no removal instruction`.
   - Problem: the test failed on any `delete`. The phantom-chardev verdict
     in detectors.md says to leave the masks out of every add, delete and
     report, and phantom-untracked restates that. So the test could not
     go green without the executor changing the design's text.
   - Fix: the test now strips the phrase `add, delete and report` before
     matching.
   - **Status**: FIXED

2. **Item 4.1 turns `tests/matchers.bats` red.**
   - Location: 4.1 (and 8.2).
   - Problem: the live-file case greps the store for git's partial
     follow-on quote. Item 4.1 deletes the index.lock section, and the
     cross-cutting rule removes the matching frontmatter symptom. Those
     are the file's only two occurrences (verified), so the grep fails
     and the gate goes red.
   - Fix: 4.1 now deletes that case in the same commit, and 8.2 deletes
     the one live-file case that remains.
   - **Status**: FIXED

3. **Item 3.2's fixtures turn `tests/matchers.bats` red.**
   - Location: 3.2.
   - Problem: the suite's case requiring an expectation for every fixture
     on disk fails as soon as the new fixtures are cut, and their rows
     only arrive in Items 4.2–4.6.
   - Fix: 3.2 adds each new fixture with a no-verdict row. In each of
     4.2–4.6, slice 1 flips the fire row to the detector name, and that
     flip is the item's genuine red.
   - **Status**: FIXED

4. **The config-lock reproduction was in the wrong place.**
   - Location: 3.1.
   - Problem: the `.git/config.lock` mask sits only in the session's
     project root. It is seen as a character device in this checkout today
     and does not exist in a scratch repo under `/tmp/claude/`.
   - Fix: this reproduction now runs in the checkout root with a
     throwaway key, which is cleaned up if the write succeeds. A missing
     error now also stops the phase.
   - Related evidence: a review-time attempt of the git-lock stranded-lock
     shape in a `/tmp/claude/` scratch repo committed cleanly. The item now
     says so and escalates rather than guessing.
   - **Status**: FIXED

5. **The readonly-path reproduction could not trigger.**
   - Location: 5.1.
   - Problem: `/tmp/claude/` is writable inside the sandbox (verified), so
     a worktree there never produces the read-only error.
   - Fix: the worktree now goes directly under `/tmp/`, which was verified
     read-only inside the sandbox.
   - **Status**: FIXED

6. **The hook write test was vacuous.**
   - Location: 2.3 slice 8.
   - Problem: an empty-`TMPDIR` check passes against the old `mktemp`
     buffer, because that buffer removed itself.
   - Fix: the test now uses a nonexistent `TMPDIR` and asserts the same
     output as slice 1.
   - **Status**: FIXED

7. **The flag-policy test passed vacuously.**
   - Location: 2.3 slice 4.
   - Problem: the "byte-identical" outputs would also be identical if all
     three were empty.
   - Fix: the test now also requires non-empty output.
   - **Status**: FIXED

8. **The shared-paragraph assertion was impossible.**
   - Location: 2.3 slice 3.
   - Problem: the phantom-untracked paragraph restates phantom-chardev,
     so "chardev paragraph absent" cannot hold as a substring check.
   - Fix: the test now asserts that `additionalContext` equals the
     untracked verdict's line 1 exactly.
   - **Status**: FIXED

9. **The verdict interface was defined after the item that builds it.**
   - Location: 2.3 and 4.1.
   - Problem: 2.3's `verdict_<name>` interface said "as Item 4.1". The
     probe call (with which arguments) was split ambiguously between 2.3
     and 4.1, and 2.3 would have shipped an untested probe call.
   - Fix: the verdict interface now lives in 2.3, and 2.3 calls verdicts
     only. 4.1 owns the hook-to-probe contract (flag, cwd, and only for
     names that have a verdict), with slice 8 added.
   - **Status**: FIXED

10. **The BSD `stat` path was untestable, and stderr rules conflicted.**
    - Location: 2.4.
    - Problem: on Linux the real `stat -f` is filesystem mode, so a stub
      that only refuses `-c` exercises nothing. Separately, the rule
      against `2>/dev/null` conflicted with a try-BSD-then-GNU selection
      and with `fuser` always writing to stderr.
    - Fix: the stub now serves `-f %m` from the real `stat -c %Y`. The
      two expected-noise captures are justified inline, per
      no-stderr-suppression, and slice 9 runs under the stub.
    - **Status**: FIXED

11. **The line-limit test contradicted its port source.**
    - Location: 2.1.
    - Problem: the asserted output dropped the colon that edify's script
      prints. The item also said "tracked" while the port walks `find`,
      which would sweep `.venv/`.
    - Fix: the interface now uses the port's format and a
      `git ls-files -z` walk with a ROOT argument. Fixture roots are git
      repos, and an untracked-file case was added.
    - **Status**: FIXED

12. **The skill would have duplicated stayed-candidate sections.**
    - Location: 7.1.
    - Problem: stayed-candidate sections were to go into the skill while
      also staying in memory, which D-11 forbids.
    - Fix: skill-mapped remainders are taken regardless of ship status.
      A detector-mapped part stays only in memory, and the post-state was
      updated to match.
    - **Status**: FIXED

13. **Editing `.envrc` mid-session breaks the gate runs.**
    - Location: 1.2 and cross-cutting.
    - Problem: shells that are already running never see the new venv
      `PATH`, and `direnv allow` is a trust step.
    - Fix: a cross-cutting note now covers this. Gates run as
      `direnv exec . just precommit` until the session restarts, and
      8.1's verification invokes `./.bin/claude` directly.
    - **Status**: FIXED

14. **The retired-path guard fired on files that must stay.**
    - Location: 8.2.
    - Problem: a bare `sandbox-effects.md` needle would fire on the
      `tests/extract-fixtures.py` cut selector (needed for FR-8
      reproducibility) and on a historical comment in
      `tests/matchers.bats`. It would also fire on `docs.bats` itself.
    - Fix: the needle is now the full retired path, built from fragments.
    - **Status**: FIXED

### Minor Issues

1. **Items 6.1 and 7.1 deleted skill-mapped text early.**
   - Problem: 6.1 would have deleted the merge-recovery paragraph, which
     the translation map sends to the skill, before the skill exists.
   - Fix: 6.1 now leaves it for 7.1. 7.1 now depends on 4.2–4.5 and 6.1.
   - **Status**: FIXED

2. **Items 1.4, 2.1, 2.2, 2.3, 4.6, 6.1 and 8.1 had missing or loose
   dependencies.**
   - Fix: 2.1–2.3 now declare `Depends on: Item 1.2` (they edit
     `precommit`), 4.6 and 6.1 depend on 4.1, and 8.1 depends on 2.3 and
     7.1. Item 1.4 now records the event-name and `cwd` fields that 2.3
     and 4.1 consume. It also names three calls, including a sandboxed
     write outside the allowlist, since L-5 cannot be answered from a
     plain failure. Bash is allowed in the nested `claude -p`.
   - **Status**: FIXED

3. **`tests/hook.bats` was projected past its cap.**
   - Problem: it was projected at about 390 lines, and Item 2.1 caps
     `*.bats` at 400.
   - Fix: helpers moved to `tests/helpers/hook.bash`, and candidate hook
     cases moved to `tests/hook-candidates.bats`. This is a test-layout
     change, not a design decision. FR-5's pinned-by line names both
     files when it flips.
   - **Status**: FIXED

4. **`detectors.md` growth was unbounded.**
   - Problem: it is 311 lines, with additions due from 1.4, 3.1, 3.2, 5.1
     and 8.2.
   - Fix: 3.2 now keeps each record to the shipped entries' shape
     (`Matcher.` paragraph plus one `Corpus.` line). 8.2 records its audit
     as a table column and fixes the stale "Phase 6 step" reference.
   - **Status**: FIXED

5. **`docs/design.md` sits at exactly 400 lines.**
   - Problem: 1.3 adds the exemption paths, and 2.1's gate has no
     allowlist.
   - Fix: 1.3 now replaces the wording rather than adding to it, and 1.2
     records the post-reflow count. 2.1 now stops and escalates if the
     file is over its cap, since splitting the living design is a
     design-doc decision.
   - **Status**: FIXED (stop condition; the split itself, if needed, is
     escalated)

6. **Several tdd assertions were loose.**
   - Fix, per item:
     - 4.1 slice 3 now names the outcome token the stub prints.
     - 4.1 slice 6 now states its assertion.
     - 4.1 slice 7 adds a sweep over every lock fixture with both flag
       values (FR-5 "each fixture").
     - 2.3 slice 5 now adds both flag values.
     - 2.3 slice 7 now names its payload.
     - 6.1's substring assertions are now robust to backticks around the
       path.
     - The verdicts table now asserts FR-6's em-dash human line.
     - 2.4 slice 4 now closes bats' fd 3 on the holder job.
     - 2.4 slice 5 now uses a symlink to `/dev/null`, so path extraction
       keeps the ordinary lock shape.
   - **Status**: FIXED

7. **Hooks-config, verdict-less and BSD cases were missing.**
   - Fix: 2.3 now asserts `hooks.json`'s events, matcher, timeout and
     command. It also tests the no-verdict rule that 4.6 relies on, and
     adds a BSD-stubbed case.
   - **Status**: FIXED

8. **Some items were ambiguous, and one path and one comment went stale.**
   - Problem, in each case, and what now happens:
     - 1.3 offered "per-file or aggregate" and now takes aggregate only.
     - 1.3's fault injection now builds its text from fragments.
     - 2.2 now names its test file and interface, and adds a whitespace
       slice.
     - 3.2's arbiter matcher is now scratch and not committed.
     - 1.1 now updates design.md's Status line, which names the removed
       pilot path.
     - 1.2 now tracks `uv.lock`, adds `.gitignore` and shellchecks
       `*.bash`.
     - 2.3 now drops `detect`'s exit 2 with the buffer.
     - 2.3 and 4.1 now record verdict-path wall time for NFR-3's 100 ms
       bound.
     - Each shipped matcher now re-runs the corpus pass (NFR-1). Without
       it, precision would have been measured on a scratch matcher.
   - **Status**: FIXED

9. **FR-6's cap test differs from the design's pinned-by line.**
   - Problem: design.md says `tests/hook.bats` asserts the 2 KB cap on an
     all-verdicts fixture. The runbook uses a 1900-character stub, which
     is stronger (real verdicts under 400 characters may never reach
     2 KB).
   - Fix: none needed. Update FR-6's pinned-by line when it flips.
   - **Status**: FIXED (no change; noted)

10. **`/gitlore:push` in 8.2 is outward-facing.**
    - Problem: it retires the fact for every ddaanet repo.
    - Fix: it now waits for my human partner's confirmation.
    - **Status**: FIXED

11. **Prose edits to one artifact are split across items.**
    - Problem: `sandbox-effects.md` is edited across 2.3, 4.1, 4.2–4.5,
      6.1, 7.1 and 8.2, and `detectors.md` across 1.4, 3.1, 3.2, 5.1 and
      8.2. The format's "no split prose edits" rule forbids this.
    - Fix: none. D-11 (retire per section in the translating commit) and
      FR-4 (the reproduction precedes the verdict) require the split, so
      it is accepted as design-mandated.
    - **Status**: FIXED (accepted deviation; no change)

12. **D-15 does not say who may name a residual class.**
    - Location: 3.2.
    - Problem: D-15 lets a candidate ship when every false positive is
      self-reference or "a named residual recorded beside the figure".
      Nothing says who may name a new residual class, so an executor
      could name its way past the rule.
    - **Status**: UNFIXABLE. This is a design decision for D-15. The
      suggestion is that a residual class not already listed as
      "Expected residual" in detectors.md goes to my human partner rather
      than being named by the executor.

## Fixes Applied

- Cross-cutting: tdd "same commit" defined, self-quiet broadened,
  portability rule, direnv note.
- Requirements table: FR-3, FR-5, FR-9, NFR-2 and NFR-3 rows corrected.
- 1.1: design.md Status line, and the fate of `detect`'s exit 2.
- 1.2: `uv.lock`, `.gitignore`, `*.bash`, post-reflow count, `direnv
  exec` done condition.
- 1.3: aggregate case, line-neutral exemption record, fragment-built
  fault.
- 1.4: three named calls, `--allowedTools Bash`, event and `cwd` fields,
  L-5 call.
- 2.1 and 2.2: test files, interfaces, port format, tracked walk, git
  fixture roots, whitespace and untracked slices, dependencies.
- 2.3: helper file, lib sourced from own path, sweep payload rule,
  interfaces, and slices 1, 3, 4, 5, 7, 8, 9 and 10.
- 2.4: holder-check wording, config lock path, `stat` stub emulation,
  justified captures, fd 3, symlink, slice 9.
- 3.1: config-lock moved to the checkout root; non-reproduction stop.
- 3.2: scratch arbiter, record shape and size, `expected_for` rows.
- Phase 4 preamble: red flip, verdicts rows, corpus re-run, candidate
  hook file.
- 4.1: hook-to-probe interface, stubbed probes, `matchers.bats` case
  deletion, and slices 3, 6, 7 and 8.
- 4.2 and 4.6: targets; 4.6 dependency and slice 5.
- 5.1: worktree outside the write allowlist.
- 6.1: remainders kept, targets, assertions, dependency.
- 7.1: stayed-candidate handling, post-state, dependencies.
- 8.1: verification procedure, dependencies.
- 8.2: one remaining case, full-path needle, audit as a column, push
  confirmation.

## Design Alignment

- Every item was checked against D-1 to D-16, FR/NFR and detectors.md.
  After the fixes, no item contradicts the design.
- The verdict test assertions quote only the detectors.md verdict phrases.
- No runbook line quotes a diagnostic together with its follow-on. The
  runbook, run through the pilot `matchers.sh`, prints nothing.
- The requirement mapping was checked against the tracked tree. Today
  exactly the five A-2 files fire; the 26-case pilot suite passes with
  0 skips; shellcheck is clean; the in-scope markdown links all resolve.
