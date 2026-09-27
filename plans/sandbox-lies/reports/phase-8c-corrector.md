# Phase 8c corrector — slice 8.0/5, the no-target merge clause needs git's error

**Scope**: the commit range `d1cd31c..HEAD` (`f05d3a8` spec + fixtures,
`c46241e` GREEN, `e5df535` code-review fix): the 18 changed files the dispatch
lists. Checkpoint form, after the Phase 8 boundary corrector.
**Date**: 2026-09-27
**Mode**: review + fix

## Summary

The slice does what option (a) of `reports/build-phase-8b.md` §Open gate item 1
asks. The probe prints `partial=1` when the text holds any of git's three
partial-checkout errors, and the verdict's no-target "restore them from HEAD"
clause needs that line. The spec, code, tests and fixtures agree. Both fixtures
re-cut byte-identical from the corpus, and the tests reach the real probe and
red under probe-side mutations. There were four minor findings, all fixed: a
spec residual that was missing, a design stamp naming no commit, a test name
the slice had made false, and history-narration comments in tests. One real
defect predates the range and is deferred: the probe resolves the relative path
in git's partial-checkout errors against the wrong directory.

**Overall Assessment**: Ready

## Findings

### Critical

None.

### Major

None.

### Minor

1. **The spec does not name where git's partial-checkout path is resolved.**
   - Location: `docs/references/detectors.md` §readonly-path **Probe**.
   - Problem: git names the path in all three partial-checkout errors from the
     worktree's top-level. The probe joins a relative path onto the payload
     `cwd` (`_probe_readonly_resolve`), and the spec never said which base it
     used. Verified with a scratch repo: run from a subdirectory, git's
     directory error named `sub/new`, not `new`. Under `git -C`, it named the
     path from the `-C` directory. Running the real probe on git's
     directory-creation error, with `cwd` set to the repo root, printed
     `writable` with `merge=1` and `partial=1`. With `cwd` set to a
     subdirectory, it printed `readonly` with the path doubled
     (`…/sub/sub/new`) and no facts. The verdict then says unsandboxing will
     not help, and the merge clause is gone. The fixture added in this range
     is the first recorded instance: it was recorded under `git -C` into a
     worktree the call did not run in, and the hook test overrides `cwd` so
     that the path reads writable.
   - Fix: the Probe paragraph now says a relative path joins onto the payload
     `cwd`. Its Residuals now name the git case: from a subdirectory or under
     `git -C` the path is wrong, and when the parent is missing it reads
     `readonly`, which carries no merge clause. The behaviour itself is under
     Deferred Items.
   - **Status**: FIXED (doc).
2. **`docs/design.md`'s Verified-against stamp names no commit.**
   - Location: `docs/design.md:8`.
   - Problem: `45c0316e` resolves to nothing. The reflog shows the stamped
     commit is `45c03163` ("Item 8.1 numbers requoted …"), an ancestor of
     HEAD, so the eighth hex digit was mistyped. This line was not changed in
     the range, but the dispatch's check list names it.
   - Fix: changed it to `45c03163`, which `git rev-parse --verify` resolves.
     The stamp was not advanced to HEAD. The design's claims that bear on this
     slice still hold (see the conformance table), but the whole hub was not
     re-verified.
   - **Status**: FIXED.
3. **A test name the slice made false.**
   - Location: `tests/verdicts-readonly.bats`, the test named
     `readonly-path merge alone restores the written files then acts`.
   - Problem: under the new spec `merge=1` alone does not restore. The test
     now feeds `partial=1`, and the next test asserts the opposite of its
     name.
   - Fix: renamed it to
     `readonly-path merge with partial=1 and no target restores the written
     files then acts`. The frozen reports that cite the old name are left as
     they are.
   - **Status**: FIXED.
4. **History-narration comments in tests.**
   - Location: `tests/verdicts-readonly.bats` (three comments),
     `tests/hook-candidates.bats` (two).
   - Problem: the comments said "is now required", "added here so this
     composition keeps passing", "Already holds on unchanged code …
     mutation-proved in the RED report" and "per its own note". Those
     describe the change, not the test, and they rot. The last one points at
     the dispatch brief, which a reader of the suite does not have.
   - Fix: reworded them as present-tense statements of what each test pins.
     The hook test's `cwd` comment now states the join the probe makes.
   - **Status**: FIXED.

## Deferred Items

- **The probe misresolves git's partial-checkout path from a subdirectory or
  under `git -C`.** Reason: the path extraction and `_probe_readonly_resolve`
  predate the range. They are Item 6.1 behaviour, and the dispatch's scope OUT
  covers everything outside the range. Both earlier needles have been
  affected since they shipped. The residual is now documented (finding 1).
  Recommendation for a later slice: when the matching line carries git's
  prefix, resolve a relative path from the nearest `.git` ancestor of `cwd`,
  as the lock probes do (`docs/references/hook.md` §Paths). That fixes the
  subdirectory case. `git -C` cannot be fixed without reading the command,
  which D-1 keeps out of detection, so it stays a residual.

## Fixes Applied

- `docs/references/detectors.md` §readonly-path **Probe**: one sentence saying
  where a relative path joins, and one residual for git's partial-checkout
  paths (finding 1).
