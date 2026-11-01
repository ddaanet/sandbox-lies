# Recovering a merge or checkout a sandbox refusal killed

A sandboxed `git merge --ff-only` or `git checkout <branch>` can die on a file
the sandbox will not let git write, leaving some files at the target and HEAD
either moved or not. Neither the exit status nor the command says which, and the
hook's verdict may say "HEAD unmoved" either way. One script covers every case
observed (below); run it unsandboxed:

1. **Read the plan.** Run `sandbox-lies-recover checkout <branch>` (or
   `sandbox-lies-recover merge <commit-ish>`) without `--apply`. It changes
   nothing and prints one line per path. `restore` and `remove` bring a path the
   command touched back to HEAD; `keep` is uncommitted work git carried over,
   left untouched. A last line is the command to re-run, when it did not reach
   the target. Exit 2 means the script cannot tell the state: act on nothing and
   report.
2. **Carry it out.** Run the same command again with `--apply`. It does the
   restores and removals, then re-runs the original command once, in one call,
   if the target was not reached.
3. **Never finish a checkout with `git reset --hard <target>`**: it moves the
   current branch to the target instead of switching to it, and drops the
   commits the target lacks. For a `merge --ff-only` that still refuses after
   step 2 it completes the fast-forward; it discards every uncommitted change,
   so it follows normal confirmation.

Auto mode's classifier has refused `git checkout HEAD -- <file>` as destructive
(seen 2026-10-31). The dry-run plan is what lets a refused `--apply` be asked
for: show the plan and ask, rather than reaching for a broader command.

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
not a closed list: a run can mix them. `tests/recover.bats` in the plugin
repository covers them and their neighbours.

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
