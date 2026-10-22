# The hook

What the plugin runs, when, and what it can and cannot change. What each
detector looks for and says is in [Detectors](detectors.md).

## What runs, and when

The plugin registers two scripts, each run through `bash` with a 10 s timeout,
so neither needs its executable bit and a space in the plugin's path is safe:

- `hooks/annotate.sh` after every Bash call: on `PostToolUse` when the command
  succeeded, on `PostToolUseFailure` when it exited non-zero, never both.
- `hooks/check-jq.sh` at every session start: a new session, a resume, and after
  `/clear` or a compaction.

There is no `PreToolUse` hook: nothing runs before a Bash call.

## On each Bash call

The hook reads the result text exactly as the agent saw it, never the command,
and does not consult the exit status. It runs every detector over that text. For
each detector that fires and is not silent for this call (some are silent on an
unsandboxed call), it runs that detector's check, if it has one, then composes
the verdict. The agent's paragraphs go into one `additionalContext` and your
one-line notices into one `systemMessage`, joined by `; `. A result that matches
nothing produces no output.

The hook never blocks, rewrites or unsandboxes anything, and the original result
stays visible beside the annotation. The annotation reaches the agent with its
next request, so a Bash call issued in the same batch as the failing one runs
before it lands. A check that looks for a lock's holder adds a few hundred
milliseconds to that call.

## Where a check looks

Hooks are run by Claude Code itself, outside the command sandbox, so a check
sees the machine as an unsandboxed command would: it is the "run it unsandboxed"
step done for the agent. A character device found at a checked path is read as a
sandbox mask, never as a file.

- A lock path that git printed relative is taken from the nearest directory at
  or above the call's working directory that holds a `.git` directory, else from
  that working directory; with none known, from the hook's own, never `/`.
- `readonly-path` joins a relative path onto the call's working directory,
  except when git reported a partially written checkout, whose paths are
  relative to the worktree's top-level.
- The `phantom-*` detectors run no check and their paragraphs name no location,
  so they hold whatever directory the call ran in.

## Without `jq`

`annotate.sh` reads its input with `jq`. Without `jq` on `PATH` it stays silent
and every Bash result goes unannotated. `check-jq.sh` then speaks at each
session start, through two channels:

- to you, one line naming the plugin, saying that `jq` was not found on `PATH`
  and that Bash result annotations are off until it is installed. It opens with
  a style reset, so it is not dimmed like ordinary hook output;
- to the agent, that annotations are off because `jq` is not on `PATH`, that no
  Bash result carries a sandbox-lies note until it is, and that a result without
  one is unchecked, not undistorted.

`annotate.sh` looks `jq` up again on every call, so installing `jq` restores the
annotations within the session, without a restart. With `jq` found,
`check-jq.sh` prints nothing. Neither script writes a file.
