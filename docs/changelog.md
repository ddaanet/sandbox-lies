# Changelog

Design-significant changes only; git history is the full record.

Entries from 2026-09-22 to 2026-09-27 are in
[changelog-2026-09.md](changelog-2026-09.md).

## 2026-10-05 — dogfood through the toolkit's shim

The release toolkit moved to 0.9.0, which ships a `claude` shim at
`plugin-dev/bin/claude`. It loads the plugin from a copy synced to
`dist/plugin/` rather than from the working tree. The hand-copied `.bin/claude`
went, and with it `tests/shim.bats` and the BSD `paste` stub only that suite
used. Under `--plugin-dir` on the checkout, an agent's Write or Edit there often
got no permission verdict at all, so edits had to be routed through scripts.
D-16 now names the toolkit's shim. The precommit lint now covers untracked,
unignored files too: a new bats file had reached a commit failing shellcheck,
because the gate listed tracked files only.

## 2026-10-05 — review fixes: exclusions, the `jq` notice, readonly facts

The deliverable review found the skill's `excludedCommands` model wrong. CC
applies an entry only to a call whose every command it covers; a `cd`, a
subshell, a command substitution, a redirection other than a descriptor
duplication, or a command name from a variable keeps the call sandboxed, as does
git with `-C` or an absolute, `~`-led or `..`-bearing path argument. The skill
now says so, writes entries as `git *` (`git:*` is legacy), drops the decoy
escalation, and re-ranks the working-directory acts, since a trailing `cd` and a
subshell both forfeit an exclusion; the persisted `cd` holds in the main session
only. On CC 2.1.289 a bare covered `git status` from the project root listed no
masks while `true && git status` listed them, so entries are honoured for a
fully covered call, and that bare `git status` is the re-probe. The earlier
probes read as "not honoured" — CC 2.1.281's `git --version` and `touch` pair,
the 2.288 and 2.289 `git init -q /tmp/<name>` runs — are each confounded under
the documented rule; `references/lock-detectors.md` restates them. A missing
`jq` had silenced every annotation unseen: `hooks/check-jq.sh` on `SessionStart`
now tells the user and the agent, and README §Install names `jq` as a
prerequisite. The `readonly-path` probe's `match=` names are absolute, so the
restore clause is right from any directory of the repository, and `readfile=`
takes only input operands: never an option word, a `grep`, `sed` or `awk`
pattern or program, or the output operand that makes `uniq` a writer. A refused
path that resolves to a newline-bearing one reports `nopath` rather than forging
key lines, and a lock probe whose resolved path holds a newline keeps its
outcome and leaves out `path=`. The docs now say the symptoms and figures were
recorded on Linux with macOS unverified, which repositories the hook reads
(NFR-4), how far the fixtures re-cut from the script (FR-8), and which corpus
each `phantom-untracked` figure comes from. The suite gained pins for the
review's verification gaps.

## 2026-10-08 — review fixes: a transcript probe for `resume-lost`

The second deliverable review found D-8's mitigation false: exclusions are
honoured for a fully covered call and the baseline excludes `claude`, so a
covered `claude --resume` refused for any reason carried no flag and read as a
transcript the sandbox lost. A live probe on CC 2.1.292 showed a sandboxed
`--resume` of an existing transcript succeeding, from any project directory, and
a different config directory as the observed cause of a refusal for one that
exists. `resume-lost` now has a probe, transcript existence by glob under the
config directory, and drops its flag policy: `lost` keeps the old verdict,
`found` gets its own, saying the sandbox is not the cause and naming the config
directory, and `unknown` is silent. What D-8 still accepts is a covered `git`
whose lock was gone by probe time reading `mask`, whose re-run is harmless. The
`readfile=` scan passes over a candidate holding a glob, a brace or a `$`
expansion, quoted or not. Re-observed on CC 2.1.293, the exclusion re-probe
became `git status --porcelain --ignored`, since a mask the repository ignores
shows only as `!!`. NFR-2's per-suite BSD case now binds only a suite whose code
under test calls a stubbed tool, the FR-4 pinned-by list names test families
rather than files, and `just precommit` gained a Python compile check.

