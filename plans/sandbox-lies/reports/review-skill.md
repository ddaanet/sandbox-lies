# Finish review — sandbox-lies skill

Relayed by the main session: the reviewer's hand-back reached the orchestrator,
not `build-finish`. Transcribed from its four parts; content unchanged.

## Summary

Scope read: all five files, design.md, outline.md, the three docs/references
nodes, and every file the recall artifact lists. Sizes: SKILL.md is 147 lines,
about 1,150 words (cap 200). The nodes are escapes-and-costs 75,
excluded-commands 109, masks-and-gates 58 and recipes-and-claude 64 lines (cap
400). Frontmatter is valid. No allowed-tools, which is right for a
knowledge-only skill. None of the files contains internal ids (FR/D/Item),
private paths, wikilinks, `memory/` pointers or second person.

FR-9: every item has a home. That covers excludedCommands semantics, both
escapes and their costs, strict mode, `$TMPDIR`, claude/git inside a recipe,
cleanliness gates, plus the outline's extras (read-only default, classifier,
ps, merge recovery, `!` expansion).

FR-10: every translation-map row routed to "skill" has a home. The retired
memory text was not diffed (no git tool), so fidelity rests on the map and on
Item 7.1's coverage audit.

The latest carry is the main problem. Its fact is right, but nothing routes to
it at the moment it matters, and its act conflicts with two nodes.

Rating: Needs Improvement. 5 major, 13 minor, nothing UNFIXABLE.

## Major

**M1. The masks-follow-cwd carry cannot be reached when it is needed.**
Location: masks-and-gates.md:15-21.

- The only way in is the hub pointer under "Writing a cleanliness gate", whose
  text is "Mask shapes, and the expansion path's mechanism".
- The description has no trigger for cd-ing into a submodule or subdirectory.
- An agent about to `cd` is not writing a gate, so it never reaches the act.
- Fix: add a hub bullet, for example under "Tell a sandboxed call…" or a new
  4-line section "Keep the working directory at the root". It would say: masks
  sit under the sandboxed call's working directory; the Bash tool keeps the cwd
  between calls (CC 2.1.281); use absolute paths or `git -C <dir>`. Add "a
  command that `cd`s into a submodule or subdirectory" to the description, and
  rename the pointer text to "Mask shapes and placement, and the expansion
  path's mechanism".

**M2. The carry's `(cd <dir> && …)` act conflicts with excluded-commands.md.**
Location: masks-and-gates.md:20-21.

- excluded-commands.md:40-42 says nesting fails closed, so where `git:*` is
  honoured, a git inside `( … )` runs sandboxed.
- excluded-commands.md:106-109 records that cwd-safety stopped wrapping
  `cd <dir> && …` in a subshell for exactly that reason, and now appends a
  trailing `cd <root>` line.
- excluded-commands.md:80-89 says `-C`, a `cd` in the same call as git, and
  subshells all forfeit the read-only auto-allow when the call runs
  unsandboxed.
- Fix: order the acts as follows. First, absolute paths or `git -C <dir>` (a
  top-level segment that `git:*` matches). Else, a trailing `cd <root>` line.
  The subshell comes last, with the clause "a git inside it misses an honoured
  exclusion". Add one clause saying each of these forms costs a classifier call
  when unsandboxed, pointing to `excluded-commands.md`.

**M3. The node recommends the very shape the carry forbids.** Location:
escapes-and-costs.md:50-51, "batching `cd <dir> && git status` into one call
still beats splitting it".

- A leading `cd` persists and leaves later sandboxed calls masking inside
  `<dir>`.
- Fix: change the example to `git -C <dir> status`, or to
  `git -C <dir> log …; git -C <dir> status`. The point about the compound's
  classifier cost survives unchanged.

**M4. The description misses the standalone `claude -p` SessionStart moment.**
Location: SKILL.md:3.

- The description names a recipe/script and a `--resume` flow, but not a bare
  `claude -p` run for a hook's side effect.
- That is the exact remedy shared-claude.md prescribes,
  `(cd /path/to/repo && claude -p ping)`, and the 2026-08-11 evidence in
  recipes-and-claude.md:53-58 is that same command failing silently when
  sandboxed.
- Fix: add "a `claude -p` run for a `SessionStart` hook's side effect" to the
  "Use when" list.

**M5. The `ps` claim contradicts its own evidence.** Location:
SKILL.md:137-141, "absent from any process listing the agent can take".

- The same sentence reports that `ps aux` returned 141 lines unsandboxed. An
  unsandboxed listing is taken from the host PID namespace, which normally
  contains processes started in child namespaces.
- As written, the claim rules out the one listing that could show the job. It
  also carries no CC version.
- Fix: verify with one unsandboxed `ps` while a background task runs. If the
  task shows up, restate the claim as "absent from a sandboxed `ps`". If it
  does not, add the version and the date of that check.

## Minor

**m1. SKILL.md:89-91** says a `$TMPDIR` in a handed-over command "is unset at
the other end". This contradicts :28-29, where the receiving call has its own
`$TMPDIR` (`/tmp/claude-<uid>` sandboxed, `/tmp` unsandboxed on CC 2.1.281).
Say instead: "resolves to whatever the receiving call's `$TMPDIR` is".

**m2. SKILL.md:85** says "exported by the sandbox per call". On CC 2.1.281
unsandboxed calls get `/tmp` as well, so say "set per call by the harness".
Separately, "even sandboxed" rests on the 2026-09-14 observation
(escapes-and-costs.md:31-33), which gives neither the call's sandbox state nor
the CC version. Add both, or drop "even sandboxed".

**m3. Behaviour claims without a CC version:**

