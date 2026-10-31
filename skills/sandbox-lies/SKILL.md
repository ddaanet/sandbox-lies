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

- **A call runs unsandboxed only when it carries
  `dangerouslyDisableSandbox: true` or an `excludedCommands` entry covers every
  command in it.** Any uncovered command, or a forfeiting shape listed below —
  git's absolute, `~`-led or `..`-bearing path arguments among them — keeps the
  call sandboxed. Observed on CC 2.1.289 and again on CC 2.1.293: a bare covered
  `git status` from the project root listed no masks, while the uncovered form,
  the same status behind `true && command`, ran sandboxed and listed them.
  Before relying on an exclusion, re-probe with
  `git status --porcelain --ignored` alone in its call: without `--ignored`, a
  sandboxed listing leaves out every mask name the repository ignores. Earlier
  "not honoured" probes were confounded.
- **A visible mask proves nothing about the call that saw it.** Mask paths are
  visible from every process while any sandboxed command runs, this session's or
  a parallel agent's. The evidence runs one way: no mask in a listing of the
  call's own working directory, ignored names included, proves the call ran
  unsandboxed.
- **The mask-free test is a write only the sandbox refuses.**
  `touch /tmp/<name>` fails with the read-only-filesystem error only inside the
  sandbox. `${TMPDIR-UNSET}` also discriminates: `/tmp/claude-<uid>` sandboxed,
  `/tmp` unsandboxed on CC 2.1.281 (unset on CC 2.1.233).
- **Nothing records that a call ran unsandboxed** — not the tool result, not the
  transcript, not the hook payload. A clean unsandboxed `git status` is not
  evidence that the sandbox is clean.

## Writing an `excludedCommands` entry

An entry is a permission-rule pattern, and CC applies it only when it covers
every command in the call. Before writing one:

- Write `git *`, a prefix; `git:*` is the legacy form. A plain `"git status"`
  covers only the bare literal.
- A covered call still stays sandboxed with a `sudo`, `eval` or `xargs` head, a
  `cd`, `pushd` or `popd` anywhere, a subshell, a command substitution, an `if`
  or `for` block, a redirection (a descriptor duplication such as `2>&1` is
  documented as fine, but was seen to keep a call sandboxed on CC 2.1.289), or a
  command name from a variable. Nested commands never match: `sh -c '…'` and a
  git inside a recipe or script.
- Git stays sandboxed under any entry with `-C <dir>`, and with an absolute,
  `~`-led or `..`-bearing path argument (`git init`, `git clone`,
  `git worktree add`, among others).
- It does not grant approval: the rest of the permission pipeline still judges
  the command. A narrow allow rule covering the command clears it before the
  classifier. So does the read-only validator, for a bare read-only command from
  the original working directory, except where the session has server-side
  review.

The full list of forfeiting shapes, what was observed beyond the documented
ones, the confounded probes, wrapper unwrapping, the read-only validator's
refusals and why an exclusion beats a rewriting hook:
[references/excluded-commands.md](references/excluded-commands.md).

## Leaving the sandbox for one call

- **Per call:** `dangerouslyDisableSandbox: true`. **Standing:**
  `sandbox.excludedCommands`, for a call whose every command an entry covers,
  honoured in strict mode too, at user scope.
- **Strict mode ignores the per-call flag**: the call still runs, sandboxed. It
  is `sandbox.allowUnsandboxedCommands: false`, shown in `/sandbox` as Strict
  sandbox mode; check it rather than assume. Under it, ask the human partner to
  run the command as `! <command>` or to change the mode; never retry the same
  sandboxed command. In a background session, and on Linux with
  `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB` set, a `!` command runs sandboxed too:
  there, ask for the mode change.
- **An unsandboxed command reaches the permission classifier** unless a narrow
  allow rule covering it or the read-only validator clears it, and the
  classifier denies benign compounds unpredictably. Keep an escaped command in
  its own call rather than appending a compound to it, even to save a call.
- **Read-only inspection is not mutation.** Where the human partner has made
  reading local git state or a masked path unsandboxed a standing default, call
  it directly, without asking. Anything that writes follows normal confirmation.

Detail and observed refusals:
[references/escapes-and-costs.md](references/escapes-and-costs.md).

## Keeping the working directory at the project root

Masks sit under the sandboxed call's working directory. In the main session the
Bash tool keeps a top-level `cd` between calls (CC 2.1.281), so one `cd` into a
submodule leaves every later sandboxed call masking inside it; a subagent's
working directory resets per call. In order of preference:

- Give a command absolute paths; give git `-C <dir>`.
- Otherwise use a subshell, `(cd <dir> && …)`, whose `cd` cannot persist.
- Or end the call with a `cd <root>` line.

`git -C`, a git absolute-path argument, a `cd` and a subshell each keep the call
sandboxed under any `excludedCommands` entry. Run with
`dangerouslyDisableSandbox`, `git -C`, a subshell and a `cd` beside git each
forfeit the read-only auto-allow and, absent an allow rule, cost a classifier
call:
[references/excluded-commands.md](references/excluded-commands.md).

## Writing a recipe or script that must run unsandboxed

- **Run it entirely unsandboxed.** An environment variable passing through the
  sandbox does not make the path it names writable, and a recipe that dies late
  has usually done its irreversible steps already. An exclusion never reaches a
  `git` or `claude` inside the recipe: the top-level segment is the recipe
  runner.
- **A multi-turn `claude --resume` flow must run unsandboxed.** A sandboxed
  `claude --print` turn never persists: a new session cannot be resumed, and a
  turn on a persisted one answers but is dropped (CC 2.1.292). A single-turn
  connectivity probe passes sandboxed and cannot detect this.
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

- **A porcelain gate inverts under the sandbox.** Masks the repository does not
  ignore are reported as `??` lines, so "non-empty `git status --porcelain`
  means dirty" fails a genuinely clean tree, indistinguishably from a real
  failure.
- **Do not filter the mask names.** The set is version-dependent, and a filter
  hides real untracked files sharing those names. Run the status unsandboxed
  with no sandboxed command running alongside it, or scope the gate to tracked
  paths with `git status --porcelain --untracked-files=no` where untracked files
  are not the subject.
- **A slash command's `` !`cmd` `` expansion is a Bash call no hook sees.** It
  goes through the same sandbox decision as a typed call, so a `## Context`
  block can list masks, its own or a concurrent sibling's, and no annotation
  will say so. Never act on an injected listing: re-run `git status` unsandboxed
  first.

Mask shapes and placement, and the expansion path's mechanism:
[references/masks-and-gates.md](references/masks-and-gates.md).

## Recovering a merge a sandbox refusal killed

After a refused `git merge --ff-only` or `git checkout <branch>`, whatever its
exit status, run unsandboxed: compare `git rev-parse HEAD` with the target;
bring every path the command touched back to HEAD; re-run the command once only
if HEAD is not at the target. Never finish a checkout with
`git reset --hard <target>`: it moves the current branch instead. The procedure
and its evidence:
[references/refused-merge-recovery.md](references/refused-merge-recovery.md).

## Background tasks are invisible to a sandboxed `ps`

A sandboxed `ps` cannot see `run_in_background` tasks, so an empty one is not
evidence a job died: check with an unsandboxed `ps`, the task's output file and
the artifact it writes. Never restart the job in the foreground to check.
Evidence and waiting rules:
[references/background-tasks.md](references/background-tasks.md).
