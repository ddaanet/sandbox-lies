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
