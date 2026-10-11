# Changelog

Design-significant changes only; git history is the full record.

## 2026-09-22 — design written

Repository initialised, release toolkit vendored, `ddaanet` memory tier mounted,
`docs/design.md` written from `BRIEF.md`, the pilot brief and the
`sandbox-effects` memory file. The pilot's decision rule — three detectors must
hold — resolved as two held, one dead for a reason specific to its shape (D-1);
this repository is the answer. Eleven detectors catalogued in
`references/detectors.md`, five measured, six candidates; the `ps` case needs
the command word and goes to the skill; the symptom-less knowledge assigned to
one skill (D-9); memory retirement sequenced after dogfooding (D-11).

## 2026-09-22 — outline review: failures fire a different event

The outline review found, and a read of the CC 2.1.280 bundle confirmed, that a
Bash call exiting non-zero dispatches `PostToolUseFailure` with the result text
in an `error` string, and `PostToolUse` only on success. The design had named
one event; it now registers one script on both (D-13). The same review added the
probe output contract (FR-4), the per-detector flag policy (FR-5), the verdict
composition rule (FR-6), the `unknown` lock outcome (D-14), the second
self-reference residual (D-10, FR-11) and the translation map in
`references/detectors.md`.

## 2026-09-22 — decisions taken at outline validation

Skill named `sandbox-lies` (D-9). No verdict instructs a removal (D-7).
Retirement per section, immediate, in the commit that lands each translation
(D-11 reversed from wait-for-dogfood). Candidate ship rule by false-positive
classification, not a precision floor (D-15). `tmp-full` dropped as not a
sandbox effect. Dogfood through a `.bin/claude` shim (D-16). Line cap and link
check added as NFR-5.

## 2026-09-23 — live payloads: one merged stream

Recording both events from a nested `claude -p` on CC 2.1.280 showed the Bash
tool merging stderr into stdout in emission order, sandboxed and unsandboxed:
`tool_response.stderr` arrives empty, and `error` is the exit-code line followed
by that merged output. The bundle reading behind D-13 had described separate
streams and an exit-line, stderr, stdout order; D-13 now states the recorded
shape. Its reopen-if did not fire — both payloads are byte-identical to the tool
result the model sees, which is the text the fixtures were cut from. The flag is
absent from `tool_input` when unset, and a sandboxed write refused by the
allowlist carried no sandbox-violation annotation (L-5).

## 2026-09-24 — the hook ships with the phantom verdicts

