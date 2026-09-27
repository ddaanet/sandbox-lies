# Build — Phase 8 (partial: stopped at the context hard stop)

## What was built

(A) The verdict conditional rework, added to the runbook as **Item 8.0**, three
TDD slices, each through RED → test review → GREEN → code review:

- Spec first: `docs/references/detectors.md` (readonly-path probe facts table;
  tail acts and merge clause by fact), `docs/references/lock-detectors.md`
  (*Re-run*/*Retry* flag table, config-lock settings act), `docs/references/hook.md`
  (Flow), `docs/design.md` FR-4, FR-6 and a new **D-17 — The script decides
  conditions** (the standing rule), `docs/changelog.md` entry.
- 8.0/1 — lock verdicts take the flag as `$2`: `mask` re-runs with
  `dangerouslyDisableSandbox: true` (flag false) or once no sandboxed command is
  running (flag true); config-lock `mask` gives the update-config act only when
  `path=` is a `.claude/settings.json.lock`.
- 8.0/2 — the hook passes `tool_input.command` as each probe's third argument;
  `verdict_readonly_path` composes the tail from the probe's facts (readfile →
  settings → re-run with `dangerouslyDisableSandbox: true`; the merge clause
  names matching files and the target, or says "restore them from HEAD" with no
  target, or is left out when a target matches nothing).
- 8.0/3 — `probe_readonly_path` prints `merge=1`, `target=`, `match=`,
  `readfile=` (new `lib/probes-readonly-facts.sh`, `lib/probes-readonly-command.sh`).

(B) Item 8.1, (C) Item 8.2 partial, (D) skill carry: **not started**.

## Deviations

- The rework became runbook Item 8.0, placed ahead of 8.1, with three slices.
  The item text is committed in `runbook.md`.
- Beyond the five listed conditions: `orphan` and `unknown` word their retry by
  the flag too. "Retry the command unsandboxed" was false under flag true, and
  the flag is script-decidable.
- The update-config act replaces the re-run rather than sitting beside it (a
  pair of alternative acts is itself a condition). `readfile=` wins over the
  settings act.
- A merge with a named target where no modified file matches gets no merge
  clause, because nothing sits at the target to restore.
- D-17 took `docs/design.md` past 400 lines. The arguments for D-6 and D-13
  moved verbatim into `references/hook.md`, and D-14's into
  `references/lock-detectors.md`. Each left its conclusion in the hub, and the
  changelog records the move.
- `tests/verdicts.bats` went over the cap at 8.0/1 GREEN, so it was split:
  `tests/verdicts-locks.bats` and `tests/helpers/verdicts.bash`.
- A `rumdl fmt` run on `runbook.md` reflowed the whole file. It was undone by a
  follow-up commit that restored the prior content plus the list revision.
- The 8.0/3 code review found four defects that GREEN's tests missed, and fixed
  them:
  - `git diff` rewrote `.git/index` even with optional locks off.
  - Cost grew with the square of the command length, plus two forks per file.
  - Some repo states wrote to stderr.
  - `git pull` aborted under bash 3.2 `set -u`.

  **These fixes are not pinned by tests.** That is the first carry item.

## Resume

- Last commit: `🐛 Item 8.0/3 — code-review fixes: bounded, non-writing,
  stderr-free probe facts`. Tree clean; verify-step CLEAN.
- Where it stopped: Item 8.0/3's after-the-slice steps are done up to the code
  review commit. Its list revision is not recorded yet. It should say: slice 4
  added (below).
- Carry, in order:
  1. **Item 8.0/4 — regression pins for the 8.0/3 review fixes**, as a slice
     proven by mutation (the behaviour exists), in
     `tests/probes-readonly-facts.bats` or a sibling file if that one nears the
     cap. Pin these (see `reports/item-8-0-s3-code-review.md`):
     - `.git/index` is not rewritten, with a stale-stat fixture that makes a
       porcelain refresh write, so the mtime check can fail.
     - No stderr and exit 0 for a tag on a tree or blob, a broken gitlink and
       an unborn HEAD.
     - A bare `git pull` under `set -u`.
     - Past 1000 modified files, no `target=`.
     - The 16384-character and `<<` scan cuts.

     Then test review, and a code review that reviews nothing new.
  2. **Phase 8 corrector checkpoint for Item 8.0**, or fold it into the phase
     boundary corrector.
  3. (B) Item 8.1 dogfood on the final wording. Beyond the runbook's checks:
     does `tmpdir-unset` ever fire on current CC; how often `readonly-path`
     yields `nopath`; report the numbers.
  4. (D) Skill carry into `skills/sandbox-lies/references/masks-and-gates.md`
     (CC 2.1.281): masks appear under the sandboxed call's working directory,
     so a persisted Bash cwd inside the `memory/` submodule put `.claude/` and
     `.mcp.json` masks there, and a sandboxed commit then failed on them. Use
     absolute paths and never leave cwd in a subdirectory.
  5. (C) Item 8.2 partial, memory edits LAST:
     - Repoint the `memory/ddaanet/shared-claude.md` phantom-dotfile bullet to
       the skill's `references/masks-and-gates.md` and add its `!`-expansion
       clause.
     - Refresh `docs/design.md` `## Now`, its Status and Verified-against line.
       The Status still says "Nothing dogfooded".
     - Rewrite the six inbound `[[sandbox-effects]]` links. The
       `detectors.md` "Phase 6 step" reference is already fixed to Item 8.2.
     - Do NOT delete `memory/ddaanet/sandbox-effects.md` (the zellij section
       stays).
     - Do NOT run `/gitlore:push`: the push is held until the plugin is
       published and installable.
     - The gitlore memory gate goes back to the main session as `## Open gate`.
  6. Phase 8 boundary corrector, then this report's Finish resume block.
     Finish itself (tdd-audit, review gate) is dispatched by the main session.
- Decisions given (team-lead brief): the script decides conditions (D-17). The
  git-lock repeat-failure clause and seccomp-init's split clause stay. Splitting
  docs past 400 lines is authorized. The push is held. Other repos stay
  read-only (a plugin-craft brief already exists; do not touch it).
- Environment notes: `git:*` in excludedCommands is not honoured on CC 2.1.281.
  Run verify-step and `just precommit` with the sandbox disabled, in the
  foreground, with a 600000 ms timeout; a 120 s default pushed precommit into
  the background once. Named subagents cannot be spawned from this teammate
  (the roster is flat), so dispatches are unnamed. Every dispatch returned
  without a SubagentHandback report, so read the artifact at the assigned path.
- Build baseline: `.git/build-baseline` (the whole build's). The Item 8.0 range
  starts after `7c4f811`.

## Context usage

About 195k tokens of this delegate's own context at the stop, most of it skill
bodies loaded at pre-work and eleven dispatch round-trips.
