# The hook at run time

How `hooks/annotate.sh` runs on each Bash call, why it can see what the tool
could not, and how a probe finds the path it checks. `docs/design.md`
§Architecture keeps the component map and one line for each conclusion here; the
per-detector mechanism is in [detectors.md](detectors.md) and
[lock-detectors.md](lock-detectors.md). Read this node before changing
`annotate.sh`'s call sequence or a probe's path handling.

**Flow.** The harness starts `annotate.sh` after every Bash call with the
payload on stdin: `PostToolUseFailure` when the command exited non-zero,
`PostToolUse` otherwise, never both (D-13). The script rebuilds the result text
as the model saw it, pipes it through `detect`, and stops if nothing fires. A
name its flag policy silences on this call, or with no `verdict_<name>`, is
skipped before any probe runs. For each remaining name it calls `probe_<name>`
if one exists, which prints an outcome token and its values; `verdict_<name>`
prints the agent paragraph and the human line. The paragraphs concatenate into
`additionalContext`, the human lines into `systemMessage` joined by `; `, and
one JSON object goes to stdout with exit 0.

**Why the hook can see what the tool could not.** Hooks are run by the harness,
not through the Bash tool, so they are outside the command sandbox; a stat from
the hook is the "run it unsandboxed" step the memory file asked the agent to
perform. Reopen-if: a hook is ever found sandboxed. A probe that finds a
character device treats it as a mask, never as a file — unsandboxed readers have
seen masks while another session's sandbox was live.

**Paths.** A lock probe takes its path from the error text; a relative one (git
prints it from the main worktree's top-level) resolves from the nearest ancestor
of the payload's `cwd`, itself included, holding a `.git` directory, else from
the `cwd`, and with no `cwd` from the probe's working directory, never `/`.
Phantom masks sit in the session's project root only, and the `phantom-*`
detectors read text and run no probe; their verdict says where the masks are.
