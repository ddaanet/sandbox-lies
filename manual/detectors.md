<!-- No entry quotes a diagnostic together with its follow-on sentence, and
quoted strings are described rather than copied, so that this file stays quiet
when the detectors read it back. -->

# Detectors

Each detector reads the text of a Bash result, never the command, and fires only
on the shape the failing tool itself prints. It matches the shape of a line, so
a quotation set inside a sentence does not fire, but a log holding the line
verbatim fires when it is read back. When a detector fires, the agent receives a
short paragraph and you a one-line notice; both are given below for each
outcome, the paragraph first, then the notice after a `·`. Where the answer
depends on the machine, the hook first runs a check outside the sandbox, and its
outcome picks the paragraph. How the hook runs and where its checks look is in
[The hook](hook.md).

A call made with `dangerouslyDisableSandbox: true` is an *unsandboxed call*
below. A call that a `sandbox.excludedCommands` entry unsandboxed carries no
such flag, so the hook reads it as sandboxed.

Nine detectors ship. A tenth, for zellij's socket being unreachable from the
sandbox, is not shipped: no recorded session has shown its symptom.

## git-lock

**Fires on** git's refusal to create a lock file that already exists, together
with git's follow-on sentence about another git process, complete through its
final clause about this repository. Exit status is not consulted, so a failure
piped into `tail` still fires.

**Check.** The hook looks at the lock path outside the sandbox, then asks which
process holds it, with `lsof`, else `fuser`:

- `mask` — the path is a character device, whichever way the call ran.
- `gone` — the lock is absent, whichever way the call ran.
- `held` — the lock exists and a process holds it.
- `orphan` — the lock exists and the holder check found no holder.
- `unknown` — the lock exists and no holder check was possible: neither tool is
  on `PATH`, or the check failed. A lock with no holder check is never reported
  as `orphan`, since a process may still hold it.

**Unsandboxed calls.** Fires either way. The flag no longer picks between `mask`
and `gone`: it words the re-run and the retry, `gone`'s included. The cause of a
missing lock is hedged when the flag is absent because nothing in the payload
records an `excludedCommands` exclusion, and a lock its holder has released
leaves nothing at the path, as a sandbox mask does. The labels below therefore
key on the flag, not on how the call ran: a call an exclusion unsandboxed reads
as flag absent. *Re-run* and *Retry* below stand for:

- flag absent or false — "Once no sandboxed command is running, re-run the same
  command with `dangerouslyDisableSandbox: true`" and "Retry the command with
  `dangerouslyDisableSandbox: true`";
- flag true — "Re-run the same command once no sandboxed command is running" and
  "Retry the command once".

**What it says.**

- `mask` — The lock in this error is a sandbox artefact and the repository is
  healthy. *Re-run*. A repeat failure on a commit whose hook stages files is
  that hook leaking `GIT_INDEX_FILE`, not the sandbox. ·
  `index.lock — sandbox mask, not a real lock`
- `gone`, flag true — No lock exists now; git cleaned it after the failure.
  Retry once. A repeat failure on a commit whose hook stages files is that hook
  leaking `GIT_INDEX_FILE`, not the sandbox. ·
  `index.lock — cleared after failure`
- `gone`, flag absent or false — No lock exists now: this refusal came from a
  sandbox mask or from a lock its holder has since released. *Retry*. A repeat
  failure on a commit whose hook stages files is that hook leaking
  `GIT_INDEX_FILE`, not the sandbox. ·
  `index.lock — absent now, mask or released`
- `held` — A process (pid N) holds the lock. Wait for it, then retry. ·
  `index.lock — held by pid N`
- `orphan` — The lock exists outside the sandbox (N bytes, age Ns) and no
  process holds it. *Retry*; a second identical failure means the lock predates
  this session. · `index.lock — present, no holder`
- `unknown` — The lock exists outside the sandbox (N bytes, age Ns); no holder
  check is available here. *Retry*. · `index.lock — present, holder unknown`

No outcome tells the agent to remove the lock.

## config-lock

**Fires on** git's refusal to lock a config file because its lock exists, at the
start of a line: `git config`, `git remote add` and the toolkit's
`just update-plugin-dev` produce it.

