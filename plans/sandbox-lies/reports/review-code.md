# Review: Finish review gate — whole build, weighted to Phase 8

**Scope**: `git diff e873bf4..0df5864` over hooks, lib, tests, scripts, docs,
justfile, `.bin`, `.envrc`, README.md, CLAUDE.md, pyproject.toml, .rumdl.toml,
weighted to Phase 8 (`7c4f811..HEAD`). Phases 1–7 and the two Phase 8
checkpoints (`phase-8-corrector.md`, `phase-8c-corrector.md`) were taken as
settled; earlier code was re-read only where Phase 8 depends on it.
**Date**: 2026-09-27
**Mode**: review + fix. Nothing committed; nothing staged.

## Summary

D-17 holds across code, tests and nodes. Every verdict condition is selected by
a probe fact or the flag, `partial=1` alone selects the no-target merge clause,
`merge=1` keeps its meaning, and the `match=` clause never reads `partial=1`.
The shim, the 8.0/3 review fixes and slice 8.0/5 are correct and pinned. Six
findings, all fixed:

- one major: the linear-cost merge pass in `_readonly_repo_facts` had no test
  for either of its unequal-name branches;
- five minor: two undeclared or misstated probe contract points in the nodes,
  two stale state-layer lines in `docs/design.md`, and a test comment citing a
  residual that does not exist.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

1. **The ls-tree merge pass's unequal branches were unpinned**
   - Location: `lib/probes-readonly-facts.sh:389-402` (`_readonly_repo_facts`),
     from the 8.0/3 linear-cost fix (Critical Issue 2 of
     `item-8-0-s3-code-review.md`).
   - Problem: the pass pairs the sorted modified-file list with the sorted
     ls-tree records. It steps one side when a name is only on that side. Every
     fixture had identical name sets on both sides, so the `elif [[ < ]]` and
     `else` branches never ran. I mutated `<` to `>` in place and ran
     `probes-readonly-facts.bats`, `probes-readonly-pins.bats` and
     `hook-candidates.bats`: all 37 passed. A swapped step drops every
     `match=` after the first unpaired name, and nothing caught it.
   - Fix: two tests in `tests/probes-readonly-pins.bats`, sharing a
     `make_merge_pass_repo` helper.
     - A staged new file `m`, absent at the target, sorts before the matching
       `z`. This exercises the file-side step.
     - A modified file `x` that is a directory at the target, so ls-tree lists
       `x/y`, sorts before `z`. This exercises the tree-side step. The test
       asserts the precondition, that ls-tree lists `x/y`.

     Each asserts `target=feat` and `match=z`. Mutation results, each applied
     in place and reverted with `git checkout -- lib/probes-readonly-facts.sh`:

     | mutation | test 1 | test 2 |
     |---|---|---|
     | swap `<` to `>` | red | red |
     | `elif false` (always step files) | green | red |
     | `elif true` (always step tree) | red | red |

     Unmutated, both are green.
   - **Status**: FIXED.

### Minor Issues

1. **detectors.md Conventions misstated the probe arguments**
   - Location: `docs/references/detectors.md` Conventions.
   - Problem: it said a probe takes "the flag as its first argument and the
     payload `cwd` as its second". Since Item 8.0, `hooks/annotate.sh` passes
     `tool_input.command` as `$3` to every probe. FR-4 and `hook.md` Flow
     already say so.
   - Fix: "with the flag, the payload `cwd` and `tool_input.command` as its
     arguments". The line count is unchanged.
   - **Status**: FIXED.
2. **Both probes print `path=`, but neither node declared it**
   - Location: the `docs/references/detectors.md` §readonly-path Probe
     paragraph, and the `docs/references/lock-detectors.md` git-lock Probe
     paragraph.
   - Problem: the verdicts select acts from `path=`. `readonly-path` uses it
     for the settings-path act, and `config-lock` `mask` for the update-config
     act. D-17 wants every fact a probe prints declared. `path=` appeared only
     in the verdict bullets and the live-reproduction transcripts; the
     outcome and fact tables did not list it.
   - Fix:
     - `detectors.md`: "Extract the path from the matching line, printed as
       `path=`". Reflowed, the file stays at 399 lines.
     - `lock-detectors.md`: "Every outcome also prints the resolved lock path
       as `path=`." This matches `lib/probes.sh`, which prints it on all five
       outcomes.
   - **Status**: FIXED.
