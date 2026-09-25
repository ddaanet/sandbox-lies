# Detectors

The mechanism behind `docs/design.md` FR-7. One entry per detector: the memory
section it replaces, the matcher's discriminator, the probe and its outcomes,
the verdict text per outcome, and the corpus figure. A detector without a corpus
figure is a candidate and does not ship.

Conventions. A **matcher** reads the tool-result text on stdin and exits 0/1; it
never reads the command or the exit status. The text is the `error` string of a
`PostToolUseFailure` payload, or `tool_response.stdout`, a newline and
`tool_response.stderr` of a `PostToolUse` payload. Recorded live on CC 2.1.280
on 2026-09-23 (`tests/fixtures/payload-*.json`), sandboxed and unsandboxed
alike: the Bash tool merges stderr into stdout in emission order, so
`tool_response.stderr` arrives empty and `error` is the exit-code line followed
by that merged output — byte-identical to the tool result the model sees. Both
events carry `hook_event_name` and a `cwd`, which was the session's working
directory; no recorded call changed directory, so where a `cd` inside the call
leaves `cwd` is unrecorded. A sandboxed write refused by the allowlist carried
no harness sandbox-violation annotation in the payload or in the model's tool
result (L-5). A **probe** runs in the hook process, outside the sandbox, reads
the same text on stdin with the flag as its first argument and the payload `cwd`
as its second, and prints an outcome token on its first line followed by
`key=value` lines. The **flag** is `tool_input.dangerouslyDisableSandbox` from
the payload, absent from `tool_input` when unset (read as false) and `true` when
set (recorded 2026-09-23); every detector states its **flag policy** — what
happens when the call ran unsandboxed. Verdict text is given as the agent
paragraph, then the human line. No entry here quotes a diagnostic together with
its follow-on sentence, and candidate strings are described rather than quoted,
so that this file stays quiet under the detectors it specifies.

Corpus: 21,453 Bash tool-use/result pairs, 1,682 JSONL files, 35 projects,
measured 2026-09-03 with the shell matchers as arbiter
(`plans/2026-09-03-sandbox-matcher-corpus-eval.md`). The corpus is
self-polluting — sessions studying the detectors add hits to `git-lock` and
`phantom-gitadd` — so every figure carries its date.

## Shipped from the pilot

### git-lock

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
the path is absent.

**Verdicts.**

- `mask` — The lock in this error is a sandbox artefact; no such file exists
  outside the sandbox and the repository is healthy. Re-run the same command
  with `dangerouslyDisableSandbox: true`. A repeat failure on a commit whose
  hook stages files is that hook leaking `GIT_INDEX_FILE`, not the sandbox. ·
  `index.lock — sandbox mask, no file exists`
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
`sh -c 'git add f && git commit -m x'` in that scratch repo — nested so the
`git:*` exclusion does not lift it — committed cleanly, its hook's staging
included, as a 2026-09-23 attempt had: that session's sandbox masked
`.git/config.lock` in the project root but no `index.lock` there or in the
scratch repo, so the error never arose and the probe had no text to read.

### config-lock

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

**Verdicts.** As `git-lock`, naming `config.lock`; the `mask` paragraph adds:
run the `git config` or `git remote` write unsandboxed, or through the
`update-config` skill when the target is `.claude/settings.json`.

**Flag policy.** As `git-lock`.

**Live reproduction (2026-09-25): `mask`.** In this project's root, where a
sandboxed `ls` showed `.git/config.lock` as a character device and an
unsandboxed one showed no such file, a sandboxed
`sh -c 'git config sandboxlies.probe 1'` raised the config-lock error naming
`.git/config` relative; `probe_config_lock false <root>` run unsandboxed on that
text printed `mask`, `path=<root>/.git/config.lock`. The key was not written.

**Corpus.** 4 hits, 4 true. 100%, 2026-09-03.

### phantom-chardev

Replaces the listing half of `Phantom dotfiles: the /dev/null masks`.