**Check and unsandboxed calls.** As `git-lock`, on the config file's lock.

**What it says.** `git-lock`'s outcomes, naming `config.lock`, without the
`GIT_INDEX_FILE` clause. When the lock is a `.claude/settings.json.lock`, the
`mask` paragraph, under either flag, and the `gone` paragraph, when the flag is
absent or false, say to write `.claude/settings.json` through the
`update-config` skill instead of *Re-run* or *Retry*.

- `mask` — The `config.lock` behind this error is a sandbox artefact and the
  repository is healthy. *Re-run*. ·
  `config.lock — sandbox mask, not a real lock`
- `gone`, flag true — No lock exists now; git cleaned it after the failure.
  Retry once. · `config.lock — cleared after failure`
- `gone`, flag absent or false — No lock exists now: this refusal came from a
  sandbox mask or from a lock its holder has since released. *Retry*. ·
  `config.lock — absent now, mask or released`
- `held` — A process (pid N) holds the lock. Wait for it, then retry. ·
  `config.lock — held by pid N`
- `orphan` — The lock exists outside the sandbox (N bytes, age Ns) and no
  process holds it. *Retry*; a second identical failure means the lock predates
  this session. · `config.lock — present, no holder`
- `unknown` — The lock exists outside the sandbox (N bytes, age Ns); no holder
  check is available here. *Retry*. · `config.lock — present, holder unknown`

## phantom-chardev

**Fires on** a listing line whose mode string marks a character device: the
`/dev/null` masks the sandbox lays over dotfiles, as `ls -l` shows them. A real
device listing, such as `ls -la /dev`, fires too.

**Unsandboxed calls.** Fires either way, with the same paragraph: masks are
visible to unsandboxed readers too while another sandboxed command runs. When
this detector and `phantom-untracked` both fire on one result, one paragraph is
given.

**What it says.** The character-device entries in this listing are sandbox
masks, not files in the repository. Leave them out of every add, delete and
report. With no sandboxed command running in the background, `ls -a` and
`git status` run unsandboxed show the real tree. ·
`phantom dotfiles — sandbox masks in listing`

## phantom-untracked

**Fires on** at least two names from the set of paths the sandbox masks, each
alone on a `git status` line: after `??`, or indented as in the long format.

**Unsandboxed calls.** As `phantom-chardev`.

**What it says.** As `phantom-chardev`, opening "The dotfile entries" in place
of "The character-device entries", with: a cleanliness check that reads these
`??` lines as dirty is reading the sandbox, not the tree. ·
`phantom dotfiles — masks listed as untracked`

## phantom-gitadd

**Fires on** `git add` refusing a path because it is not a regular file, a
symbolic link or a git directory, at the start of a line after git's `error:`
prefix.

**Unsandboxed calls.** Fires either way, same paragraph.

**What it says.** `git add` aborted on a sandbox mask, not a file. Stage
explicit paths, or re-run the same command unsandboxed. ·
`git add — refused a sandbox mask`

## readonly-path

**Fires on** a write refused because the file system is read-only or the device
busy, on a line that begins with the refusing tool's own prefix (`cp`, `mv`,
`rm`, `touch`, bash with its line number, git's `error`, `fatal` or `warning`)
and ends with the kernel's message, or on Python's exception line for the same
two errors.

**Check.** The hook takes the refused path from the line and tests outside the
sandbox whether it, or its parent when it does not exist, is writable:

- `writable` — writable outside the sandbox.
- `readonly` — not writable outside either.
- `nopath` — no path could be read from the line.

**Unsandboxed calls.** Silent.

**What it says.**

- `writable` — `<path>` is writable outside the sandbox, whose allowlist refused
  it. Then the act below. · `read-only — sandbox allowlist, writable outside`
- `readonly` — `<path>` is not writable outside the sandbox either; this is not
  a sandbox effect. Unsandboxing will not help: write somewhere writable, or ask
  before changing its permissions. · `read-only — real`
- `nopath` — The sandbox's write allowlist most likely refused this write. Then
  the act below. · `read-only — probably the sandbox, path not checked`

