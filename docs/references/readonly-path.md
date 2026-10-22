# readonly-path

The `readonly-path` detector: matcher, probe and outcomes, flag policy, Probe
facts, how those facts select the verdict, live reproductions, corpus figure and
the decision. What it says, outcome by outcome, is in the manual's
[Detectors](../../manual/detectors.md). The catalogue entry is a stub in
[detectors.md](detectors.md), whose conventions — what a matcher, probe and flag
are, the verdict-text format, the corpus the figures come from — apply here
unchanged. No entry here quotes a diagnostic together with its follow-on
sentence, so that this file stays quiet under the detectors it specifies.

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

**Probe.** Extract the path from the matching line, printed as `path=` in
`printf %q` form (pinned to the `C` locale, so a non-ASCII byte is octal);
`test -w` on it, or on its parent when it does not exist. The printed value is
the wire form, and it takes one of two shapes. The backslash form puts a
backslash before each blank or shell-special byte (`/tmp/a\ b`), and none before
a plain path. The `$'…'` form wraps the whole path in `$'` and `'` and spells
each control or non-ASCII byte as an escape (`\n`, `\001`, `\303`); it is
printed when the path holds such a byte. The path is the first single-quoted
segment, straight or curly as a UTF-8 locale prints it, except in `mv`'s
inter-device form, whose path after `to` names the target. Elsewhere a `to`
changes nothing: `mv`'s other two-path messages give the first quoted path, the
source. Unquoted, it is read in four fixed forms only, each right after the
tool's own prefix: bash's `line N: <path>:`, dash's `N: cannot create <path>:`,
git's `error: could not lock config file <path>:` and
`fatal: cannot mkdir <path>:`. Any other unquoted shape is `nopath`. An unquoted
path runs to the line's last colon and space, since the kernel message after it
holds none, so a path holding blanks, `: ` or its form's own words is read
whole. A relative path joins onto the payload `cwd`, except for git's
partial-checkout refusals, which name the path from the worktree's top-level.
Only when the matching line itself is a partial-checkout refusal, the path joins
onto the worktree top: the nearest ancestor of `cwd`, itself included, holding a
`.git` entry, a file (linked worktree) or a directory. With no such ancestor it
joins onto `cwd`; another partial-checkout line elsewhere in the text moves
nothing. Residuals: a quoted path holding its own closing quote, which the tool
prints escaped, is cut at that quote or yields `nopath`; a curly-quoted or
unquoted path holding two straight quotes is read as what lies between them;
under `git -C` a relative path names the `-C` directory's tree, not the `cwd`'s,
so it is wrong, and one whose parent is missing reads `readonly`, which carries
no merge clause.

Five `nopath` shapes stay unextracted; together they are 11 of the 195 hits of
the 2026-09-27 dogfood: `tee`'s refusal of a file under `/tmp`; `sed`'s
temporary file in a relative directory; git's refusal to write `.git/config`,
which is busy rather than read-only; a removal warning on a dotfile; and `cp`
with an empty operand, which names no path at all. In every recorded case a path
would not change the act: each extractable path is writable outside the sandbox,
so `writable` would give the same re-run `nopath` gives, and none names
`.claude/settings.json`. A removal refused on a leaked phantom mask gets that
re-run too, and the leak makes it futile, since the mask outlives its command
and a restart clears it. A detector for that symptom would need a corpus replay
under D-15.

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
| `partial=1` | a line of the text opens with git's partial-checkout message, its `error: ` or `fatal: ` prefix included, or holds it after a carriage return (git's own progress fragment), for `unable to unlink old`, `unable to create file` or `cannot create directory at`, under any command |
| `target=<ref>` | with `merge=1`: the first word after a `merge`, `checkout` or `switch` subcommand, before any `--`, that resolves to a commit |
| `match=<repo>/<file>` | with `target=`: one line per file modified against HEAD, staged or not, whose working-tree content equals the target's, named by absolute path — the repository root, trailing slashes stripped, then the file's name within it |
| `readfile=<path>` | every command in the call's pipelines and lists is a reader — `cat`, `head`, `tail`, `grep`, `sed` without in-place editing, `awk`, `cut`, `sort`, `uniq` without a second operand, `wc`, `tr`, `less` — with no output redirection, and an input-file operand or `<` target has a command-output name: `*.log`, `*.output`, `*.out`, `*.err`; the first such. Never an input operand: a word opening with `-`; the first operand of `grep`, `sed` or `awk`, the pattern or program, unless an `-e` or `-f` came earlier in the segment; the word after a separate `-e` or `-f` |

