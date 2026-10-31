# Recovering a merge or checkout a sandbox refusal killed

A sandboxed `git merge --ff-only` or `git checkout <branch>` can die on a file
the sandbox will not let git write. Where HEAD ends up depends on how git
failed, so establish it first: `git log -1` and `git status`, and whether the
command exited 0. Never assume HEAD is still the pre-merge commit.

## Which failure moves HEAD

Reproduced 2026-10-31 on git 2.47.3 in a scratch repo, unsandboxed, with
read-only directories (`chmod 555`) standing in for the sandbox's refusal:

- **Git only fails to unlink a file it replaces** (an `error:` line, no
  `fatal:`). `git checkout <branch>` carries on: it switches the branch, moves
  HEAD to the target and exits 0. The refused file keeps its old content and
  shows modified; every other file is at the target. `git merge --ff-only` in
  the same position exits 1 with HEAD unmoved, the other files updated and the
  files the target adds left untracked.
- **Git fails to create a directory the target adds** (a `fatal:` line). Both
  commands die with exit 128 and HEAD unmoved.

Recorded 2026-09-27 on CC 2.1.281: a sandboxed `git checkout` on a linked
worktree outside the write allowlist died on the directory-creation failure,
HEAD unmoved (the fixture `tests/fixtures/fire-readonly-path-git-mkdir.txt` in
the plugin repository records that command).

Harness-mounted files — the session's live `hooks/hooks.json` and the project's
`.claude/settings.json`, held read-only whatever the write allowlist says — fail
at the unlink, so a checkout that hits one is the HEAD-moves case. Seen once in
another repository on `.claude/settings.json` (2026-10-31, CC version not
recorded).

In both cases git does not roll back the files it updated. A plain re-run of the
merge refuses them, and refuses the files the target adds once they exist
untracked.

## HEAD unmoved: a merge, or a checkout that died on `fatal:`

Recover before retrying:

1. Start from the files the hook's verdict names, where it names them; else
   `git status`. Diff each modified file against the target
   (`git diff <target> -- <file>`).
2. If they match the target exactly, restore them with
   `git checkout HEAD -- <files>`, and remove the untracked files the target
   added.
3. Re-run the whole merge unsandboxed in one call, not piecemeal.
4. If the checkout and the merge both choke on protected files,
   `git reset --hard <target>` run unsandboxed completes the fast-forward. It
   discards every uncommitted change, so it follows normal confirmation, and
   first confirm `git status` lists only files the merge wrote.

## HEAD moved: a checkout that exited 0

The target is already checked out. The refused files are the only casualty,
holding the old branch's content and showing modified. Restore them to HEAD,
unsandboxed.

Auto mode's classifier has refused `git checkout HEAD -- <file>` as destructive
(seen 2026-10-31). When the stranded copy is exactly the version a following
fast-forward brings in, `git add` of it lets that fast-forward proceed.
