# Leaving the sandbox: the two escapes and what they cost

**Per call:** `dangerouslyDisableSandbox: true` on the Bash tool. **Standing:**
`sandbox.excludedCommands` in `~/.claude/settings.json`
([excluded-commands.md](excluded-commands.md)), honoured in strict mode too —
where it is honoured at all, which CC 2.1.281 does not do.

## Strict mode blocks the per-call flag

With `/sandbox` set to *Strict sandbox mode*, `dangerouslyDisableSandbox` is
refused and git writes fail with the read-only-filesystem error on
`.git/index.lock`; the exclusions still apply where honoured (recorded by
2026-07-16, CC version not recorded). Ask the human partner to run the command
via `! git …` or to toggle the mode — do not retry the same sandboxed command.
Strict mode is a user setting: check rather than assume.

## The read-only-inspection default

Reaching for `dangerouslyDisableSandbox` to read local git state or a masked
path is a read-only inspection. Where the human partner has set it as a standing
default, it is not a per-case approval to seek: call it directly, without
pre-announcing or asking. Under an honoured `git:*`/`ls:*`/`find:*` baseline it
has little left to do, and it fires on a symptom rather than while composing: a
phantom dotfile in a listing, an empty `cat` of a `.claude/` path, a
`git status` that ran inside `( … )`, `$( … )`, `sh -c` or a recipe, or a
segment the matcher missed (a quoted argument, a double space, `/bin/ls`).
Mutating operations (`git commit`, `push`, `reset`, `checkout -- …`, anything
that writes) are not covered and follow normal confirmation rules.

## The observed `$TMPDIR` collapse

Re-confirmed 2026-09-14 on CC 2.1.266, the call's sandbox state not recorded: a
`cp … "$TMPDIR/checkpoint.py.bak"` died unable to create `/checkpoint.py.bak` in
a session whose earlier calls had a working `$TMPDIR`. The cases that pay for it
are a backup restored by a *later* call — a mutation check, a staged fixture —
where a restore path that silently resolves elsewhere lets the check report
success while the original is never put back.

## Cost: the classifier denies benign compounds unpredictably

Sandboxed commands are auto-allowed (`autoAllowBashIfSandboxed`) with no
classifier call. Leaving the sandbox by either escape moves the command *into*
classifier evaluation unless the read-only validator
([excluded-commands.md](excluded-commands.md)) clears it. Observed 2026-08-16
(CC version not recorded), after the exclusions were written:
`ls -a | wc -l; echo …`, `find … | wc -l; echo …` and `claude --version; echo …`
were each refused, while `ls -a; echo …`, `find …; echo …`, `git log …; echo …`
and a bare `claude --version` passed. No stable rule separates them — the pipe
is not it.

Mitigation is shape, not settings: keep an escaped command in its own call
rather than appending a compound to it. A classifier call is one model call over
cached context with no generation, cheaper than an agent turn, so batching
`git -C <dir> log …; git -C <dir> status` into one call still beats splitting
it.

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

`git:*` does not reach a git call inside a recipe — `just` is the top-level
segment. The classifier likewise judges an unsandboxed recipe by its top-level
command: an unsandboxed `just release minor` went through whole, its
cross-repository `git -C "$MARKETPLACE_DIR" push` included.
