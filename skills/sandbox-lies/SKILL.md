---
name: sandbox-lies
description: "What the Claude Code command sandbox does to Bash calls that no tool result reveals: whether a call ran sandboxed, what `excludedCommands` and `dangerouslyDisableSandbox` cost, why `$TMPDIR` does not survive a call, and where masks land. Use when writing a `sandbox.excludedCommands` entry, a recipe or script that must run unsandboxed, a cleanliness gate over `git status`, a `cd` into a submodule or subdirectory, a scratch path a later command or subagent reads, a `claude -p` run for a `SessionStart` hook's side effect, or a multi-turn `claude --resume` flow; when acting on a slash command's `` !`cmd` `` context block or recovering a merge or checkout a sandbox write refusal hit, even one that exited 0; and when reading `ps` for a background task."
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
  call sandboxed. Before relying on an exclusion, re-probe with
  `git status --porcelain --ignored` alone in its call: without `--ignored`, a
  sandboxed listing leaves out every mask name the repository ignores. The
  probes, and why earlier "not honoured" ones prove nothing:
  [references/excluded-commands.md](references/excluded-commands.md).
- **A visible mask proves nothing about the call that saw it.** Mask paths are
  visible from every process while any sandboxed command runs, this session's or
  a parallel agent's. The evidence runs one way: no mask in a listing of the
  call's own working directory, ignored names included, proves the call ran
  unsandboxed.
- **The mask-free test is a write only the sandbox refuses.**
  `touch /tmp/<name>` fails with the read-only-filesystem error only inside the
  sandbox. `${TMPDIR-UNSET}` also discriminates: `/tmp/claude-<uid>` sandboxed,
  `/tmp` unsandboxed, unset on older versions
  ([references/masks-and-gates.md](references/masks-and-gates.md)).
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
  documented as fine, but was seen to keep a call sandboxed), or a command name
  from a variable. Nested commands never match: `sh -c '…'` and a git inside a
  recipe or script.
- Git stays sandboxed under any entry with `-C <dir>`, and with an absolute,
  `~`-led or `..`-bearing path argument (`git init`, `git clone`,
  `git worktree add`, among others).
- It does not grant approval: the rest of the permission pipeline still judges
  the command. A narrow allow rule covering the command clears it before the
  classifier. So does the read-only validator, for a bare read-only command from
  the original working directory, except where the session has server-side
  review.

The full list of forfeiting shapes, wrapper unwrapping, the read-only
validator's refusals and the rewriting-hook alternative:
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

Masks sit under the sandboxed call's working directory, and in the main session
a top-level `cd` persists between calls, so one `cd` into a submodule leaves
every later sandboxed call masking inside it. In order of preference:

- Give a command absolute paths; give git `-C <dir>`.
- Otherwise use a subshell, `(cd <dir> && …)`, whose `cd` cannot persist.
- Or end the call with a `cd <root>` line.

`git -C`, a git absolute-path argument, a `cd` and a subshell each keep the call
sandboxed under any `excludedCommands` entry. Run with
`dangerouslyDisableSandbox`, `git -C`, a subshell and a `cd` beside git each
cost a classifier call, absent an allow rule:
[references/excluded-commands.md](references/excluded-commands.md).

## Writing a recipe or script that must run unsandboxed

- **Run it entirely unsandboxed.** An environment variable passing through the
  sandbox does not make the path it names writable. An exclusion never reaches a
  `git` or `claude` inside the recipe: the top-level segment is the recipe
  runner.
- **A multi-turn `claude --resume` flow must run unsandboxed.** A sandboxed
  `claude --print` turn never persists: a new session cannot be resumed, and a
  turn on a persisted one answers but is dropped.
- **A sandboxed `claude -p` skips every `SessionStart` hook** of every plugin,
  silently. Unsandbox the whole call whenever its point is a hook's side effect.

Why the recipe runs whole, the release half-landing, the eval-harness signatures
and the `SessionStart` evidence:
[references/recipes-and-claude.md](references/recipes-and-claude.md).

## A scratch path that must survive the call

`$TMPDIR` is set per call by the harness and is not stable across calls. Treat
every use as scoped to the single command that expands it. For a backup a
*later* call restores, and for any path written into a subagent directive,
hardcode the literal scratch path (`/tmp/claude/<job>/…`, created with
`mkdir -p`), since a subagent shell inherits neither the environment nor the
working directory.

Why a restore path that resolves elsewhere is the expensive case, and the
observed collapse:
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

## Recovering a merge or checkout a sandbox refusal hit

After a refused `git merge --ff-only` or `git checkout <branch>`, even at exit
0, run `sandbox-lies-recover checkout <branch>` (or `merge <commit-ish>`)
unsandboxed without `--apply`; read the plan, then run it with `--apply`. Never
finish a checkout with `git reset --hard <target>`. The procedure and its
evidence:
[references/refused-merge-recovery.md](references/refused-merge-recovery.md).

## Background tasks are invisible to a sandboxed `ps`

A sandboxed `ps` cannot see `run_in_background` tasks, so an empty one is not
evidence a job died: check with an unsandboxed `ps`, the task's output file and
the artifact it writes. Never restart the job in the foreground to check.
Evidence and waiting rules:
[references/background-tasks.md](references/background-tasks.md).
