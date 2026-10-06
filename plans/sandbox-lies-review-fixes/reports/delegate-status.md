# Delegate status — sandbox-lies-review-fixes

## Phase reached

Planning done: outline and runbook approved at `/proof` (2026-10-04). Build
running (`/edify:build plans/sandbox-lies-review-fixes`), baseline `a7ff5e5` (in
`.git/build-baseline`; `tmp/` is not gitignored in this repo, so the baseline
lives under `.git/`).

## Build progress

- Phase 1 — Item 1.1 done (`reports/item-1-1.md`); phase-1 corrector
  `reports/phase-1-corrector.md`.
- Phase 2 — Items 2.1–2.5 done (`reports/item-2-{1..5}.md`); phase-2 corrector
  `reports/phase-2-corrector.md` (Ready; it ran faults for the assertions the
  item reports left unrecorded, fixed three minors).
- Phase 3 — Items 3.1–3.4 done (`reports/item-3-{1..4}.md`); phase-3 corrector
  `reports/phase-3-corrector.md` (Ready; ran the missing faults for 3.4's
  `path=` positives, fixed the paste stub's missing-argument message and
  `git-env.bash`'s `setup_file` fallback).
- Phase 4 — Item 4.1 slices 1 and 2 done (RED, test review, GREEN, code review
  each; `reports/item-4-1-s{1,2}-*.md`), slice-2 refactor
  (`reports/item-4-1-s2-refactor.md`: the operand-rule cases moved to
  `tests/probes-readonly-operands.bats`), list revision committed in
  `runbook.md`. Slice 3 done (`reports/item-4-1-s3-*.md`; the code review fixed
  a `<`-in-argument-slot regression), list revision committed in `runbook.md` (a
  pin for it in slice 4; four docs-step residuals). Slice 4 done
  (`reports/item-4-1-s4-*.md`; the code review fixed four missed uniq operands,
  pinned afterwards by a test-only dispatch with one mutation per run,
  `reports/item-4-1-s4-pins.md`); list revision after slice 4: none. Docs step
  done (`reports/item-4-1-docs.md`). Item 4.1 complete.
- Phase 4 — Item 4.2 done: slice 1 (`reports/item-4-2-s1-*.md`; hook case in
  `tests/hook-writes.bats`), code review folding in the main session's security
  finding (a newline in the repository root split `match=` lines and forged key
  lines: guarded, pinned red-first) plus a trailing-slash `//` fix, pinned by
  `item-4-2-s1-pins`; docs step `reports/item-4-2-docs.md`.
- Phase 4 — Item 4.3 done: slices 1 and 2 (`reports/item-4-3-s{1,2}-*.md`;
  `SessionStart` entry with no matcher and a 10 s timeout), docs step
  `reports/item-4-3-docs.md`. Phase-4 corrector `reports/phase-4-corrector.md`
  (Ready; six minor fixes, faults A–F run).
- Phase 5 — Item 5.1 done on the second dispatch under the revised D1
  (`reports/item-5-1-r2.md`, commit "Item 5.1 — skill exclusion rule per revised
  D1"; post-item gate clean). Item 5.2 done (`reports/item-5-2.md`, with an
  orchestrator addendum): the dispatch stopped at the item's own stop condition,
  `docs/design.md` at 417 lines after moving D-8's argument to
  `docs/references/sandbox-state.md`; my human partner chose option (a′)
  (§Decisions given), applied in session —
  `docs/references/rejected-alternatives.md`, design.md 399 lines — and Item 5.2
  committed. Item 5.3 done in session (`reports/item-5-3.md`; comment and
  help-text edits only, reviewed by the Phase 5 corrector). Item 5.4 done: slice
  1 RED, test review (added an absolute-path half that kills a cwd-keyed guard),
  GREEN, code review (`reports/item-5-4-s1-*.md`); list revision: none (single
  slice). The code review ran the lock probes on scratch input and found the
  same newline `path=` forgery there (§Open question). Phase 5 checkpoint
  `reports/phase-5-corrector.md` (Ready; five minor fixes; lifecycle audit
  clean). Item 5.5 (lock-probe `path=` newline guard, option 1, one tdd slice)
  added to `runbook.md` on 2026-10-06; then the finish (review gate, triage,
  tdd-audit, completion).

## Build decisions

- Entry and post-item gates run `verify-step.sh` with an env-only git exclude
  (`GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.excludesFile GIT_CONFIG_VALUE_0=/tmp/claude-1000/sl/build-exclude`,
  file holding `/.claude/gitlore-memory-message`): that untracked file is
  sanctioned by the dispatch brief and is the gate's only dirt. Nothing in the
  repo changes.
- Dispatches run unnamed (brief), one at a time; report paths still follow the
  build skill's dispatch names.
- From slice 4.1/1's code review on, the harness sometimes refuses a subagent's
  report Write ("Subagents should return findings as text"). That is a reasoned
  refusal, not the no-verdict gap, so it is not routed around: every dispatch is
  told to reply with the full report ending `END OF REPORT` when refused, and
  the orchestrator saves it to the assigned path (noting so at its top) and
  commits it with the slice. A GREEN refused its report commits without it.
- Item 4.1's docs step ran as one opus dispatch after slice 4.
- Slice 3: GREEN implemented only the tested `-e`/`-f` forms; clustered and long
  forms became docs-step residuals (orchestrator's call, recorded in the
  test-review report).
- A code-review fix with no test is pinned before the next step: by the next
  slice's list revision where one remains (slice 3), else by a test-only
  dispatch proving each pin by mutation (slice 4, `item-4-1-s4-pins`).

- From the 2026-10-05 resume on, the main session's tracked
  `.claude/handoff-task.md` and `.claude/handoff-todo.md` edits and an untracked
  `inbox/` sit in the tree and are not this build's. The gates run
  `verify-step.sh`'s two checks by hand: `git status --porcelain` under the
  env-only exclude (now `/.claude/gitlore-memory-message` and `/inbox/`, file
  under `$TMPDIR`), filtered of ` M memory` and those two handoff lines and
  required empty, then `just precommit` with its exit status read.

- Item 5.1's second dispatch reports to `reports/item-5-1-r2.md`, not the
  dispatch name's `item-5-1.md`: that file is the first dispatch's probe
  evidence, cited by the revised D1, and stays as written.

## Deferrals (in the outline's OUT list)

- m-1 quadratic tokenizer, m-7 line-cap gate coverage, m-8 corpus-eval
  idempotency, m-9 extract-fixtures robustness, Unchosen host (dispatch scope).
- Tests m-6 Linux-only suite: portability work, not a mechanical fix.
- `build-finish.md` §Carry-forward (dispatch scope).

## Notes for the main session

- Item 3.1 adds a BSD `paste` stub and a shim case to `tests/shim.bats`; the
  saved `.bin/claude` patch re-applied after the build must keep it green.

## RCA follow-ups

- Item 2.2 first committed a shellcheck failure: `just precommit`'s `tracked()`
  lists files with `git ls-files`, so a new untracked `.bats` or `.sh` skips
  shellcheck and `bash -n` (bats still runs it). Remedied by a follow-up commit;
  every later dispatch is told to `git add` new files before the gate. The gate
  gap itself (`--others --exclude-standard`) is out of this job's scope —
  proposed for my human partner.

## Decisions given

- Runbook approved as committed at `/proof` (2026-10-04).
- The main session's `match=` newline finding folded into Item 4.2 (done).
- 2026-10-05, at the Item 5.1 gate, by my human partner:
  1. **D1 revised.** On CC 2.1.289 an `excludedCommands` entry is honoured for a
     call whose every command it covers. The exception is git with an absolute,
     `~`-led or `..`-bearing path argument (`git init`, `git clone`,
     `git worktree add/move`, `git bundle create`, among others;
     `git config --file /tmp/...` also observed sandboxed), which stays
     sandboxed. Evidence: `reports/item-5-1.md` probes 2–4; the main session
     re-confirmed the bare `git status` case. The 2.288 and 2.289
     `git init -q /tmp/...` probes are recorded as confounded by that rule. The
     re-probe becomes a bare covered `git status` from the project root showing
     no masks. Every "where honoured" / "not honoured" qualifier in the skill
     and references follows, per `reports/item-5-1.md` §What depends on the
     answer; Item 5.2's `lock-detectors.md` text too. Recorded in `outline.md`
     D1 (revision bullet) and `runbook.md` Phase 5 preamble.
  2. **The `path=` newline forgery is fixed in this job**, as Item 5.4 (tdd, one
     slice) in `runbook.md`: a resolved refused path holding a newline is
     reported as `nopath`, and the A-3 contract (`readonly-path.md` outcome
     table) gets a matching line.

- 2026-10-05, at the Item 5.2 gate, by my human partner: `docs/design.md` gets
  back under 400 lines by option (a′) — each rejected alternative's argument
  moves verbatim to a new node `docs/references/rejected-alternatives.md`;
  design.md keeps every name with a one-line conclusion, folded as a *Rejected*
  line under the decision it protects where one maps cleanly (D-9: the
  `craft`/`prohibitions` home and the two names), otherwise in a compact
  §Rejected alternatives list with a pointer to the node. D-8's move to
  `sandbox-state.md` stays. No other section reworded. Result: 399 lines.

- 2026-10-06, at the lock-probe `path=` gate, by my human partner:
  1. **Fixed now with option (1), as Item 5.5** (one tdd slice, shaped like
     Item 5.4): when the lock path holds a newline, `_probe_lock_at` keeps the
     outcome and leaves out the `path=` line; `lock-detectors.md`'s A-3 text
     changes to match; every verdict reading `path=` from a lock probe must
     still read correctly with it absent. RED, test review, GREEN and code
     review per the skill.
  2. **A path encoding is a carry-list entry, not this job** (Carry list,
     first entry, in my human partner's words).

## Carry list

- Later, per my human partner: replace the newline guards — readonly `nopath`,
  and Item 5.5's omitted lock `path=` — with a `path=` encoding that can carry
  newlines. Bash `$'a\nb'` syntax was suggested. A candidate is to print the
  raw path when it holds no control characters and the `printf %q` form only
  when it does; bash 3.2's `%q` also emits the `$'...'` form (verified by my
  human partner 2026-10-06).
- `craft:design-doc-writing` also wants a split to ship with loading
  instructions: `docs/design.md`'s opening should state that it is a hub whose
  detail lives in `docs/references/`, and `CLAUDE.md` should carry a routing
  table from code symbol / FR / D id to node. Neither is in scope for Item 5.2.
- `docs/design.md` sits at 399 of its 400 lines after Item 5.2: the next
  addition needs a further move-out.

- Precommit lints only tracked files (RCA above) — since fixed outside this job
  (the `justfile`'s `tracked()` now lists `--others --exclude-standard`).
- `tests/hook-candidates.bats` is at 374 lines; Item 4.2's hook case goes in
  `tests/hook-writes.bats` if it runs past ~24 lines.
- The outline's OUT list (above).
- Simplifier note: `readonly-path.md`, `hook.md`, `detectors.md` and
  `lib/matchers.sh` are each edited by more than one item (accepted at runbook
  proof).

## Resume

- **Last commit:** "Item 5.5 added to the runbook" (with this file).
- **Exact step:** Item 5.5 slice 1, RED dispatch next.
- **Why stopped:** not stopped; in progress.
- **Decisions given:** see §Decisions given.
- **Next:** Item 5.5 slice 1 RED, test review, GREEN, code review; then the
  finish (`references/finishing.md`: review gate, triage, tdd-audit,
  completion).
- **Carry list:** as above.