The skill follows: strict mode ignores the per-call flag, so the call runs
sandboxed, and a `!` command runs sandboxed too in a background session or on
Linux with `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB` set; an allow rule joins the
read-only validator as what clears an unsandboxed command before the classifier,
and is the documented mitigation for its cost; the exclusion re-probe is
`git status --porcelain --ignored`, with the CC 2.1.293 observation; and a
sandboxed turn on a persisted session, verified on CC 2.1.292, answers but is
dropped.

The suite gained the pins the previous review asked for: the slash-suffixed
`phantom-untracked` forms, a guard that the real-probe case runs with no `.git`
above its tree, a `mktemp` spy for NFR-4, and a BSD-stub case in seven suites.
The review of those fixes tightened the probe: a config directory it cannot
search (`projects/` missing or unreadable, or an id unfound while a project
directory cannot be listed) reads `unknown` rather than `lost`, a caller's
`noglob` no longer turns every id missing, the refusal line shape is held once
and shared with the matcher, the transcript is pinned as never opened, and the
`readfile=` skip covers a brace expansion.

## 2026-10-11 — review fixes 3: `path=` in `printf %q` form

Every `path=` value the probes print is now `printf %q` of the resolved path,
pinned to the `C` locale so a non-ASCII byte is octal under any session locale.
Only a newline in the payload `cwd` had triggered the old guards, which dropped
the line (lock probes) or degraded the outcome to `nopath` (`readonly-path`);
both are gone, and such a path gets its real outcome with one `$'…'` line. An
empty path now prints no `path=` line, where the lock probes printed a bare one.
The verdict decodes the value without eval: the backslash form through `read`
without `-r`, the `$'…'` form through a grammar check and `printf %b` on an
argument, never a format, one escape at a time so a digit after a control byte's
octal escape stays a digit; any other value reads as no path. The decoded path
is shown raw unless it holds a control byte, then the wire form. The
`readfile=`, `match=` and `target=` newline skips stay, since each loses one
optional fact and not the path. A partial-checkout refusal's relative path now
joins onto the worktree top, the nearest ancestor holding a `.git` entry, when
the matching line itself is git's refusal; it had joined onto the `cwd` and
could read `readonly`, which says unsandboxing will not help. `git -C` remains a
residual. The phantom verdicts no longer name the project root, which a
persisted `cd` made false. The `readonly-path` command scan's tokenizer appends
to a bounded pending run instead of copying the growing word: one
16384-character word took 31.7 s on bash 3.2.0 against the hook's 10 s timeout,
and now takes 3.5 s.

Test side: two new suites pin the contract, `tests/verdicts-readonly-path.bats`
(the decode and display rule) and `tests/probes-readonly-resolve.bats` (the
relative-path resolution, including the worktree-top join). `utf8_locale` moved
into `tests/helpers/locale.bash` and `probes.bats` uses it and `index_mtime`
where it had a literal locale and GNU `stat`; written portable by construction,
unverified on a Mac. The line cap now covers `*.awk`, `*.toml`, `justfile` and
`*.json` at any depth outside `plans/`, `plugin-dev/` and `tests/fixtures/`. The
Python tools gained suites, `tests/corpus-eval.bats` and
`tests/extract-fixtures.bats`, and fixes: `corpus-eval.py` empties `survivors/`
and removes `verdicts.tsv` before extracting, skips and counts a verdict line
with no manifest entry, and reads a non-dict `input` as no command;
`extract-fixtures.py` reads a `null` timestamp as no day and a non-dict `input`
as no command. The review added three guards, each pinned by a case: a non-dict
JSONL line in both tools, and a `null` text item in a list-form tool result. Two
cleanups: `pick()` in `extract-fixtures.py` lost its branch that searched every
project when none was named, and `corpus-eval.py`'s usage docstring now
redirects its verdict loop's output once after `done` instead of appending on
each pass.

