# The hook at run time

How `hooks/annotate.sh` runs on each Bash call, why it can see what the tool
could not, and how a probe finds the path it checks; the arguments for D-1
(output over command), D-6 (probes in the hook) and D-13 (the two events); and
the registration in `hooks/hooks.json`, with the `SessionStart` check that says
when `jq` (D-12) is missing. `docs/design.md` §Architecture keeps the component
map and one line for each conclusion here; the per-detector mechanism is in
[detectors.md](detectors.md), [lock-detectors.md](lock-detectors.md) and
[readonly-path.md](readonly-path.md). Read this node before changing
`annotate.sh`'s call sequence, a probe's path handling, or `hooks/hooks.json`.

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

**Registration.** `hooks/hooks.json` holds three entries, each a single command
hook of the form `bash "${CLAUDE_PLUGIN_ROOT}/hooks/<script>"` with a 10 s
`timeout`: `annotate.sh` on `PostToolUse` and on `PostToolUseFailure`, both with
matcher `Bash`, and `check-jq.sh` on `SessionStart` with no matcher. Running the
script through `bash`, with the root quoted inside the command string, makes the
executable bit and a space in the plugin root irrelevant. On `SessionStart` a
matcher filters the start source (`startup`, `resume`, `clear`, `compact`); with
none the check fires on all four, so the notice is issued again after a `clear`
or a `compact`, either of which can leave the conversation without the first
one. The `SessionStart` entry takes the annotate entries' 10 s bound (NFR-3)
rather than the harness default. Pinned by `tests/hook.bats` "hooks.json names
the three events": exactly these three event keys (FR-1: no `PreToolUse`), one
entry each, the `Bash` matcher on the two annotate entries and no matcher key on
the `SessionStart` one, each `timeout` and each command string.

**When `jq` is missing (D-12).** `annotate.sh` parses the payload with `jq`;
without it that first call fails and the script exits 0 with nothing on stdout
(FR-3), so every Bash result goes unannotated and nothing says so.
`hooks/check-jq.sh` says so at each session start. It ignores stdin and tests
`command -v jq`, which resolves `jq` as `annotate.sh`'s own bare call will, an
exported function of that name included. When `jq` resolves, it prints nothing.
Otherwise it prints one fixed JSON object with a single `printf`, with no
interpolation and no external tool, so the notice needs no `jq` to be emitted.
The object carries two channels:

- `systemMessage`, for the user: one line naming the plugin, that `jq` was not
  found on `PATH`, and that Bash result annotations are off until it is
  installed. It opens with a style reset written as the JSON escape `\u001b[0m`,
  since a raw ESC byte would make the object invalid JSON. The reset lifts the
  line out of the dimming Claude Code applies to ordinary hook output, which
  suits a hook that speaks only when something is wrong.
- `hookSpecificOutput.additionalContext`, with `hookEventName` `SessionStart`,
  for the agent: annotations are off because `jq` is not on `PATH`, no Bash
  result carries a sandbox-lies note until it is, and a result without one is to
  be read as unchecked, not as undistorted. "Until it is" holds within the
  session: `annotate.sh` looks `jq` up on every call, so a `jq` that appears on
  `PATH` restores the annotations without a restart.

The script writes no file, needs no temp directory, and exits 0 on every path.
Pinned by `tests/check-jq.bats`, which runs the command string registered in
`hooks.json` from a working directory outside the checkout: silent with `jq` on
`PATH`; with a cleared environment and a `PATH` holding no `jq`, exactly one
JSON object, no raw ESC byte, `systemMessage` opening with the reset and naming
`jq`, the `SessionStart` event name, `additionalContext` naming `jq`, empty
stderr and exit 0; and the same stdout with `TMPDIR` naming a missing directory
and with the BSD stubs ahead on `PATH`. No test pins the wording beyond the `jq`
name.

**Why the hook can see what the tool could not.** Hooks are run by the harness,
not through the Bash tool, so they are outside the command sandbox; a stat from
the hook is the "run it unsandboxed" step the memory file asked the agent to
perform. Reopen-if: a hook is ever found sandboxed. A probe that finds a
character device treats it as a mask, never as a file — unsandboxed readers have
seen masks while another session's sandbox was live.

**Output annotation, not command matching (D-1).** The pilot's one `PreToolUse`
command matcher (sandboxed `claude -p` dropping `SessionStart` hooks) found zero
true positives over 21,453 calls. The pilot read every real invocation as
already unsandboxed by the `claude:*` exclusion. That is what the configuration
implied, not an observed run, and an entry frees only a call whose every command
it covers. The one uncovered case sat inside a `just` recipe whose command text
held no `claude` token. That failure does not generalise to the output
annotators — it was the only detector whose target produces no output — and it
is why the plugin exists at all: the pilot's rule was "all three hold"; two held
decisively and the third died for a reason specific to its shape.

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

**Dogfood through the toolkit's shim (D-16).** `plugin-dev/bin/claude`, vendored
with the release toolkit, syncs the plugin into `dist/plugin/` at launch (and on
`just dogfood`) and chains to the next `claude` on `PATH` with that copy as its
plugin dir; `.envrc` adds `plugin-dev/bin` last so it sits ahead of the gitlore
launcher. The marketplace route clones with submodules and aborts on the memory
submodule's relative url, and the flag typed by hand is forgotten. Loading the
working tree itself, as the earlier `.bin/claude` shim did with `--plugin-dir`,
left agent edits in the checkout without a permission verdict and ran
half-edited hook scripts.
