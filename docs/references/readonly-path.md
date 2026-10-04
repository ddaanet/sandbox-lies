# readonly-path

The `readonly-path` detector: matcher, probe and outcomes, flag policy, Probe
facts, verdict text per outcome, live reproductions, corpus figure and the
decision. The catalogue entry is a stub in [detectors.md](detectors.md), whose
conventions — what a matcher, probe and flag are, the verdict-text format, the
corpus the figures come from — apply here unchanged. No entry here quotes a
diagnostic together with its follow-on sentence, so that this file stays quiet
under the detectors it specifies.

## readonly-path

Replaces `Harness-mounted config paths are busy/read-only`,
`Sibling worktree writes`, and cost 3 of `Leaving the sandbox` (a recipe's
`inter-device move failed`).

**Matcher.** A line that begins with a tool's own prefix — a run free of blanks,
backticks, pipes and colons, then a colon and a space, as `cp`, `mv`, `rm`,
`touch`, `/bin/bash` (then `line N`) and git's `error`, `fatal`, `warning` print
it — and ends in a colon, a space and the kernel's read-only-filesystem (EROFS)
or busy-device (EBUSY) message, trailing blanks allowed. Or Python's: a line
beginning with an exception name ending in `Error`, a colon and a space, errno
30 or 16 in brackets, the same message, a colon. The store quotes both mid-line.
Expected residual: a path not writable outside the sandbox either.

**Flag policy.** Silent when the flag is true.

**Probe.** Extract the path from the matching line, printed as `path=`;
`test -w` on it, or on its parent when it does not exist. The path is the first
single-quoted segment, straight or curly as a UTF-8 locale prints it, except
after `mv`'s `to`, which names the target. Unquoted, it is read in four fixed
forms only, each right after the tool's own prefix: bash's `line N: <path>:`,
dash's `N: cannot create <path>:`, git's
`error: could not lock config file <path>:` and `fatal: cannot mkdir <path>:`.
Any other unquoted shape is `nopath`. An unquoted path runs to the line's last
colon and space, since the kernel message after it holds none, so a path holding
blanks, `: ` or its form's own words is read whole. A relative path joins onto
the payload `cwd`. Residuals: a quoted path holding its own closing quote, which
the tool prints escaped, is cut at that quote or yields `nopath`; a curly-quoted
or unquoted path holding two straight quotes is read as what lies between them.
Git names the path in its partial-checkout errors from the worktree's top-level,
so from a subdirectory or under `git -C` the path is wrong, and one whose parent
is missing reads `readonly`, which carries no merge clause.

| outcome | condition |
|---|---|
| `writable` | writable outside the sandbox |
| `readonly` | not writable outside either |
| `nopath` | no path extracted |

The probe also takes the payload's `tool_input.command` as its third argument
and, under `writable` and `nopath`, prints the facts the verdict's acts depend
on. The command shapes the wording only; detection never reads it (D-1).

| key | printed when |
|---|---|
| `merge=1` | a git segment of the command runs `merge`, `pull`, `checkout`, `switch`, `rebase` or `cherry-pick`, after any global options; or `partial=1` is printed |
| `partial=1` | the text holds git's partial-checkout error, `unable to unlink old`, `unable to create file` or `cannot create directory at`, under any command |
| `target=<ref>` | with `merge=1`: the first word after a `merge`, `checkout` or `switch` subcommand, before any `--`, that resolves to a commit |
| `match=<file>` | with `target=`: one line per file modified against HEAD, staged or not, whose working-tree content equals the target's |
| `readfile=<path>` | every command in the call's pipelines and lists is a reader — `cat`, `head`, `tail`, `grep`, `sed` without in-place editing, `awk`, `cut`, `sort`, `uniq`, `wc`, `tr`, `less` — with no output redirection, and an argument has a command-output name: `*.log`, `*.output`, `*.out`, `*.err` |

