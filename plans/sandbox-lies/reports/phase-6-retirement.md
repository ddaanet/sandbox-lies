# Phase 6 retirement: memory sections and design status flips (Item 6.1)

This is the memory retirement and set of status flips that Item 6.1 deferred from its final slice commit, done as one change the way Phase 4 did it. Nothing is committed and nothing is staged. The memory edits wait for the gitlore approval gate, which the orchestrator runs. This report does not draft the gate summary.

## Edits by file

### memory/ddaanet/sandbox-effects.md (388 → 344 lines)

- **Frontmatter `description`:** replaced `sibling worktree \"Read-only file system\", \"Device or resource busy\" on .claude/settings.json & .git/config, own hooks.json unlink EROFS,` with `a merge killed mid-way by a sandbox write refusal leaves files updated with HEAD unmoved (recover before retrying),`. The new phrase names the part that stays, the same way Phase 4 reworded the `--resume` clause.
  - I checked each removed symptom against the `readonly-path` matcher. I built one line per symptom in the shape the tool prints: git's unlink error on `hooks/hooks.json` (read-only) and on `.claude/settings.json` (busy), git's config-write warning on `.git/config` (busy), a sibling worktree's index.lock (read-only), and `cp` into another repo (read-only). `detect` printed `readonly-path` for all five. These are constructed lines, not recorded ones. The corpus paragraph in detectors.md lists sibling repositories and harness-mounted config among the true hits.
  - Nothing else in the description was covered by this detector, so nothing else was removed. The description has no cost 3 clause, so none was removed.
- **Symptom table:** deleted the `Device or resource busy` / `Read-only file system` row (Harness-mounted config paths) and the `git -C <other-worktree>` row (Sibling worktree writes). Added one row pointing at the kept remainder: `after a merge died mid-way, git status lists files already at the target while HEAD has not moved` → `Interrupted merge`.
- **`## Harness-mounted config paths are busy/read-only`:** deleted, apart from what the new section below keeps. Gone:
  - the list of mounted paths and the four failing-operation bullets, `git checkout`/`reset --hard`, `git branch -d`, the `mktemp`+`mv` settings-merge and the plugin's own `hooks/hooks.json`. `readonly-path` fires on all of them.
  - the "run those operations unsandboxed" instruction. The verdict now says to re-run the whole call with the flag.
  - the `update-config` paragraph. The verdict carries "For `.claude/settings.json`, use the `update-config` skill". The paragraph's open question about `enabledPlugins` and its `[[classifier-denied-self-config]]` link went with it. That link target is still linked from `## Multi-turn claude flows`, and no other `[[...]]` link was in the deleted text.
- **`## Sibling worktree writes`:** deleted whole. `readonly-path` covers the write refusal. Its writable verdict covers the retry ("re-run the whole call with `dangerouslyDisableSandbox: true`") and the partial-merge check ("compare modified files against the target").
- **New `## Interrupted merge: recover before retrying`**, placed where the harness-mounted section was. It holds the merge-recovery procedure (see the judgement calls).
- **Cost 3 of `## Leaving the sandbox`:** trimmed in place. Only the quoted diagnostic left. The sentence now ends "then dies on the marketplace step, whose `mv` of a `mktemp` file onto `$MARKETPLACE_DIR/.claude-plugin/marketplace.json` the sandbox refuses." The quoted `inter-device move failed … Read-only file system` text is gone. Everything else stays word for word:
  - `.envrc` variables pass through the sandbox without making their paths writable
  - the steps before the failure cannot be undone
  - `just resume-release` recovers only when run unsandboxed
  - `git:*` does not reach a git call inside a recipe
  - Phase 4's top-level-classifier sentence, still the last sentence of cost 3
  
  The label stays `Cost 3`, and no cost label was renumbered.
- **Links:** none of the six inbound `[[sandbox-effects]]` links points into deleted text. They are in git-add-untracked-deletion, classifier-denied-self-config, bang-shell-shared-cwd, cc-bash-background-no-duration-cap, codex-review-of-design-docs and cc-worktree-bash-guard. `shared-claude.md` names the file in prose.
- As expected, every write drew the memory hook's "over the 4KB recall limit … Rewrite it to under 2.8KB" error. I ignored it, as Phase 4 did.

### memory/MEMORY.md and memory/ddaanet/MEMORY.md

The `sandbox-effects` index line in each got the same substitution as the description. A shell comparison confirmed that the two index lines, with the link stripped, are byte-identical to each other and to the unescaped `description`.

