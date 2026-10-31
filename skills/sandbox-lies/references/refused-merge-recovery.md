# Recovering a merge or checkout a sandbox refusal killed

A sandboxed `git merge --ff-only` or `git checkout <branch>` can die on a file
the sandbox will not let git write. Where HEAD ends up depends on how git
failed, and neither the exit status nor the command decides it. Check first:

- `git rev-parse HEAD` compared with the target's (`git rev-parse <target>`):
  this says whether HEAD moved;
- whether git printed a `fatal:` line.

Never assume HEAD is still the pre-merge commit, and never assume it moved. The
hook's verdict may say "HEAD unmoved" either way: trust the check above, not the
verdict.

## What was observed

Reproduced 2026-10-31 on git 2.47.3 in a scratch repo, unsandboxed, with
read-only directories (`chmod 555`) standing in for the sandbox's refusal. The
target changed one thing in a refused directory:

| The target… | git printed | `checkout` | `merge --ff-only` |
| --- | --- | --- | --- |
| changes a file | `error:` unable to unlink | exit 0, HEAD moved, file `M` | exit 1, HEAD unmoved |
| adds a file | `error:` unable to create | exit 0, HEAD moved, file `D` | exit 1, HEAD unmoved |
| deletes a file | `warning:` unable to unlink | exit 0, HEAD moved, file `??` | exit 0, HEAD moved, file `??` |
| adds a directory | `fatal:` cannot create directory | exit 128, HEAD unmoved | exit 128, HEAD unmoved |

Where HEAD stayed unmoved, the other files git processed were still at the
target, and the files the target adds were untracked. These are the cases seen,
not a closed list: a run can mix them, and the check above decides.

Recorded 2026-09-27 on CC 2.1.281: a sandboxed `git checkout` on a linked
worktree outside the write allowlist died on the directory-creation `fatal:`,
HEAD unmoved (`docs/references/readonly-path.md` and the
`fire-readonly-path-git-mkdir` entry in `tests/extract-fixtures.py`, in the
plugin repository, record it).

Harness-mounted files (the session's live `hooks/hooks.json` and the project's
`.claude/settings.json`) are held read-only whatever the write allowlist says. A
checkout refused on `.claude/settings.json` was seen in another repository with
HEAD moved (2026-10-31, CC version not recorded).

Git rolls back none of the files it updated. Where HEAD stayed unmoved, a plain
re-run of the command refuses them, and refuses the files the target adds once
they exist untracked.

## HEAD unmoved

Recover before retrying:

1. Start from the files the hook's verdict names, where it names them; else
   `git status`. Diff each modified file against the target
   (`git diff <target> -- <file>`).
2. If they match the target exactly, restore them with
   `git checkout HEAD -- <files>`, and remove the untracked files the target
   added.
3. Re-run the whole merge or checkout unsandboxed in one call, not piecemeal,
   then repeat the check above.
4. For a `merge --ff-only` only: if the file restore of step 2 and the re-run
   both choke on protected files, `git reset --hard <target>` run unsandboxed
   completes the fast-forward. Never use it for a checkout: it moves the current
   branch to the target instead of switching to it. It discards every
   uncommitted change, so it follows normal confirmation, and first confirm
   `git status` lists only files the merge wrote.

## HEAD moved

The target is already checked out. Do not re-run the command: a checkout of the
branch it is on reports "Already on" and leaves every refused file as it was.
The refused files are the casualties: a file the target changes still holds the
old branch's content (`M`), a file the target adds is missing (`D`), and a file
the target deletes is left untracked (`??`). Restore the first two to HEAD and
remove the third, unsandboxed.

Auto mode's classifier has refused `git checkout HEAD -- <file>` as destructive
(seen 2026-10-31). When the stranded copy is exactly the version a following
fast-forward brings in, `git add` of it lets that fast-forward proceed.
