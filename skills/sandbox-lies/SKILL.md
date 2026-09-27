---
name: sandbox-lies
description: "What the Claude Code command sandbox does to Bash calls that no tool result reveals: whether a call ran sandboxed, what `excludedCommands` and `dangerouslyDisableSandbox` cost, why `$TMPDIR` does not survive a call, and where masks land. Use when writing a `sandbox.excludedCommands` entry, a recipe or script that must run unsandboxed, a cleanliness gate over `git status`, a `cd` into a submodule or subdirectory, a scratch path a later command or subagent reads, a `claude -p` run for a `SessionStart` hook's side effect, or a multi-turn `claude --resume` flow; when acting on a slash command's `` !`cmd` `` context block or recovering a merge a sandbox write refusal killed; and when reading `ps` for a background task."
---

# Sandbox lies

The Claude Code command sandbox confines each Bash call separately, and some of
what it distorts leaves nothing in the output: a call that ran unsandboxed looks
the same as one that did not, a `claude -p` that skipped every `SessionStart`
hook replies normally, a `$TMPDIR` path that resolved elsewhere fails only on a
later call. This plugin's hooks annotate the results that do show a symptom.
This skill carries the rest — what has to be right while *writing* the command,
the recipe, the gate or the directive, before any output exists.

## Tell a sandboxed call from an unsandboxed one

- **Treat every call as sandboxed unless it carries
  `dangerouslyDisableSandbox: true`.** On CC 2.1.281 the `excludedCommands`
  entries are not honoured: with `git:*` in user settings, a git call ran
  sandboxed (2026-09-26). Re-probe before relying on an exclusion.
- **A visible mask proves nothing about the call that saw it.** Mask paths are
  visible from every process while any sandboxed command runs, this session's or
  a parallel agent's. The evidence runs one way: no mask in a listing of the
  call's own working directory proves the call ran unsandboxed.
- **The mask-free test is a write only the sandbox refuses.**
  `touch /tmp/<name>` fails with the read-only-filesystem error only inside the
  sandbox. `${TMPDIR-UNSET}` also discriminates: `/tmp/claude-<uid>` sandboxed,
  `/tmp` unsandboxed on CC 2.1.281 (unset on CC 2.1.233).
- **Nothing records that a call ran unsandboxed** — not the tool result, not the
  transcript, not the hook payload. A clean unsandboxed `git status` is not
  evidence that the sandbox is clean.

## Writing an `excludedCommands` entry

Where honoured — not on CC 2.1.281; re-probe with the `/tmp` write first — an
entry is a permission-rule pattern, and one matching segment unsandboxes the
*whole* call. Before writing one:

- `foo bar` is exact and `foo bar:*` a prefix. A plain `"git status"` covers
  only the bare literal; only `git:*` reaches `git -C <dir> status`.
- Nesting fails closed: `( … )`, `$( … )`, `sh -c '…'` and a git inside a recipe
  or script never match.
- The match is static: `false && git status; <payload>` frees the whole call
  while the decoy never runs.
- It does not grant approval: the rest of the permission pipeline still judges
  the command, clearing a bare read-only command from the original working
  directory before any classifier call.

Splitting rules, wrapper unwrapping, the read-only validator's refusals and why
an exclusion beats a rewriting hook:
[references/excluded-commands.md](references/excluded-commands.md).

## Leaving the sandbox for one call

- **Per call:** `dangerouslyDisableSandbox: true`. **Standing:**
  `sandbox.excludedCommands`, honoured in strict mode too where honoured at all.
- **Strict mode refuses the per-call flag.** Ask the human partner to run the
  command as `! <command>` or to change the mode; never retry the same sandboxed
  command.
- **An unsandboxed command reaches the permission classifier**, which denies
  benign compounds unpredictably. Keep an escaped command in its own call rather
  than appending a compound to it.
- **Read-only inspection is not mutation.** Where the human partner has made
  reading local git state or a masked path unsandboxed a standing default, call
  it directly, without asking. Anything that writes follows normal confirmation.

Detail and observed refusals:
[references/escapes-and-costs.md](references/escapes-and-costs.md).

## Keeping the working directory at the project root

Masks sit under the sandboxed call's working directory, and the Bash tool keeps
a `cd` between calls (CC 2.1.281): one `cd` into a submodule leaves every later
sandboxed call masking inside it. In order of preference:

- Give a command absolute paths; give git `-C <dir>`.
- Otherwise end the call with a `cd <root>` line.
- A subshell, `(cd <dir> && …)`, comes last: a git inside it misses an honoured
  `git:*` exclusion.

Unsandboxed, `git -C`, a `cd` beside a git segment and a subshell each forfeit
the read-only auto-allow and cost a classifier call:
[references/excluded-commands.md](references/excluded-commands.md).

