# Recovering a merge or checkout a sandbox refusal killed

A sandboxed `git merge --ff-only` or `git checkout <branch>` can die on a file
the sandbox will not let git write, leaving some files at the target and HEAD
either moved or not. Neither the exit status nor the command says which, and the
hook's verdict may say "HEAD unmoved" either way. One procedure covered every
case observed (below), run unsandboxed:

1. **Find where HEAD is.** Compare `git rev-parse HEAD` with
   `git rev-parse <target>`. The commit before the command is `HEAD` if they
   differ, `HEAD@{1}` if they match: call it `<pre>`.
2. **Bring the paths the command touched back to HEAD.** For each path in
   `git diff --name-only <pre> <target>`: a tracked one `git status` lists is
   restored with `git checkout HEAD -- <path>`; an untracked one is removed.
   Limit it to that list: other uncommitted work is not the command's, which
   would have refused to start had it overlapped.
3. **If HEAD is not at the target, re-run the whole command once**, in one call,
   not piecemeal. Re-running when HEAD already moved does nothing: a checkout
   reports "Already on" and leaves the refused files as they were.
4. **Never finish a checkout with `git reset --hard <target>`**: it moves the
   current branch to the target instead of switching to it, and drops the
   commits the target lacks. For a `merge --ff-only` that still refuses after
   step 3 it completes the fast-forward; it discards every uncommitted change,
   so it follows normal confirmation.

Auto mode's classifier has refused `git checkout HEAD -- <file>` as destructive
(seen 2026-10-31): ask for it rather than reaching for a broader command.

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
not a closed list: a run can mix them. The procedure above was re-run over all
eight (2026-10-31): each ended with HEAD at the target and an unrelated
uncommitted change kept.

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
