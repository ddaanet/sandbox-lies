# Detectors

The mechanism behind `docs/design.md` FR-7. One entry per detector: the memory
section it replaces, the matcher's discriminator, the probe and its outcomes,
the verdict text per outcome, and the corpus figure. A detector without a corpus
figure is a candidate and does not ship (D-15, below). The two lock detectors
and `readonly-path` keep a stub here and their entries in
[lock-detectors.md](lock-detectors.md) and [readonly-path.md](readonly-path.md);
read the node before making a claim about, or changing, one of them.

**Candidate ship rule (D-15).** A candidate ships when the replay finds at least
one true positive and every false positive is classified as self-reference
(D-10) or as a named residual recorded beside the figure. Any other
false-positive class tightens the matcher or keeps it a candidate. A precision
floor was rejected: on two- and four-hit bases a single hit swings precision by
tens of points, so the number would gate on noise while the classification names
what actually fired.

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
leaves `cwd` is unrecorded. A related question is open: in the main session the
Bash tool keeps a top-level `cd` between calls (seen on CC 2.1.281), and whether
the payload `cwd` then follows the persisted directory or stays the session's is
not recorded. The lock probes and `readonly-path`'s probe resolve a relative
path against that `cwd`, so the answer decides where they look. A sandboxed
write refused by the allowlist carried no harness sandbox-violation annotation
in the payload or in the model's tool result (L-5). A **probe** runs in the hook
process, outside the sandbox, reads the same text on stdin with the flag, the
payload `cwd` and `tool_input.command` as its arguments, and prints an outcome
token on its first line followed by `key=value` lines. The **flag** is
`tool_input.dangerouslyDisableSandbox` from the payload, absent from
`tool_input` when unset (read as false) and `true` when set (recorded
2026-09-23); every detector states its **flag policy** — what happens when the
call ran unsandboxed. Verdict text is given as the agent paragraph, then the
human line. No entry here quotes a diagnostic together with its follow-on
sentence, and candidate strings are described rather than quoted, so that this
file stays quiet under the detectors it specifies.

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

**Verdict.** The character-device entries in this listing are sandbox masks, not
files in the repository. Leave them out of every add, delete and report. With no
sandboxed command running in the background, `ls -a` and `git status` run
unsandboxed show the real tree. · `phantom dotfiles — sandbox masks in listing`

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
above it and is kept for the one real listing with only two names: in the
pilot's layer-1 replay (2026-09-02, 21,272 Bash pairs,
`plans/2026-09-02-sandbox-detector-replay-results.md`), ≥2 gave 41 hits and ≥5
gave 40. That replay's Python form required four or more blanks before a name,
so it missed the tab-indented long-format block; its 41 is an undercount of the
57 below.

**Probe.** None.

**Verdict.** As `phantom-chardev`, opening "The dotfile entries" in place of
"The character-device entries", since a status lists names and not modes, with:
a cleanliness check that reads these `??` lines as dirty is reading the sandbox,
not the tree. · `phantom dotfiles — masks listed as untracked`

**Flag policy.** As `phantom-chardev`.

**Corpus.** 57 hits, 56 true, 1 fixture read. 98%, 2026-09-03, over the
21,453-pair corpus above with the shell matcher as arbiter.

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
pairs; a hit is a match the flag lets fire. Each shipped candidate's figure was
then re-measured over the same extraction with its shipped matcher as arbiter,
and none moved (`plans/sandbox-lies/reports/item-4-2-s1-code-review.md`,
`plans/sandbox-lies/reports/item-4-3-s1-green.md`).

### readonly-path