**Matcher.** A line whose first non-blank field is a character-device mode
string (leading `c`, nine permission characters). Every corpus hit was genuine,
across eight repos, half of them incidental `ls -la` calls where the agent was
not investigating the sandbox. A real device listing (`ls -la /dev`) would
match; none exists in the corpus.

**Probe.** None.

**Verdict.** The character-device entries in this listing are sandbox masks over
dotfiles in the project root, not files in the repository. Leave them out of
every add, delete and report. With no sandboxed command running in the
background, `ls -a` and `git status` run unsandboxed show the real tree. ·
`phantom dotfiles — sandbox masks in listing`

**Flag policy.** Fires either way with the same verdict: masks have been seen
from unsandboxed readers while another session's sandbox was live, and the
listing is wrong in both cases. When both listing detectors fire on one result,
one paragraph is emitted.

**Corpus.** 17 hits, 17 true. 100%, 2026-09-03.

### phantom-untracked

Replaces the `git status` half of the same section.

**Matcher.** At least two distinct names from the masked set standing alone on a
status-shaped line (`??` prefix or leading whitespace, optional trailing slash).
The masked set is the 22 paths measured 2026-08-15. Threshold 2 buys nothing
above it (≥2 gives 41 hits, ≥5 gives 40) and is kept for the one real listing
with only two names.

**Probe.** None.

**Verdict.** As `phantom-chardev`, with: a cleanliness check that reads these
`??` lines as dirty is reading the sandbox, not the tree. ·
`phantom dotfiles — masks listed as untracked`

**Flag policy.** As `phantom-chardev`.

**Corpus.** 57 hits, 56 true, 1 fixture read. 98%, 2026-09-03.

### phantom-gitadd

Replaces the `git add -A` paragraph.

**Matcher.** A line beginning with git's `error:` prefix and ending in its "can
only add regular files, symbolic links or git-directories" refusal.
Line-anchored; the store's changelog quotes the error and its follow-on in one
sentence, so the follow-on test does not separate these.

**Probe.** None.

**Verdict.** `git add` aborted on a sandbox mask, not a file. Stage explicit
paths, or re-run the same command unsandboxed. ·
`git add — refused a sandbox mask`

**Flag policy.** Fires either way, same verdict.

**Corpus.** 3 hits, 2 true, 1 fixture read. 67% on a two-hit base; re-measure
once this repository's traffic stops entering the corpus.

## Candidates

