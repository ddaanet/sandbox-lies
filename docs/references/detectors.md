# Detectors

The mechanism behind `docs/design.md` FR-7. One entry per detector: the memory
section it replaces, the matcher's discriminator, the probe and its outcomes,
the verdict text per outcome, and the corpus figure. A detector without a corpus
figure is a candidate and does not ship. The two lock detectors keep a stub here
and their entries in [lock-detectors.md](lock-detectors.md); read it before
making a claim about, or changing, either one.

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

Replaces `.git/index.lock: one error string, three causes`. Fires on git's lock
error only with its follow-on sentence complete; the hook probes the lock
outside the sandbox, and the verdict names one of five outcomes. Matcher, probe,
flag policy, verdicts, corpus and live reproductions:
[lock-detectors.md](lock-detectors.md#git-lock).

### config-lock

Replaces the `.git/config.lock` paragraph of the same section and the
`git config` / `git remote add` / `just update-plugin-dev` shape. Fires on git's
config-lock error at a line start; the probe and outcomes are `git-lock`'s, on
the config file's lock. Matcher, probe, flag policy, verdicts, corpus and live
reproduction: [lock-detectors.md](lock-detectors.md#config-lock).

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
Measured 2026-09-25 by that replay, then `tests/corpus-eval.py` over 55,896 Bash
pairs, a scratch shell matcher as arbiter; a hit is a match the flag lets fire.

### readonly-path

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

**Probe.** Extract the first quoted path from the matching line; `test -w` on
it, or on its parent when it does not exist.

| outcome | condition |
|---|---|
| `writable` | writable outside the sandbox |
| `readonly` | not writable outside either |
| `nopath` | no path extracted |

**Live reproduction (2026-09-26): `writable`.** Scratch repo under
`/tmp/claude/` with a linked worktree directly under `/tmp/`, outside the
sandbox's write allowlist, both made unsandboxed; CC 2.1.281, `/bin/sh` dash. A
sandboxed `sh -c 'touch <worktree>/<file>'` raised touch's read-only error
naming the file in straight quotes; a `touch` directly under `/tmp/` in the same
call raised the same error, so that call was sandboxed. `detect` on that text
named `readonly-path`, and `probe_readonly_path false <root>` run unsandboxed on
it printed `writable`, `path=<worktree>/<file>`. Neither file was written; the
worktree was removed unsandboxed.

**Verdicts.**

- `writable` — `<path>` is writable outside the sandbox, whose allowlist refused
  the write. Re-run the whole call with `dangerouslyDisableSandbox: true` or, if
  it only read a command-output file such as a `*.log`, the command that wrote
  that file. For `.claude/settings.json`, use the `update-config` skill. A merge
  or checkout that died here may be partial: compare modified files against the
  target first. · `read-only — sandbox allowlist, writable outside`
- `readonly` — `<path>` is not writable outside the sandbox either; this is not
  a sandbox effect. · `read-only — real`
- `nopath` — The sandbox's write allowlist most likely refused this write, then
  the `writable` paragraph from `Re-run` on. · `read-only — sandbox allowlist`

The read clause covers the corpus's command-output reads below: the refusal in
such a file came from the call that wrote it, so re-running the read changes
nothing.

**Corpus.** 162 hits, 161 true, 1 the residual (`mkdir` of a path directly under
`/`, left by an empty variable). 99% on 2026-09-25; 11 hits this project's
traffic. True: sandbox refusals under `/tmp`, `~/.cache`, `~/.claude`, sibling
repositories, harness-mounted config and the masks, and four reads of a file
with a command-output name — a background task's `*.output`, a `*.log` —
carrying an earlier sandboxed call's refusal. Any such name (`*.out`, `*.err`
and the like too) is a legitimate flag; a `*.md` or other document carrying one
is material about sandbox effects, self-reference (D-10).

**Decision: ships.**

### tmpdir-unset

Replaces cost 1 of `Leaving the sandbox`.

**Matcher.** A line that begins with a tool's own prefix (as `readonly-path`),
optionally bash's `line N` locator, naming a path of one component directly
under `/` — bare, or in straight or GNU curly quotes after the tool's own words
— and ends in a colon, a space and the permission-denied or missing-file
message, trailing blanks allowed. That is the shape an empty `$TMPDIR` expansion
produces; a refusal on a deeper path is the near-miss.

**Flag policy.** Fires only when the flag is true; silent otherwise.

**Verdict.** `$TMPDIR` expanded empty in this unsandboxed call, so the path
collapsed to `/`. Use the literal scratch path `/tmp/claude/<job>` (create it
with `mkdir -p`) in this and every unsandboxed or delegated command. ·
`$TMPDIR — expanded empty, path collapsed to /`

**Corpus.** 13 hits, 13 true, each a `$TMPDIR` path collapsed to `/`. 100% on
2026-09-25; no pilot traffic. The 182 matches without the flag are silent
(sandboxed collapses, deliberately missing paths).

**Caveat (2026-09-26).** On CC 2.1.281 an unsandboxed call's `$TMPDIR` read
`/tmp`, not unset, so the collapse may not occur unsandboxed on current CC; the
13 hits predate that observation. The verdict states only what the flagged call
shows, never that the variable is always unset outside the sandbox.

**Decision: ships.**

### resume-lost

Replaces `--resume dies because the transcript never persisted`.

**Matcher.** `claude`'s resume refusal from the start of its line — no prefix of
its own — naming the session ID it cannot find, then the id (hex digits and
hyphens) and nothing but trailing blanks. The store quotes it mid-line.

**Flag policy.** Fires only when the flag is false; unsandboxed, the cause is
elsewhere.

**Verdict.** The transcript was never written: `~/.claude/projects` is read-only
inside the sandbox. Run the entire multi-turn flow in one unsandboxed call. ·
`--resume — transcript not persisted in sandbox`

**Corpus.** 2 hits, 2 true, one gitlore session reproducing the loss on
2026-07-17. 100% on 2026-09-25, a two-hit base; no pilot traffic. A third match,
resuming an all-zero id on purpose, had the flag set: silent.

**Decision: ships.**

### zellij-socket

Replaces `zellij IPC socket is outside the sandbox`.

**Matcher.** zellij's no-active-session refusal at a line start, measured for
want of a live instance to select a shape.

**Flag policy.** Fires only when the flag is false.

**Verdict.** The zellij session exists; its socket is outside the sandbox.
Re-run the same command with `dangerouslyDisableSandbox: true`. ·
`zellij — socket unreachable from sandbox`

**Corpus.** 0 hits, zero true positives, 2026-09-25; unanchored and case-blind,
67 matches, all quoting the store.

**Decision: stays a candidate.**

### seccomp-init

Replaces `Sandbox setup itself fails`.

**Matcher.** The seccomp apply failure naming the user-namespace `unshare` with
an invalid-argument errno, alone on its line from its start (trailing blanks
allowed): live, it is the whole result. The store quotes it mid-line.

**Flag policy.** Cannot occur on an unsandboxed call; silent if the flag is
true.

**Verdict.** The sandbox failed to initialise before the command ran; this is
transient. Retry the identical command once; if it fails the same way, split it
into smaller calls. Escape the sandbox only after both. ·
`sandbox init failed — transient, retry`

**Corpus.** 8 hits, 8 true, all on 2026-08-14 in edify, handoff and gitlore.
100% on 2026-09-25; no pilot traffic.

**Decision: ships.**

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
| cost 1, `$TMPDIR` collapse and instability | `tmpdir-unset`; instability → skill; its top-level-classifier note moved to cost 3 |
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