### docs/design.md (396 → 395 lines; no split)

Status flips; before → after is below. rumdl re-filled the edited paragraphs. The file stayed under 400 lines, so there is no split and no changelog entry (see findings).

### docs/references/detectors.md

Unchanged. The three `## Translation map` rows are already accurate:

- `harness-mounted config paths; merge recovery` → `readonly-path; recovery clause in its verdict and the skill`. The verdict carries "compare modified files against the target". The procedure stays in memory for Item 7.1's skill.
- `sibling worktree writes` → `readonly-path`. The dropped classifier sentence is covered below.
- `cost 3, recipes entirely unsandboxed` → `readonly-path; skill`. The diagnostic goes to the detector and the recipe guidance to the skill. The cost 1 row already records that its classifier note moved to cost 3.

## Judgement calls, each with how to revert

1. **Merge recovery lives in its own trimmed section, `## Interrupted merge: recover before retrying`, in the old section's place.** This follows Phase 4's resume-lost remnant.
   - Why a section of its own: the reader arrives with a different symptom, a tree left partly updated after the merge died. That is not the refusal `readonly-path` annotates, so it gets its own table row.
   - Why not fold it into `Leaving the sandbox`: that section covers the escapes and what they cost, and recovery is neither.
   - **Revert:** delete the section and its table row, and restore the procedure paragraph under whatever heading is wanted.
2. **The recovery paragraph gained a lead clause so that it stands alone.** The original opened "a `git merge --ff-only` that dies on `hooks/hooks.json`" and relied on the deleted bullet to explain why that file fails. It now reads "…dies on a harness-mounted path — the session's live `hooks/hooks.json`, held read-only whatever the write allowlist says — can leave…". The procedure itself is unchanged, word for word.
   - The claim still covers only harness-mounted paths. The deleted sibling section said a sibling-worktree merge aborts cleanly, so I did not extend the claim to sibling worktrees.
   - **Revert:** restore the original opening clause.
3. **The `git reset --hard <branchtip>` sentence moved into the recovery section.** It sat in the harness-mounted section's "How to apply", not in the named remainder. It is recovery guidance for the same failure, when `checkout` + `merge` choke on the protected files, and nothing carries it: the verdict only says to re-run. Deleting it would lose the fact. It describes a destructive command, but it was already in memory in the same scope.
   - **Revert:** delete the last sentence of the recovery section.
4. **Cost 3 stays in place, and only its quoted diagnostic was cut.** The part the detector translates is the failure text. The rest of cost 3 is about avoiding the failure before the recipe runs, since the steps ahead of it cannot be undone. That is authoring-time guidance, the skill's job, and it is exactly the remainder the runbook keeps. Cutting the quote also removes a whole diagnostic from a file that Item 7.1 will lift text out of.
   - **Revert:** restore `…then dies on the marketplace step:` followed by the three quoted-diagnostic lines, from git history of the memory submodule.
5. **Sibling worktree: one sentence dropped with nothing to receive it.** "Where the user's own prompt asked for the write, the auto classifier lets the retry through, so routing around the denial with a tool that is not under the command sandbox buys nothing and loses the shell." The verdict's instruction to re-run with the flag carries the act. The sentence is the reason not to route around the refusal, which directive-writing cuts from verdicts. The translation map maps the section to `readonly-path` alone. The "half-prints Updating … then aborts cleanly (no `MERGE_HEAD`)" detail was dropped the same way.
   - **Revert:** restore the sentence as a paragraph, for example under `Leaving the sandbox` next to cost 2, and map it to the skill in the translation map.
6. **Design status: FR-7 is `Done`, not `Partial`.** The runbook's requirement map gives FR-7 to Items 3.2, 4.2, 4.3 and 6.1, and all four are done. `zellij-socket` staying a candidate is D-15's recorded outcome, not unfinished work.
   - **Revert:** `Partial (zellij-socket stays a candidate)`.
7. **Design header status line updated too.** It still said "the `readonly-path` matcher and probe (no verdict yet)", which Item 6.1 made false. The design-doc state layer requires the edit that falsifies a claim to touch it.
   - **Revert:** restore the old clause.

## Status lines, before → after (docs/design.md)