The repository for `target=` and `match=` is the one holding the path's nearest
existing directory, else the payload `cwd`'s. Git reads run with optional locks
off, so the probe writes nothing (NFR-4). Word splitting is safe for `target=`,
since a ref name holds no blank; `readfile=` honours single and double quotes. A
`readfile=` candidate holding `*`, `?`, `[`, `{` or `$` is a glob, a brace
expansion or a `$` expansion, not a name the command wrote, and is passed over
for the next one; in a word holding `<`, only the name after the last `<` is
tested. So `grep pat *.log x.err` gives `x.err`, `cat $OUT.log` and
`cat {a,b}.log` give no line, and `grep 'err.*'<x.log` gives `x.log`. Residuals:
`merge=1` read off the command alone does not show that the git segment died, so
a call whose merge or checkout succeeded before another command's write was
refused gets it too; its clause then rests on `match=` lines, which a finished
checkout leaves none of. A partial checkout whose text lost git's error — cut by
a `tail`, or sent to a file — and whose target does not resolve gets no clause.
`partial=1` does not check which git command printed the error, so a `stash` or
`restore` dying on the same error counts too. A git partial-checkout line that
another program prefixed or indented (a wrapper's own prefix) does not count;
git's own progress fragment before the message, ended by a carriage return,
does. A file whose name holds a newline is never a `match=` or a `readfile=`,
and a repository root holding one gives no `target=` or `match=` at all: either
would split a `match=` line and forge the key line after it. A repository at `/`
gives `match=//<file>`. A reader behind a `cd`, or a reader or git behind a
variable assignment, is not recognised. The scan does not parse `$( )`,
backticks, subshells, braces or `$'…'`, so their contents read as words of the
command around them; it stops at the end of a line holding `<<`, and after 16384
characters, and neither cut command yields `readfile=`. A `>` anywhere in a word
counts as output redirection, quoted or not, except a descriptor duplication
(`2>&1`, `>&2`); so do `sort -o` and `awk -i`. A candidate ref holding `@{`,
`^{`, `:` or a leading `-` is skipped. With an unborn HEAD, or past 1000 files
modified against HEAD, no `target=` is printed. A file matches byte for byte,
before any clean filter, and never as a symlink.

The `readfile=` operand rule leaves these residuals, each shown by what the
probe prints:

- Other options' separate arguments (`-n 5`, `-d ,`) read as operands. A
  log-named one is the candidate (`sort -T t.log in.txt` gives `t.log`); under
  `grep`, `sed` or `awk` one takes the pattern role, so the pattern is taken as
  input (`grep -m 5 x.log y.out` gives `x.log`); under `uniq` one counts as an
  operand, so `uniq -f 1 in.log` reads as a writer and gives no line.
- Clustered short (`-ne`, `-nf`) and long (`--regexp=`, `--expression=`,
  `--file=`) forms of the `-e`/`-f` family are not recognised. Glued, the
  pattern role stays open and takes the input (`grep -nepat x.log` and
  `grep --regexp=pat x.log` give no line); a separate clustered form after an
  earlier `-e` leaves its argument as input (`grep -e a -ve x.log y.out` gives
  `x.log`).
- sed's `w` command and the `s///w` flag write a file but are not counted as
  writers: `sed 's/a/b/w out.log' in.log` gives `in.log`.
- A descriptor duplication such as `2>&1` standing in the pattern slot or an
  `-e`/`-f` argument slot is taken as that operand, so the word after it is read
  as input: `grep 2>&1 x.log y.out` gives `x.log`, and
  `grep -e 2>&1 pat.log x.log` gives `pat.log`.
- `--` is honoured only in `uniq`'s operand count. A file named `-x.log` after
  it is never a candidate (`cat -- -x.log` gives no line), and a pattern opening
  with `-` after it is passed over as an option, so `grep -- -x.log y.out` gives
  no line.
- A `<` anywhere in a word reads as an input redirection, quoted or not:
  `grep '<div' y.out` gives no line, and `cat 'a<x.log'` gives `x.log`. A
  here-string's word is a candidate too: `grep pat <<<x.log` gives `x.log`.
- In `uniq`, a lone `-` glued to a redirection is skipped as an option:
  `uniq -<in.log out.log` writes `out.log` and gives `in.log`.
- The glob and expansion skip tests the word with its quotes already removed, so
  a quoted literal naming a real file is skipped too: `grep -l pat '*.log'`
  gives no line, the safe side.
- A backtick substitution is not parsed, so it is not skipped:
  ``cat `echo a`.log`` gives the backtick word as `readfile=`, the same
  misdirection the skip withholds for a glob.

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

**Verdicts.** In the manual,
[readonly-path](../../manual/detectors.md#readonly-path): one paragraph per
outcome, `writable` and `nopath` followed by a tail act, `readonly` by none.

`<path>` is the decoded path, shown raw: a blank or a UTF-8 byte reads as the
path holds it. When it holds a control byte (`\001` to `\037`, `\177`) the wire
form is shown instead, since a raw newline would split the verdict's paragraph
from its human line. A `path=` value that is neither the backslash form nor a
well-formed `$'…'` form reads as no path: the verdict says "The path". The
decoder never evaluates the value.

The tail is one act, the first of these whose fact the probe printed:

- `readfile=` — re-run the command that wrote `<readfile>`
- `path=` names a `.claude/settings.json` (`writable` only) — write
  `.claude/settings.json` through the `update-config` skill
- otherwise — re-run the whole call with `dangerouslyDisableSandbox: true`

The act stands alone as its own sentence, capitalised, unless a merge clause
leads into it, lowercase. With `merge=1`, the probe's facts select the clause:

- `match=` lines — the clause names the files at the target, to be restored from
  HEAD before the act: five names at most, then `and N more`. Each name is its
  `match=` line's absolute path, so the clause names the same files from any
  working directory; a backtick in a name closes its code span early, bytes
  intact.
- no `target=`, and `partial=1` — the clause names no file: it says to restore
  the files the command wrote from HEAD before the act.
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