The act is the first of these that applies:

- every command in the call only reads files, and one file it reads has a
  command-output name (`*.log`, `*.output`, `*.out`, `*.err`) — re-run the
  command that wrote that file, since the refusal in it came from that call;
- the path is a `.claude/settings.json` (`writable` only), the call ran no git
  `merge`, `pull`, `checkout`, `switch`, `rebase` or `cherry-pick`, and the text
  holds no git partial-checkout error — write `.claude/settings.json` through
  the `update-config` skill;
- otherwise — re-run the whole call with `dangerouslyDisableSandbox: true`.

A recovery clause replaces the act when the text holds git's partial-checkout
error, whatever command printed it, or when the call ran one of those git
commands and modified files already match the target it was moving to.

The clause tells you to run `sandbox-lies-recover -C <repo> <kind> <ref>` with
`dangerouslyDisableSandbox: true` and read its plan when the script's invocation
is exactly what the call ran; the `sandbox-lies:sandbox-lies` skill says how to
carry the plan out. That takes one such git command in the call, running where
the hook looks (no `-C`, `--git-dir` or `--work-tree`, no `cd` or `pushd` before
it, and the refused path in the working directory's repository), with one target
and no `--`, no option but `-q`, `--quiet` and `--ff-only`, and for a `checkout`
or `switch` a local branch. Otherwise the clause points at the skill's recovery
of a refused merge or checkout.

The clause does not say where HEAD is, since a checkout can move HEAD although
git reported an error and exited 0. It removes nothing and never asks for the
script's `--apply`. If the refusal came from a file the call read, the re-run of
the command that wrote that file follows the clause as its own sentence. With no
partial-checkout error and no matching file, there is no clause and the act
applies.

## tmpdir-unset

**Fires on** a tool's own refusal naming a path of one component directly under
`/`, with a permission-denied or missing-file message: the shape a `$TMPDIR`
that expanded empty leaves behind.

**Unsandboxed calls.** Fires only on an unsandboxed call; silent otherwise.

**What it says.** `$TMPDIR` expanded empty in this unsandboxed call, so the path
collapsed to `/`. Use the literal scratch path `/tmp/claude/<job>` (create it
with `mkdir -p`) in this and every unsandboxed or delegated command. ·
`$TMPDIR — expanded empty, path collapsed to /`

## resume-lost

**Fires on** `claude`'s refusal to resume because no conversation has the given
session ID, at the start of a line and ending with the ID.

**Check.** The hook looks for that session's transcript under the config
directory's `projects/`, the directory Claude Code itself uses:
`CLAUDE_CONFIG_DIR` when set in the session, else `~/.claude`. A
`CLAUDE_CONFIG_DIR=` prefix on the Bash call itself is not seen. Transcripts
under `archived/` or `subagents/` are not searched.

- `lost` — some session in the refusal has no transcript.
- `found` — every one has.
- `unknown` — nothing could be checked; the hook says nothing.

**Unsandboxed calls.** The check decides under either flag: whether a transcript
was written depends on the call that should have written it, not on the call
that resumes it.

**What it says.**

- `lost` — The transcript was never written: `~/.claude/projects` is read-only
  inside the sandbox. Run the entire multi-turn flow in one unsandboxed call. ·
  `--resume — transcript not persisted in sandbox`
- `found` — A transcript for this session exists, so the sandbox did not lose it
  and an unsandboxed retry will not help. `--resume` finds a session from any
  working directory: check that this call reads the config directory that holds
  the transcript (`CLAUDE_CONFIG_DIR`, else `~/.claude`). ·
  `--resume — transcript exists, not the sandbox`

## seccomp-init

**Fires on** the sandbox's seccomp setup failing on the user-namespace `unshare`
with an invalid-argument error, alone on its line: the sandbox failed to start
before the command ran.

**Unsandboxed calls.** Cannot occur; silent.

**What it says.** The sandbox failed to initialise before the command ran; this
is transient. Retry the identical command once; if it fails the same way, split
it into smaller calls. Escape the sandbox only after both. ·
`sandbox init failed — transient, retry`
