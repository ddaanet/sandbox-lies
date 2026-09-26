# Lock detectors

`git-lock` and `config-lock`, the two detectors whose verdict depends on a probe
of a lock path: matcher, probe and outcomes, flag policy, verdict text per
outcome, corpus figure and live reproductions. The catalogue entry for each is a
stub in [detectors.md](detectors.md), whose conventions — what a matcher, probe
and flag are, the verdict-text format, the corpus the figures come from — apply
here unchanged. No entry here quotes a diagnostic together with its follow-on
sentence, so that this file stays quiet under the detectors it specifies.

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
empty `cwd` falls back to the probe's own working directory, never `/` — then a
holder check: `lsof -t`, else `fuser`. Size and age come from a portable `stat`
form (BSD and GNU differ).

| outcome | condition |
|---|---|
| `mask` | flag false, path absent outside the sandbox, or it stats as a character device |
| `gone` | flag true, path absent |
| `held` | path present, a process holds it (`pid=`) |
| `orphan` | path present, holder check ran, no holder (`bytes=`, `age=`) |
| `unknown` | path present, no holder tool on `PATH`, or the holder check errored (`bytes=`, `age=`) |

**Flag policy.** Fires either way; the flag selects `mask` versus `gone` when
the path is absent. Under flag true, `mask` is the character-device case: a mask
visible outside the sandbox while a sandboxed command runs, where re-running
unsandboxed at once changes nothing. The `mask` wording holds under both flags
rather than taking the flag as an argument.

**Verdicts.**

- `mask` — The lock in this error is a sandbox artefact and the repository is
  healthy. Re-run the same command with `dangerouslyDisableSandbox: true`; if it
  already ran that way, re-run it once no sandboxed command is running. A repeat
  failure on a commit whose hook stages files is that hook leaking
  `GIT_INDEX_FILE`, not the sandbox. ·
  `index.lock — sandbox mask, not a real lock`
- `gone` — No lock exists now; git cleaned it after the failure. Retry once. A
  repeat failure on a commit whose hook stages files is that hook leaking
  `GIT_INDEX_FILE`, not the sandbox. · `index.lock — cleared after failure`
- `held` — A process (pid N) holds the lock. Wait for it, then retry. ·
  `index.lock — held by pid N`
- `orphan` — The lock exists outside the sandbox (N bytes, age Ns) and no
  process holds it. Retry the command unsandboxed; a second identical failure
  means the lock predates this session. · `index.lock — present, no holder`
- `unknown` — The lock exists outside the sandbox (N bytes, age Ns); no holder
  check is available here. Retry the command unsandboxed. ·
  `index.lock — present, holder unknown`

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
run sandboxed there, the `git:*` exclusion unhonoured on CC 2.1.281, the version
both days ran: in the main session on 2026-09-26,
`git --version && touch /tmp/sbx-probe-git` failed with the read-only-filesystem
error, and the same `touch` with the sandbox disabled succeeded. A write to
`/tmp/<name>` fails that way only inside the sandbox. A mask proves nothing
about the call that sees it, since masks are visible from every process while
any sandboxed command runs.

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
from the `cwd`. Note `.git/config.lock` is itself in the masked set, so the
sandboxed write fails on a bind-mount, not on a file.

**Verdicts.** `git-lock`'s, naming `config.lock`, without the `GIT_INDEX_FILE`
leak clause, which concerns `index.lock` only; the `mask` paragraph adds the
config write.

- `mask` — The `config.lock` behind this error is a sandbox artefact and the
  repository is healthy. Re-run the same command with
  `dangerouslyDisableSandbox: true`; if it already ran that way, re-run it once
  no sandboxed command is running. Run the `git config` or `git remote` write
  unsandboxed, or through the `update-config` skill when the target is
  `.claude/settings.json`. · `config.lock — sandbox mask, not a real lock`
- `gone` — No lock exists now; git cleaned it after the failure. Retry once. ·
  `config.lock — cleared after failure`
- `held` — A process (pid N) holds the lock. Wait for it, then retry. ·
  `config.lock — held by pid N`
- `orphan` — The lock exists outside the sandbox (N bytes, age Ns) and no
  process holds it. Retry the command unsandboxed; a second identical failure
  means the lock predates this session. · `config.lock — present, no holder`
- `unknown` — The lock exists outside the sandbox (N bytes, age Ns); no holder
  check is available here. Retry the command unsandboxed. ·
  `config.lock — present, holder unknown`

**Flag policy.** As `git-lock`.

**Live reproduction (2026-09-25): `mask`.** In this project's root, where a
sandboxed `ls` showed `.git/config.lock` as a character device and an
unsandboxed one showed no such file, a sandboxed
`sh -c 'git config sandboxlies.probe 1'` raised the config-lock error naming
`.git/config` relative; `probe_config_lock false <root>` run unsandboxed on that
text printed `mask`, `path=<root>/.git/config.lock`. The key was not written.
The same write from a script run as `sh <script>`, with no `git` on the command
line, gave the same error and the same probe output; a visible
`cd <root> && git config` and a bare `git -C <root> config` gave the same error
too. These ran in a delegated agent's session; the bare form did the same, key
unwritten, in the main session that dispatched it. That they ran sandboxed
despite `git:*` in the user settings' `sandbox.excludedCommands` rests on the
`/tmp` write test under `git-lock`'s owed `mask` reproduction, not on the mask
they hit.

**Corpus.** 4 hits, 4 true. 100%, 2026-09-03.