- strict mode (escapes-and-costs.md:10-14, no date either)
- the 2026-08-16 classifier refusals (:42-46)
- the prompted-retry sentence (:53-55, no date)
- the 2026-07-30 release half-landing
- the SessionStart finding of 2026-08-11 (recipes-and-claude.md:53)
- `--resume` persistence (:9-11)
- the zero-byte mask shape "since 2026-07-20" (masks-and-gates.md:11)
- ps, 2026-08-15

Where the transcript records a `version`, add it. Otherwise add "(CC version
not recorded)".

**m4. escapes-and-costs.md:12.** "the exclusions still apply" (under strict
mode) needs "where honoured". It currently contradicts :5-6 on CC 2.1.281.

**m5. SKILL.md:45-46.** "usually clearing it as read-only before any
classifier call" overstates the rule. Only a read-only command is cleared, and
only in the bare form from the original cwd (excluded-commands.md:80-89). Say:
"clearing a bare read-only command from the original working directory before
any classifier call".

**m6. SKILL.md:34-37.** The section's lead does not say the mechanism is
unhonoured on current CC; only the first section says so. Open with: "Where
honoured (not on CC 2.1.281; re-probe with the `/tmp` write):".

**m7. masks-and-gates.md:5.** The opener "hides deny-listed paths in the
project root" is contradicted two paragraphs later by the carry itself. Say
"in the sandboxed call's working directory, normally the project root".

- Also :19, "A `cd` at the head of a call persists too", is narrower than the
  mechanism the paragraph implies. A top-level `cd` anywhere in the call
  persists, and one inside `( … )` does not.
- Reword to match, but verify first, because this is a claim about CC's cwd
  capture.

**m8. SKILL.md:24-25.** "no mask where one would show" leaves the place
unnamed. Now that masks land at the sandboxed call's cwd, say "no mask in a
listing of the call's own working directory".

**m9. SKILL.md:119-122.** The sibling-worktree parenthetical ("abort cleanly,
with no `MERGE_HEAD`") is undated.

- detectors.md:215-219 records the same layout on 2026-09-27 (CC 2.1.281): git
  died on partial-checkout errors with HEAD unmoved. The hook's verdict turns
  that into a restore clause pointing to this section.
- Restate the parenthetical with that evidence: what was written, HEAD
  unmoved, date and version.
- Drop "no `MERGE_HEAD`", since `--ff-only` never writes one.

**m10. SKILL.md:124-133.**

- Step 1 re-derives by hand what the readonly-path verdict now names (its
  `match=` files). Add "start from the files the hook's verdict names, where it
  names them", which keeps the mechanical work in the harness.
- Step 4 (`git reset --hard <target>`) is destructive. It should carry "with
  the human partner's confirmation", per the hub's own rule at :63.

**m11. recipes-and-claude.md:18-19.** "The git directory is likewise
write-blocked" is overbroad. lock-detectors.md:87-89 records sandboxed commits
succeeding. Scope it to what was observed (the paths refused, where) and date
it, or drop the clause and keep the IPC-location fact.

**m12. The hub-to-node pointers are code spans, not links.** This covers
SKILL.md:49, 65, 81, 93 and 111, and the node-to-node mentions. check-links.sh
blanks code spans before it matches `](…)` (lines 47-50, 68-69), so NFR-5's
"links resolve" pins none of them. Make them inline links, for example
`[references/excluded-commands.md](references/excluded-commands.md)`.

**m13. The description is long and missing triggers.**

- Length is about 590 characters (guideline 500, hard limit 1024).
- It opens with a noun phrase, then "Use when…". That is acceptable house
  style but not the "This skill should be used when" form.
- It lacks triggers for: judging whether a call ran sandboxed, or whether an
  exclusion is honoured; and writing or acting on a `` !`cmd` `` context block.

Suggested description, about 790 characters and still under 1024:

"What the Claude Code command sandbox does to Bash calls that no tool result
reveals: whether a call ran sandboxed, how `excludedCommands` and
`dangerouslyDisableSandbox` escape it and what each costs, why `$TMPDIR` does
not survive a call, and where masks land and why they break a cleanliness gate.
Use when writing a `sandbox.excludedCommands` entry, a recipe or script that
must run unsandboxed, a cleanliness gate over `git status`, a command that
`cd`s into a submodule or subdirectory, a subagent directive or later command
naming a scratch path, a `claude -p` run for a `SessionStart` hook's side
effect, or a multi-turn `claude --resume` flow; when recovering a merge a
sandbox write refusal killed mid-way; and when reading `ps` for a background
task."

**m14. recipes-and-claude.md:37-38.** "reports the pipeline's exit status"
should read "reports `tail`'s exit status (without `pipefail`)".

## Progressive disclosure

- The hub is lean and holds the acts. Every node is opt-in, and all four are
  reachable from the hub.
- The one routing gap is M1: the new carry sits in a node whose pointer
  advertises something else.

## Positive aspects

- Diagnostics are described, never quoted with their follow-on text (FR-11).
- The CC 2.1.281 unhonoured-exclusion fact is carried consistently with
  lock-detectors.md, along with the one-way mask evidence and the `/tmp` write
  test.
- No retired memory file is named as the owner of a mechanism, and
  memory/ddaanet/shared-claude.md's pointer to `references/masks-and-gates.md`
  resolves to the right content.
- The earlier fixes from Item 7.1 (merge scope, the `just evals` attribution,
  the IPC sentence) all hold.

## Priority

1. M1, M2 and M3, which together make the carry reachable and consistent.
2. M4, the description trigger.
3. M5: verify the `ps` claim, then restate it.

END OF REPORT
