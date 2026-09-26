# Review: Item 7.1 — `skills/sandbox-lies/` (uncommitted draft)

**Scope**: `skills/sandbox-lies/SKILL.md` and the four files under
`skills/sandbox-lies/references/`, reviewed against
`memory/ddaanet/sandbox-effects.md` (source, read-only), the translation map in
`docs/references/detectors.md`, and the extraction checklist.
**Date**: 2026-09-26
**Mode**: review + fix. Every finding below is applied; nothing committed.

## Verdict

**Ready.** After the fixes: every skill-mapped paragraph of the source has a
home; dates match the source token-for-token; no requirement/decision ids, no
`/Users/` or `~/code/` paths, no wikilinks, no second person; no matcher fires
on any of the five files; `rumdl fmt` re-wrapped five paragraphs; `just
precommit` exit 0 (`plugin.json, hooks.json, shellcheck, bash -n, rumdl, line
limits, links, tests` — 196 bats passed). Hub 145 lines, references 50–109.

## Findings

### Major

1. **Merge recovery widened to a case the source contradicts** —
   `SKILL.md` "Recovering a merge". The draft said the partial-update recovery
   applies when the merge dies on "a sibling worktree, or a harness-mounted
   file". The retired `Sibling worktree writes` section (memory history,
   commit `17ef338`) says a sibling-worktree merge "half-prints 'Updating …'
   then aborts cleanly (no `MERGE_HEAD`)"; the partial update is specific to
   the harness-mounted `hooks/hooks.json` case, where "every other file in the
   same merge updates normally" and `git checkout <branch>` fails the same
   way. **FIXED**: scoped the section to the harness-mounted file, added
   `git checkout <branch>`, and one clause saying a refusal elsewhere aborts
   before anything is written.
2. **`just evals` attributed to the plugin-dev toolkit** —
   `references/recipes-and-claude.md`. The draft said "In the `plugin-dev`
   toolkit, `just release` depends on `just prerelease`, which runs
   `just evals`". `plugin-dev/release.just` has `release … : prerelease`; the
   `prerelease` recipe is the consuming repository's (this repo's is
   `prerelease: precommit`), and the `just evals` step is gitlore's. **FIXED**:
   "The `plugin-dev` toolkit's `just release` depends on the repository's own
   `just prerelease`; gitlore's runs `just evals` …".
