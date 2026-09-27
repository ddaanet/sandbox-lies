# `excludedCommands`: whole-call semantics

Decompiled from CC 2.1.233 and confirmed by probe, with `${TMPDIR-UNSET}` as the
discriminator: it read `/tmp/claude-1000` sandboxed and `UNSET` unsandboxed
then, and reads `/tmp` unsandboxed on CC 2.1.281.

**Not honoured at all on CC 2.1.281.** With `git:*` in user settings,
`git --version && touch /tmp/sbx-probe-git` failed with the read-only-filesystem
error, and the same `touch` with `dangerouslyDisableSandbox` succeeded
(2026-09-26); the call's `${TMPDIR-UNSET}` also read the sandboxed
`/tmp/claude-1000`. The sandbox configuration injected into that session listed
no `excludedCommands`. Everything below describes the mechanism where it is
honoured; re-probe with the `/tmp` write before relying on it.

## The baseline it was written for

The setup these observations were made under: `/sandbox` set to
*unsandboxed fallback* (not strict), auto mode on, and user-scope
`sandbox.excludedCommands: ["git:*", "find:*", "ls:*", "claude:*"]`. Where the
exclusion is honoured, every top-level `git`, `find`, `ls` and `claude` segment
runs outside the sandbox with no flag, so most sandbox effects are met only
where it does not reach: a command nested in `( … )`, `$( … )` or `sh -c`, a
recipe or script that runs git internally, or a machine without the entries.

An exclusion match silently sets `dangerouslyDisableSandbox` for a command
visible in the call's own text. It changes nothing about what that command sees
of *other* calls' sandboxes: their masks stay visible to it.

## Matching

- **Entries are permission-rule patterns, not plain strings.** `foo bar` is
  exact; `foo bar:*` is a prefix matching `foo bar` or `foo bar` + a space +
  anything; an unescaped `*` is a glob. A plain `"git status"` entry covers only
  the bare literal — 2.8% of real `git status` traffic across a 45-day
  transcript corpus, since `--short`, `--porcelain` and `git -C <dir> status`
  all miss it. Prefix entries anchor at the segment start, so `git status:*`
  cannot reach `git -C <dir> status` (31.6% of git-bearing calls); only `git:*`
  covers every shape.
- **Splitting** is a tree-sitter-bash parse, cut at `&&`, `||`, `|`, `;`, `&`
  and newline. Nesting is never descended into: `( … )`, `$( … )`, `sh -c '…'`
  and `if …; fi` are compared whole, so they never match. Nesting fails closed,
  and so does a parse failure: a call whose heredoc delimiter is never closed is
  one unmatched segment, so its `git status` ran sandboxed and listed the masks
  (2026-08-28). A heredoc body can never trigger a match (only the command word
  is compared), and cannot smuggle a write past the read-only validator (the
  capability comes from the command word, not the channel).
- **Comparison is on source text**, per segment. Leading `VAR=value` assignments
  and trailing redirections are outside the compared span, and wrapper commands
  are unwrapped — `timeout 5 git status` matches a `git status` entry, as do
  `time`, `nice`, `stdbuf`, `nohup`, `command`, `builtin`, `noglob`. `LD_*`,
  `DYLD_*` and `PATH=` assignments are deliberately not stripped. Double spaces,
  quoted arguments, `/bin/ls`, an extra argument, and pre-expansion `$VAR` all
  defeat the match.
- **One matching segment unsandboxes the entire call**, neighbours included, and
  the decision is static rather than reachability-aware:
  `false && git status; <payload>` frees the whole call while the decoy never
  runs. Nothing in the tool result or the transcript records that a call ran
  unsandboxed.
- **`` !`cmd` `` expansions in a slash command or skill body are matched too**,
  and `PreToolUse` hooks do not run on that path
  ([masks-and-gates.md](masks-and-gates.md)).
- **Settings reload live.** `excludedCommands`, `autoAllowBashIfSandboxed` and
  `permissions.deny` each took effect mid-session in both directions, with no
  restart, so a probe does not need a fresh session.

## Approval: what judges an unsandboxed command

An exclusion does not grant approval, but that rarely costs a classifier call.
The sandbox auto-allow shortcut is skipped precisely when the command is not
sandboxed, so deny and ask rules and then the rest of the permission pipeline
still evaluate it — a `Bash(sudo:*)` deny rule refused a call carrying an
excluded segment.

What catches it next is a **sandbox-independent read-only auto-allow** (decision
reason `Read-only command is allowed`), which sits ahead of the auto-mode
classifier and never consults sandbox state: `git log`, `git diff`, `git show`,
`ls -a` and `find` are allowed locally whether sandboxed or not, so unsandboxing
them is free. The classifier is reached only where that validator refuses. It
requires **every** segment to pass, and rejects:

- any subshell or `compound_statement` anywhere, any `&`, any unquoted `$VAR`;
- a `cd` in the same call as any git segment;
- the git global options `-C`, `-c`, `--git-dir`, `--work-tree`, `--exec-path`,
  `--config-env`, `--bare`, `--attr-source` and `--shallow-file`;
- any git segment when sandboxing is enabled globally and the working directory
  is not the session's original one.

So the cheap shape is a bare `git <subcommand>` from the original working
directory; `cd <dir> && git …`, `(cd <dir> && git …)` and `git -C <dir> …` each
forfeit it. Gating is otherwise equivalent to an agent-declared
`dangerouslyDisableSandbox`, minus the round-trip.

## Why `git:*` rather than a rewriting hook

The `unsandbox-git-status` plugin — a `PreToolUse` Bash hook that detected
`git status` and set `dangerouslyDisableSandbox` in place — is retired, removed
from the `ddaanet` marketplace and its repository archived. It paired
`updatedInput` with `permissionDecision: "allow"`, pre-approving anything
chained alongside the `git status` (confirmed live:
`true && git status --porcelain` ran). A hook that must rewrite returns
`updatedInput` alone; the mechanism is in the `plugin-craft` plugin's
`hook-authoring` skill.

The exclusion covers every git shape rather than a best-effort `git status`
subset, is honoured in strict mode, and does not settle the permission gate. The
one shape the hook caught and the exclusion misses is a git command nested in
`( … )`, `$( … )` or `sh -c`. The `cwd-safety` plugin used to manufacture that
shape by wrapping `cd <dir> && …` in a subshell, and now appends `cd <root>` as
a trailing line instead, so what remains is the genuine residue
(`echo "[$(git -C <dir> ls-files <path>)]"`) and git run inside recipes.
