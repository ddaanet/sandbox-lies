## Brief: a sandboxed checkout that trips on `.claude/settings.json` still moves HEAD

2026-10-31, from autodrive-handoff. A finding and a proposal, not a decision.

### Decisions

- None taken here. What follows is one observation and what it suggests for the
  skill.

### Constraints

- Seen once, in the autodrive-handoff repository; not reproduced in this
  repository's suite. The Claude Code version was not recorded.

### Rejected approaches

- `git checkout HEAD -- .claude/settings.json` to restore the stranded file:
  auto mode's classifier refused it as Irreversible Local Destruction.

### Additional context

What happened:

- A sandboxed `git checkout <branch>` between two branches whose
  `.claude/settings.json` differ failed with
  `error: unable to unlink old '.claude/settings.json': Device or resource busy`,
  yet switched the branch. HEAD moved. The file kept the old branch's content
  and showed as modified.
- The `PostToolUse` annotation then pointed at `update-config`, the act for a
  settings edit. That is the wrong act for a checkout.
- Running the checkout unsandboxed avoids the failure. When the stranded copy is
  the version a following fast-forward brings in, `git add` of it lets that
  fast-forward proceed.
- The project's `.claude/settings.json` is on the sandbox's `denyWithinAllow`
  list, the same class as the live `hooks/hooks.json` the skill names.

How it differs from `skills/sandbox-lies/SKILL.md`, "Recovering a merge a
sandbox refusal killed":

- That section has HEAD unmoved after the refusal. Here HEAD moved, so a reader
  following it diffs against a target that is already checked out, and the
  denied file is the only casualty.
- Its step 2, `git checkout HEAD -- <files>`, is the restore auto mode refused.

Proposal:

- Add the case where HEAD moves: check `git log -1` and `git status` before
  assuming the pre-merge commit, and name the denied-write file as the likely
  sole casualty.
- Name the auto-mode refusal of the step 2 restore, and the `git add` route for
  a stranded copy equal to the version the next fast-forward brings in.
- Consider whether the `PostToolUse` annotation can tell a checkout or merge
  from a settings edit before it names `update-config`.

### Reproduced at triage

2026-10-31, git 2.47.3, unsandboxed scratch repository under `$TMPDIR`: two
branches differing in `d/f` and `g`, the second adding `h`, with `d` made
read-only by `chmod 555`.

- `git checkout b` printed the unlink error for `d/f` and still switched the
  branch, **exiting 0**. HEAD is at `b`, and `d/f` shows modified with the old
  content. Every other file is at `b`.
- `git merge --ff-only b` printed the same error and exited 1, HEAD unmoved at
  `a`, with `g` updated and `h` untracked: the case the skill already describes.

So the skill's "Recovering a merge a sandbox refusal killed" claims HEAD unmoved
for both commands, and that holds for the merge only. A checkout's exit status
does not show the failure either. `skills/sandbox-lies/SKILL.md` is at the
200-line hub cap, so the fix moves that section into a `references/` node.
