# Item 5.1 — stopped before editing: D1's observation is contradicted

Status: **stopped, no file edited, nothing staged or committed.** The skill's
edit depends on a fact D1 records, and probes in this dispatch contradict it.
Only my human partner can settle D1, so the skill was left untouched.

## The conflict

D1 says the skill should record that exclusions are "observed not honoured under
either syntax". It rests that on `git init -q /tmp/sl-exclprobe-288` (`git:*`,
CC 2.1.288) and `git init -q /tmp/sl-exclprobe-289` (`"git *"`, CC 2.1.289),
which both ran sandboxed.

The current CC docs list that probe shape among the calls that **stay sandboxed
even when covered**. Settings reference, §`sandbox.excludedCommands`, fetched
2026-10-05 from `https://code.claude.com/docs/en/settings-reference.md`:

> A `git clone`, `git init`, `git worktree add`, `git worktree move`, or
> `git bundle create` with a path argument that is absolute, starts with `~`, or
> contains a `..` segment

So the 2.288 and 2.289 runs are confounded the way the 2.281 `touch` probe was.
Under the documented rule they stay sandboxed whether or not exclusions are
honoured.

## Probes run in this dispatch (2026-10-05, CC 2.1.289, Linux)

User settings `sandbox.excludedCommands` is
`["git *", "find *", "ls *", "claude *", "just release *"]`. Each probe was a
single call with no `dangerouslyDisableSandbox`:

1. `git config --file /tmp/sl-exclprobe-cfg-289 probe.x 1` failed: could not
   lock the config file, read-only file system. It **ran sandboxed**, and the
   file does not exist.
2. `find /tmp -maxdepth 0 -fprint /tmp/sl-exclprobe-find-289` succeeded. An
   unsandboxed `ls -la` shows the file at mode `-rw-r--r--` containing `/tmp`.
   It **ran unsandboxed**: the `find *` exclusion was honoured.
3. `git status --porcelain` listed only `?? .claude/gitlore-memory-message`, no
   masks. By the skill's own one-way rule, a listing of the call's own working
   directory with no masks proves an unsandboxed run, so the `git *` exclusion
   was honoured.
4. Control: `true && git status --porcelain` (uncovered `true`) listed 20
   phantom dotfile masks. It **ran sandboxed**, as the every-command rule
   predicts.

What this shows: on CC 2.1.289, `"git *"` and `"find *"` entries are honoured
for a call whose every command they cover. Probes 1–4 are consistent with the
documented every-command rule. The git commands that stayed sandboxed both
carried an absolute `/tmp` path argument:

- `git init` is in the docs' explicit list;
- `git config --file` is not listed, but the docs' list ends "among others".

Not settled:

- whether `git:*` was honoured on 2.288;
- which git shapes beyond the listed five stay sandboxed.

Left behind: `/tmp/sl-exclprobe-find-289`, the 5-byte file from probe 2. It is
harmless and was not removed.

## What depends on the answer

These parts of the item hinge on whether exclusions are honoured:

- `SKILL.md` §Tell, first bullet ("Treat every call as sandboxed unless it
  carries `dangerouslyDisableSandbox: true`"). It would flip.
- The prescribed re-probe. A single covered `git init` or `git … /tmp/<abs>`
  writer cannot discriminate. A discriminating one is either:
  - a covered `find … -fprint /tmp/<name>`;
  - a bare covered `git status` whose own listing shows no masks.
- Every "where honoured" qualifier: `SKILL.md` §Writing and §Leaving,
  `excluded-commands.md`'s opening and "Not honoured" block,
  `escapes-and-costs.md`'s opening, `masks-and-gates.md`'s `` !`cmd` ``
  paragraph and `recipes-and-claude.md`'s two mentions.
- Item 5.2's `lock-detectors.md` paragraphs, which D1 also drives.

These parts do not depend on it, and the docs fetched today confirm them:

- **The rule.** Entries apply "only when they cover every command in it".
  Calls that stay sandboxed:
  - `sudo`, `eval`, `xargs` heads;
  - `cd`, `pushd` or `popd` anywhere;
  - a command substitution, a subshell, or `if`/`for` blocks;
  - a redirection other than a descriptor duplication;
  - a command name from a variable;
  - the git path-argument rule above.

  `sandboxing.md` §Run commands outside the sandbox adds that `git -C` stays
  sandboxed, in its git-network example.
- **Syntax.** `docker *`, ending in ` *`.
- **Strict mode.** `sandbox.allowUnsandboxedCommands: false`, shown in the
  `/sandbox` Overrides tab as **Strict sandbox mode**. Under it, commands are
  sandboxed unless they match an `excludedCommands` entry.
- **Auto-allow exceptions.** `sandboxing.md` §Sandbox modes lists three: plan
  mode, an auto-mode command carrying per-command allowed domains, and
  server-side classifier review of sandboxed commands in auto mode.
- **The classifier decision order.** In `permission-modes.md` §How the
  classifier evaluates actions, read-only and sandboxed shell commands wait for
  server-side review where the session has it.
- **The main-session qualifier** for the persisted `cd`, the re-ranked cwd list,
  and the batching fix.

## Question for my human partner

Should the skill record exclusions as honoured on CC 2.1.289 for a fully covered
call, with the git absolute-path shapes kept sandboxed, using probes 2–4 above?
Or should it keep D1's "observed not honoured"?

Default if unanswered: the former, with the re-probe changed to a bare covered
`git status` from the project root that shows no masks. Item 5.2's
`lock-detectors.md` text then needs the same correction.