- `docs/design.md:8`: `45c0316e` changed to `45c03163` (finding 2).
- `tests/verdicts-readonly.bats`: renamed one test (finding 3) and reworded
  three comments (finding 4).
- `tests/hook-candidates.bats`: reworded two comments (finding 4).

No code changed.

## Spec and requirements conformance

| Item | Status | Evidence |
|---|---|---|
| Option (a): the no-target clause only on git's error, plus the third needle | Satisfied | `lib/verdicts.sh` `elif [ -n "$partial" ]`; `_readonly_partial_checkout_text` has three needles |
| `partial=1` row: any of three needles, under any command | Satisfied | the probe sets `partial` before the subcommand gate; `tests/probes-readonly-facts.bats` checks all three under `just sync` |
| `merge=1` row: shape, or `partial=1` printed | Satisfied | gate `[ -z "$sub" ] && [ "$partial" -eq 0 ]`; mutation M3 below |
| `partial=1` only under `writable`/`nopath` | Satisfied | `_readonly_print_facts` is called only from those two branches |
| Merge-clause bullets form a complete partition given `merge=1` | Satisfied | match / no target+partial / target without match / neither; each has a verdict test |
| `match=` clause independent of `partial=1` | Satisfied | the `target=` branch never reads `partial`; test pairs `match=a` with `partial=1` |
| Residuals paragraph (shape-only `merge=1`, a lost error, which git command) | Satisfied | matches the code; relative-path residual added (finding 1) |
| Live reproduction 2026-09-27 | Satisfied | fixture text and recorded command agree with the paragraph; scratch trees gone |
| Corpus note "3 of 195" | Satisfied | the same figure as `phase-8-corrector.md` finding 1; the config-busy fixture is one of the 3 |
| Changelog entry | Satisfied | states the trigger change, the unchanged `match=` clause and the third needle, all accurately |
| D-1 (the command shapes wording only) | Satisfied | `partial=1` comes from the text; `merge=1`'s command reading is unchanged |
| D-17 (the script decides; no condition in the text) | Satisfied | the clause is selected by a fact line; the verdict text holds no conditional |
| FR-4 (the verdict never reads tool text) | Satisfied | the verdict reads stdin facts only; the needle test is in the probe |
| FR-6 (under 400 characters, quiet) | Satisfied | length and matcher-quiet assertions on every new composition |
| FR-11 (self-quiet) | Satisfied | the lib needle and test helper are built from fragments; `tests/docs.bats` passes |
| NFR-3 (bounded) | Satisfied | three in-process `case` matches, no new process |
| NFR-4 (writes nothing) | Satisfied | see Lifecycle |
| D-15 (fixtures cut, never by hand) | Satisfied | both `SPEC` entries exist; a scratch re-cut is byte-identical (`cmp`) |
| `docs/design.md` FR-4, D-17, `## Now` | No change needed | FR-4's "command facts and partial-merge files" and D-17's "a partial merge names the files that match its target" still hold; nothing in `## Now` names the merge clause |
| `docs/references/hook.md` | No change needed | §Paths covers the lock probes' resolution only; readonly-path's is now stated in `detectors.md` |

## Test evidence

- **Fixtures**: I copied `tests/extract-fixtures.py` to a scratch directory
  and re-ran it for both names. `cmp` found both identical to the committed
  files. Each recorded command, taken from the corpus, is byte-equal to the
  one the hook test uses.
- **Probe-side mutations**, each done in place and restored from a copy, with
  `git diff` empty afterwards:
  - M1: the third needle disabled. Two tests redded: the probe-facts
    three-needle case and the hook no-target case.
  - M2: `partial=1` set from command shape. The same two tests redded: the
    negative controls caught it.
  - M3: the needle no longer opens the `merge=1` gate. Three tests redded,
    including the BSD-stub re-run.
- The verdict-side mutation (`elif [ -n "$merge" ]`) was already run by the
  code review and redded both the verdict and hook negatives.
- The hook test runs the real probe (`hook_copy_tree`, no stub). Its negative
  asserts the exact act-alone text, so an empty output cannot pass it.
- All four touched bats files load `helpers/bsd-stubs`.

## Lifecycle audit

- **Probe**: the change adds only `case` globbing on the text. The git reads
  on the `target=` path are unchanged: optional locks off, and `diff-index`
  with no refresh. No write path was added.
- **Tree after the suites and the mutation runs**: no `.git/index.lock`. A
  `.git/config.lock` shows only inside the sandbox; stat run unsandboxed says
  it does not exist, so it is a mask. `git worktree list` shows the main tree
  only. The tree holds only my four edits, the pre-existing staged handoff
  files and sandbox masks.
- **Live reproduction scratch**: no `/tmp/sl8c*` left behind, checked
  unsandboxed. The mutation backups and scratch repos under `$TMPDIR` were
  removed.

## Recommendations

- `docs/references/detectors.md` is at 399 of 400 lines. The next addition
  should split §readonly-path into its own node, as `lock-detectors.md` was
  split, with inbound links fixed. It should not be trimmed to fit.
- The deferred path-resolution fix above, as its own TDD slice.

## Gate

`just precommit` after the fixes: exit 0. Recap: `precommit passed:
plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests`
(bats: 249 passed, 0 failed). Nothing committed.