## Writing a recipe or script that must run unsandboxed

- **Run it entirely unsandboxed.** An environment variable passing through the
  sandbox does not make the path it names writable, and a recipe that dies late
  has usually done its irreversible steps already. An exclusion never reaches a
  `git` or `claude` inside the recipe: the top-level segment is the recipe
  runner.
- **A multi-turn `claude --resume` flow must run unsandboxed.** A sandboxed
  `claude --print` turn never persists its transcript, so turn 2 cannot resume
  it. A single-turn connectivity probe passes sandboxed and cannot detect this.
- **A sandboxed `claude -p` skips every `SessionStart` hook** of every plugin,
  silently. Unsandbox the whole call whenever its point is a hook's side effect.

The release half-landing, the eval-harness signatures and the `SessionStart`
evidence: [references/recipes-and-claude.md](references/recipes-and-claude.md).

## A scratch path that must survive the call

`$TMPDIR` is set per call by the harness and is not stable across calls. Treat
every use as scoped to the single command that expands it. For a backup a
*later* call restores, and for any path written into a subagent directive,
hardcode the literal scratch path (`/tmp/claude/<job>/…`, created with
`mkdir -p`). A subagent shell inherits neither the environment nor the working
directory, so a `$TMPDIR` in a handed-over command resolves to whatever the
receiving call's `$TMPDIR` is, and a restore path that silently resolves
elsewhere is the expensive case.

The observed collapse:
[references/escapes-and-costs.md](references/escapes-and-costs.md).

## Writing a cleanliness gate

- **A porcelain gate inverts under the sandbox.** Masks are reported as `??`
  lines unconditionally, so "non-empty `git status --porcelain` means dirty"
  fails a genuinely clean tree, indistinguishably from a real failure.
- **Do not filter the mask names.** The set is version-dependent, and a filter
  hides real untracked files sharing those names. Run the status unsandboxed
  with no sandboxed command running alongside it, or scope the gate to tracked
  paths with `git status --porcelain --untracked-files=no` where untracked files
  are not the subject.
- **A slash command's `` !`cmd` `` expansion is a Bash call no hook sees.** It
  is sandboxed like a typed call, so a `## Context` block can list masks, and no
  annotation will say so. Never act on an injected listing: re-run `git status`
  unsandboxed first.

Mask shapes and placement, and the expansion path's mechanism:
[references/masks-and-gates.md](references/masks-and-gates.md).

## Recovering a merge a sandbox refusal killed

A sandboxed `git merge --ff-only` or `git checkout <branch>` that dies on a
harness-mounted file — the session's live `hooks/hooks.json`, held read-only
whatever the write allowlist says — updates every other file it processed to the
target's content while HEAD stays at the pre-merge commit. Git does not roll
them back, and a plain re-run refuses them, as it refuses the files the target
adds once they exist untracked. On a sibling worktree outside the write
allowlist altogether, the same merge or checkout died on git's own error
creating a directory the target adds, or replacing a tracked file it changes,
HEAD again unmoved (2026-09-27, CC 2.1.281). Recover before retrying:

1. Start from the files the hook's verdict names, where it names them; else
   `git status`. Diff each modified file against the merge target
   (`git diff <target> -- <file>`).
2. If they match the target exactly, restore them with
   `git checkout HEAD -- <files>`, and remove the untracked files the target
   added.
3. Re-run the whole merge unsandboxed in one call, not piecemeal.
4. If the checkout and the merge both choke on protected files,
   `git reset --hard <target>` run unsandboxed completes the fast-forward. It
   discards every uncommitted change, so it follows normal confirmation, and
   first confirm `git status` lists only files the merge wrote.

## Background tasks are invisible to a sandboxed `ps`

A sandboxed Bash call runs in its own PID namespace, so its `ps` lists only that
call's processes: a `run_in_background` task, with everything it spawns, is
absent from it. An unsandboxed `ps` lists it. Checked 2026-09-27 on CC 2.1.281:
with a sandboxed `sleep` running in the background, `ps -eo pid,args` returned 5
lines and no `sleep` sandboxed, and 204 lines with the `sleep` unsandboxed.
Earlier, a `ps` showed two `bash` entries while a background test suite was
mid-run and went on to complete (2026-08-15, CC version not recorded). An empty
sandboxed `ps` is not evidence that a background job died. Restarting the work
in the foreground to check puts two heavy runs on the box; the second times out,
and both then look like the first one failing. Check with an unsandboxed `ps`,
and watch the task's output file and the artifact the job writes on success; a
completion notification may never reach a subagent, so it is never the only
thing waited on. Key a wait on the command's exit, not on an output line that
reads as terminal.
