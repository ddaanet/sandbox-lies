# Review: Item 3.1 — second pass on the lock-mask paragraphs

**Scope**: uncommitted edit to `docs/references/detectors.md` — the `git-lock`
entry's rewritten `Live reproduction owed: mask` paragraph and the sentence
appended to the `config-lock` entry's `Live reproduction (2026-09-25): mask`.
**Date**: 2026-09-25
**Mode**: review + fix

Recall: `plans/sandbox-lies/recall-artifact.md` resolved;
`memory/ddaanet/sandbox-effects.md` read for the index.lock discriminator and
the `excludedCommands` mechanism the new paragraph makes claims about
(`git:*` in `~/.claude/settings.json` confirmed present). The other artifact
entries do not bear on two prose paragraphs.

## Summary

Both paragraphs carry the 2026-09-25 facts without quoting a git diagnostic,
but the git-lock paragraph overstated what its evidence covered in two places
and lost the `git:*` observation a retry needs, and the config-lock entry did
not record the two unnested write shapes that also drew the error. Three fixes
applied in place; the gate passes and the file stays at 348 lines.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

1. **"sandboxed in every shape tried … since each hit the config-lock mask"
   is false for the git-lock shape**
   - Location: `docs/references/detectors.md:108-110` (git-lock owed
     paragraph, last sentence)
   - Problem: "every shape tried" reads as every git call of the session, and
     the `sh -c 'git add f && git commit'` shape ran in the scratch repo where
     no `config.lock` mask exists, so it hit no mask. Only the config-lock
     write shapes did. The sentence also hung off "Its", whose nearest
     antecedent was "That session's sandbox".
   - Fix: restated as "Git did run sandboxed there: every shape of the
     config-lock write below, a bare `git -C <root> config` included, hit a
     mask that exists only inside the sandbox." — the claim is now scoped to
     the write that carries the evidence, and it states what the git-lock
     escalation needs from it (the clean commit was not the exclusion lifting
     the sandbox).
   - **Status**: FIXED

2. **Unnested config-lock shapes and the `git:*` observation recorded nowhere**
   - Location: `docs/references/detectors.md:140-141` (config-lock
     reproduction paragraph)
   - Problem: the ground truth has a visible `cd <root> && git config …` and a
     bare `git -C <root> config …` both drawing the error while `git:*` sits in
     the user settings' `sandbox.excludedCommands`. The appended sentence
     recorded only the `sh <script>` shape, and the git-lock paragraph alluded
     to the bare shape without saying why it is notable. The previous version
     of the owed paragraph carried the exclusion rationale and the prior review
     restored it on purpose; the rewrite dropped it.
   - Fix: config-lock paragraph now records both shapes and the exclusion:
     "a visible `cd <root> && git config` and a bare `git -C <root> config`
     gave the same error too, despite `git:*` in the user settings'
     `sandbox.excludedCommands`." Probe output is claimed only for the script
     shape, which is the only one the probe was run on.
   - **Status**: FIXED

### Minor Issues

1. **"That session's sandbox masked no index lock" generalises past the two
   places checked**
   - Location: `docs/references/detectors.md:107-108`
   - Note: the run checked the scratch repo and the project root. Rewritten as
     "With no index lock masked, the error could not arise", which follows the
     sentence naming the two places and inherits their scope. `ls` made
     specific as `ls -la` on both lock paths, matching the script.
   - **Status**: FIXED

## Fixes Applied

- `docs/references/detectors.md:102-110` — git-lock owed paragraph: `ls -la`
  on both lock paths; scoped "no index lock masked" sentence; final sentence
  restated as a claim about the config-lock write shapes, no dangling "Its".
- `docs/references/detectors.md:140-143` — config-lock reproduction: the two
  unnested write shapes and the `git:*` exclusion recorded.

Gate after edits: `just format-docs && just precommit` —
`precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line
limits, links, tests` (bats 131 passed). rumdl reflowed both paragraphs. `git
status` shows only `docs/references/detectors.md` modified; the `??` dotfiles
are sandbox masks.

## Requirements Validation

| Requirement | Status | Evidence |
|-------------|--------|----------|
| FR-4 / Item 3.1 — a sandboxed command that does not produce its error is recorded beside the outcomes proved and escalated | Satisfied | `detectors.md:102-110`: date, command shapes, the locks observed in each place, and the evidence that git ran sandboxed; git-lock `mask` stays owed by design |
| Self-quiet — git's diagnostics described, never quoted | Satisfied | "the error", "the config-lock error naming `.git/config` relative" — no diagnostic text |
| rumdl 80-column reflow; file under 400 lines | Satisfied | `rumdl fmt` clean after reflow; 348 lines |

**Gaps:** none within scope. git-lock `mask` unreproduced is the recorded
escalation (scope OUT).

## Positive Observations

- The `sh <script>` control, with no `git` on the command line, is the right
  shape to rule out the exclusion, and the paragraph says so in five words.
- Recording the character-device `config.lock` beside the absent `index.lock`
  keeps the discriminating observation with the escalation rather than a bare
  "did not reproduce".

## Recommendations

None beyond the recorded escalation.