- **Header:** `…and the readonly-path matcher and probe (no verdict yet). Nothing dogfooded.` → `…and the readonly-path verdicts with the hook's call to their probe. Nothing dogfooded.` The `Verified against:` line is untouched.
- **FR-4:** where `lib/probes.sh` → `lib/probes-readonly.sh` added, because slice 1 split the probe into that file. Pinned-by gains `tests/probes-readonly.bats` over each path-extraction form, and `tests/hook-locks.bats` over the hook's call becomes `tests/hook-locks.bats` and `tests/hook-candidates.bats` over the hook's calls. Status: `Partial (lock probes proved live and hook-called; readonly-path probe proved live, hook call with its verdict: Item 6.1).` → `Done.`
- **FR-5:** `Partial (readonly-path policy: Item 6.1).` → `Done.` The pinned-by already named `tests/hook-candidates.bats`, whose `readonly-path flag policy` case pairs the fixture with both flag values.
- **FR-6:** `Partial (readonly-path verdicts: Item 6.1).` → `Done.` The pinned-by already names `tests/verdicts.bats`, where Item 6.1 added the three readonly-path rows and text cases, so it is unchanged.
- **FR-7:** `Partial (four candidates shipped, readonly-path without its verdict until Item 6.1; zellij-socket stays a candidate).` → `Done (four candidates shipped; zellij-socket stays a candidate under D-15).` Pinned-by unchanged.
- **FR-10:** `Partial (phantom, /tmp, lock, $TMPDIR-unset, --resume and sandbox-setup sections retired; rest: Items 6.1, 7.1, 8.2).` → `Partial (phantom, /tmp, lock, $TMPDIR-unset, --resume, sandbox-setup, harness-mounted and sibling-worktree sections retired; rest: Items 7.1, 8.2).` Cost 3 is not listed as retired because its paragraph stays. Pinned-by unchanged, since Item 6.1 added no FR-10 test.

## Checks

- `cd /Users/david/code/sandbox-lies && bash lib/matchers.sh < memory/ddaanet/sandbox-effects.md; echo "exit=$?"` → no output, `exit=1`, so the file fires nothing.
  - `memory/` is **outside** the self-quiet guard. `tests/docs.bats` walks `git ls-files -s` and skips mode `160000`, and `memory` is a gitlink, so no memory file is swept.
  - The only suite that reads the live file is `tests/matchers.bats`, whose `the live memory file still fires nothing` case passed. No other test greps the file.
- `cd /Users/david/code/sandbox-lies && direnv exec . just precommit > "$TMPDIR/pc.out" 2>&1; echo "exit=$?"; tail -3 "$TMPDIR/pc.out"` →

```
exit=0
scripts/run-bats.sh tests/
bats: 196 passed, 0 failed — full log: /tmp/claude-1000/sandbox-lies-bats.4hxr8N
precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests
```

## Other findings, for the caller

- **No changelog entry records the `readonly-path` verdicts shipping or this retirement.** None of Item 6.1's slice commits added one, and my brief allowed a changelog edit only for a split. Phase 4 recorded its retirement in `docs/changelog.md`, `2026-09-26 — lock and candidate memory retired; …`, so the orchestrator may want a matching entry.
- **design.md's Architecture map** still lists only `lib/probes.sh probe_<verdict> functions`, although `probe_readonly_path` now lives in `lib/probes-readonly.sh`. I left it alone because it is not a status line. Adding a map line would take design.md to 396 lines.
- **`## Now`** still says "Next: corpus replay for the five candidate detectors", which is stale. Item 8.2 owns that section, so I left it.

## Status output

```
$ git status --porcelain --untracked-files=no; git -C memory status --porcelain; git -C memory/ddaanet status --porcelain
M  .claude/handoff-task.md
M  .claude/handoff-todo.md
 M docs/design.md
 M memory
 M MEMORY.md
 M ddaanet
 M MEMORY.md
 M sandbox-effects.md
```

The two staged `.claude/handoff-*.md` entries belong to another session and were not touched.

## Applied after this report

The working tree that carries this retirement differs from the account above in four places, each settling one of the findings: `docs/changelog.md` gained the `2026-09-26 — readonly-path verdicts shipped; config and worktree memory retired` entry; design.md's Architecture map gained the `lib/probes-readonly.sh` line; judgement call 5's dropped sentence was restored as the last sentence of cost 2 in `memory/ddaanet/sandbox-effects.md`; and the translation map's `sibling worktree writes` row in `docs/references/detectors.md` now reads `readonly-path; its classifier note moved to cost 2`. The phase-6 corrector review (reports/phase-6-corrector.md) lists its own edits.
