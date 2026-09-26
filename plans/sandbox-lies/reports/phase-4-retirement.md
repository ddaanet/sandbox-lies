# Phase 4 retirement: memory sections and design status flips (Items 4.1, 4.2)

These are the memory retirement and status flips that Items 4.1 and 4.2 deferred, done as one change. Nothing is committed. The memory edits have to pass the gitlore approval gate, so they wait for my human partner's approval. The draft summary for that gate is at the end of this report.

## Edits by file

### memory/ddaanet/sandbox-effects.md (449 → 368 lines)

- **Frontmatter `description`:** removed `index.lock/"Another git process" (only a real lock survives unsandboxed)`, `$TMPDIR unset unsandboxed and`, and `` `apply-seccomp: unshare(CLONE_NEWUSER)` = sandbox init failed ``. Replaced `--resume "No conversation found…"` with ``a multi-turn `--resume` eval harness must run unsandboxed``, which names the part that stays, the same way Item 2.3's tidy commit reworded the phantom clause.
- **Symptom table:**
  - Deleted the `Unable to create '.git/index.lock'…` row and the `apply-seccomp…` row.
  - The `$TMPDIR` row now reads ``$TMPDIR` expands empty in a sandboxed call; a benign compound denied``. It was `… /foo.log: Permission denied …`, which is the retired unsandboxed collapse.
  - The `No conversation found with session ID` row became `every two-turn eval scenario fails 0/5 under just prerelease` → `Multi-turn claude flows`.
- **Item 4.1:** deleted the whole `## .git/index.lock: one error string, three causes` section, including the `.git/config.lock` paragraph (inside cause 4) and the "Do not fix the hook" paragraph. Its only `[[...]]` link, `[[git-hook-env-leak]]`, went with it. No other `[[...]]` link in the file pointed into that section, so no link needed fixing. `git-hook-env-leak.md` is untouched.
- **Item 4.2 `tmpdir-unset`:** deleted the `**Cost 1 — $TMPDIR is unset when unsandboxed.**` paragraph. The `**$TMPDIR is not stable across calls even while sandboxed**` paragraph stays where it was. The labels `Cost 2` and `Cost 3` are **not renumbered**, because detectors.md and runbook Item 6.1 cite "cost 3".
  - **One sentence moved (a judgement call):** cost 1 also said that the classifier judges an unsandboxed recipe by its top-level command (`just release minor` went through, cross-repo `git -C "$MARKETPLACE_DIR" push` included). The `tmpdir-unset` detector does not carry that fact. Rather than drop it, I moved it to the end of **Cost 3** as one sentence. Cost 3's recipe guidance already goes to the skill. Reverting means deleting that sentence and restoring the detectors.md row below.
- **Item 4.2 `resume-lost`:** replaced the `## --resume dies because the transcript never persisted` heading and its mechanism paragraph with `## Multi-turn claude flows must run unsandboxed` and a two-line lead: a sandboxed turn never persists its transcript, so resuming by id fails, and the Agent SDK's `query()` resumes the same way. The two eval-harness paragraphs stay verbatim: "Consequence for eval/harness design" and "So `just prerelease` and `just release` must run unsandboxed". The remnant is therefore a lead plus two paragraphs, not one line. The second paragraph is the same consequence applied to the release gate, and it carries diagnostic tells that no detector covers.
- **Item 4.2 `seccomp-init`:** deleted the whole `## Sandbox setup itself fails: …` section, which was the last one in the file.
- **Kept, as instructed:** the zellij section.
- The file does not fire `detect` (exit 1). Every write drew the memory hook's "over the 4KB recall limit … Rewrite it to under 2.8KB" error. I ignored it: this file is being retired section by section and Item 8.2 deletes it. Splitting it was not asked.

### memory/MEMORY.md and memory/ddaanet/MEMORY.md

The `sandbox-effects` index line in each got the same four substitutions as the description. The two lines are identical apart from the link path.