Each needs a layer-1 replay, a shape discriminator the replay selects (line
start, the tool's own prefix, a follow-on), and its fixtures cut before it ships
under D-15. A candidate with a probe builds it only once the detector ships.

### readonly-path

Replaces `Harness-mounted config paths are busy/read-only`,
`Sibling worktree writes`, and cost 3 of `Leaving the sandbox` (a recipe's
`inter-device move failed`).

**Matcher.** The kernel's read-only-filesystem message (EROFS) or its
busy-device message (EBUSY), in the tool's own prefixed form (`git`'s "unable to
unlink", `mv`'s "inter-device move failed", a bare `touch` or `cp` refusal); the
discriminator is selected at replay. Expected residual: a genuinely read-only
mount.

**Flag policy.** Silent when the flag is true.

**Probe.** Extract the first quoted path from the matching line; `test -w` on
it, or on its parent when it does not exist.

| outcome | condition |
|---|---|
| `writable` | writable outside the sandbox |
| `readonly` | not writable outside either |
| `nopath` | no path extracted |

**Verdicts.**

- `writable` — `<path>` is writable outside the sandbox; the failure is the
  sandbox's write allowlist. Re-run the whole call with
  `dangerouslyDisableSandbox: true`. For `.claude/settings.json`, use the
  `update-config` skill instead. A merge or checkout that died here may have
  updated some files already: compare modified files against the target before
  retrying. · `read-only — sandbox allowlist, writable outside`
- `readonly` — `<path>` is not writable outside the sandbox either; this is not
  a sandbox effect. · `read-only — real`
- `nopath` — the `writable` paragraph without the path.

### tmpdir-unset

Replaces cost 1 of `Leaving the sandbox`.

**Matcher.** A permission or missing-file refusal naming a path directly under
`/` (a single path component after the root), the shape an empty `$TMPDIR`
expansion produces.

**Flag policy.** Fires only when the flag is true; silent otherwise.

**Verdict.** `$TMPDIR` is unset outside the sandbox, so the path collapsed to
`/`. Use the literal scratch path `/tmp/claude/<job>` (create it with
`mkdir -p`) in this and every unsandboxed or delegated command. ·
`$TMPDIR — unset unsandboxed`

### resume-lost

Replaces `--resume dies because the transcript never persisted`.

**Matcher.** `claude`'s resume refusal naming a session id it cannot find.

**Flag policy.** Fires only when the flag is false; unsandboxed, the cause is
elsewhere.

**Verdict.** The transcript was never written: `~/.claude/projects` is read-only
inside the sandbox. Run the entire multi-turn flow in one unsandboxed call. ·
`--resume — transcript not persisted in sandbox`

### zellij-socket

Replaces `zellij IPC socket is outside the sandbox`.

**Matcher.** zellij's no-active-session refusal.

**Flag policy.** Fires only when the flag is false.

**Verdict.** The zellij session exists; its socket is outside the sandbox.
Re-run the same command with `dangerouslyDisableSandbox: true`. ·
`zellij — socket unreachable from sandbox`

### seccomp-init

Replaces `Sandbox setup itself fails`.

**Matcher.** The seccomp apply failure naming the user-namespace `unshare` with
an invalid-argument errno, alone on its line.

**Flag policy.** Cannot occur on an unsandboxed call; silent if the flag is
true.

**Verdict.** The sandbox failed to initialise before the command ran; this is
transient. Retry the identical command once; if it fails the same way, split it
into smaller calls. Escape the sandbox only after both. ·
`sandbox init failed — transient, retry`

## Translation map

Where each section of `memory/ddaanet/sandbox-effects.md` lands. Every paragraph
must map before the file is deleted (FR-10); the audit that confirms it is a
Phase 6 step.

| memory section | lands in |
|---|---|
| baseline exclusions and their reach | skill |
| `.git/index.lock`: three causes | `git-lock`; "do not fix the hook" → the `mask`/`gone` leak clause |
| `.git/config.lock` paragraph | `config-lock` |
| phantom dotfiles: masks, who sees them | `phantom-chardev`, `phantom-untracked`; zero-byte shape → skill |
| phantom dotfiles: `git add -A` | `phantom-gitadd` |
| phantom dotfiles: porcelain gate | skill |
| phantom dotfiles: visible unsandboxed | flag policy of the `phantom-*` detectors |
| phantom dotfiles: `## Context` is a Bash call | L-1; `shared-claude.md` bullet; skill (`!`-expansion facts) |
| harness-mounted config paths; merge recovery | `readonly-path`; recovery clause in its verdict and the skill |
| sibling worktree writes | `readonly-path` |
| leaving the sandbox: escapes, strict mode, read-only default | skill |
| cost 1, `$TMPDIR` unset and unstable | `tmpdir-unset`; instability → skill |
| cost 2, classifier and compounds | skill |
| cost 3, recipes entirely unsandboxed | `readonly-path`; skill |
| `excludedCommands` whole-call semantics | skill |
| `ps` cannot see background tasks | skill |
| `--resume` transcript never persisted | `resume-lost`; eval-harness consequence → skill |
| zellij socket | `zellij-socket` |
| sandboxed `claude -p` drops `SessionStart` | skill |
| sandbox setup fails | `seccomp-init` |
| `/tmp` reads full | dropped — not a sandbox effect (design, rejected alternatives) |

## Not detectors

- **`ps` shows only the agent's shell.** Detectable only by reading the command
  word, which the contract forbids, and an empty listing is not a symptom in the
  output. Skill content.
- **Sandboxed `claude -p` drops `SessionStart` hooks.** No output symptom (D-1).
  Skill content.
- **`excludedCommands` semantics, the classifier refusing benign compounds,
  strict mode.** No symptom in a tool result. Skill content.
- **A slash command's `## Context` listing masks.** No hook runs on the
  `!`-expansion path (L-1). One line in the shared conventions file.
