# What the Bash tool's own wrapper does to a command

The Bash tool does not hand a command to a bare shell. Three effects of its
wrapper hold whether the call is sandboxed or not, and none shows in the output
of the call that suffers it.

## `set -e` is inert inside a call

Verified against CC 2.1.247, the tool runs

    bash -c "source <snapshot> 2>/dev/null || true && … && eval '<command>' && pwd -P >| /tmp/claude-<uid>/cwd-<id>"

The `eval` is a non-final element of an `&&` list, so POSIX ignores errexit
inside it, and bash extends that to every compound command and subshell nested
in it. `set -e` and `set -euo pipefail` therefore abort nothing: a subshell
`(set -e; cd missing; rm -rf build)` runs the `rm` from the original working
directory. `$-` still shows `e`, so reading the flags proves nothing.

- Chain with `&&` where a step must not run after a failure; the list rule
  itself is in `shell-scripting:shell-gotchas`.
- Or run the script in a fresh shell, which is not inside the list:
  `bash -e -c '…'`, or `bash -euo pipefail <<'EOF'` with a heredoc.
- Never let a hook grant something on the strength of a command's `set -e`: the
  guarantee does not exist.

The trailing `pwd -P >| …/cwd-<id>` is how the tool carries the working
directory to the next call: a `cd`, a `pushd`, or a run that went on past a
failure all persist. It records the physical path, so a symlinked project
directory reports its resolved path. The hook payload side is in
`plugin-craft:hook-authoring`.

## `grep` typed into the tool is ugrep

The tool's shell defines `grep` as a function (`type grep` shows it). Unless an
argument is one of ugrep's own flags (`--filter`, `--pager`, `-Z`, `--null`,
among others), it runs the `claude` binary as `exec -a ugrep` with
`-G --ignore-files --hidden -I --exclude-dir=.git --exclude-dir=.svn` and more,
falling back to `command grep` only when that binary is missing. Seen on CC
2.1.278.

Functions are not exported, so a script the tool runs, and every hook, gets the
real `grep` on `PATH`. What the function distorts is a probe typed directly into
the tool to learn how grep behaves: the exit status of `-q` on a closed pipe,
whether `--` is honoured, output on binary files (`-I` is on), whether ignored
files are searched (`--ignore-files` is on). Probe with `command grep` or
`/usr/bin/grep`, or from inside a script file, whenever the result stands for
what a script sees. A grep result that disagrees with a script's behaviour is
this mismatch until shown otherwise.

## The human partner's `!` shell shares the agent's working directory

A `!`-prefixed command the human partner types runs in the same shell working
directory as the agent's Bash calls, so a `cd` left by an earlier call relocates
it. A `cd` into a submodule followed by a handed-over `! git push origin main`
pushes the submodule, prints `Everything up-to-date`, and leaves the root's
commits unpushed; `git ls-remote origin refs/heads/main` shows the remote head
did not move. Make every command handed over as `! …` independent of the working
directory: `git -C <abs-path> …`, absolute paths, or an explicit
`cd <abs-path> &&` at its front.