Replaces `Harness-mounted config paths are busy/read-only`,
`Sibling worktree writes`, and cost 3 of `Leaving the sandbox` (a recipe's
`inter-device move failed`). Fires on a tool's own-prefix error line; the probe
checks the named path outside the sandbox. Matcher, probe, flag policy, Probe
facts, verdicts, live reproductions, corpus and decision:
[readonly-path.md](readonly-path.md#readonly-path).

### tmpdir-unset

Replaces cost 1 of `Leaving the sandbox`.

**Matcher.** A line that begins with a tool's own prefix (as
[`readonly-path`](readonly-path.md#readonly-path)), optionally bash's `line N`
locator, naming a path of one component directly under `/` — bare, or in
straight or GNU curly quotes after the tool's own words — and ends in a colon, a
space and the permission-denied or missing-file message, trailing blanks
allowed. That is the shape an empty `$TMPDIR` expansion produces; a refusal on a
deeper path is the near-miss.

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

**Probe.** `probe_resume_lost` takes every session id from a refusal line in the
text, the line shape the matcher anchors on, and tests each for a regular file
`<config dir>/projects/*/<id>.jsonl`. The config dir is CC's own resolution:
`CLAUDE_CONFIG_DIR` when set, else `$HOME/.claude`, read from the hook's
environment, the session's, not the Bash call's: a `CLAUDE_CONFIG_DIR=` prefix
on the call never reaches the probe, which is why `found` fits E5 below. The
search is a shell glob over the project directories, so it never derives a
project-directory name from the `cwd`; the ids are hex digits and hyphens, safe
inside a glob. The transcript is tested for existence only, never opened, and
the probe prints no key lines. Outcomes:

- `lost` — some id has no transcript.
- `found` — every id has one.
- `unknown` — nothing checkable: no id extracted, `CLAUDE_CONFIG_DIR` set but
  empty, or it unset and `HOME` unset or empty; a config dir whose `projects/`
  is missing or cannot be listed (a relative `CLAUDE_CONFIG_DIR`, resolved
  against the hook's directory, is the likeliest); or an id with no hit while a
  project directory cannot be listed, since the transcript may sit in it. The
  verdict has no text for it, so the hook is silent.

Residuals: `archived/` and `subagents/` sit below the glob's depth and are not
searched, and whether `--resume` reads `archived/` is untested. The fire
fixture's ids have no transcript, so reading the fixture still gives `lost`
(D-10).

**Flag policy.** None: the probe decides under either flag. Whether a transcript
was written depends on the call that should have written it, not on the call
that resumes it, and a call an exclusion unsandboxed carries no flag anyway
([sandbox-state.md](sandbox-state.md)).

**Verdicts.**

- `lost` — The transcript was never written: `~/.claude/projects` is read-only
  inside the sandbox. Run the entire multi-turn flow in one unsandboxed call. ·
  `--resume — transcript not persisted in sandbox`
- `found` — A transcript for this session exists, so the sandbox did not lose it
  and an unsandboxed retry will not help. `--resume` finds a session from any
  working directory: check that this call reads the config directory that holds
  the transcript (`CLAUDE_CONFIG_DIR`, else `~/.claude`). ·
  `--resume — transcript exists, not the sandbox`

**Live reproduction (2026-10-07, CC 2.1.292).** Linux bubblewrap, with
`~/.claude/projects` in the sandbox's write deny list; each sandboxed call
proved its own state with a write test there that failed read-only in the same
call, and every call ran `claude -p` with `--model haiku` from a scratch
directory (`plans/sandbox-lies-review-fixes-2/resume-probe-evidence.md`).

- E1, unsandboxed: a new session in directory A wrote its transcript.
- E2, sandboxed, from A: `--resume` of that session answered with no refusal,
  but its turn was not persisted.
- E3, unsandboxed, from directory B, another project: the resume answered and
  appended to the original file under A's project directory. `-p --resume <id>`
  finds a session in any project directory under the config dir.
- E3s, sandboxed, from B: the resume answered too. So neither the sandbox nor a
  project mismatch makes `--resume` refuse a transcript that exists.
- E4, sandboxed, from B, the fixture's shape: a session started sandboxed left
  no transcript, its resume printed the refusal, and the installed hook fired
  with this detector's verdict.
- E5, unsandboxed, from A, `CLAUDE_CONFIG_DIR` naming an empty directory: the
  resume of E1's session was refused. A different config dir is the observed
  cause for a transcript that exists, which the `found` verdict names.

Not tested: interactive `--resume` (the picker) and `--continue`.

**Corpus.** 2 hits, 2 true, one gitlore session reproducing the loss on
2026-07-17. 100% on 2026-09-25, a two-hit base; no pilot traffic. A third match,
resuming an all-zero id on purpose, had the flag set and was silent under the
flag policy the detector then had; with none, it would read `lost`, a false
positive, since no transcript was meant to exist.

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

Where each section of `memory/ddaanet/sandbox-effects.md` lands. Every section
the plugin carries maps to a detector or the skill (FR-10); the file stays for
the two that map nowhere.

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
| sibling worktree writes | `readonly-path`; its classifier note moved to cost 2 |
| leaving the sandbox: escapes, strict mode, read-only default | skill |
| cost 1, `$TMPDIR` collapse and instability | `tmpdir-unset`; instability → skill; its top-level-classifier note moved to cost 3 |
| cost 2, classifier and compounds | skill |
| cost 3, recipes entirely unsandboxed | `readonly-path`; skill |
| `excludedCommands` whole-call semantics | skill, corrected: an entry frees only a call whose every command it covers |
| `ps` cannot see background tasks | skill |
| `--resume` transcript never persisted | `resume-lost`; eval-harness consequence → skill |
| zellij socket | stays in memory: `zellij-socket` is a candidate under D-15 |
| phantom dotfiles that outlive their command (the leak) | stays in memory: no detector |
| sandboxed `claude -p` drops `SessionStart` | skill |
| sandbox setup fails | `seccomp-init` |
| `/tmp` reads full | dropped — not a sandbox effect (design, rejected alternatives) |

## Not detectors

- **A sandboxed `ps` shows only the agent's shell.** Detectable only by reading
  the command word, which the contract forbids, and an empty listing is not a
  symptom in the output. Skill content.
- **Sandboxed `claude -p` drops `SessionStart` hooks.** No output symptom (D-1).
  Skill content.
- **Which calls an `excludedCommands` entry unsandboxes, the classifier refusing
  benign compounds, strict mode.** No symptom in a tool result: an entry frees
  only a call whose every command it covers, and nothing records that it did.
  Skill content.
- **A slash command's `## Context` listing masks.** No hook runs on the
  `!`-expansion path (L-1). One line in the shared conventions file.