The repository for `target=` and `match=` is the one holding the path's nearest
existing directory, else the payload `cwd`'s. Git reads run with optional locks
off, so the probe writes nothing (NFR-4). Word splitting is safe for `target=`,
since a ref name holds no blank; `readfile=` honours single and double quotes.
Residuals: `merge=1` read off the command alone does not show that the git
segment died, so a call whose merge or checkout succeeded before another
command's write was refused gets it too; its clause then rests on `match=`
lines, which a finished checkout leaves none of. A partial checkout whose text
lost git's error — cut by a `tail`, or sent to a file — and whose target does
not resolve gets no clause. `partial=1` does not check which git command printed
the error, so a `stash` or `restore` dying on the same error counts too. A file
whose name holds a newline is never a `match=` or a `readfile=`; a reader behind
a `cd`, or a reader or git behind a variable assignment, is not recognised. The
scan does not parse `$( )`, backticks, subshells, braces or `$'…'`, so their
contents read as words of the command around them; it stops at the end of a line
holding `<<`, and after 16384 characters, and neither cut command yields
`readfile=`. A `>` anywhere in a word counts as output redirection, as do
`sort -o` and `awk -i`. A candidate ref holding `@{`, `^{`, `:` or a leading `-`
is skipped. With an unborn HEAD, or past 1000 files modified against HEAD, no
`target=` is printed. A file matches byte for byte, before any clean filter, and
never as a symlink.

**Live reproduction (2026-09-26): `writable`.** Scratch repo under
`/tmp/claude/` with a linked worktree directly under `/tmp/`, outside the
sandbox's write allowlist, both made unsandboxed; CC 2.1.281, `/bin/sh` dash. A
sandboxed `sh -c 'touch <worktree>/<file>'` raised touch's read-only error
naming the file in straight quotes; a `touch` directly under `/tmp/` in the same
call raised the same error, so that call was sandboxed. `detect` on that text
named `readonly-path`, and `probe_readonly_path false <root>` run unsandboxed on
it printed `writable`, `path=<worktree>/<file>`. Neither file was written; the
worktree was removed unsandboxed.

**Live reproduction (2026-09-27): `partial=1`.** Same layout, CC 2.1.281, git
2.47.3: a sandboxed `merge --ff-only` or `checkout` of a branch adding a
directory died on git's `cannot create directory at` error, one also changing a
tracked file on `unable to unlink old` first; HEAD stayed put. Cut as
`fire-readonly-path-git-mkdir`.

**Verdicts.**

- `writable` — `<path>` is writable outside the sandbox, whose allowlist refused
  it. Then the tail below. · `read-only — sandbox allowlist, writable outside`
- `readonly` — `<path>` is not writable outside the sandbox either; this is not
  a sandbox effect. Unsandboxing will not help: write somewhere writable, or ask
  before changing its permissions. · `read-only — real`
- `nopath` — The sandbox's write allowlist most likely refused this write. Then
  the tail below. · `read-only — probably the sandbox, path not checked`

The tail is one act, the first of these whose fact the probe printed:

- `readfile=` — re-run the command that wrote `<readfile>`
- `path=` names a `.claude/settings.json` (`writable` only) — write
  `.claude/settings.json` through the `update-config` skill
- otherwise — re-run the whole call with `dangerouslyDisableSandbox: true`

The act stands alone as its own sentence, capitalised, unless a merge clause
leads into it, lowercase. With `merge=1`, the probe's facts select the clause:

- `match=` lines — The merge or checkout left files at the target with HEAD
  unmoved, blocking a re-run: restore `<a>`, `<b>` from HEAD — they match
  `<target>` —, then *act*. Five names at most, then `and N more`.
- no `target=`, and `partial=1` — The merge or checkout left the files it wrote
  with HEAD unmoved, blocking a re-run: restore them from HEAD, then *act*.
- `target=` and no `match=` — no clause: nothing sits at the target to restore.
- neither `target=` nor `partial=1` — no clause: the command shape alone does
  not show the git segment wrote anything. Of 195 hits on 2026-09-27, 3 were
  this case, each another write's refusal (`fire-readonly-path-git-config-busy`
  is one).

The read act covers the corpus's command-output reads below: the refusal in such
a file came from the call that wrote it, so re-running the read changes nothing.
The merge clause states the tree's state and the order of acts and removes
nothing: a fast-forward re-run over files already at the target is refused
(`tests/verdict-premises.bats`), and the untracked files the target added are
left to the skill's recovery procedure.

**Corpus.** 162 hits, 161 true, 1 the residual (`mkdir` of a path directly under
`/`, left by an empty variable). 99% on 2026-09-25; 11 hits this project's
traffic. True: sandbox refusals under `/tmp`, `~/.cache`, `~/.claude`, sibling
repositories, harness-mounted config and the masks, and four reads of a file
with a command-output name — a background task's `*.output`, a `*.log` —
carrying an earlier sandboxed call's refusal. Any such name (`*.out`, `*.err`
and the like too) is a legitimate flag; a `*.md` or other document carrying one
is material about sandbox effects, self-reference (D-10).

**Decision: ships.**