### docs/references/detectors.md

The translation map row `cost 1, $TMPDIR unset and unstable` now ends `…; instability → skill; its top-level-classifier note moved to cost 3`. The other rows state truthfully where each retired paragraph went, so they are unchanged: `.git/index.lock` → `git-lock` plus the leak clause, the config.lock paragraph → `config-lock`, `--resume` → `resume-lost` with the eval-harness part → skill, and sandbox setup → `seccomp-init`.

### tests/matchers.bats

Deleted one case (below).

### docs/design.md (400 → 395 lines; split, see below)

Status flips, the new hub opening, the Architecture pointer, and the restored map line.

### docs/references/hook.md (new, 31 lines, **untracked**)

The split node. Stage it by name.

### lib/probes.sh

One comment cited design.md's "Why the hook can see" paragraph, which has moved. It now points at `docs/references/hook.md`, re-wrapped. Comment only.

### docs/changelog.md

New entry `2026-09-26 — lock and candidate memory retired; hook runtime split out`. It records the retirement, the moved sentence, the section that stays for zellij, and the split.

## Test cases

- **Deleted:** `the live memory file's quotation never carries the full follow-on clause` in tests/matchers.bats. With the section and the description symptom gone, `grep -c 'Another git process'` on the file returns 0, so the case's `grep -q 'Another git process'` would have gone red.
- **Kept:** `the live memory file still fires nothing` (it stays until Item 8.2).
- **Other cases the deletions turn red:** none. A grep of tests/ shows matchers.bats (lines 276 and 289) is the only reader of the live memory file. The full suite passed: 181 passed, 0 failed. `tests/extract-fixtures.py` names the memory file only in corpus cut selectors, which read transcripts, not the live file.

## Status lines, before → after (docs/design.md)

- **Header:** `Partial. Built and tested: the hook, the phantom-* verdicts, the lock probes (not live-proved or hook-called). Nothing dogfooded; no candidates.` → `Partial. Built and tested: the hook, the phantom-* and lock verdicts, the hook's lock-probe call, the tmpdir-unset, resume-lost and seccomp-init verdicts, and the readonly-path matcher and probe (no verdict yet). Nothing dogfooded.` The `Verified against:` line was not touched. rumdl re-filled it into the same paragraph.
- **FR-3:** `Partial (probe call: Item 4.1).` → pinned-by gains `tests/hook-locks.bats over the probe call`; status `Done.`
- **FR-4:** `Partial (lock probes proved live; hook call: Item 4.1; readonly-path: Item 4.3).` → pinned-by gains `tests/hook-locks.bats over the hook's call`; status `Partial (lock probes proved live and hook-called; readonly-path probe built, live proof: Item 5.1, verdict: Item 6.1).`
- **FR-5:** pinned-by `tests/hook.bats pairs…` → `tests/hook.bats, tests/hook-locks.bats and tests/hook-candidates.bats pair…`; status `Partial (lock, candidate, readonly-path policies: Items 4.1, 4.2, 6.1).` → `Partial (readonly-path policy: Item 6.1).`
- **FR-6:** `Partial (lock, candidate, readonly-path verdicts: Items 4.1, 4.2, 6.1).` → `Partial (readonly-path verdicts: Item 6.1).`
- **FR-7:** `Planned.` → `Partial (four candidates shipped, readonly-path without its verdict until Item 6.1; zellij-socket stays a candidate).` The body ("five measured and shipped from the pilot, five candidates") is unchanged.
- **FR-10:** `Partial (phantom and /tmp retired; rest: Items 4.1, 4.2, 6.1, 7.1, 8.2).` → `Partial (phantom, /tmp, lock, $TMPDIR-unset, --resume and sandbox-setup sections retired; rest: Items 6.1, 7.1, 8.2).`
- **NFR-1:** `Partial (harness promoted).` → `Done (harness promoted; each shipped candidate re-measured with its shipped matcher as arbiter, not gated).`
  - The runbook's requirement map assigns NFR-1 to Items 1.1, 3.2, 4.2 and 4.3, and all four are done. The green reports record the re-measurements: readonly-path 162, tmpdir-unset 13, resume-lost 2, seccomp-init 8, none moved.
  - This follows NFR-3's `Done (… measured, not gated)` precedent. Nothing re-checks precision on every commit, so under the strict legend `Partial` is the alternative.

