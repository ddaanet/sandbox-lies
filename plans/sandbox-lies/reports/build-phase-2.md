# Build — Phase 2 remainder (complete)

Phase 2 is done: Item 2.3 slice 10's code review, Item 2.4 (11 slices as
executed), and the Phase 2 boundary corrector. Phase 3 was not started. One
open gate at the end (design-doc cap), non-blocking for Phase 3.

## Per-item outcome

### Item 2.3 slice 10 code review (d)

`item-2-3-s10-code-review.md`, verdict Ready. Fixes: design.md header
`Status:` (Planned → Partial), FR-3 pin names `tests/hook-malformed.bats`,
FR-6 pin names `tests/hook-cap.bats` (no all-verdicts fixture exists), FR-10
remainder "phantom and `/tmp` retired", NFR-4 `Done (read scope: review, not
gated)`; memory: the sandbox-effects description and both index lines
rewritten to a parenthetical, the symptom-table row drops the retired
"untracked". Committed after the gitlore memory-summary gate, approved by my
human partner (relayed by team-lead).

### Item 2.4 — lock probes

`lib/probes.sh` (`probe_git_lock`, `probe_config_lock`, shared
`_probe_lock_at`), suites `tests/probes.bats`, `tests/probes-edges.bats`,
`tests/probes-tools.bats`, `tests/probes-config.bats`, helpers
`tests/helpers/probes.bash`, `stat`/`wc` stubs in `tests/helpers/bsd-stubs.bash`.
Every slice ran RED → test review → GREEN → code review → list revision, each a
separate dispatch. Outcomes delivered: `mask`/`gone` by flag (only the literal
`true` reads unsandboxed), `held` with first pid, `orphan`, `unknown` (no
holder tool, or the holder check errored), character device → `mask`,
vanished lock → `gone`, non-regular lock → no `bytes=`, clamped future
mtime, BSD-first `stat -f %m` with digit checks, writes nothing (no
`mktemp` — the slice 4 GREEN used one; the code review removed it), relative
lock paths resolved from the nearest `.git` directory at or above the payload
`cwd` (my human partner's decision), missing/empty `cwd` → the probe's
working directory.

Slices added by list revision beyond the original nine: slice 10 (errored
holder check → `unknown`, plus three stat edge cases) and slice 11 (walk-up
edge cases). Executed order: 1–7, 9, 10, 8, 11 (slice 8 waited on the
path-base gate).

### Phase 2 boundary corrector

`phase-2-corrector.md`, verdict Ready. One major code fix: the config-lock
extractor is anchored at line start as its matcher is (a `> `-quoted copy
could have been read first; new red-then-green test). Doc fixes: D-14 and
NFR-2 caught up with the probes, detectors.md Conventions name `cwd` as `$2`,
a `2026-09-25` changelog entry. Test helper dedup (`kill_holder`,
`assert_no_git_above`). All five carried edits applied (chardev sentence
qualified across detectors.md, `lib/verdicts.sh`, `tests/verdicts.bats`;
NFR-5 and Item 2.2 inline-only; `unknown` row widened; Paths sentence
rewritten in place; Status line). Verification-standard audit: every new
assertion class red once, except two named BSD-`mktemp` smoke runs (Items 2.1,
2.2), already labelled as such in their test comments.

## Review findings worth my human partner's attention

- **Chardev clause removed beyond the correction's scope.** Besides adding
  the "no sandboxed command running in the background" condition, the
  corrector deleted "; outside the sandbox they do not exist" from both
  phantom paragraphs: it read the clause as contradicting the correction, and
  keeping it put the untracked paragraph at 422 characters, over FR-6's 400.
  The general claim (masks, not repository files) stays. If the clause
  should come back, something else in the untracked paragraph has to shrink.
- **`.git` file vs directory.** The walk-up stops at a `.git` *directory*,
  walking past a `.git` file (linked worktree, submodule), because git
  prints the lock path absolute from those (verified for a linked worktree
  on git 2.47.3). That refines "nearest ancestor holding `.git`".
- **Residuals recorded, not tested:** a symlinked `cwd` walks the link's
  lexical parents; a `cwd` inside a gitdir resolves against an enclosing
  worktree; a config path containing `: File exists` or a non-UTF-8 byte
  (the git-lock twin pins the technique); a pre-epoch mtime; the pathless-text
  outcome stays open (unreachable behind the matchers' gates); the `lsof`
  branch runs in the suite only through a stub.
- The design doc's `Verified against:` stamp still predates Phase 1: nobody
  has re-verified the whole doc.

## For the run summary at Finish

- Refactor signal (slice 5 code review) folded into slice 8's GREEN instead of
  an `edify:refactor` dispatch, following the reviewer's timing advice.
- Slice 11 had no implementation change: after its RED and test review, I
  committed the tests directly (no GREEN dispatch) and skipped its (d) code
  review, since there was no implementation to review. The phase corrector
  covered the suite as a whole.
- The memory-summary approval and the path-base decision both reached me
  relayed through team-lead.
- Dispatches ran unnamed (a teammate cannot name subagents); resumption
  would be by agentId.
- Two agents ran unusually long (slice 8 test review ~2.3 h, slice 8 code
  review ~1.6 h wall time). Both delivered complete reports, and no stray
  process was left.
- List revisions: after slices 1–9 of Item 2.4, each committed; after slice
  10: none; after slice 11: none.
- Item 4.1 inherits runbook notes from Item 2.4: verdicts must not
  interpolate a missing `bytes=`/`age=`, and the `mask` wording for a
  character device under flag `true` needs checking.

## Deviations

- `verify-step.sh` reported DIRTY at entry (the two pre-staged handoff files
  plus this report) and after later items (this report only). Each time I
  substituted `git status --porcelain --untracked-files=no` (empty) plus
  `just precommit` (green). This report is committed with the resume block
  below, so the next session's entry gate should be clean.
- Two runbook list-revision commits were made before `just precommit` ran.
  Precommit passed immediately after each (they changed `plans/` only).
- The staged `.claude/handoff-task.md` / `handoff-todo.md` went into the
  `Item 2.3/10 — code-review fixes` commit, which the lead's carry-over allows.

## Open gate — design doc at its cap (non-blocking for Phase 3)

`docs/design.md` is at exactly 400 of 400 lines after `rumdl fmt`. The phase
corrector had one addition it could not fit: an Architecture-map line
`scripts/check-*.sh      line-limit and link gates (NFR-5); lib/ shared walk`
(minor, since NFR-5 already names both scripts). Any future edit that adds a
line hits the runbook's split-the-design-doc escalation.

**Question:** split the design doc now to make room, or drop the
Architecture-map line?
**Default:** drop the line and leave the doc unsplit. Later flips and edits
rewrite lines in place, and the split decision comes up at the first edit
that cannot fit.

## Phase 2 boundary resume block

```
Resume /build at Phase 3 of /Users/david/code/sandbox-lies/plans/sandbox-lies/runbook.md.
Phase 2 closed at commit "Phase 2 checkpoint — config-lock read anchored; chardev sentence qualified; lock-path base recorded".
Build baseline: .git/build-baseline. verify-step: /Users/david/.claude/plugins/cache/ddaanet/edify/0.3.0/skills/build/scripts/verify-step.sh (run unsandboxed).
Next: Item 3.1 (live reproductions for probe_git_lock / probe_config_lock, recorded in docs/references/detectors.md), then Item 3.2 (candidate triage), then the Phase 3 boundary corrector.
Carry: docs/design.md is at 400/400 lines (open cap gate in plans/sandbox-lies/reports/build-phase-2.md); Item 3.1's config-lock reproduction runs in this checkout's root, and its sandboxed git write must be nested under sh -c; probe_config_lock appends .lock to the named config file and resolves a relative path from the nearest .git directory at or above $2.
```

## Commits this run (oldest first)

- 📝 Item 2.3/10 — code-review fixes
- ✨ Item 2.4/1 — absent lock under the sandbox is mask
- 🐛 Item 2.4/1 — code-review fixes
- 📝 Item 2.4/1 — list revision: slices 2-3 pin the byte-exact and quoted path
- ✨ Item 2.4/2 — absent lock outside the sandbox is gone
- 🐛 Item 2.4/2 — code-review fixes
- 📝 Item 2.4/2 — list revision: slice 3 runs both flags and pins the flag default; slice 7 leaves $2's cwd
- ✨ Item 2.4/3 — present unheld lock is orphan
- 🐛 Item 2.4/3 — code-review fixes
- 📝 Item 2.4/3 — list revision: slices 4, 5, 9 and Item 4.1 pin the probe's edge cases
- ✨ Item 2.4/4 — a held lock names its holder
- 🐛 Item 2.4/4 — code-review fixes
- 📝 Item 2.4/4 — list revision: slice 6 stubs the holder tools in a new suite; slice 9 pins writes-nothing
- 📝 Item 2.4/4 — list revision: slice 5 opens the edge-case suite
- ✨ Item 2.4/5 — a character device at the lock path is a mask
- ♻️ Item 2.4/5 — code-review fixes
- 📝 Item 2.4/5 — list revision: dangling-symlink case; slice 8 lifts the shared helper
- ✨ Item 2.4/6 — no holder tool reads unknown
- 🐛 Item 2.4/6 — code-review fixes
- 📝 Item 2.4/6 — list revision: slice 10 reads an errored holder check as unknown; placement for 7-10
- ✨ Item 2.4/7 — a relative lock path resolves against the payload cwd
- 🐛 Item 2.4/7 — code-review fixes
- 📝 Item 2.4/7 — list revision: slice 8 pins the pathless case; relative-path base escalated
- ✨ Item 2.4/9 — the lock's mtime is read the BSD way first
- 🐛 Item 2.4/9 — code-review fixes
- 📝 Item 2.4/9 — list revision: slice 10 gains the stat edge cases in a new suite
- ✨ Item 2.4/10 — an errored holder check reads unknown
- ♻️ Item 2.4/10 — code-review fixes
- 📝 Item 2.4 — gate answered: a relative lock path resolves from the nearest .git ancestor of the cwd
- ✨ Item 2.4/8 — config-lock probe; relative lock paths resolve from the nearest .git
- 🐛 Item 2.4/8 — code-review fixes
- 📝 Item 2.4/8 — list revision: slice 11 pins the walk-up's edge cases
- ✅ Item 2.4/11 — the walk-up's edge cases, proven by mutation
- 📝 Phase 2 checkpoint — config-lock read anchored; chardev sentence qualified; lock-path base recorded
- (this report's own commit follows)

## Context usage

About 330k tokens of this session's budget used, by the running total
(~14.67M shown remaining). No sign the context window is under pressure.
