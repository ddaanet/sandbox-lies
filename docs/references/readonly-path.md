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
30 or 16 in brackets, the same message, a colon. Or, as a third alternative, one
of five git refusals that end in the operation-not-permitted message, each a
whole line from its start, trailing blanks allowed: `error:` failing to create a
file, `error:` failing to unlink an old file and `warning:` failing to unlink a
file (both with the path single-quoted), `error:` failing to write the config
file, and `fatal:` failing to create an index lock (the path single-quoted and
ending in `/.git/index.lock`). That message is taken from no other line, so
another tool's refusal ending in it stays quiet, as does a git line outside the
five. The evidence for this alternative is macOS transcript records only; no
live reproduction exists for it. The store quotes the messages mid-line.
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
source. Unquoted, it is read in five fixed forms only, each right after the
tool's own prefix: bash's `line N: <path>:`, dash's `N: cannot create <path>:`,
git's `error: could not lock config file <path>:`, `fatal: cannot mkdir <path>:`
and `error: unable to create file <path>:`. Any other unquoted shape is
`nopath`. An unquoted path runs to the line's last colon and space, since the
kernel message after it holds none, so a path holding blanks, `: ` or its form's
own words is read whole. A relative path joins onto the payload `cwd`, except
for git's partial-checkout refusals and its `warning:` unlink line, which name
the path from the worktree's top-level, git's own working directory (verified
with git 2.47 from a subdirectory). Only when the matching line itself is one of
these, the path joins onto the worktree top: the nearest ancestor of `cwd`,
itself included, holding a `.git` entry, a file (linked worktree) or a
directory. With no such ancestor it joins onto `cwd`; another such line
elsewhere in the text moves nothing. Residuals: a quoted path holding its own
closing quote, which the tool prints escaped, is cut at that quote or yields
`nopath`; a curly-quoted or unquoted path holding two straight quotes is read as
what lies between them; under `git -C` a relative path names the `-C`
directory's tree, not the `cwd`'s, so it is wrong (`recover=` is withheld
there), and one whose parent is missing reads `readonly`, which carries no merge
clause. Index locks under `.git/worktrees/<name>/` and `.git/modules/<name>/` do
not end in `/.git/index.lock`, so the fifth shape does not take them.

The config-write line of the third alternative reads `nopath` like its twin,
since its path is unquoted. Five `nopath` shapes stay unextracted; together they
are 11 of the 195 hits of the 2026-09-27 dogfood: `tee`'s refusal of a file
under `/tmp`; `sed`'s temporary file in a relative directory; git's refusal to
write `.git/config`, which is busy rather than read-only; a removal warning on a
dotfile; and `cp` with an empty operand, which names no path at all. In every
recorded case a path would not change the act: each extractable path is writable
outside the sandbox, so `writable` would give the same re-run `nopath` gives,
and none names `.claude/settings.json`. A removal refused on a leaked phantom
mask gets that re-run too, and the leak makes it futile, since the mask outlives
its command and a restart clears it. A detector for that symptom would need a
corpus replay under D-15.

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
| `recover=<kind>` | with `target=`, under the `recover=` rule below: `merge` for a `merge` segment, `checkout` for a `checkout` or `switch` segment |
| `repo=<root>` | with `recover=`: the repository root in `printf %q` form (`C` locale), so the clause's `-C` argument runs as printed |
| `match=<repo>/<file>` | with `target=`: one line per file modified against HEAD, staged or not, whose working-tree content equals the target's, named by absolute path — the repository root, trailing slashes stripped, then the file's name within it |
| `claudeonly=1` | every line the matcher takes names a path, and each, resolved as the probe resolves the first, has a `.claude` component, the last one not followed by `worktrees`: Claude Code's worktrees sit under `.claude/worktrees/`, and their project files run no code. The path is read as the tool printed it, unnormalised, so a `..` segment after `.claude/`, which can climb back out, voids the `worktrees` exception |
| `configonly=1` | every line the matcher takes is git's `error: could not write config file` refusal, whatever its message |
| `readfile=<path>` | every command in the call's pipelines and lists is a reader — `cat`, `head`, `tail`, `grep`, `sed` without in-place editing, `awk`, `cut`, `sort`, `uniq` without a second operand, `wc`, `tr`, `less` — with no output redirection, and an input-file operand or `<` target has a command-output name: `*.log`, `*.output`, `*.out`, `*.err`; the first such. Never an input operand: a word opening with `-`; the first operand of `grep`, `sed` or `awk`, the pattern or program, unless an `-e` or `-f` came earlier in the segment; the word after a separate `-e` or `-f` |