## Split

The flips took design.md to 408 lines after rumdl. The size distribution is flat: the largest entry is Rejected alternatives at 7.1%, and nothing dominates. So I cut by need-time, per the splitting rules, and moved one cluster verbatim:

- The Architecture section's **Flow**, **Why the hook can see what the tool could not** and **Paths** paragraphs moved to `docs/references/hook.md`. That is what a reader needs when changing `annotate.sh` or a probe's path handling.
- The hub keeps the component map and a paragraph of conclusions: the hook runs outside the sandbox, so a probe's stat is the unsandboxed step (with the reopen-if); a character device is a mask; and a pointer to the node.
- The hub opening now says it is a hub with one `references/` node per mechanism, and says to read the node before making a claim or changing its mechanism.
- Restored map line: `scripts/check-*.sh      line-limit and link gates, NFR-5`.
- **Inbound links:** no `design.md#` anchor exists anywhere. The one inbound reference to a moved paragraph was a comment in `lib/probes.sh`, now fixed. The link gate passed.
- **Not done:** a CLAUDE.md routing table. The splitting rules recommend one, but the repo's CLAUDE.md is only the shared import, and the earlier detectors.md split added none either. Out of scope here.

## Precommit (final line)

```
precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests
```

(bats: 181 passed, 0 failed.)

## Other findings, for the caller

- `memory/ddaanet/git-add-untracked-deletion.md` still cites `[[sandbox-effects]]` for "a stranded `index.lock`", and that content has just left the file. The link still resolves. Item 8.2 already rewrites this link, so I did not edit it.
- `docs/references/hook.md` is untracked. Line-limit and link checks cover tracked files only. rumdl formatted the node and `detect` is silent on it; its two relative links were checked by hand.

## Draft memory summary (for the gitlore gate)

Retire the lock, `$TMPDIR`-unset, `--resume` and sandbox-setup sections of ddaanet/sandbox-effects, now carried by sandbox-lies. The `.git/index.lock` section and its `.git/config.lock` paragraph are gone: the plugin's `git-lock` and `config-lock` verdicts probe the lock outside the sandbox and report whether it is a mask, cleared, held, orphaned or unknown, which replaces the hand-run discriminator. Cost 1 of "Leaving the sandbox" (an unsandboxed `$TMPDIR` collapsing to `/`) is now the `tmpdir-unset` verdict. The `--resume` mechanism (a sandboxed turn's transcript never persists) is the `resume-lost` verdict. The sandbox-setup section (`apply-seccomp` failing at namespace init) is the `seccomp-init` verdict. What the skill will later carry stays: the `$TMPDIR` instability paragraph, and the eval-harness consequence under a new heading, "Multi-turn `claude` flows must run unsandboxed". Cost 1's note that the classifier judges an unsandboxed recipe by its top-level command moves into cost 3 rather than being lost. The zellij section stays, because its detector did not ship. The description, the symptom table and both index lines drop the retired symptoms.

## Status output

```
$ git status --porcelain --untracked-files=no && git -C memory status --porcelain
 M docs/changelog.md
 M docs/design.md
 M docs/references/detectors.md
 M lib/probes.sh
 M memory
 M tests/matchers.bats
 M MEMORY.md
 M ddaanet
```

(`git -C memory/ddaanet status --porcelain`: ` M MEMORY.md`, ` M sandbox-effects.md`.)