Item 2.3 landed `hooks/annotate.sh` on both events with the three `phantom-*`
verdicts, and retired the memory file's phantom-dotfile masks, who-sees-them,
`git add -A` and visible-unsandboxed paragraphs and its `/tmp reads full`
section; the zero-byte mask shape has no verdict and goes to the skill. Wall
time of `bash hooks/annotate.sh`, mean of 30 runs, `PostToolUse` payloads built
as `tests/helpers/hook.bash` builds them, on a 2-core Debian 13 box (Linux 6.12,
GNU bash 5.2.37, load average ~2.1) inside the command sandbox: 52 ms on
`quiet-clean-status`, 64 ms on `fire-masks-porcelain` (a verdict without a
probe, against NFR-3's 100 ms bound), 54 ms on a quiet 25,000-character
`tool_response.stdout`. A first pass gave 61, 61 and 52 ms, with one
`fire-masks-porcelain` run at 169 ms: the bound holds for the mean, not for
every run on a loaded box. Nothing gates these figures.

## 2026-09-25 — the gates and the lock probes

Items 2.1 and 2.2 put `scripts/check-line-limits.sh` and
`scripts/check-links.sh` into `just precommit`, closing NFR-5; the link check
covers inline links only, reference-style definitions staying unchecked. Item
2.4 built `probe_git_lock` and `probe_config_lock`, tested but not yet
live-proved or called by the hook. Two rules changed while building them. A
relative lock path now resolves from the nearest ancestor of the payload `cwd`
holding a `.git` directory, not from the `cwd` itself: git prints the
config-lock path relative to the main worktree's top-level even from a
subdirectory (checked on git 2.47.3), so a join onto the `cwd` named a lock that
was never there; a missing `cwd` falls back to the probe's working directory,
never `/`. A holder check that errored reads `unknown`, as a missing holder tool
does (D-14): it has not shown the lock unheld. The phantom verdicts' claim that
unsandboxed `ls -a` and `git status` show the real tree now holds only with no
sandboxed command running in the background, since the masks are visible from
any process while one runs.

## 2026-09-25 — lock detectors split out; `mask` wording flag-neutral

`references/detectors.md` had reached its line cap with the lock verdicts still
to be written out and four candidates about to ship, so `git-lock` and
`config-lock` moved whole into `references/lock-detectors.md`, leaving a stub
per detector in the catalogue. They are the one self-contained cluster: a shared
probe, one outcome set, and verdicts that differ only in the lock they name. The
`config-lock` verdicts are now written out in full in place of the `As git-lock`
shorthand; they drop the `GIT_INDEX_FILE` leak clause, which concerns
`index.lock` only and took the `mask` paragraph past FR-6's 400 characters. The
probe reports `mask` for a character device under either flag, and under flag
true the old `mask` wording was false: re-running unsandboxed was what had just
failed, and a device did exist outside the sandbox. The `mask` paragraph now
reads true under both flags — re-run unsandboxed, or, if the call already ran
that way, once no sandboxed command is running — and its human line says the
lock is not real rather than that no file exists.

## 2026-09-26 — lock and candidate memory retired; hook runtime split out

With the lock verdicts and the `tmpdir-unset`, `resume-lost` and `seccomp-init`
verdicts shipped, their memory sections left `memory/ddaanet/sandbox-effects.md`
together: the `.git/index.lock` section with its `.git/config.lock` paragraph,
cost 1 of `Leaving the sandbox` (the unsandboxed `$TMPDIR` collapse), the
`--resume` mechanism and the sandbox-setup section. The skill-mapped parts stay
for the skill: the `$TMPDIR` instability paragraph, and the eval-harness
consequence of a lost transcript under a new heading. Cost 1's note that the
classifier judges an unsandboxed recipe by its top-level command moved into cost
3, whose recipe guidance also goes to the skill. `zellij-socket` stayed a
candidate, so its section stays. The status flips took `docs/design.md` past its
line cap, so the Architecture section's flow, why-the-hook-sees and paths
paragraphs moved verbatim into `references/hook.md`, the need-time cluster for
changing `annotate.sh` or a probe's path handling; the hub keeps the component
map, now with the `scripts/check-*.sh` gates again, and one paragraph of
conclusions.

## 2026-09-26 — `$TMPDIR` not unset unsandboxed; mask evidence replaced

On CC 2.1.281 an unsandboxed call's `$TMPDIR` read `/tmp`, not unset, which
falsified the `tmpdir-unset` verdict's claim that the variable is unset outside
the sandbox; the collapse its 13 corpus hits record may not occur on current CC.
The verdict now states only what the flagged call shows — the expansion came up
empty and the path collapsed to `/` — and keeps the literal-scratch-path
directive; the entry carries the observation as a dated caveat, and NFR-4 no
longer asserts the hook's `$TMPDIR` is unset. The Item 3.1 notes in
`references/lock-detectors.md` had argued from masks that every git call ran
sandboxed, but a mask is visible from every process while any sandboxed command
runs, so it proves nothing about the call that sees it. The conclusion stands on
a mask-free test instead: a `touch` under `/tmp` chained after `git` failed
read-only, and the same write with the sandbox disabled succeeded.

## 2026-09-26 — `readonly-path` verdicts shipped; config and worktree memory retired

`readonly-path` now reaches its probe and one of three verdicts, and stays
silent on an unsandboxed call. The probe's path extraction was widened before
the verdict shipped, from real messages collected sandboxed: curly quotes,
`mv`'s target after `to`, and four unquoted forms (bash's `line N:`, dash's
`cannot create`, git's `could not lock config file` and `cannot mkdir`); any
other unquoted shape stays `nopath`. The probe moved to
`lib/probes-readonly.sh`. The `writable` and `nopath` verdicts carry the
command-output-read clause: a refusal read back from a `*.log` or similar points
at the command that wrote the file. They ask for the partial-merge comparison
before the re-run, and `readonly` names an act. `writable` is the first verdict
to interpolate an unbounded value, so FR-6's 400 characters now state what the
suite measures: the text before interpolation, where `writable` stands at 391
and a path of 15 characters or more takes it to 400. The harness-mounted config
and sibling-worktree sections left `memory/ddaanet/sandbox-effects.md`; the
merge-recovery procedure stays under its own heading for the skill, cost 3 keeps
its recipe guidance without the quoted diagnostic, and the sibling section's
classifier note moved into cost 2.

## 2026-09-26 — the skill shipped; the memory file down to zellij

`skills/sandbox-lies/` carries the symptom-less knowledge: `excludedCommands`
semantics, the escapes and their costs, `$TMPDIR` scoping, cleanliness gates
over the masks, the `!`-expansion path, merge recovery, `ps`, and `claude` under
the sandbox. Every skill-mapped section left
`memory/ddaanet/sandbox-effects.md`, which keeps its context paragraph and the
zellij section, the detector-mapped part of a candidate that did not ship; Item
8.2's deletion waits on it. The `readonly-path` partial-merge clause now states
the tree's state and the order of acts — files already at the target, HEAD
unmoved, a re-run refused, restore from HEAD then re-run — and removes nothing;
`tests/verdict-premises.bats` pins git's refusal. `nopath`'s human line says the
path went unchecked, and `phantom-untracked` opens on dotfile entries, since a
status lists names and not modes. `README.md`, an MIT `LICENSE` and a
`CLAUDE.md` body for agents working in the repository shipped in the same phase;
the README installs by `--plugin-dir`, since a marketplace install aborts on the
memory submodule's placeholder url.

## 2026-09-26 — the script decides a verdict's conditions

My human partner ruled that text a hook emits for the agent carries no
conditional the script could evaluate itself; that is now D-17. The verdicts had
kept such branches to stay one fixed paragraph per outcome — "if it already ran
that way", "if a merge or checkout died", "once they match the target", "if it
only read a command-output file", "for `.claude/settings.json`" — each a check
the agent was left to run on facts the hook already had or could probe. The
verdict functions now take the flag as a second argument and the lock verdicts
word their re-run by it, `orphan` and `unknown` included, whose "retry
unsandboxed" was false under flag true. The `readonly-path` probe takes the
command as a third argument and reports what the acts depend on: a git
merge-style command or git's own partial-checkout error, its target, the
modified files already at that target, and a read of a command-output file; the
verdict states only the acts those facts select. The update-config act replaces
the re-run when the path or the config file is `.claude/settings.json`. With the
branches gone the budget no longer forces "unsandboxed", so the re-runs name
`dangerouslyDisableSandbox: true` again. The clauses keyed to a repeat failure,
which a stateless hook cannot see, stay in the text. D-17 took `docs/design.md`
past its cap, so the arguments for D-6 and D-13 moved verbatim into
`references/hook.md` and D-14's into `references/lock-detectors.md`, each
leaving its conclusion in the hub.

## 2026-09-27 — dogfooded through the shim

The D-16 shim landed as `.bin/claude`. It drops every `PATH` entry whose
`claude` is the shim itself rather than every entry spelled like its directory:
a trailing slash on that entry had the shim re-executing itself without end.
Through it, on CC 2.1.283, the skill listed as `sandbox-lies:sandbox-lies` and
the hook's context on an `sh -c 'ls -la'` run without the sandbox flag carried
the `phantom-chardev` verdict, which closed FR-1. Earlier in the build, on CC
2.1.281, masks turned up under the sandboxed call's working directory after a
persisted `cd` into a submodule, not only under the project root; the skill and
`references/hook.md` now say so, while the phantom verdicts still name the
project root. D-1's argument moved verbatim into `references/hook.md`, leaving
its conclusion in the hub, to keep `docs/design.md` under its cap.

## 2026-09-27 — the merge clause needs git's own error

The `readonly-path` verdict's "restore them from HEAD" clause, given when no
target resolves, had fired on the command's shape alone: a git merge, pull,
checkout, switch, rebase or cherry-pick anywhere in the call. Over the corpus it
fired 3 times and was false every time, since another write in the call was the
one refused. The probe now prints `partial=1` when the text holds git's
partial-checkout error, and the no-target clause needs it. The clause naming
files that match the target is unchanged, since those matches are their own
evidence. Git's `cannot create directory at` error, which a live reproduction
showed ending a merge that adds a directory, joined the two earlier needles.

## 2026-09-27 — skill review: `ps` corrected, the cwd act reachable

The skill had said a background task is absent from any process listing the
agent can take. A probe on CC 2.1.281 contradicted it: a sandboxed `ps` listed 5
lines and no background `sleep`, an unsandboxed one 204 lines with it. The skill
now says the task is invisible to a sandboxed `ps` only, and has the agent check
with an unsandboxed one; `references/detectors.md` names the case the same way.
The masks-follow-the-cwd fact gained a hub section and a description trigger,
and its acts now run absolute paths or `git -C` first, a trailing `cd <root>`
line next, and a subshell last, since a git inside one misses an honoured
exclusion. The description also gained triggers for a `claude -p` run for a
`SessionStart` side effect and for a slash command's context block, and the
hub's node pointers became links the link check resolves.

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
both are gone, and such a path gets its real outcome with one `$'…'` line. The
verdict decodes the value without eval: the backslash form through `read`
without `-r`, the `$'…'` form through a grammar check and `printf %b` on an
argument, never a format, one escape at a time so a digit after a control byte's
octal escape stays a digit; any other value reads as no path. The decoded path
is shown raw unless it holds a control byte, then the wire form. The
`readfile=`, `match=` and `target=` newline skips stay, since each loses one
optional fact and not the path. A partial-checkout refusal's relative path now
joins onto the worktree top, the nearest ancestor holding a `.git` entry, when
the matching line alone is git's refusal; it had joined onto the `cwd` and could
read `readonly`, which says unsandboxing will not help. `git -C` remains a
residual. The phantom verdicts no longer name the project root, which a
persisted `cd` made false. The `readonly-path` command scan's tokenizer appends
to a bounded pending run instead of copying the growing word: one
16384-character word took 31.7 s on bash 3.2.0 against the hook's 10 s timeout,
and now takes 3.5 s.

Test side: `utf8_locale` moved into `tests/helpers/locale.bash` and
`probes.bats` uses it and `index_mtime` where it had a literal locale and GNU
`stat`; written portable by construction, unverified on a Mac. The line cap now
covers `*.awk`, `*.toml`, `justfile` and `*.json` at any depth outside `plans/`,
`plugin-dev/` and `tests/fixtures/`. The Python tools gained suites,
`tests/corpus-eval.bats` and `tests/extract-fixtures.bats`, and fixes:
`corpus-eval.py` empties `survivors/` and removes `verdicts.tsv` before
extracting, skips and counts a verdict line with no manifest entry, and reads a
non-dict `input` as no command; `extract-fixtures.py` reads a `null` timestamp
as no day and a non-dict `input` as no command. The review added three guards,
each pinned by a case: a non-dict JSONL line in both tools, and a `null` text
item in a list-form tool result.

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
