# The hook at run time

How `hooks/annotate.sh` runs on each Bash call, why it can see what the tool
could not, and how a probe finds the path it checks; the arguments for D-1
(output over command), D-6 (probes in the hook) and D-13 (the two events).
`docs/design.md` §Architecture keeps the component map and one line for each
conclusion here; the per-detector mechanism is in [detectors.md](detectors.md),
[lock-detectors.md](lock-detectors.md) and [readonly-path.md](readonly-path.md).
Read this node before changing `annotate.sh`'s call sequence or a probe's path
handling.

**Flow.** The harness starts `annotate.sh` after every Bash call with the
payload on stdin: `PostToolUseFailure` when the command exited non-zero,
`PostToolUse` otherwise, never both (D-13). The script rebuilds the result text
as the model saw it, pipes it through `detect`, and stops if nothing fires. A
name its flag policy silences on this call, or with no `verdict_<name>`, is
skipped before any probe runs. For each remaining name it calls `probe_<name>`
if one exists, with the flag, the payload `cwd` and `tool_input.command` as
arguments, which prints an outcome token and its values; `verdict_<name>`, given
the outcome and the flag, prints the agent paragraph and the human line. The
paragraphs concatenate into `additionalContext`, the human lines into
`systemMessage` joined by `; `, and one JSON object goes to stdout with exit 0.

**Why the hook can see what the tool could not.** Hooks are run by the harness,
not through the Bash tool, so they are outside the command sandbox; a stat from
the hook is the "run it unsandboxed" step the memory file asked the agent to
perform. Reopen-if: a hook is ever found sandboxed. A probe that finds a
character device treats it as a mask, never as a file — unsandboxed readers have
seen masks while another session's sandbox was live.

**Output annotation, not command matching (D-1).** The pilot's one `PreToolUse`
command matcher (sandboxed `claude -p` dropping `SessionStart` hooks) found zero
true positives over 21,453 calls: every real invocation was already unsandboxed
by the `claude:*` exclusion, and the one uncovered case sat inside a `just`
recipe whose command text held no `claude` token. That failure does not
generalise to the output annotators — it was the only detector whose target
produces no output — and it is why the plugin exists at all: the pilot's rule
was "all three hold"; two held decisively and the third died for a reason
specific to its shape.

**Probes run in the hook and inject the verdict, not the test (D-6).** The
memory's longest section taught a three-way test for the lock error whose first
step was an unsandboxed `ls`. The hook performs it. A probe that has never
returned what the memory claims is an assertion, not evidence, so each is proved
once live. Accepted tradeoff: a holder check costs a few hundred milliseconds on
a hook that otherwise costs nothing.

**Paths.** A lock probe takes its path from the error text; a relative one (git
prints it from the main worktree's top-level) resolves from the nearest ancestor
of the payload's `cwd`, itself included, holding a `.git` directory, else from
the `cwd`, and with no `cwd` from the probe's working directory, never `/`.
Phantom masks sit under the sandboxed call's working directory: the session's
project root, or a subdirectory a persisted `cd` left the Bash tool in (seen on
CC 2.1.281). The `phantom-*` detectors read text and run no probe; their verdict
names the project root, the usual case.

**Failures arrive on `PostToolUseFailure` (D-13).** In the CC 2.1.280 bundle the
Bash tool raises on a non-zero exit, and the tool-failure path dispatches
`PostToolUseFailure` with the result text in an `error` string — the exit code
line, then the command's output. `PostToolUse` carries `tool_response` and fires
only on success. The Bash tool merges stderr into stdout in emission order, so
`tool_response.stderr` arrives empty; recorded live 2026-09-23, sandboxed and
unsandboxed, both payloads byte-identical to the tool result the model sees.
Nearly every symptom here is a failing command, so a `PostToolUse`-only hook
would see just the piped cases. Both events accept `additionalContext`.
Reopen-if: a recorded live payload of either event does not reproduce the text
shape the fixtures were cut from.