3. **Hub/reference duplication beyond a rule and its pointer** — three
   sections were carried in full in both places: mask visibility (hub "Tell a
   sandboxed call…" vs `masks-and-gates.md` "Mask visibility"), the porcelain
   gate remedies, and the whole `$TMPDIR` section (hub vs
   `escapes-and-costs.md`). **FIXED**: cut "Mask visibility" from the
   reference (the hub carries it entirely); reduced the reference's porcelain
   section to the edify instance plus the parallel-sandbox caveat; reduced the
   reference's `$TMPDIR` section to the 2026-09-14 evidence and the
   mutation-check consequence, with a pointer from the hub.

### Minor

4. **"A common setup"** — `references/excluded-commands.md` baseline. A claim
   about consumers' settings with no basis; the source says it is the
   author's baseline. **FIXED**: "The setup these observations were made
   under".
5. **"Strict mode … is often off"** — `references/escapes-and-costs.md`.
   Source: "usually off in ddaanet repos"; the generalization asserts something
   the skill cannot know. **FIXED**: "Strict mode is a user setting: check
   rather than assume."
6. **"low-risk" added to the read-only-inspection bullet** — `SKILL.md`. Not
   in the source; it is justification, which the directive rules cut.
   **FIXED**: bullet now states the conditional default and the act.
7. **IPC-file inlining changed the claim** — `references/recipes-and-claude.md`.
   The `[[classifier-denied-self-config]]` inlining became "an IPC file a hook
   must read belongs in the parent worktree", which is not what the source
   says. **FIXED**: "gitlore's memory-message IPC file lives in the parent
   worktree rather than under `.git/`" (the source sentence, wikilink dropped).
8. **Ungrammatical closing sentence, cross-plugin pointer lost** —
   `references/recipes-and-claude.md`. "`SessionStart` fires under `--print` at
   all — that finding was made unsandboxed" lost its subject when the skill
   reference was cut. **FIXED**: "That `SessionStart` fires under `--print` at
   all was established unsandboxed (the `plugin-craft` plugin's
   `hook-authoring` skill)" — a plugin skill name is reachable by consumers, as
   the same form already used in `excluded-commands.md`.
9. **Two `ps` facts dropped** — `SKILL.md`. The two-`bash`-entries observation
   during a live background suite, and "the second times out" in the
   foreground-restart warning. **FIXED**: both restored.
10. **Gate caveat reference-only** — "with no sandboxed command running
    alongside it" qualifies the unsandboxed-status remedy and belongs at the
    authoring moment. **FIXED**: added to the hub's gate bullet.
11. **No trigger for the `ps` section** — the description named every other
    section's moment but not this one, so the section could never be found.
    **FIXED**: description ends "and when reading `ps` for a background task".
12. **Merge step 1 gave no command** — `SKILL.md`. **FIXED**: added
    `git diff <target> -- <file>`.

### Judged acceptable, not changed

- Source facts dropped as rationale or unreachable pointers: "which is why the
  baseline carries it"; "the strictest silent failure in this file, and the
  reason `claude:*` is in the baseline exclusions";
  `[[cc-bash-background-no-duration-cap]]` and
  `plugin-craft:verifying-plugin-changes` pointers; the `05-recall` scenario
  name and its "injected body vs self-issued Read" purpose; the
  `bump_marketplace` recipe name; the bats-summary-line example generalized to
  "an output line that reads as terminal".
- Generalizations kept: `verify-step.sh` → "edify's build step verifier";
  `tests/evals/run-evals.sh` → "gitlore's eval runner";
  `commit-commands/commands/commit.md` → "the `commit-commands` plugin's
  `/commit`"; `git -C memory/ddaanet ls-files X` → `git -C <dir> ls-files
  <path>`; "my human partner" → "the human partner" (house phrasing ships
  per the extraction checklist; either form is fine). Each keeps the project
  as evidence and drops the file the reader cannot open.
- Hub line 29 "(unset on CC 2.1.233)": source says "`UNSET` unsandboxed then",
  "then" being the CC 2.1.233 decompile-and-probe; faithful.
- `$MARKETPLACE_DIR/.claude-plugin/marketplace.json` stays: a variable-rooted
  path illustrating what the refused `mv` targets, not a file to open.
- Hub bullet 1 "Treat every call as sandboxed" generalizes the source's "every
  git call": with exclusions unhonoured, nothing but the flag unsandboxes a
  call, so the wider form is the true one.

## Coverage audit (source section → home)

| memory section | home | note |
|---|---|---|
| baseline exclusions and reach | `excluded-commands.md` "The baseline" | wording fixed (4) |
| exclusion sets flag; masks visible from every process; `touch /tmp` test | hub "Tell a sandboxed call…" | reference dup removed (3) |
| not honoured on CC 2.1.281 | hub bullet 1; `excluded-commands.md` intro | |
| phantom: zero-byte shape since 2026-07-20 | `masks-and-gates.md` "The mask shapes" | |
| phantom: porcelain gate | hub "Writing a cleanliness gate"; reference evidence | |
| phantom: `## Context` is a Bash call, no hook, 2026-08-16 / 2026-09-02 / 2026-05-24 | hub bullet; `masks-and-gates.md` | all figures present |
| interrupted merge | hub "Recovering a merge" | scope fixed (1) |
| escapes; strict mode; read-only default | hub "Leaving the sandbox"; `escapes-and-costs.md` | (5), (6) |
| `$TMPDIR` instability, 2026-09-14 | hub "A scratch path"; reference evidence | dup removed (3) |
| cost 2 classifier, 2026-08-16 | `escapes-and-costs.md` | verbatim figures |
| cost 3 recipes, 2026-07-30, gitlore 0.4.4, plugin-dev 0.5.0 | `escapes-and-costs.md` | |
| `excludedCommands` bullets (2.8%, 45-day, 31.6%, 2026-08-28, validator refusals, live reload) | `excluded-commands.md` | all present |
| why `git:*` rather than a hook | `excluded-commands.md` | |
| `ps`, 2026-08-15 | hub "Background tasks" | two facts restored (9) |
| multi-turn `claude`, eval signatures | `recipes-and-claude.md` | (2), (7); strings described, not quoted |
| zellij | **absent** — stayed a candidate, memory-only | verified by grep |
| `claude -p` drops `SessionStart`, 2026-08-11 | `recipes-and-claude.md` | (8) |

## Merge-recovery procedure: correctness

Checked against git's behaviour. A fast-forward updates index and worktree
through unpack-trees; a refused file write is recorded and the update returns
an error without writing the index or moving HEAD, so the files already
written sit at the target while `git status` shows them modified against an
unchanged index. `git checkout HEAD -- <files>` restores index and worktree
from HEAD; removing the untracked files the target added is right because they
do not exist at HEAD. `git reset --hard <target>` moves HEAD to the target and
resets index and worktree to it, which on a fast-forward is exactly the merge
result; it overwrites untracked files present in the target tree, so the
leftovers from step 2 do not block it. The caution — it discards every
uncommitted change, so confirm `git status` lists only files the merge wrote —
is correct and is the one thing the source omitted.

## Skill shape

- Description opens with what the skill is, then "Use when …" naming the four
  authoring moments the item requires, the resume flow, the merge recovery and
  now the `ps` read. Third person throughout.
- Body is imperative where it instructs; no second-person hits.
- Hub 145 lines (cap 200), each reference under 110; four pointers from hub
  to references, none the other way.
- Error strings described everywhere (`detect` is silent on all five files).

## Doc inconsistencies (reported, not edited — docs/ is out of scope)

- `docs/design.md` FR-9 is `Planned` and FR-10 says "rest: Items 7.1, 8.2";
  both flip when this item commits. The `## Now` block's **Next** ("corpus
  replay for the five candidate detectors") predates Phase 6.
- The memory-side half of Item 7.1 (delete every skill-mapped section from
  `sandbox-effects.md` in the same commit) is not done in this draft and was
  outside my write scope. What should go: everything except the zellij section
  and its symptom-table row; the frontmatter `description` then needs
  rewriting to the zellij fact alone.

## Fixes applied

- `skills/sandbox-lies/SKILL.md` — description gains the `ps` trigger;
  read-only-inspection bullet loses "low-risk"; gate bullet gains the
  parallel-sandbox caveat; `$TMPDIR` section gains a pointer; merge section
  rescoped to the harness-mounted case with `git checkout <branch>` and a
  `git diff` command; `ps` section restores two source facts.
- `skills/sandbox-lies/references/masks-and-gates.md` — "Mask visibility"
  removed; porcelain section reduced to evidence plus caveat.
- `skills/sandbox-lies/references/escapes-and-costs.md` — "often off"
  removed; `$TMPDIR` section reduced to evidence.
- `skills/sandbox-lies/references/excluded-commands.md` — "A common setup"
  reworded.
- `skills/sandbox-lies/references/recipes-and-claude.md` — IPC sentence
  restored to the source claim; `just evals` attribution corrected; closing
  sentence repaired with the cross-plugin pointer.
- `rumdl fmt` re-wrapped five paragraphs across `SKILL.md`,
  `excluded-commands.md`, `recipes-and-claude.md`.

## UNFIXABLE

None.