3. **`## Now` Focus named work already done**
   - Location: `docs/design.md` `## Now`.
   - Problem: Focus read "Item 8.2's memory-tier edits, then review and TDD
     audit". Those edits landed: memory commit `e247362` is recorded in the
     parent at `d1cd31c`. The deferred remainder (the file's deletion) is out
     of scope.
   - Fix: "closing the first build — its review and TDD audit."
   - **Status**: FIXED.
4. **FR-10's pinned-by asserted a test that does not exist**
   - Location: `docs/design.md` FR-10.
   - Problem: it said "`tests/docs.bats` fails if a live pointer … still names
     the retired path". `tests/docs.bats` has no such case: it is deferred
     with the file's deletion (`build-phase-8b.md`). That makes it an
     unverified pin stated as present.
   - Fix: "from the file's deletion, `tests/docs.bats` fails if …", with the
     status parenthetical naming "the deletion and that case: Item 8.2". The
     deferred work itself is not raised.
   - **Status**: FIXED.
5. **A test comment cited a residual detectors.md does not carry**
   - Location: `tests/probes-readonly-pins.bats`, the `git pull` pin comment.
   - Problem: "(Residual, detectors.md)" pointed at a bash-5-cannot-reproduce
     residual that no node states.
   - Fix: the citation is dropped, and the comment otherwise stands.
   - **Status**: FIXED.

### State layer: Verified-against re-stamped

`45c03163` resolved, but it predates slice 8.0/5 and the 8c checkpoint.
`phase-8-corrector.md` left re-stamping to Finish. I checked each hub claim
against `0df5864`:

- Status;
- FR-1 to FR-11 and NFR-1 to NFR-5, both status and every pinned-by file;
- NFR-2's "every bats file loads bsd-stubs", 25 of 25 files;
- D-16 against the shim and `.envrc`;
- D-17 against `lib/verdicts.sh` and the probes.

With findings 3 and 4 fixed, the stamp is now `0df5864e` (2026-09-27), and
`git rev-parse --verify 0df5864e^{commit}` resolves.

## Fixes Applied

- `tests/probes-readonly-pins.bats`:
  - `make_merge_pass_repo` and two merge-pass tests (major 1);
  - the dangling residual citation dropped (minor 5).
- `docs/references/detectors.md`: the Conventions probe arguments (minor 1),
  and `path=` in the readonly-path Probe paragraph (minor 2). Re-wrapped by
  `just format-docs`; 399 lines.
- `docs/references/lock-detectors.md`: the `path=` sentence (minor 2); 155
  lines.
- `docs/design.md`: the Verified-against stamp, the `## Now` Focus (minor 3)
  and the FR-10 pinned-by (minor 4); 395 lines.

`git diff -- lib hooks` is empty: no implementation changed. There is no
`.git/index.lock`.

## D-17 conformance (IN scope)

| Check | Result | Evidence |
|---|---|---|
| Every verdict condition decided by the script | Holds | `lib/verdicts.sh`: lock re-run/retry by flag (`_lock_rerun`, `_lock_retry`); readonly tail by `readfile=` → settings `path=` (writable only) → whole call; merge clause by `match=` / (`partial=1`, no `target=`) / none. Remaining conditionals are the repeat-failure clauses D-17 keeps, seccomp's ruled exception, and the phantom text Item 8.0 excluded |
| Every printed fact declared | Holds after minor 2 | readonly: `path=` plus five facts in the Probe facts table; lock: `path=`, `pid=`, `bytes=`, `age=` in `lock-detectors.md` |
| `partial=1` selects the no-target clause | Holds | `elif [ -n "$partial" ]`; three needles in `_readonly_partial_checkout_text`, including `cannot create directory at`; `verdicts-readonly.bats` and `hook-candidates.bats` positive/negative pairs |
| `merge=1` keeps its meaning | Holds | gate `[ -z "$sub" ] && [ "$partial" -eq 0 ]` |
| `match=` clause ignores `partial=1` | Holds | the `target=` branch never reads `partial`; test pairs `match=a` with `partial=1` |
| design.md D-17/FR-4/FR-6, detectors.md, lock-detectors.md, hook.md Flow agree with code | Holds after minor 1 | hook passes flag, cwd, command to probes and flag as `$2` to verdicts |

## Shim

- `.bin/claude` strips by identity (`-ef "$0"`), which covers a trailing slash
  and a relative `.bin`.
- Arguments pass through as `"$@"`, and each `PATH` entry is read with
  `IFS= read -r`. Empty entries are preserved.
- `paste -sd: -` takes BSD's explicit operand.
- With no other `claude` on `PATH`, the shim exits 127.
- `.envrc` puts `PATH_add .bin` last.
- The justfile shellchecks `.bin/*`.
- `tests/shim.bats` loads `bsd-stubs` and pins all four behaviours.

## 8.0/3 review fixes

- No `.git/index` rewrite: `diff-index` without a refresh, optional locks
  off, fsmonitor off. Pinned by bytes, mtime and `index.lock` absence over a
  stat-dirty `d`.
- Linear cost: four git processes, the 1000-file cap and the 16384-character
  scan cap are pinned. The merge pass is pinned now (major 1).
- No stderr: pinned per shape (tree tag, blob tag, broken gitlink, unborn
  HEAD).
- The bash 3.2 `set -u` guard on `git pull`: an outcome pin only. bash 3.2 is
  not available here, as the build report records.

## Requirements Validation

| Requirement | Status | Evidence |
|---|---|---|
| D-17 | Satisfied | table above |
| FR-4 | Satisfied | `probe_readonly_path <flag> <cwd> <command>`; facts in `probes-readonly-facts.bats`, `probes-readonly-pins.bats` |
| FR-6 | Satisfied | `< 400` asserted on every readonly composition; longest real composition 289 (`phase-8-corrector.md` §1), unchanged by 8.0/5, whose no-target clause is the existing text |
| FR-11 | Satisfied | needles built from fragments in lib and tests; `tests/docs.bats` green |
| NFR-2 | Satisfied | arrays guarded under `set -u`; `read -d ''`, `+=`, `$'…'`, `[[ < ]]` under `LC_ALL=C` are all bash 3.2; 25/25 bats files load `bsd-stubs` |
| NFR-4 | Satisfied | no-write pins as above |
| NFR-5 | Satisfied | design 395, detectors 399, lock-detectors 155, pins 358 lines; links gate green |

## Judged acceptable, not changed

- Test comments citing items, slices and review-issue numbers
  (`probes-readonly-pins.bats`, `hook-locks.bats:58`). This is the suite-wide
  pattern since Phase 2 (`probes-tools.bats`, `check-links.bats` and others),
  so it is pattern-consistent.
- The `hook.md` Flow line "`verdict_<name>`, given the outcome and the flag"
  also covers a verdict with no probe, which the hook calls with no arguments.
  It reads correctly in context: the sentence follows "calls `probe_<name>` if
  one exists".

## Positive Observations

- The mutation-proof discipline holds across Phase 8. Every negative has a
  positive control over the same fixture, and the hook test runs the real
  probe on cut fixtures.
- `_readonly_repo_facts` has an empty-record sentinel on each streamed git
  call, which tells a truncated list apart from a complete one.
- The nodes carry arguments and the hub carries conclusions, which keeps
  `design.md` under its cap without cramming.

## Gate

`just precommit`, run unsandboxed in the foreground after the fixes: **exit 0**.
`precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line
limits, links, tests`, with **251 bats passed, 0 failed**. The baseline before
the fixes was 249.

## Files changed

- `/Users/david/code/sandbox-lies/tests/probes-readonly-pins.bats`
- `/Users/david/code/sandbox-lies/docs/references/detectors.md`
- `/Users/david/code/sandbox-lies/docs/references/lock-detectors.md`
- `/Users/david/code/sandbox-lies/docs/design.md`
