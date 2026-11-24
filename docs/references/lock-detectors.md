# Lock detectors

`git-lock` and `config-lock`, the two detectors whose verdict depends on a probe
of a lock path: matcher, probe and outcomes, flag policy, corpus figure and live
reproductions, and the argument for D-14. What each says, outcome by outcome, is
in the manual's [Detectors](../../manual/detectors.md). The catalogue entry for
each is a stub in [detectors.md](detectors.md), whose conventions — what a
matcher, probe and flag are, the verdict-text format, the corpus the figures
come from — apply here unchanged. No entry here quotes a diagnostic together
with its follow-on sentence, so that this file stays quiet under the detectors
it specifies.

## git-lock

Replaces `.git/index.lock: one error string, three causes`.

**Matcher.** Two substrings anywhere in the text: git's "unable to create" lock
error with its `File exists` tail, and git's follow-on sentence about another
process, required in full through its final `in this repository` clause. The
store's quotations truncate before that clause, which is what separates a live
failure from prose about one. Unanchored by design — a rebase prefixes the error
with progress on the same line. Exit status is not consulted: two corpus
failures were piped through `tail` and report 0.

**Probe.** `stat` the lock path named in the error — git prints it absolute; a
relative one resolves against the nearest ancestor of the payload `cwd` (itself
included) holding a `.git` directory, else against the `cwd`, and a missing or
empty `cwd` falls back to the probe's own working directory, never `/`. A
directory the Bash command names as `cd <dir>` or `git -C <dir>` (one literal
word, quoted or bare; a relative one taken from the `cwd`, a leading `~` from
`HOME`) resolves the same way when no lock exists at the `cwd` result, and the
last such directory under which the lock exists wins, since the command may have
run git in another repository; a lock at the `cwd` result always stands, and a
lock under none of them keeps it. Between `cd` and `<dir>`, `--` and options
made of `L`, `P`, `e` and `@` are skipped; between `git` and `-C`, every word
starting with `-` is, and the separate value of `-c`, `--git-dir`,
`--work-tree`, `--namespace` and `--config-env`. A word not starting with `-`
ends git's options, so a `-C` after a subcommand names nothing. Only the first
`-C` after `git` is read, and a `<dir>` starting with `-` is skipped. A target
in a variable or a substitution names no directory, nor does a recipe or script
that runs git elsewhere. Then a holder check: `lsof -t`, else `fuser`. Size and
age come from a portable `stat` form (BSD and GNU differ). Every outcome also
prints the resolved lock path as `path=` in `printf %q` form, so a newline in it
is escaped and cannot split the line or forge a key line; an empty path prints
no `path=` line.

| outcome | condition |
|---|---|
| `mask` | the path stats as a character device, or as an empty regular file with no write bit for anyone (mode & 0222 == 0), symlinks followed, decided before the holder check, under either flag |
| `gone` | the path is absent, under either flag |
| `held` | path present, a process holds it (`pid=`) |
| `orphan` | path present, holder check ran, no holder (`bytes=`, `age=`) |
| `unknown` | path present, no holder tool on `PATH`, or the holder check errored (`bytes=`, `age=`) |

**A lock with no holder check is `unknown`, not `orphan` (D-14).** The holder
check is `lsof -t`, then `fuser`; the Linux dev box has only the latter. With
neither, or a failed check, the verdict reports the lock's presence and carries
no removal instruction: a held lock also fails an identical retry, so degrading
to `orphan` would hand it the instruction the plugin exists to withhold.

**Flag policy.** Fires either way; the probe does not read the flag to choose an
outcome, and keeps it as its first argument for the uniform probe signature.
`mask` is a character device or an empty non-writable regular file: a mask
visible outside the sandbox while a sandboxed command runs, where re-running
unsandboxed at once changes nothing. Linux's bubblewrap shows the second shape
(see the config-lock reproduction of 2026-11-18). Git gives a config lock the
config file's mode before writing to it (`config.c`, git 2.47.3), so git's own
lock on a config file with no write bit can have that shape too, and reads as
`mask`. An absent path is `gone` under either flag, because a call that
`excludedCommands` unsandboxed carries no flag in the payload, and a lock its
holder has since released leaves nothing at the path, as a sandbox mask does
(the 2026-11-01 `just release minor` failure, whose lock was gone by probe time,
was told it had met a sandbox artefact). The verdict takes the flag as its
second argument and words by it the re-run of `mask`, the retry of `orphan` and
`unknown`, and `gone`: flag true keeps "git cleaned it after the failure. Retry
once."; flag false or absent says the refusal came from a sandbox mask or from a
lock its holder has since released, and retries with
`dangerouslyDisableSandbox: true`, which is harmless on a covered call. It
asserts no sandbox artefact. `mask` asserts none either: it says the lock has
the shape of a sandbox mask and most likely is one, and that a lock which
refuses again after the re-run is a real file with that shape, to report to the
user by path and not delete. `config-lock` instead hands such a lock to the
user, below.

