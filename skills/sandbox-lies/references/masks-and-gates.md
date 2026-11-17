# Masks, cleanliness gates and the `!` expansion path

## The mask shapes

The sandbox hides deny-listed paths in the sandboxed call's working directory,
normally the project root — shell rc files, `.gitconfig`, `.mcp.json`, entries
under `.claude/` and the like — behind masks, which a listing or a `git status`
then shows as if they were files in the repository. Two shapes occur:

- `/dev/null` character devices bound over the path;
- since 2026-07-20 (CC 2.1.215), also **zero-byte read-only regular files**
  (mode `-r--r--r--`, size 0), a path that ought to be a directory getting a
  zero-byte file too.

The mask-free test of a call's sandbox state is a write only the sandbox
refuses, `touch /tmp/<name>`. `${TMPDIR-UNSET}` discriminates too: on CC 2.1.281
it is `/tmp/claude-<uid>` sandboxed and `/tmp` unsandboxed, and on CC 2.1.233 it
was unset.

That directory is not always the project root. Seen on CC 2.1.281: in the main
session the Bash tool's working directory persists between calls, so one `cd`
into a submodule left later sandboxed calls masking `.claude/` and `.mcp.json`
inside the submodule, and a sandboxed commit there then failed on them. A
subagent's working directory resets per call instead. A top-level `cd` anywhere
in a call persists, not only at its head; one inside `( … )` does not (probed
2026-09-27, CC 2.1.281). Give commands absolute paths or `git -C <dir>`;
otherwise use a subshell, `(cd <dir> && …)`, whose `cd` cannot persist, or end
the call with a `cd <root>` line. `git -C`, a git absolute-path argument, a `cd`
and a subshell each keep the call sandboxed under any `excludedCommands` entry;
run with `dangerouslyDisableSandbox`, `git -C`, a subshell and a `cd` beside git
each forfeit the read-only auto-allow and, absent an allow rule, cost a
classifier call
([excluded-commands.md](excluded-commands.md)).

This plugin annotates a listing or a status that shows them. What it cannot
annotate is code that consumes such output without an agent reading it.

A mask says nothing about the repository: it is not a file anyone created there,
and its presence or absence is not a finding about the tree. Never delete one,
commit one, or report one as a file or change in the repository.

## A mask that outlives its command

The masks exist while a sandboxed command runs, any one, this session's, a
subagent's or a concurrent session's, and are torn down when it completes, so a
reader that sees them has normally caught one mid-run. Masks still present with
nothing running are a leak. Observed on CC 2.1.278: the full set stood in an
idle tree across several turns and was gone after a Claude Code restart.

Trying to delete one looks like a real failure. Inside a sandboxed command the
mask is a mount point in that command's own namespace, so `rm` reports the
device as busy and `git clean -f` prints one removal warning per mask while
removing nothing. Asked to remove stray untracked files, read the tree with an
unsandboxed `git status` first and report that there is nothing to remove; if
masks show there with nothing running, restart Claude Code rather than delete.

## A porcelain gate reports DIRTY against a clean tree

A mask the repository does not ignore is reported as a `??` line whatever else
the call did, so any check whose rule is "non-empty `git status --porcelain`
means dirty" inverts under the sandbox; one it ignores shows only under
`--ignored`, as `!!`. edify's build step verifier did exactly this and failed a
step whose tree was genuinely clean; the failure is indistinguishable from a
real one in its output. An unsandboxed status is clean of masks only while no
sandboxed command runs alongside it, this session's or a parallel agent's: the
masks are visible from every process for as long as one does.

## A slash command's `## Context` block is a Bash call

The injection is `` !`cmd` `` expansion in the command body — the
`commit-commands` plugin's `/commit` carries a `git status` expansion — and
decompiling CC 2.1.233 shows it executed through the ordinary Bash tool call
with a bare `{command}`. The sandbox decision and the `excludedCommands` match
apply exactly as to a typed call, so an entry frees an expansion only when it
covers every command in it. Observed 2026-08-16: an excluded bare `git status`
expansion saw the real tree while an unmatched one saw the masks.

**No hook runs on that path.** Measured 2026-09-02 on CC 2.1.258: a `!` block
that demonstrably executed (its side-effect flag file was written) drew no
`PreToolUse` and no `PostToolUse` entry under `matcher: "*"`, while an ordinary
`Bash` call in the same run logged both; the wildcard rules out the block
running under some other tool name. The bundle shows why: the expansion executor
calls the shell tool's own `.call()` directly, bypassing the wrapper that
dispatches `PreToolUse` for model-issued tool calls, while the sandbox and
`excludedCommands` decision sits one layer lower in the shared runner and so
still applies. Several `` !` `` blocks in one body run concurrently.

So this plugin never annotates such a listing. Even a fully covered expansion —
a bare `git status` under a `git *` entry — can list the masks of a sandboxed
sibling block running alongside it, and nothing says which happened. Never act
on the injected listing: re-run `git status` unsandboxed first. A 2026-05-24
`/commit` context showed about 14 untracked dotfiles where the unsandboxed tree
had one build artefact.
