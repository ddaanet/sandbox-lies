# Auto-mode classifier denials

The auto-mode permission classifier is not the sandbox:
`dangerouslyDisableSandbox` leaves the sandbox, and the classifier has no such
toggle. It refuses an agent's write to a path that configures or audits the
agent itself, whatever tool carries the write; the denials below also cover
pushes, publishing and subtrees. A denial is a guardrail, not a prompt: it is
lifted only by what its own bullet names, and one whose bullet names nothing is
final. Approval does not lift it and a retry fails identically.

## Denials, by the reason the classifier names

- **`~/.claude/settings.json` `enabledPlugins`**, and likely other startup keys:
  self-modification of the agent's startup configuration. Editing hook wiring in
  `settings.json` falls under it too.
- **A gitdir file a hook consumes.** A heredoc writing a hook's message file
  under `.git/modules/…` drew *Logging/Audit Tampering*; the same content
  through the Write tool drew *Auto Mode Bypass*, citing the agent's own note
  that the Write tool would do as intent.
- **A push to another repository or a submodule** draws
  *external repo outside the trusted source control org*. Neither
  `dangerouslyDisableSandbox` nor removing an ask rule changes it: an absent ask
  is not an allow. `/add-dir` on that repository, run by the human partner,
  clears it durably and satisfies the sandbox too; an explicit allow rule also
  works.
- **A push to the default branch `main`** is denied after a generic "push"; it
  wants the push to `main` named, or an allow rule.
- **Publishing reached for unprompted** draws *Create Public Surface*: a
  `just release minor` issued while executing a task file, with no user message
  naming a release, was denied with a `sandbox.excludedCommands` entry in place.
- **Adding a git subtree** is handed to the human partner rather than run.

## The verdict weighs the command as invoked, and who asked for it

A cross-repository push nested inside a user-named `just release` passed; the
same recipe, agent-initiated, was denied (one pair of runs, CC 2.1.263). This is
not a way to launder a denied write through a script. How the classifier judges
an unsandboxed recipe by its top-level command:
[escapes-and-costs.md](escapes-and-costs.md).

## After a denial

Stop. Where the *path* is the objection, a write through another tool after a
denied Bash call reads as tunnelling the same act. Where a destructive *verb*
is, the recoverable equivalent passes: a bare `rm` is denied where `git rm` goes
through. Write no reasoning about getting past a denial into any file; the
classifier reads it back as intent. Pick the writer the path belongs to:

- **The human partner**, through a ready-to-run `!` command, made independent of
  the working directory ([bash-tool-wrapper.md](bash-tool-wrapper.md)); for
  startup configuration, with a reminder to restart Claude Code.
- **A hook**, which runs outside both the sandbox and the classifier: an agent
  writes ordinary files, and a hook runs the git that consumes them.