**Verdicts.** In the manual, [git-lock](../../manual/detectors.md#git-lock),
with the flag's wording of the re-run and the retry. No outcome carries a
removal instruction, `orphan` included (D-14, above).

**Corpus.** 14 hits, 9 true, 5 self-reference (fixture reads, a fault-injection
probe, this project's replay). 64% on 2026-09-03 after pilot traffic; 82% on
2026-09-02 before it.

**Live reproduction (2026-09-25): `orphan`.** Scratch repo under `/tmp/claude/`
whose pre-commit hook stages a file; git 2.47.3, holder tool `fuser`. With an
empty `index.lock` made by hand, an unsandboxed `git add f` raised the lock
error; `probe_git_lock true <repo>` on that text printed `orphan`, `bytes=0`,
`age=0`, `path=<repo>/.git/index.lock`.

**Live reproduction (2026-09-25): `held`.** The same lock held open by a
background `sleep 30 9>>.git/index.lock`; the same probe call on the same text
printed `held`, `pid=<the sleep's pid>`, and the same `path=`.

**Live reproduction owed: `mask`.** On 2026-09-25 a sandboxed
`sh -c 'git add f && git commit -m x'` in that scratch repo committed cleanly,
its hook's staging included, as a 2026-09-23 attempt had. A script run as
`sh <script>`, no `git` on the command line, then ran `ls -la` on both lock
paths and `git status` in the scratch repo and in the project root: no
`index.lock` in either, only the project root's `.git/config.lock` as a
character device. With no index lock masked, the error could not arise. Git did
run sandboxed there, by the shape of both calls rather than by an exclusion
being ignored: an `sh` heads each, and CC applies an `excludedCommands` entry
only to a call whose every command it covers, so the `git:*` entry then
configured could not reach either. The probe recorded at the time as showing
that entry unhonoured on CC 2.1.281 (main session, 2026-09-26:
`git --version && touch /tmp/sbx-probe-git` failed with the read-only-filesystem
error, and the same `touch` with the sandbox disabled succeeded) is confounded:
its uncovered `touch` keeps the call sandboxed whether or not the entry is
honoured, so it shows only that this call ran sandboxed. A write to
`/tmp/<name>` fails that way only inside the sandbox. The later single-command
probes `git init -q /tmp/<name>` (CC 2.1.288 with `git:*`, 2026-10-03; CC
2.1.289 with `git *`, 2026-10-04) ran sandboxed too, and are confounded the same
way: git with an absolute, `~`-led or `..`-bearing path argument stays sandboxed
under any entry. What was observed, on CC 2.1.289 on 2026-10-05, is an entry
honoured: a bare covered `git status --porcelain` from the project root listed
no masks, while `true && git status --porcelain` listed them. On CC 2.1.293 on
2026-10-07 the same contrast held with `--ignored`: the bare covered form listed
no mask name, while `true && command git status --porcelain --ignored`, shown
sandboxed by a refused write to `/tmp/<name>` in the same call, listed 20 as
`??` and a gitignored one as `!!`, which a listing without `--ignored` leaves
out (`plans/sandbox-lies-review-fixes-2/m4-reprobe-evidence.md`). So the
re-probe is a bare `git status --porcelain --ignored`: without `--ignored`, a
sandboxed listing in a repository that ignores every mask name shows none and
reads as an unsandboxed run. A mask proves nothing about the call that sees it,
since masks are visible from every process while any sandboxed command runs.

## config-lock

Replaces the `.git/config.lock` paragraph of the same section and the
`git config` / `git remote add` / `just update-plugin-dev` shape.

**Matcher.** A line that begins with git's "could not lock config file" error
and ends in `File exists`. The line anchor is the discriminator: the pilot's own
report echoes the same text behind a `> ` marker.

**Probe.** As `git-lock`, on the config file the line-start error names, plus
`.lock`. Git prints that path relative to the main worktree's top-level even
from a subdirectory, and absolute from a linked worktree or a submodule, which
is why a relative path resolves from the nearest `.git` directory rather than
from the `cwd`, or from a `cd` or `git -C` directory in the command, as for
`git-lock`. Note `.git/config.lock` is itself in the masked set, so the
sandboxed write fails on a bind-mount, not on a file. When a lock exists under
one of those directories besides the one resolved, cwd's or another directory's,
and is not the same file, the probe also prints `ambiguous=1`: the lock the call
met may be either.

**Verdicts.** In the manual,
[config-lock](../../manual/detectors.md#config-lock): `git-lock`'s, naming
`config.lock`, without the `GIT_INDEX_FILE` leak clause, which concerns
`index.lock` only. The test that swaps the re-run for the `update-config` act on
a `.claude/settings.json.lock` applies to `mask` under either flag and to `gone`
when the flag is absent or false, never to `gone` under flag true. It runs on
the decoded value of `path=`, not on the wire form (the printed value, defined
in [readonly-path.md](readonly-path.md), Probe); a value that decodes to no path
keeps the re-run, or for `gone` the retry.

**A lock that refuses again.** On Linux a sandbox that dies uncleanly can leave
its mask of `.git/config.lock` on disk, an empty read-only file that fails every
config write, sandboxed or not, until removed; a live mask has the same shape,
and only `/proc/*/mountinfo` would tell them apart, which the hook does not
read. So `mask`, given a decoded `path=`, tells the agent to leave the lock and
hand the user `rm` of that path, to run once they have checked that no sandboxed
command is running in any session. This is D-7's one exception: the `rm` is
handed to the user, and the agent is told to remove nothing. The user pastes the
command into their own shell, so the path is printed in single quotes, and only
when every byte of it is printable ASCII (0x20 to 0x7E) other than a single
quote, a backslash and a backtick. Such a word reads the same in bash, zsh, dash
and fish and reaches the user as printed. Outside that set, a single quote ends
the word, fish reads a backslash inside it as an escape, a backtick closes the
code span around the command, a byte that is not valid UTF-8 is replaced on the
way to the agent, and a control byte does not survive a paste; the rule names
the bytes known to arrive instead of listing those that do not. Any other path,
non-ASCII included, a value that decodes to no path, or a path the probe marked
`ambiguous=1`, gets no `rm` and keeps `git-lock`'s report-and-leave sentence: an
`rm` must never name one repository's lock when the call may have failed on
another's. Recorded case: a 2026-11-13 session elsewhere, where an unsandboxed
`just sync` met a nine-day-old empty mode-0444 `.git/config.lock` listed in no
mountinfo, and `rm` cleared it. `git-lock` keeps report-and-leave: its
paragraph's `GIT_INDEX_FILE` sentence leaves no room for the hand-off under
FR-6's 400 characters.

**Flag policy.** As `git-lock`.

**Live reproduction (2026-09-25): `mask`.** In this project's root, where a
sandboxed `ls` showed `.git/config.lock` as a character device and an
unsandboxed one showed no such file, a sandboxed
`sh -c 'git config sandboxlies.probe 1'` raised the config-lock error naming
`.git/config` relative; `probe_config_lock false <root>` run unsandboxed on that
text printed `mask`, `path=<root>/.git/config.lock` (the rule then: an absent
path under flag false read `mask`; it now reads `gone`, and `mask` needs the
character device or the empty non-writable file). The key was not written. The
same write from a script run as `sh <script>`, with no `git` on the command
line, gave the same error and the same probe output; a visible
`cd <root> && git config` and a bare `git -C <root> config` gave the same error
too. These ran in a delegated agent's session; the bare form did the same, key
unwritten, in the main session that dispatched it. That they ran sandboxed
despite `git:*` in the user settings' `sandbox.excludedCommands` needs no
exclusion to have been ignored: an `sh` head, a `cd` and `git -C` each keep a
call sandboxed under CC's every-command rule. The `/tmp` write test once cited
for it is confounded (`git-lock`'s owed `mask` reproduction), and the mask they
hit proves nothing about the call either.

**Live reproduction (2026-11-18): `mask` as a regular file.** Linux, where the
command sandbox is bubblewrap. With a sandboxed `sleep 60` running in the
background, a sandboxed `git config sandboxlies.probe 1` in this repository
failed on the config lock error. Outside the sandbox the lock was an empty
mode-0444 regular file, not a character device, so the probe read `orphan` (0
bytes, age 9s), which says the lock predates the session. An unsandboxed retry
of the same write failed identically. After the `sleep` ended the file was gone
unsandboxed and no key had been written: a live mask, not an orphan. Under
`.git` only `config.lock` was masked; `index.lock` was not.

**Corpus.** 4 hits, 4 true. 100%, 2026-09-03.