**The `recover=` rule.** It prints only when the script's invocation is exactly
what the call ran, which takes all of these:

- the call holds exactly one segment running one of the six merge-style
  subcommands, and the scan of the command was not cut;
- git runs where the probe looks: the segment has no `-C`, `--git-dir` or
  `--work-tree` global option, every segment before it is itself a `git` command
  (first word exactly `git`, no such option; a `cd`, `export`, `eval`,
  assignment or group opener there may have moved the working directory), and
  the refused path's repository is the `cwd`'s. git's partial-checkout paths are
  relative and join onto the `cwd`, so otherwise the probe's repository is not
  the one git ran in;
- the segment holds exactly one non-option word, the target, a word holding `>`
  or `<` being a redirection and not counted;
- its only options are `-q`, `--quiet` and `--ff-only`;
- it holds no literal `--`;
- for a `checkout` or `switch`, `refs/heads/<target>` exists.

With several merge-style segments, `target=` and `match=` still come from the
first.

A plain `git merge <ref>` on diverged history still prints `recover=merge`. The
script's re-run line is `merge --ff-only`, which refuses without changing
anything.

The repository for `target=`, `recover=`, `repo=` and `match=` is the one
holding the path's nearest existing directory, else the payload `cwd`'s. The
probe runs five git processes, with optional locks off, so it writes nothing
(NFR-4). Word splitting is safe for `target=`, since a ref name holds no blank;
`readfile=` honours single and double quotes. A `readfile=` candidate holding
`*`, `?`, `[`, `{` or `$` is a glob, a brace expansion or a `$` expansion, not a
name the command wrote, and is passed over for the next one; in a word holding
`<`, only the name after the last `<` is tested. So `grep pat *.log x.err` gives
`x.err`, `cat $OUT.log` and `cat {a,b}.log` give no line, and
`grep 'err.*'<x.log` gives `x.log`. Residuals: `merge=1` read off the command
alone does not show that the git segment died, so a call whose merge or checkout
succeeded before another command's write was refused gets it too; its clause
then rests on `match=` lines, which a finished checkout leaves none of. A
partial checkout whose text lost git's error — cut by a `tail`, or sent to a
file — gets a clause only through a `match=` line. The delete-only case (git's
`warning:` on an unlink, exit 0, HEAD moved) prints no `partial=1`, so it gets a
clause only when a `match=` line fires; it can fire the detector alone, through
the third alternative, and then gets the bare re-run act. `partial=1` does not
check which git command printed the error, so a `stash` or `restore` dying on
the same error counts too. A git partial-checkout line that another program
prefixed or indented (a wrapper's own prefix) does not count; git's own progress
fragment before the message, ended by a carriage return, does. A file whose name
holds a newline is never a `match=` or a `readfile=`, and a repository root
holding one gives no `target=` or `match=` at all: either would split a `match=`
line and forge the key line after it. A repository at `/` gives
`match=//<file>`. A reader behind a `cd`, or a reader or git behind a variable
assignment, is not recognised. The scan does not parse `$( )`, backticks,
subshells, braces or `$'…'`, so their contents read as words of the command
around them, and a `cd` inside a subshell does not withhold `recover=`; it stops
at the end of a line holding `<<`, and after 16384 characters, and neither cut
command yields `readfile=`. A `>` anywhere in a word counts as output
redirection, quoted or not, except a descriptor duplication (`2>&1`, `>&2`); so
do `sort -o` and `awk -i`. A candidate ref holding `@{`, `^{`, `:` or a leading
`-` is skipped. With an unborn HEAD, or past 1000 files modified against HEAD,
no `target=` is printed. A file matches byte for byte, before any clean filter,
and never as a symlink.

The `readfile=` operand rule leaves residuals, each shown by what the probe
prints, in [readonly-path-readfile.md](readonly-path-readfile.md).

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
- `path=` names a `.claude/settings.json` (`writable` only) and no `merge=1` —
  write `.claude/settings.json` through the `update-config` skill
- `claudeonly=1` — every refused path is under a `.claude` directory, a project
  file of a `.claude/worktrees/` worktree aside, whose files can run code: tell
  the user what was refused, and leave any unsandboxed re-run or recovery to
  them
- `configonly=1` — only git's config-file write was refused and the rest of the
  call may already have run: make that config change alone with
  `dangerouslyDisableSandbox: true`, not a re-run of the whole call
- otherwise — re-run the whole call with `dangerouslyDisableSandbox: true`

The `update-config` act is for a settings edit; a checkout or merge that tripped
on the file is not one, so with `merge=1` it falls through to the next act.

`claudeonly=1` follows Claude Code's own note on a git result refused there
(observed on CC 2.1.326): those files can run code, so the command is not to be
redone outside the sandbox unprompted, and the user is told. The rule is the
path, whatever the tool or message, and a home `~/.claude` counts too, since an
unsandboxed self-configuration write is what the permission classifier refuses.
One refused path elsewhere keeps the re-run, and a project file of a worktree
under `.claude/worktrees/` is elsewhere. `configonly=1` covers a git command
whose own work landed before its config update was refused: a `checkout -b` that
made and checked out its branch but not its tracking config
(`fire-readonly-path-config-eperm`), or a `branch -D` that deleted the branch
but not its config section (`fire-readonly-path-git-config-busy`). Re-running
either call fails on the branch it already made or removed.

The act stands alone as its own sentence, capitalised. With `merge=1`, a clause
fires and replaces the act when `partial=1` is printed or any `match=` line is.
`match=` lines only decide that: they signal that git wrote at the target when
the text lost git's own error, and no file name reaches the verdict. The clause
is one of two:

- `recover=`, `target=` and `repo=` all printed — it names the script: run
  `sandbox-lies-recover -C <repo> checkout <branch>` (or `merge <commit-ish>`),
  `<repo>` in its `%q` form, with `dangerouslyDisableSandbox: true` and read its
  plan; the `sandbox-lies:sandbox-lies` skill says how to carry it out. It never
  names `--apply` and instructs no removal (D-7).
- otherwise — it points at the skill's recovery of a refused merge or checkout.

Under `claudeonly=1` neither fires: the clause says the git command may have
stopped part-way, then gives the `claudeonly=1` act, naming no script.

Neither says where HEAD is: a checkout can move HEAD at exit 0 and a merge not
(`skills/sandbox-lies/references/refused-merge-recovery.md`). With neither
`partial=1` nor a `match=` line there is no clause and the act stands alone, as
before: the command shape alone does not show the git segment wrote anything. Of
195 hits on 2026-09-27, 3 were this case, each another write's refusal
(`fire-readonly-path-git-config-busy` is one).

If `readfile=` is printed, the read act follows the clause as its own sentence,
since the refusal came from the call that wrote that file.

The clause replaces the act because, after a checkout that moved HEAD, a re-run
does nothing and adds a reflog entry the script must skip, while the script's
plan prints the re-run when one is needed. Recorded case:
`fire-readonly-path-checkout-moved`, 2026-10-31 in the handoff repository, a
`git checkout main && git merge --ff-only dev` whose unlink refusal on
`.claude/settings.json` still switched the branch; refused under `.claude`
alone, it gets the `claudeonly=1` form, and the same text on another path gets
the generic clause for its two merge-style segments. The reproduction table in
the recovery reference gives the other outcomes. The clause removes nothing; a
fast-forward re-run over files already at the target is refused
(`tests/verdict-premises.bats`), and the untracked files the target added are
left to the recovery procedure.

The read act covers the corpus's command-output reads below: the refusal in such
a file came from the call that wrote it, so re-running the read changes nothing.

**Corpus.** 162 hits, 161 true, 1 the residual (`mkdir` of a path directly under
`/`, left by an empty variable). 99% on 2026-09-25; 11 hits this project's
traffic. True: sandbox refusals under `/tmp`, `~/.cache`, `~/.claude`, sibling
repositories, harness-mounted config and the masks, and four reads of a file
with a command-output name — a background task's `*.output`, a `*.log` —
carrying an earlier sandboxed call's refusal. Any such name (`*.out`, `*.err`
and the like too) is a legitimate flag; a `*.md` or other document carrying one
is material about sandbox effects, self-reference (D-10).

The third alternative, replayed on 2026-11-13 with the shipped matcher as
arbiter over the whole local corpus: 34 hits that the first two alternatives do
not take, all true (100%), 6 of them this project's traffic. 28 are sandbox
refusals, 27 in `edify` and 1 in `devddaanet`, none run with the unsandbox flag;
the 6 are sessions of this project printing corpus or fixture lines back (D-10).
The same replay finds 169 hits for the first two alternatives, against the 162
of 2026-09-25 above; the 7 additional hits were not classified, since the
earlier hit list was not kept, and the 99% figure is the earlier measurement,
not re-taken.

**Decision: ships.**
