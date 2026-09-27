# `claude` inside the sandbox: resumed flows and `SessionStart`

Two effects of running `claude` sandboxed leave the visible reply intact. Both
bite hardest inside a recipe or script, where a `claude:*` exclusion never
reaches: the top-level segment is the recipe runner.

## Multi-turn `claude` flows must run unsandboxed

A sandboxed `claude --print` turn never persists its transcript —
`~/.claude/projects` is read-only inside the sandbox — so resuming it by id
fails (CC version not recorded). The Agent SDK's `query()` resumes the same way.

Any two-turn (or N-turn) flow relying on `--resume` must therefore run
**unsandboxed**: `dangerouslyDisableSandbox`, the `claude:*` exclusion for a
top-level call where honoured, or the human partner's own shell. A single-turn
connectivity **probe cannot detect this** — it never resumes, so it passes
sandboxed while the real flow cannot. gitlore's eval runner documents this in
its header and beside its probe. gitlore keeps its memory-message IPC file in
the parent worktree rather than under `.git/`, where the sandbox masks some
paths: the project root's `.git/config.lock` showed as a character device on
2026-09-25 (CC 2.1.281), while sandboxed commits in a scratch repository
succeeded.

**An eval harness run from a release recipe inherits this.** The `plugin-dev`
toolkit's `just release` depends on the repository's own `just prerelease`;
gitlore's runs `just evals`, which is exactly such a flow, so there both must
run unsandboxed. Sandboxed, it fails at `pass^5` in a way that looks like it
indicts the scenarios or the code, and does not: every run of an affected
scenario fails identically, 0/5 rather than flaky. Two signatures name the
cause:

- every two-turn scenario reports that no conversation was found for the session
  ID and that turn 2 yielded no result;
- a scenario whose assertion reads the session transcript reports that none was
  captured.

A third tell is upstream of the evals and visible on every trial: direnv failing
to open a file on a read-only file system during the install step. Diagnose from
these before suspecting a scenario — and note that piping the gate into `tail`
reports `tail`'s exit status (without `pipefail`), so a failing run looks like
exit 0.

## A sandboxed `claude -p` silently drops every `SessionStart` hook

A `claude -p <prompt>` spawned from inside the command sandbox needs to `mkdir`
a per-hook scratch directory under `~/.claude/session-env/<session-id>/` before
running each `SessionStart` hook, and that path sits outside the sandbox's write
allowlist. Every registered `SessionStart` hook across every plugin — not just
the one being chased — then fails with a read-only-filesystem `mkdir` error on
that directory. It surfaces only in the debug log
(`-d hooks --debug-file <path>`); the turn itself completes and returns its
normal reply, so nothing in the visible output signals that every `SessionStart`
side effect was skipped.

Symptom: a fix that depends on a `SessionStart` hook's side effect appears to do
nothing even after the documented remedy. Confirmed 2026-08-11 (CC version not
recorded): gitlore's `git config gitlore.hooksDir`, repointed to the current
plugin version on every `SessionStart`, stayed pinned at the old version through
two sandboxed `claude -p ping` calls in the target repository — the standard
"start a session there" remedy — and only updated once retried with
`dangerouslyDisableSandbox: true`.

A `claude -p` inside a recipe or a script needs the whole call unsandboxed
whenever its *point* is a hook's side effect. A sandboxed one is fine only when
the model's textual reply is all that is needed. That `SessionStart` fires under
`--print` at all was established unsandboxed (the `plugin-craft` plugin's
`hook-authoring` skill); this is the sandbox-specific caveat on top of it.