Closed, not built. The five `nopath` shapes (`tee`, `sed`'s temporary file,
git's busy `.git/config`, a dotfile removal, `cp` with an empty operand): a path
would not change the act in any recorded case, since each extractable one is
writable outside the sandbox and `writable` gives the re-run `nopath` gives. The
Item 8.2 remainder: `memory/ddaanet/sandbox-effects.md` stays, as the home of
the zellij section, whose detector cannot ship under D-15 with 0 corpus hits,
and of the phantom-dotfile leak. FR-10 now says so and is Done, and the
translation map no longer promises a deletion.

## 2026-10-11 — linear path decode

The `$'...'` decode in `_verdict_path_read` was quadratic in the escapes: a
3873-byte CJK path took 31.9 s under bash 3.2.0 in a UTF-8 locale, past the
hook's 10 s. It now splits the body once on its backslashes, under `LC_ALL=C`,
and takes 0.4 s there (0.3 s on bash 5.2); the output is unchanged.

## 2026-10-11 — tokenizer no longer copies the run on # and >&

`_readonly_tokenize` joined its pending run into the word on every unquoted `#`
and every `&`, so a 16384-character word of `#` after a letter, or of `>&`, was
quadratic: 66.7 s and 38.5 s under bash 3.2.0 in a UTF-8 locale, past the hook's
10 s. The word's emptiness and last character are now tracked apart from it, so
those words take 3.7 s and 4.6 s, like a plain one (3.7 s), and the tokens are
unchanged.

## 2026-10-11 — review fixes: locale leak, errexit, undecodable wire values

`verdict_config_lock` called `_verdict_path_read` bare, so a caller under
`set -e` got status 1 and no text for a `mask` with no decodable `path=` line;
it now prints the paragraph. `_verdict_has_control` and the `$'...'` escape loop
(now `_verdict_unescape`) restore the caller's `LC_ALL` on every return, since
bash 3.2.0 does not undo a `local LC_ALL=C` and left the calling shell in the C
locale. `_verdict_path_read` now reads `$''`, a relative `$'...'` value and a
`/` value ending in a lone backslash as no path, as the encoder never writes
them, so the paragraph no longer opens with an empty code span.

## 2026-10-11 — partial-checkout gate anchored, trailing newline and empty cwd

The join onto the worktree top in `probe_readonly_path` now fires only when the
matching line opens with git's own message (`error: unable to unlink old`,
`error: unable to create file` or `fatal: cannot create directory at`), not on
any line holding the phrase, so a cp refusal naming such a path joins onto its
cwd. The top's name keeps a trailing newline the `$(...)` walk used to strip,
and an empty cwd starts the walk at the probe's working directory rather than
joining onto it unwalked. `partial=1` still reads the phrase anywhere in the
text.

## 2026-10-11 — corpus tools skip odd lines instead of tracing back

`tests/corpus-eval.py` and `tests/extract-fixtures.py` read transcript JSON
whose fields are not always the type they are keyed on. Both now skip a record
they cannot key: a Bash `tool_use` whose `id` is not a string, and a
`tool_result` whose `tool_use_id` is not a string, were a `TypeError` on the
dict lookup. In `extract-fixtures.py` a non-string `timestamp` reads as an empty
day and a non-string `text` item in a list-form result reads as an empty line.
`corpus-eval.py extract` no longer fails with `IsADirectoryError` when
`survivors/` holds a subdirectory: it clears the regular files and leaves the
directory alone. `aggregate` splits a verdict line with `partition`, so a line
with no tab is counted in `verdict lines skipped, no manifest entry` like a line
naming an unknown file, instead of raising `ValueError`. No broad exception
catch was added; a valid neighbouring line is read as before.

## 2026-10-13 — `partial=1` reads lines, not the whole text

`partial=1` fired when git's partial-checkout phrase appeared anywhere in the
text, so a `cp` or `mv` refusal quoting a path that held the phrase printed
`merge=1` and `partial=1` with them. It now requires a line that opens with
git's prefixed message, the test `_probe_partial_checkout_line` already applied
to the matching line, so the phrases live in one place. A git line prefixed or
indented by another program no longer counts.
