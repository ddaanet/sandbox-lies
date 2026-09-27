# Review fixes: sandbox-lies skill (Finish review gate)

**Scope**: `skills/sandbox-lies/SKILL.md` and its four `references/` nodes,
applying M1–M5 and m1–m14 of `plans/sandbox-lies/reports/review-skill.md`; one
`docs/changelog.md` entry. **Date**: 2026-09-27 **Mode**: fix (findings given)

## Summary

18 of 19 findings are FIXED, and one half of m7 is DEFERRED. The masks-follow-cwd
carry now has a hub section and a description trigger. Its acts are ordered the
same way in the hub and the node, and escapes-and-costs no longer recommends a
leading `cd`. The `ps` claim was probed and restated: a sandboxed `ps` cannot
see a background task, but an unsandboxed one can. Every hub-to-node and
node-to-node pointer is now a link that `check-links.sh` resolves.

**Overall Assessment**: Ready. One DEFERRED item needs a main-session probe.

## Probes

### M5: `ps` and a background task (2026-09-27, CC 2.1.281)

The version comes from this session's transcript `version` field
(`"version":"2.1.281"`).

1. A sandboxed Bash call with `run_in_background: true` ran `sleep 907`.
2. Unsandboxed, `ps -eo pid,args | wc -l; ps -eo pid,args | grep -F 'sleep 907'`
   printed `204`. The matches were the sandbox wrapper chain (`bash -c socat …`,
   then `/proc/self/fd/3 /bin/bash -c … eval 'sleep 907' …`) and
   `2648403 sleep 907`.
3. Sandboxed, the same pipeline printed `5`, and the grep matched nothing
   (`grep-exit=1`).
4. Cleanup: an unsandboxed `kill 2648403` ended the task with exit 143. A
   follow-up `ps` with an anchored pattern, `^ *[0-9]+ sleep 907$`, matched
   nothing.

A sandboxed `ps` lists only its own call's PID namespace. The host listing that
an unsandboxed `ps` takes includes the sandboxed background task.

### m7, second bullet: cwd persistence in this subagent

- Call 1: `cd /tmp && pwd` printed `/tmp`.
- Call 2: `pwd` printed `/Users/david/code/sandbox-lies`.

The cwd resets between this subagent's calls, so the head-versus-anywhere and
subshell probe cannot run here.

One lead for the main-session probe, from the M5 listing: the sandboxed wrapper
runs `eval '<command>' < /dev/null && pwd -P >| <cwd-file>`. The cwd is
therefore captured from the shell's final state after an `eval` in the same
shell. That predicts three things:

- a top-level `cd` anywhere in the call persists;
- a `cd` inside `( … )` does not;
- nothing is captured when the command exits non-zero.

This is a reading of the wrapper, not an observed cwd.

### m3: version lookups

Each lookup was one targeted `grep` over `~/.claude/projects`, keeping only
lines stamped with the claim's date and reading only the `version` field.

| Claim | String / date | Result |
| --- | --- | --- |
| `$TMPDIR` collapse | `checkpoint.py.bak` / 2026-09-14 | CC 2.1.266. The line is a subagent's report that `$TMPDIR` was unset; sandbox state not recorded |
| zero-byte masks | `r--r--r--` / 2026-07-20 | CC 2.1.215 |
| classifier refusals | `ls -a \| wc -l` / 2026-08-16 | none; the earliest hit is 2026-08-28 |
| release half-landing | `marketplace.json` / 2026-07-30 | none |
| `SessionStart` | `gitlore.hooksDir` / 2026-08-11 | none |
| `ps` | `ps aux` / 2026-08-15 | none (superseded by the M5 probe) |
| strict mode (undated) | `Strict sandbox mode` | first seen 2026-07-16 (CC 2.1.211), as a memory file already written; its origin session's transcript is gone |
| `--resume`, prompted retry (undated) | node phrases | 2026-09-26 hits only, the skill's own authoring sessions |

## Issues and status

### Major

1. **M1: carry unreachable.** FIXED.
   - A new hub section, "Keeping the working directory at the project root",
     states where masks land, that the `cd` persists (CC 2.1.281), and the
     ordered acts.
   - The description gained "a `cd` into a submodule or subdirectory".
   - The masks-and-gates pointer now reads "Mask shapes and placement, and the
     expansion path's mechanism".
2. **M2: acts conflicted with excluded-commands.md.** FIXED, in the hub and in
   masks-and-gates.md.
   - Order: absolute paths or `git -C <dir>` first, then a trailing `cd <root>`
     line, then a subshell last, "a git inside it misses an honoured `git:*`
     exclusion".
   - The cost clause names `git -C`, a `cd` beside a git segment, and a
     subshell. The review's "each of these forms" would have included absolute
     paths, which do not forfeit the read-only auto-allow.
3. **M3: escapes-and-costs recommended `cd <dir> && git status`.** FIXED. The
   example is now `git -C <dir> log …; git -C <dir> status`, and the cost point
   is unchanged.
4. **M4: `claude -p` `SessionStart` trigger.** FIXED. It was added to the
   description; see m13 for the cost.
5. **M5: `ps` claim.** FIXED from the probe above.
   - The heading is now "invisible to a sandboxed `ps`".
   - The body states the namespace scope, the 2026-09-27 CC 2.1.281 counts (5
     lines without the `sleep`, 204 with it), and the 2026-08-15 observation
     marked "CC version not recorded".
   - The act is now "Check with an unsandboxed `ps`, and watch the task's output
     file and the artifact". The unsupported 141-line figure is dropped.

### Minor

1. **m1.** FIXED. A handed-over `$TMPDIR` "resolves to whatever the receiving
   call's `$TMPDIR` is".
