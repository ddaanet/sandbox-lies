# Leaving the sandbox: the two escapes and what they cost

**Per call:** `dangerouslyDisableSandbox: true` on the Bash tool. **Standing:**
`sandbox.excludedCommands` in `~/.claude/settings.json`, for a call whose every
command an entry covers ([excluded-commands.md](excluded-commands.md)), honoured
in strict mode too, bar a project-scope entry under managed or `--settings`
strict mode.

## Strict mode ignores the per-call flag

Strict mode is `sandbox.allowUnsandboxedCommands: false`, shown in the
`/sandbox` Overrides tab as *Strict sandbox mode*. Under it, Claude Code ignores
`dangerouslyDisableSandbox`: the call is not refused, it runs sandboxed, so what
the sandbox permits still happens and git writes fail with the
read-only-filesystem error on `.git/index.lock` (recorded by 2026-07-16, CC
version not recorded). Commands stay sandboxed unless they match an
`excludedCommands` entry, so a fully covered call still runs unsandboxed. Ask
the human partner to run the command via `! git …` or to toggle the mode — do
not retry the same sandboxed command. Strict mode is a user setting, or a
managed or `--settings` one, which makes the sandbox admin-required: Claude Code
then ignores the repository's settings that loosen it, `excludedCommands`
entries included. Check the key rather than assume.

A `!` command does not always leave the sandbox under strict mode. The
sandboxing doc (§Turn off the retry with strict sandbox mode) names two cases
where it runs sandboxed too: a background session, and a Linux session with
`CLAUDE_CODE_SUBPROCESS_ENV_SCRUB` set. There, ask for the mode change rather
than a `!` command.

## The read-only-inspection default

Reaching for `dangerouslyDisableSandbox` to read local git state or a masked
path is a read-only inspection. Where the human partner has set it as a standing
default, it is not a per-case approval to seek: call it directly, without
pre-announcing or asking. A `git *`/`ls *`/`find *` baseline frees only a call
made of covered commands alone, so the default still has work, and it fires on a
symptom rather than while composing: a phantom dotfile in a listing, an empty
`cat` of a `.claude/` path, a `git status` that ran beside an uncovered command,
with `-C` or an absolute path argument, after a `cd`, inside `( … )`, `$( … )`,
`sh -c` or a recipe, or a command the matcher missed (a glob argument, `2>&1`, a
double space, `/bin/ls`). Mutating operations (`git commit`, `push`, `reset`,
`checkout -- …`, anything that writes) are not covered and follow normal
confirmation rules.

## The observed `$TMPDIR` collapse

A subagent shell inherits neither the environment nor the working directory, so
a `$TMPDIR` in a handed-over command resolves to whatever the receiving call's
`$TMPDIR` is.

Re-confirmed 2026-09-14 on CC 2.1.266, the call's sandbox state not recorded: a
`cp … "$TMPDIR/checkpoint.py.bak"` died unable to create `/checkpoint.py.bak` in
a session whose earlier calls had a working `$TMPDIR`. The cases that pay for it
are a backup restored by a *later* call — a mutation check, a staged fixture —
where a restore path that silently resolves elsewhere lets the check report
success while the original is never put back.

## Cost: the classifier denies benign compounds unpredictably

Sandboxed commands are auto-allowed (`autoAllowBashIfSandboxed`) with no
classifier call, except where the sandboxing doc lists otherwise: in plan mode;
for an auto-mode command carrying per-command allowed domains; and in auto mode
where the session has server-side classifier review of sandboxed commands. The
permission-modes doc's decision order puts read-only commands behind that
server-side review too, where the session has it. Leaving the sandbox by either
escape moves the command *into* classifier evaluation unless a narrow allow rule
covering it or the read-only validator
([excluded-commands.md](excluded-commands.md)) clears it. Observed 2026-08-16
(CC version not recorded; how each call left the sandbox, by flag or by
exclusion, was not recorded): `ls -a | wc -l; echo …`, `find … | wc -l; echo …`
and `claude --version; echo …` were each refused, while `ls -a; echo …`,
`find …; echo …`, `git log …; echo …` and a bare `claude --version` passed. No
stable rule separates them — the pipe is not it.

The documented mitigation is an allow rule: per the sandboxing doc, a command an
allow rule covers gets no prompt when it runs outside the sandbox, and a
matching allow rule also approves the unsandboxed retry of a sandboxed failure.
Auto mode drops broad allow rules on entry (`Bash(*)`, wildcarded interpreters)
and sends a command carrying per-command allowed domains to the classifier
whatever rule matches (permission-modes doc). Allow rules are the human
partner's permission settings, so propose a narrow one for a command escaped
routinely rather than writing it. Without one, mitigation is shape: keep an
escaped command in its own call rather than appending a compound to it, even
where batching would save a call. A classifier call is a model call that
generates a verdict; a denied compound costs that call and a reshaped retry
besides.

The classifier does let through the unsandboxed retry of a write the user's own
prompt asked for (CC version not recorded). Routing around a sandbox write
refusal with a tool not under the command sandbox therefore buys nothing and
loses the shell.

## Cost: a recipe that must run unsandboxed must run entirely so

`.envrc` variables pass through the sandbox (`MARKETPLACE_DIR`, `DIRENV_*` —
direnv runs in the launching shell), but the variable arriving does not make the
path it names writable. A sandboxed `just release` gets through the bump,
commit, tag, `git push` and `gh release create`, then dies on the marketplace
step, whose `mv` of a `mktemp` file onto
`$MARKETPLACE_DIR/.claude-plugin/marketplace.json` the sandbox refuses. Every
step before it is irreversible, so the plugin is left tagged and published
against a stale marketplace entry (confirmed 2026-07-30, gitlore 0.4.4; CC
version not recorded). `just resume-release` (plugin-dev 0.5.0 and later)
recovers a half-landed release, but only unsandboxed: it runs that `mv`
unconditionally, before comparing local and remote heads.

A `git *` entry does not reach a git call inside a recipe: the call's own
command is `just`, which only an entry covering the recipe, such as
`just release *`, frees. The classifier likewise judges an unsandboxed recipe by
its top-level command: an unsandboxed `just release minor` went through whole,
its cross-repository `git -C "$MARKETPLACE_DIR" push` included.
