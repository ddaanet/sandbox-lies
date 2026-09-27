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
the same text on stdin with the flag, the payload `cwd` and `tool_input.command`
as its arguments, and prints an outcome token on its first line followed by
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

**Verdict.** As `phantom-chardev`, opening "The dotfile entries" in place of
"The character-device entries", since a status lists names and not modes, with:
a cleanliness check that reads these `??` lines as dirty is reading the sandbox,
not the tree. · `phantom dotfiles — masks listed as untracked`

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

**Probe.** Extract the path from the matching line, printed as `path=`;
`test -w` on it, or on its parent when it does not exist. The path is the first
single-quoted segment, straight or curly as a UTF-8 locale prints it, except
after `mv`'s `to`, which names the target. Unquoted, it is read in four fixed
forms only, each right after the tool's own prefix: bash's `line N: <path>:`,
dash's `N: cannot create <path>:`, git's
`error: could not lock config file <path>:` and `fatal: cannot mkdir <path>:`.
Any other unquoted shape is `nopath`. An unquoted path runs to the line's last
colon and space, since the kernel message after it holds none, so a path holding
blanks, `: ` or its form's own words is read whole. A relative path joins onto
the payload `cwd`. Residuals: a quoted path holding its own closing quote, which
the tool prints escaped, is cut at that quote or yields `nopath`; a curly-quoted
or unquoted path holding two straight quotes is read as what lies between them.
Git names the path in its partial-checkout errors from the worktree's top-level,
so from a subdirectory or under `git -C` the path is wrong, and one whose parent
is missing reads `readonly`, which carries no merge clause.

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
| `partial=1` | the text holds git's partial-checkout error, `unable to unlink old`, `unable to create file` or `cannot create directory at`, under any command |
| `target=<ref>` | with `merge=1`: the first word after a `merge`, `checkout` or `switch` subcommand, before any `--`, that resolves to a commit |
| `match=<file>` | with `target=`: one line per file modified against HEAD, staged or not, whose working-tree content equals the target's |
| `readfile=<path>` | every command in the call's pipelines and lists is a reader — `cat`, `head`, `tail`, `grep`, `sed` without in-place editing, `awk`, `cut`, `sort`, `uniq`, `wc`, `tr`, `less` — with no output redirection, and an argument has a command-output name: `*.log`, `*.output`, `*.out`, `*.err` |

The repository for `target=` and `match=` is the one holding the path's nearest
existing directory, else the payload `cwd`'s. Git reads run with optional locks
off, so the probe writes nothing (NFR-4). Word splitting is safe for `target=`,
since a ref name holds no blank; `readfile=` honours single and double quotes.
Residuals: `merge=1` read off the command alone does not show that the git
segment died, so a call whose merge or checkout succeeded before another
command's write was refused gets it too; its clause then rests on `match=`
lines, which a finished checkout leaves none of. A partial checkout whose text
lost git's error — cut by a `tail`, or sent to a file — and whose target does
not resolve gets no clause. `partial=1` does not check which git command printed
the error, so a `stash` or `restore` dying on the same error counts too. A file
whose name holds a newline is never a `match=` or a `readfile=`; a reader behind
a `cd`, or a reader or git behind a variable assignment, is not recognised. The
scan does not parse `$( )`, backticks, subshells, braces or `$'…'`, so their
contents read as words of the command around them; it stops at the end of a line
holding `<<`, and after 16384 characters, and neither cut command yields
`readfile=`. A `>` anywhere in a word counts as output redirection, as do
`sort -o` and `awk -i`. A candidate ref holding `@{`, `^{`, `:` or a leading `-`
is skipped. With an unborn HEAD, or past 1000 files modified against HEAD, no
`target=` is printed. A file matches byte for byte, before any clean filter, and
never as a symlink.

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

**Verdicts.**

- `writable` — `<path>` is writable outside the sandbox, whose allowlist refused
  it. Then the tail below. · `read-only — sandbox allowlist, writable outside`
- `readonly` — `<path>` is not writable outside the sandbox either; this is not
  a sandbox effect. Unsandboxing will not help: write somewhere writable, or ask
  before changing its permissions. · `read-only — real`
- `nopath` — The sandbox's write allowlist most likely refused this write. Then
  the tail below. · `read-only — probably the sandbox, path not checked`

The tail is one act, the first of these whose fact the probe printed:

- `readfile=` — re-run the command that wrote `<readfile>`
- `path=` names a `.claude/settings.json` (`writable` only) — write
  `.claude/settings.json` through the `update-config` skill
- otherwise — re-run the whole call with `dangerouslyDisableSandbox: true`

The act stands alone as its own sentence, capitalised, unless a merge clause
leads into it, lowercase. With `merge=1`, the probe's facts select the clause:

- `match=` lines — The merge or checkout left files at the target with HEAD
  unmoved, blocking a re-run: restore `<a>`, `<b>` from HEAD — they match
  `<target>` —, then *act*. Five names at most, then `and N more`.
- no `target=`, and `partial=1` — The merge or checkout left the files it wrote
  with HEAD unmoved, blocking a re-run: restore them from HEAD, then *act*.
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
must map before the file is deleted (FR-10); the audit that confirms it is Item
8.2 of the build runbook.

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
| `excludedCommands` whole-call semantics | skill |
| `ps` cannot see background tasks | skill |
| `--resume` transcript never persisted | `resume-lost`; eval-harness consequence → skill |
| zellij socket | `zellij-socket` |
| sandboxed `claude -p` drops `SessionStart` | skill |
| sandbox setup fails | `seccomp-init` |
| `/tmp` reads full | dropped — not a sandbox effect (design, rejected alternatives) |

## Not detectors

- **A sandboxed `ps` shows only the agent's shell.** Detectable only by reading
  the command word, which the contract forbids, and an empty listing is not a
  symptom in the output. Skill content.
- **Sandboxed `claude -p` drops `SessionStart` hooks.** No output symptom (D-1).
  Skill content.
- **`excludedCommands` semantics, the classifier refusing benign compounds,
  strict mode.** No symptom in a tool result. Skill content.
- **A slash command's `## Context` listing masks.** No hook runs on the
  `!`-expansion path (L-1). One line in the shared conventions file.
