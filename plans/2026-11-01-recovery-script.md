# Plan: the refused merge/checkout recovery as a script

2026-11-01. My human partner approved the move, for this release. Why: five
review rounds kept finding cases that the prose steps 1–2 of
`skills/sandbox-lies/references/refused-merge-recovery.md` missed. The latest
were the high H1 and the mediums M1, M5 and M6 in
`tmp/2026-11-01-release-review-docs.md`. Steps 1–2 hold no judgement, only
detection and branching, so they move into a script tested over every state
probed so far.

## Contract

`bin/sandbox-lies-recover` is executable bash, run unsandboxed by the agent. A
plugin's `bin/` is on PATH (plugin-craft skill-authoring, bundled scripts), so
`dist.include` gains `bin`.

```
sandbox-lies-recover [--apply] [-C <dir>] checkout <branch>
sandbox-lies-recover [--apply] [-C <dir>] merge <commit-ish>
```

- `-C` names the repository and defaults to the current directory, so a
  linked worktree works. Without `--apply` it prints the plan and changes
  nothing. With `--apply` it carries the plan out and prints each act as it
  runs it.
- **Reached.** For a checkout, `git symbolic-ref -q HEAD` names
  `refs/heads/<branch>`. For a merge, `HEAD` equals `<commit-ish>^{commit}`.
- **`<pre>`, the commit before the refused command.** If the target was not
  reached, it is `HEAD`. If it was, the script walks the HEAD reflog,
  newest first, to the most recent entry that moved to the target from
  something else: a checkout's `checkout: moving from <X> to <branch>` with
  X ≠ branch, or a merge's fast-forward entry for the target. `<pre>` is
  that entry's old value. The same-branch entries a re-run writes are skipped
  (H1). If no such entry exists, the script exits 2 with a message saying it
  cannot tell, and acts on nothing.
- **Paths.** `git diff --no-renames --name-only -z <pre> <target>`, read
  NUL-delimited, no `git status` filter (M1, M5). For each path, take the
  state of the working copy: absent, or a regular file compared by bytes
  (`git show <rev>:<path> | cmp -s - <path>`, with `git cat-file -e` for
  whether the rev has it) (M6). Then:
  - It equals HEAD's version, or it is absent and HEAD has none: nothing to do.
  - It equals `<pre>`'s or `<target>`'s version, including absent where that
    version is absent: if HEAD has the path, `restore <path>`
    (`git checkout HEAD -- <path>`); if not, `remove <path>`.
  - Anything else: `keep <path>`, printed as uncommitted work and left
    untouched.
- **Re-run.** If the target was not reached, the plan's last line is the
  original command (`git checkout <branch>` or `git merge --ff-only
  <commit-ish>`), run once under `--apply`, with its exit status reported. If
  that refuses, the script prints that and exits non-zero. It never runs
  `reset --hard`.
- Exit status: 0 when nothing is left to do, the plan was carried out, or a
  dry run printed its plan; 1 for
  a re-run that failed; 2 for a usage error or a state it cannot tell.
- Must run under macOS `/bin/bash` 3.2 and BSD tools: no `mapfile`, no
  `${x,,}`, and `read -r -d ''` for the NUL loop. In a comment, state the
  residual bound: symlinks, mode-only changes and submodules are compared
  only as presence.

## Tests

`tests/recover.bats`, which loads `helpers/bsd-stubs`. It builds scratch repos
under `$BATS_TEST_TMPDIR` and uses `chmod 555` for the refusal, as the
observation table did. Each case runs the refused command, makes the
directories writable again, then runs `--apply`, and asserts that the branch
or HEAD is at the target, `git status --porcelain -uall` shows only the work
that was kept, and that work is intact byte for byte. The states:

- the eight cells of the table: change, add or delete a file, and add a
  directory, each under both `checkout` and `merge --ff-only`;
- a path staged with the target's content and then edited further;
- a checkout of a branch at the current commit, refused on `index.lock`;
- H1: the checkout re-run once by hand before recovery;
- M1: a file added inside a new directory, and a deleted directory;
- M5: a rename out of a refused directory;
- M6: an untracked leftover identical to `<pre>`;
- a path containing a space and one containing a newline;
- an unrelated uncommitted change elsewhere, still intact afterwards;
- a run without `--apply` that changes nothing, checked by tree and index
  hashes before and after.

The suite calls `cmp`, `git` and `mktemp`, so one case re-runs with
`make_bsd_stubs` on PATH. Red first: a missing script fails every case on an
assertion, not a setup error.

## Docs

- `refused-merge-recovery.md`: steps 1–2 become "run `sandbox-lies-recover`
  without `--apply`, read the plan, then run it with `--apply`". Keep the
  step 4 prohibition (`reset --hard` on a checkout) and the observation
  table. Rewrite the classifier note: the dry-run plan is what lets a refused
  `--apply` be asked for, not a broader command. Drop step 3's "re-running does nothing" sentence,
  since a re-run shifts the reflog and the script covers that case.
- `SKILL.md` recovery stub: the same act in one sentence, plus the
  prohibition.
- `docs/design.md` is at its 400-line cap and is left untouched. Its split is
  a TODO item already open, which gains "record `bin/sandbox-lies-recover`".
- `manual/`: one line wherever the manual lists what ships, if it has such a
  list.