2. **m2.** FIXED. The line now says "set per call by the harness". "Even
   sandboxed" is dropped: the 2026-09-14 source says `$TMPDIR` was unset, and a
   sandboxed call gets it exported. The M5 wrapper shows
   `export TMPDIR=/tmp/claude-1000`. The node now carries CC 2.1.266 and "the
   call's sandbox state not recorded".
3. **m3.** FIXED. Versions or "CC version not recorded" were added per the table
   above: strict mode, 2026-08-16, the prompted retry, 2026-07-30, `--resume`,
   2026-08-11, 2026-07-20 (CC 2.1.215), and `ps`.
4. **m4.** FIXED. The line now reads "the exclusions still apply where
   honoured".
5. **m5.** FIXED. The line now reads "clearing a bare read-only command from the
   original working directory before any classifier call".
6. **m6.** FIXED. The section now opens "Where honoured — not on CC 2.1.281;
   re-probe with the `/tmp` write first — an entry is…".
7. **m7, first bullet.** FIXED. The opener now reads "in the sandboxed call's
   working directory, normally the project root". The paragraph after it now
   opens "That directory is not always the project root" rather than repeating
   the opener.
8. **m7, second bullet.** DEFERRED. This subagent's cwd resets between calls
   (probe above), so masks-and-gates.md's "A `cd` at the head of a call persists
   too" is left unchanged.
   - What would settle it: in a main session, run `true; cd <dir>` then `pwd`,
     and `(cd <dir>)` then `pwd`, each in its own call, recording the version.
   - The wrapper reading above predicts the outcome.
9. **m8.** FIXED. The line now reads "no mask in a listing of the call's own
   working directory".
10. **m9.** FIXED. The parenthetical is replaced by the recorded sibling-worktree
    case, dated 2026-09-27 on CC 2.1.281: git's own error creating a directory
    the target adds, or replacing a tracked file it changes, with HEAD unmoved.
    The `MERGE_HEAD` clause is dropped.
11. **m10.** FIXED.
    - Step 1 now opens "Start from the files the hook's verdict names, where it
      names them; else `git status`".
    - Step 4 now says the reset "follows normal confirmation", which is the
      hub's own wording.
12. **m11.** FIXED. The clause is scoped to what was observed: gitlore keeps its
    IPC file outside `.git/`, where the sandbox masks some paths. The project
    root's `.git/config.lock` showed as a character device on 2026-09-25 (CC
    2.1.281), while sandboxed commits in a scratch repository succeeded.
13. **m12.** FIXED.
    - Seven hub pointers are now links, the new section's two among them.
    - So are three node-to-node mentions: escapes-and-costs twice, and
      excluded-commands to masks-and-gates.
    - masks-and-gates gained one new link.
    - `check-links.sh` passes, and none are left as code spans (`grep` for a
      code-span `.md` pointer is empty).
14. **m13.** FIXED. See the description decision below.
15. **m14.** FIXED. The line now reads "reports `tail`'s exit status (without
    `pipefail`)".

### Description decision (M1, M4, m13)

The description loads in every session where the plugin is enabled. It grew
from about 595 to 723 characters, roughly 30 tokens, which is under the
reviewer's 790 and the 1024 limit.

Five triggers were added:

- whether a call ran sandboxed;
- where masks land;
- a `cd` into a submodule or subdirectory;
- a `claude -p` run for a `SessionStart` hook's side effect;
- acting on a slash command's `` !`cmd` `` context block.

Two phrases were tightened to pay for them:

- "how … escape it and what each costs" became "what … cost";
- "a subagent directive or later command naming a scratch path" became "a
  scratch path a later command or subagent reads".

The skill-authoring shape is kept: what the skill is, then "Use when…".

## Fixes applied

- `SKILL.md`: the description, and the hub text for m8, m6, m5, M1/M2 (the new
  section), m2, m1, m9, m10 and M5. Links replace the code-span pointers (m12).
- `references/escapes-and-costs.md`: links (m12), m4, m3 (strict mode,
  2026-08-16, the prompted retry, 2026-07-30), m2 (2026-09-14), M3.
- `references/masks-and-gates.md`: m7 opener, m3 (CC 2.1.215), M2 act order, a
  link.
- `references/recipes-and-claude.md`: m3 (`--resume`, 2026-08-11), m11, m14.
- `references/excluded-commands.md`: a link (m12).
- `docs/changelog.md`: a 2026-09-27 entry for the `ps` correction, the reachable
  cwd act, and the description triggers. This follows the precedent that logged
  the masks-follow-the-cwd skill change.

## Out of scope, noted

- **`docs/references/detectors.md:391`** still says "`ps` shows only the agent's
  shell". The M5 probe makes that true only of a sandboxed `ps`. `docs/` is
  outside this dispatch's edits; the changelog entry names the gap.
- **The phantom verdicts' "the project root" wording in `lib/verdicts.sh`** is
  deferred by the dispatch.

## Verification

- **Line counts:**
  - SKILL.md: 173 (cap 200).
  - escapes-and-costs: 79.
  - excluded-commands: 110.
  - masks-and-gates: 60.
  - recipes-and-claude: 67 (cap 400).
- **`just precommit`**, run unsandboxed in the foreground, exited 0. It reported
  `bats: 251 passed, 0 failed` and `precommit passed: plugin.json, hooks.json,
  shellcheck, bash -n, rumdl, line limits, links, tests`, with `tests/docs.bats`
  among them.
- **`just format-docs`** was run before the gate.
- **Detectors on this report:** `lib/matchers.sh` run over it prints nothing.
- **Voice:** no second person, internal ids, memory pointers or private paths
  were added to the skill files.
