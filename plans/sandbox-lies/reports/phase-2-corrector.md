# Review: Phase 2 checkpoint — gate scripts, hook, lock probes

**Scope**: `d51b60f..HEAD` (Items 2.1–2.4) plus the five orchestrator-carried
edits. Per-slice diffs were already reviewed twice each; this pass covers
cross-item consistency, the living docs against what shipped, Item 2.4 as a
whole, the Verification standard and the Portability rule.
**Date**: 2026-09-25
**Mode**: review + fix

## Summary

Phase 2 shipped what the runbook says, and every requirement it pins has an
accurate status and pinned-by line in `docs/design.md`. This pass found one
code defect: the config-lock extractor was unanchored while its matcher is
anchored, so the probe could read a quoted copy of the error instead of the
line that fired. It also found helper duplication across the four probe suites
and several doc lines that had fallen behind the code. All are fixed. All five
carried edits are applied. `docs/design.md` is at exactly 400 lines after
`rumdl fmt`. One small architecture-map addition could not fit and is recorded
as UNFIXABLE-CAP.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

1. **The config-lock extractor reads a different line from the one its
   matcher fired on**
   - Location: `lib/probes.sh` `_probe_config_lock_path`
   - Problem: `match_config_lock` fires only on
     `^error: could not lock config file …: File exists`, a line-start anchor
     that detectors.md calls the discriminator. The extractor used
     `s/.*could not lock config file …/`, unanchored, and took the first match.
     If a `> `-quoted copy of the error (the pilot report's echo shape) came
     before the live line, the probe took the quoted path. It then stat'ed the
     wrong lock, and would answer `orphan` for a lock that does not exist.
   - Fix: anchor the extractor as the matcher is anchored. New test
     `config-lock reads the line-start error, not a quoted one` in
     `tests/probes-config.bats`. It was red on its assertion before the anchor
     (`[ "${output%%$'\n'*}" = mask ]` failed; 11 passed, 1 failed) and is
     green after.
   - **Status**: FIXED

2. **Design and reference lagged the shipped probe behaviour**
   - Location: `docs/design.md` D-14 and NFR-2;
     `docs/references/detectors.md` Conventions and the config-lock Probe
     paragraph
   - Problem: slice 10 made an errored holder check read `unknown`, but D-14
     still said only "with neither". NFR-2 listed BSD `grep`/`sed`/`mktemp`
     while the probes depend on BSD `stat` and `wc`, both now stubbed. The
     Conventions paragraph gave a probe only its flag argument, not the
     payload `cwd` as `$2`. The config-lock Probe said "on `.git/config.lock`"
     though the probe appends `.lock` to whatever config file the line names,
     `config.worktree` included.
   - Fix: D-14 now says "With neither, or a failed check," (same line count).
     NFR-2 now lists `stat`/`wc`. Conventions now name `cwd` as the second
     argument. The config-lock Probe now says "on the config file the
     line-start error names, plus `.lock`".
   - **Status**: FIXED

3. **No changelog entry for Phase 2's design-significant changes**
   - Location: `docs/changelog.md`
   - Problem: three design-level changes had no record: the relative-path
     base decision, the widened `unknown` outcome, and NFR-5 closing with
     inline links only. The changelog stopped at Item 2.3.
   - Fix: added a `2026-09-25 — the gates and the lock probes` entry. It
     covers the gates closing NFR-5 with the inline-only link scope, the
     probes built but not wired, why a relative path resolves from the
     nearest `.git` directory (checked on git 2.47.3 per `build-phase-2.md`),
     errored → `unknown`, and the chardev-sentence qualification.
   - **Status**: FIXED

### Minor Issues

1. **Duplicate teardown in two probe suites**
   - Location: `tests/probes.bats`, `tests/probes-edges.bats`
   - Note: both files had the same 7-line teardown that kills the
     `hold_lock` job.
   - **Status**: FIXED. It is now `kill_holder` in
     `tests/helpers/probes.bash`, next to `hold_lock`, and each teardown calls
     it.

2. **Duplicate no-`.git`-above precondition loop**
   - Location: `tests/probes-config.bats` (`no .git above cwd keeps cwd`,
     `relative cwd terminates at the working directory`)
   - **Status**: FIXED. It is now `assert_no_git_above <dir>` in the helper.
     Checked by hand that it exits 1 under errexit when an ancestor holds
     `.git`.

3. **Stale `tests/probes-edges.bats` header**
   - Location: `tests/probes-edges.bats:1-4`
   - Note: the header said the file held "edge cases Item 2.4 slice 3's code
     review already fixed … because tests/probes.bats stood at 256 lines".
     The file also holds slice 4/5 cases and NFR-4's writes-nothing check.
   - **Status**: FIXED. The header now describes what the file holds.

4. **Helper comments named only `probe_git_lock`**
   - Location: `tests/helpers/probes.bash` (file header, `tools_only_path`)
   - **Status**: FIXED. They now say "the lock probes" and list every helper.

5. **Architecture map omits the two gate scripts and `scripts/lib/`**
   - Location: `docs/design.md` Architecture block
   - **Status**: UNFIXABLE-CAP. See below.

## Fixes Applied

- `lib/probes.sh` — `_probe_config_lock_path` is anchored at
  `^error: could not lock config file`, and its comment says why.
- `lib/verdicts.sh` — both phantom paragraphs carry the qualified sentence
  (carried edit 1).
- `tests/verdicts.bats` — the transcribed chardev paragraph matches
  (carried edit 1).
- `tests/probes-config.bats` — new anchoring test; the precondition loops now
  call `assert_no_git_above`.
- `tests/probes.bats`, `tests/probes-edges.bats` — teardown calls
  `kill_holder`; the edges header is rewritten.
- `tests/helpers/probes.bash` — `kill_holder` and `assert_no_git_above`
  added; header and `tools_only_path` comments corrected.
- `docs/design.md` — Status (edit 5), Paths (edit 4), NFR-5 (edit 2), NFR-2,
  D-14.
- `docs/references/detectors.md` — chardev verdict (edit 1), git-lock Probe
  and `unknown` row (edits 3, 4), config-lock Probe (edit 4 plus the anchored
  read), Conventions `cwd` argument.
- `docs/changelog.md` — the Phase 2 entry.
- `plans/sandbox-lies/runbook.md` — Item 2.2 is inline-only (edit 2); Item
  2.4 records the checkpoint's anchoring test.

## The five carried edits — final text

**1. Chardev verdict** (`detectors.md`, `lib/verdicts.sh` ×2,
`tests/verdicts.bats`). The paragraph is now:

> The character-device entries in this listing are sandbox masks over
> dotfiles in the project root, not files in the repository. Leave them out of
> every add, delete and report. With no sandboxed command running in the
> background, `ls -a` and `git status` run unsandboxed show the real tree.

phantom-untracked is that paragraph plus its unchanged `??` sentence. Lengths:
chardev 287 characters, untracked 382, both under FR-6's 400 (asserted by
`verdicts under 400 chars`). Self-quiet: `verdict text is quiet` and
`tests/docs.bats` are green.

