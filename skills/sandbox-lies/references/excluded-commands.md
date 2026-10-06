# `excludedCommands`: an entry must cover every command in the call

CC's documented rule (settings reference, §`sandbox.excludedCommands`): an entry
applies to a call only when it covers every command in it. Any uncovered
command, or one of the shapes under [Matching](#matching), keeps the whole call
sandboxed.

## Observed on CC 2.1.289

On 2026-10-05, on Linux, with user-scope
`["git *", "find *", "ls *", "claude *", "just release *"]`, each probe a single
call with no `dangerouslyDisableSandbox`:

- a covered `find /tmp -maxdepth 0 -fprint /tmp/<name>` wrote its file outside
  the write allowlist: it ran unsandboxed;
- a bare covered `git status --porcelain` from the project root listed no masks:
  it ran unsandboxed;
- `true && git status --porcelain` listed 20 masks: the uncovered `true` kept it
  sandboxed;
- a covered `git config --file /tmp/<name> …` failed on the read-only file
  system: git with an absolute path argument stays sandboxed.

Re-probe with that bare covered `git status` from the project root. A listing
with no masks proves the call ran unsandboxed; a listing with masks proves
nothing on its own, since another call's sandbox may be showing them.

### Earlier probes that read "not honoured"

Each is confounded under the documented rule, so none shows exclusions ignored:

- CC 2.1.281, 2026-09-26, `git:*` in user settings:
  `git --version && touch /tmp/sbx-probe-git` failed with the
  read-only-filesystem error. The uncovered `touch` keeps the call sandboxed
  whether or not the entry is honoured. The sandbox configuration injected into
  that session listed no `excludedCommands`.
- CC 2.1.288, 2026-10-03, `git:*`: `git init -q /tmp/sl-exclprobe-288` ran
  sandboxed.
- CC 2.1.289, 2026-10-04, after a full CC restart with `"git *"`:
  `git init -q /tmp/sl-exclprobe-289` ran sandboxed the same way.

Both `git init` runs carry an absolute path argument, which keeps git sandboxed
under the documented rule. Whether the legacy `git:*` form was honoured on CC
2.1.288 is not settled.

## The baseline it was written for

The setup these observations were made under: `/sandbox` set to
*unsandboxed fallback* (not strict), auto mode on, and user-scope
`sandbox.excludedCommands` covering `git`, `find`, `ls` and `claude`, and
`just release *` at the CC 2.1.289 probes — written `git:*` and so on through CC
2.1.288, `git *` since. A call made of those commands alone runs outside the
sandbox with no flag. Any other command beside them, a shape under
[Matching](#matching), or a command nested in `( … )`, `$( … )`, `sh -c` or a
recipe keeps it sandboxed, so most sandbox effects are still met in ordinary
compound calls, and on a machine without the entries.

An exclusion match runs the call as if it carried `dangerouslyDisableSandbox`;
the flag in the hook payload stays unset. It changes nothing about what that
call sees of *other* calls' sandboxes: their masks stay visible to it.

## Matching

The splitting and comparison detail below was decompiled from CC 2.1.233 and
predates the documented rule; where they differ, the rule and the CC 2.1.289
observations above govern.

- **Entries are permission-rule patterns, not plain strings.** `foo bar` is
  exact; `foo bar *` is a prefix, and `foo bar:*` its legacy form. A plain
  `"git status"` entry covers only the bare literal — 2.8% of real `git status`
  traffic across a 45-day transcript corpus, since `--short` and `--porcelain`
  miss it. Prefix entries anchor at the command start, and `git -C <dir> …`
  (31.6% of git-bearing calls) stays sandboxed under any entry, so `git *` is
  the entry that covers every git shape an entry can cover.
- **What keeps a covered call sandboxed**, per the settings reference: a `sudo`,
  `eval` or `xargs` head; a `cd`, `pushd` or `popd` anywhere; a command
  substitution, a subshell, or an `if` or `for` block; a redirection other than
  a descriptor duplication; a command name from a variable; and git with an
  absolute, `~`-led or `..`-bearing path argument — `git init`, `git clone`,
  `git worktree add`, `git worktree move` and `git bundle create`, among others.
  The sandboxing doc adds `git -C`. Observed on CC 2.1.289: `git config --file`
  with an absolute path too.
- **Seen beyond the documented list**, on CC 2.1.289 in a separate session and
  not re-probed: `2>&1`, although a descriptor duplication is documented as
  fine; a glob argument; an unquoted `$HOME`. Each kept an otherwise covered
  call sandboxed. The same session saw a covered call with a quoted argument, a
  `\.` escape or a trailing `# comment` run unsandboxed.
- **Read from the CC 2.1.289 bundle** in that session, not observed: a
  `VAR=value` prefix outside a short allowlist (`LANG`, `TZ`, `NODE_ENV`, `CI`,
  `NO_COLOR` and a few more), and the value-taking git options `-C`, `-c`,
  `--git-dir` and `--work-tree` before the subcommand (boolean ones such as
  `--no-pager` still match), each keep a covered call sandboxed.
- **Splitting** is a tree-sitter-bash parse, cut at `&&`, `||`, `|`, `;`, `&`
  and newline. Nesting is never descended into: `( … )`, `$( … )`, `sh -c '…'`
  and `if …; fi` are compared whole, so they never match. Nesting fails closed,
  and so does a parse failure: a call whose heredoc delimiter is never closed is
  one unmatched segment, so its `git status` ran sandboxed and listed the masks
  (2026-08-28). A heredoc body can never trigger a match (only the command word
  is compared), and cannot smuggle a write past the read-only validator (the
  capability comes from the command word, not the channel).
- **Comparison is on source text**, per command. Wrapper commands are unwrapped
  — `timeout 5 git status` matches a `git status` entry, as do `time`, `nice`,
  `stdbuf`, `nohup`, `command`, `builtin`, `noglob`. On CC 2.1.233 leading
  `VAR=value` assignments were stripped before comparison, except `LD_*`,
  `DYLD_*` and `PATH=`; see the CC 2.1.289 report above for what a `VAR=` prefix
  did there. On CC 2.1.233, double spaces, quoted arguments, `/bin/ls`, an extra
  argument and pre-expansion `$VAR` all defeated the match; on CC 2.1.289 a
  covered call with a quoted argument ran unsandboxed (the separate-session
  report above).
- **Nothing records the outcome.** Nothing in the tool result or the transcript
  records that a call ran unsandboxed.
- **`` !`cmd` `` expansions in a slash command or skill body are matched too**,
  and `PreToolUse` hooks do not run on that path
  ([masks-and-gates.md](masks-and-gates.md)).
- **Settings reload live.** `excludedCommands`, `autoAllowBashIfSandboxed` and
  `permissions.deny` each took effect mid-session in both directions, with no
  restart, so a probe does not need a fresh session. Observed before the CC
  2.1.289 probes; the version was not recorded.

## Approval: what judges an unsandboxed command

An exclusion does not grant approval, but that rarely costs a classifier call.
The sandbox auto-allow shortcut is skipped precisely when the command is not
sandboxed, so deny and ask rules and then the rest of the permission pipeline
still evaluate it — a `Bash(sudo:*)` deny rule refused a call carrying an
excluded segment (observed before the every-command rule; version not recorded).

What catches it next is a **sandbox-independent read-only auto-allow** (decision
reason `Read-only command is allowed`), which sits ahead of the auto-mode
classifier and never consults sandbox state: `git log`, `git diff`, `git show`,
`ls -a` and `find` are allowed locally whether sandboxed or not, so unsandboxing
them is free. Where the session has server-side review, read-only commands wait
for it too ([escapes-and-costs.md](escapes-and-costs.md)). The classifier is
reached only where that validator refuses. It requires **every** segment to
pass, and rejects:

- any subshell or `compound_statement` anywhere, any `&`, any unquoted `$VAR`;
- a `cd` in the same call as any git segment;
- the git global options `-C`, `-c`, `--git-dir`, `--work-tree`, `--exec-path`,
  `--config-env`, `--bare`, `--attr-source` and `--shallow-file`;
- any git segment when sandboxing is enabled globally and the working directory
  is not the session's original one.

So the cheap shape is a bare `git <subcommand>` from the original working
directory; `cd <dir> && git …`, `(cd <dir> && git …)` and `git -C <dir> …` each
forfeit it, as each forfeits an exclusion. Gating is otherwise equivalent to an
agent-declared `dangerouslyDisableSandbox`, minus the round-trip.

## Why `git *` rather than a rewriting hook

The `unsandbox-git-status` plugin — a `PreToolUse` Bash hook that detected
`git status` and set `dangerouslyDisableSandbox` in place — is retired, removed
from the `ddaanet` marketplace and its repository archived. It paired
`updatedInput` with `permissionDecision: "allow"`, pre-approving anything
chained alongside the `git status` (confirmed live:
`true && git status --porcelain` ran). A hook that must rewrite returns
`updatedInput` alone; the mechanism is in the `plugin-craft` plugin's
`hook-authoring` skill.

The exclusion covers every git subcommand rather than a best-effort `git status`
subset, is honoured in strict mode, and does not settle the permission gate. It
reaches less of the call than the hook did: the hook freed any call holding a
`git status`, while the exclusion frees only a call whose every command it
covers. A git beside an uncovered command, after a `cd`, in `( … )`, `$( … )` or
`sh -c`, run with `-C`, given an absolute path argument, or run inside a recipe
stays sandboxed. The `cwd-safety` plugin used to wrap `cd <dir> && …` in a
subshell and now appends `cd <root>` as a trailing line instead; under the
documented rule both shapes keep the call sandboxed.