**Also removed:** the clause "; outside the sandbox they do not exist". It
contradicts the correction ("visible from any process while a sandboxed
command runs"). With it kept, the qualified untracked paragraph measured 422
characters and broke FR-6. The general claim, that these are masks and not
repository files, is kept. Nothing else in either paragraph changed.

**2. NFR-5 and Item 2.2 are inline-only.** Design text:

> every inline relative link resolves (reference style unchecked)

Runbook Item 2.2 text:

> every relative inline markdown link (`[x](target)`) in the same tracked
> markdown scope as Item 2.1 resolves … reference-style `[x][r]` definitions
> are unchecked (none in scope)

"None in scope" was checked by grepping tracked scope markdown for reference
definitions and `][` uses. No match in scope; the only hit was in an untracked
`.claude/` file.

**3. `unknown` row:**

> | `unknown` | path present, no holder tool on `PATH`, or the holder check
> errored (`bytes=`, `age=`) |

The `orphan` row is unchanged: "path present, holder check ran, no holder
(`bytes=`, `age=`)". It is still accurate: an errored check no longer counts
as having run.

**4. Relative lock-path resolution.** design.md Paths paragraph, rewritten in
place:

> A lock probe takes its path from the error text; a relative one (git prints
> it from the main worktree's top-level) resolves from the nearest ancestor of
> the payload's `cwd`, itself included, holding a `.git` directory, else from
> the `cwd`, and with no `cwd` from the probe's working directory, never `/`.

To fit the cap, the parenthetical "(what it holds after a `cd` inside the call
is unrecorded)" was dropped from the hub. The fact stays in detectors.md
Conventions ("where a `cd` inside the call leaves `cwd` is unrecorded"), so
nothing is lost from the doc set. The old "git prints it absolute" clause went
too: it is false for config-lock.

detectors.md git-lock Probe:

> git prints it absolute; a relative one resolves against the nearest ancestor
> of the payload `cwd` (itself included) holding a `.git` directory, else
> against the `cwd`, and a missing or empty `cwd` falls back to the probe's own
> working directory, never `/`

detectors.md config-lock Probe:

> As `git-lock`, on the config file the line-start error names, plus `.lock`.
> Git prints that path relative to the main worktree's top-level even from a
> subdirectory, and absolute from a linked worktree or a submodule, which is
> why a relative path resolves from the nearest `.git` directory rather than
> from the `cwd`.

**5. Status line:**

> **Status:** Partial. Built and tested: the hook, the `phantom-*` verdicts,
> the lock probes (not live-proved or hook-called). Nothing dogfooded; no
> candidates.

`Verified against:` was **left unchanged**. I did not re-verify the whole doc,
only the sections this report touches, so the stamp still predates Phase 1.

## UNFIXABLE-CAP

- **Architecture map line for the gates.** `docs/design.md` is at exactly 400
  lines after `rumdl fmt`, and adding this line would make 401. Proposed line,
  to go after `scripts/run-bats.sh` in the Architecture block:
  `scripts/check-*.sh      line-limit and link gates (NFR-5); lib/ shared walk`.
  This is minor: NFR-5 already names both scripts. Note that the design doc
  now sits exactly at its cap, so the next change that adds a line needs my
  human partner's split decision (Item 2.1's escalation rule).

## Requirements validation (Phase 2 pins, Cross-cutting "Design status")

| Requirement | Status line | Pinned-by accurate |
|---|---|---|
| FR-1 | Partial (dogfood: 8.1) | yes — `hooks/hooks.json`, `tests/hook.bats` key-set assertion |
| FR-3 | Partial (probe call: 4.1) | yes — `hook.bats`, `hook-malformed.bats` |
| FR-4 | Partial (live proof 3.1; hook call 4.1; `readonly-path` 4.3) | yes — `tests/probes*.bats`; `character device is mask`, `no holder tool is unknown` exist |
| FR-5 | Partial (4.1, 4.2, 6.1) | yes — `hook.bats` `phantom verdicts ignore the flag` |
| FR-6 | Partial | yes — `verdicts.bats`, `hook-cap.bats` |
| FR-10 | Partial (phantom and `/tmp` retired) | yes |
| NFR-2 | Done | yes — all 14 bats files load `helpers/bsd-stubs` (checked by grep); list widened to `stat`/`wc` |
| NFR-3 | Done (100 ms measured, not gated) | yes — changelog 2026-09-24 figures |
| NFR-4 | Done (read scope: review) | yes for the hook; the probes' own writes-nothing check (`probes-edges.bats`) joins the pin when Item 4.1 wires them |
| NFR-5 | Done | yes, narrowed to inline links |

The runbook Requirements mapping rows for Phase 2 match what shipped.

## Verification-standard audit

Every assertion class new in Phase 2 was turned red once. The evidence is the
slice RED reports (a failed assertion against an inert stub) or a Mutation
proof section. Checked:

- Item 2.1 — slices 1–4 red on assertions; slice 5 by mutation.
- Item 2.2 — slices 1–4 red; slices 5–6 by mutation, including the BSD grep
  half (`-aoE`→`-aoP`).
- Item 2.3 — slice 1 red, plus the test review's V1–V7 mutation table
  covering "quiet" and "no removal"; slices 2, 3, 6, 7, 8 red; slices 4, 9, 10
  by mutation (`-qE`→`-qP` for the BSD hook case).
- Item 2.4 — slices 1–4 and 6–10 red; slices 5, 8's added cases and 11 by
  mutation. The `wc` padding strip was mutation-proven in the slice 9 GREEN
  report.
- This checkpoint's anchoring test was red before the fix.

**Classes with no red, both named as smoke runs in their test comments:**

- `oversized markdown survives BSD mktemp` (`tests/check-line-limits.bats`).
  No mutation the `mktemp` stub refuses can reach the script's
  trailing-`X` template in one run.
- The `mktemp` half of `broken link survives BSD grep and mktemp`
  (`tests/check-links-edges.bats`). Same reason; its `grep` half is
  mutation-proven.

## Portability audit

Every new bats file loads `helpers/bsd-stubs`. Each suite exercising shell
code has one stubbed case:

- line limits: `oversized markdown survives BSD mktemp`
- links: `broken link survives BSD grep and mktemp`
- hook: `hook under BSD stubs`
- probes: `BSD stat` (`stat wc`) and `vanished lock is gone under BSD stat`

`hook-cap`, `hook-malformed`, `hook-verdicts`, `probes-edges` and
`probes-config` are split-off files of suites that already have their stubbed
case.

## Item 2.4 reviewed whole

`lib/probes.sh` matches the Item 2.4 text and Interfaces as revised:

- the A-3 contract, and `$2` resolution with the walk-up
- holder check order: `lsof` first, then `fuser`, and `unknown` when neither
  is present or the check errored
- BSD `stat -f %m` first, then GNU `-c %Y`, each accepted only as whole
  seconds
- the two commented stderr exceptions
- no `mktemp`

Across the four suites plus the helper, the only inconsistencies were the
duplication and stale comments fixed above. The pathless outcome stays open,
as the runbook records.

## Lifecycle check

- No staged content.
- No `MERGE_HEAD`.
- `.git/config.lock` shows inside the sandbox as a 0-byte character device.
  Stat'ed unsandboxed, it does not exist, and `fuser` finds nothing. It is a
  sandbox mask, not a stray lock.
- No `.git/*.lock` outside the sandbox.

## Precommit

`just precommit`, foreground, final line:

`precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests`

(bats: 131 passed, 0 failed)

## Positive observations

- The probe's stderr handling follows the no-stderr-suppression order: the
  guard comes first, then capture-and-match, then two commented exceptions.
- Every suite's wrong-reason hunting shows in its fixtures: decoy locks,
  distinct byte counts, and a backdated mtime for age.
- The `run_probe_bounded` process-group kill is a careful answer to the
  orphaned FIFO reader.
