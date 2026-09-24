# sandbox-lies — design

**Status:** Planned. Nothing in this document is live; the five measured
matchers exist as pilot code in `lib/matchers.sh`. **Verified against:**
`52e6dd82b831a1cc2b7b516d4c248df6fb1ebc8c` (2026-09-22).

Changelog: [changelog.md](changelog.md). Per-detector mechanism:
[references/detectors.md](references/detectors.md). Never make a behavioural
claim from this hub that the reference does not carry.

## Now

- **Focus:** first build — promote the pilot, wrap it in the hook, add the
  probes.
- **Next:** corpus replay for the five candidate detectors; each shipped section
  leaves the memory file in the same commit.
- **Do not re-litigate:** output annotation over command matching (D-1); hooks
  do not block or rewrite (D-2); exit status is not a gate (D-4); the skill
  lives here, not in `craft` (D-9); no verdict instructs a removal (D-7);
  retirement is immediate per section (D-11).

Status legend — `Done`: implemented and pinned by a test or a gate that
re-checks it on every commit. `Done (prose)`: instructions with nothing
re-checking them. `Partial`. `Planned`.

## What this is

The Claude Code command sandbox returns output that is confidently and
specifically wrong, and nothing in the output marks it as an artefact: a
`git commit` reports a lock held by a process that does not exist, `git status`
lists dotfiles that are `/dev/null` bind-mounts, a merge dies on a healthy
repository. The failure is misplaced confidence, not an error: the agent deletes
a lock that is not stale, commits phantom files, "fixes" a hook that is not
broken.

`sandbox-lies` is a plugin whose one hook watches Bash tool **output** for those
signatures and injects a short verdict. It blocks nothing and fixes nothing.
Where the memory file it replaces could only teach a discriminator, the hook
runs it: the hook process is started by the harness outside the sandbox, so it
can stat the lock the tool could not see.

## Functional requirements

**FR-1 — Annotate, never intervene.** One hook script, registered on
`PostToolUse` and `PostToolUseFailure` with matcher `Bash`. No `PreToolUse`, no
`permissionDecision`, no `updatedInput`, no `updatedToolOutput`. The original
result stays in context beside the verdict. Where · pinned by:
`hooks/hooks.json` · `tests/hook.bats` asserts the emitted JSON carries only
`hookSpecificOutput.additionalContext` and `systemMessage`. Planned.

**FR-2 — Matcher contract.** A matcher is a shell function that reads one Bash
tool result on stdin and exits 0 when its symptom is present, 1 when it is not.
It reads output text only — never the command, never the exit status. `detect`
runs the set over one buffered copy and prints one verdict name per firing
matcher. Where · pinned by: `lib/matchers.sh` · `tests/matchers.bats`, which
asserts the full verdict set per fixture so a matcher that starts firing on a
neighbour's symptom fails rather than double-reporting. Done.

**FR-3 — One hook composes everything.** The hook script parses the payload,
rebuilds the tool-result text — the `error` string on a failure payload, stdout
then stderr from `tool_response` on a success payload — holds it in memory, runs
`detect`, runs the probe for each verdict that has one, and emits a single JSON
document. Any parse or runtime failure exits 0 with no output. Where · pinned
by: `hooks/annotate.sh` · `tests/hook.bats` over recorded payloads of both
events, plus a malformed-payload case. Planned.

**FR-4 — Probes.** For each verdict whose correct action depends on state the
tool could not see, the hook runs a discriminator outside the sandbox and the
verdict names the outcome. A probe reads the result text on stdin, takes the
flag (FR-5) as its first argument, prints an outcome token on its first line and
`key=value` lines after it; the verdict function reads both. Three probes: lock
existence and holder (`git-lock`, `config-lock`) and path writability
(`readonly-path`). Each probe is proved once against a live reproduction before
it ships; the reproduction is recorded in `references/detectors.md`. Where ·
pinned by: `lib/probes.sh` · `tests/probes.bats` over synthetic trees in
`$BATS_TEST_TMPDIR`, including a character device at the lock path and no holder
tool on `PATH`. Planned.

**FR-5 — Sandbox-state awareness.** The payload's
`tool_input.dangerouslyDisableSandbox` (absent means false) decides wording: a
symptom on a call that ran unsandboxed has a different cause, and the verdict
says so or the detector stays silent. Every detector states its flag policy in
`references/detectors.md`; the gating lives in the hook or the verdict, never in
a matcher. Where · pinned by: `hooks/annotate.sh` · `tests/hook.bats` pairs each
fixture with both flag values against that policy. Planned.

**FR-6 — Verdict text.** Each verdict is a short paragraph of acts the agent
performs, under 400 characters, and no verdict instructs removing anything
(D-7). Verdicts compose in catalogue order; the two `phantom-*` listing verdicts
share one paragraph when both fire, and a paragraph that would push
`additionalContext` past 2 KB is dropped while its human line is kept. The human
line on `systemMessage` is one lowercase clause. No verdict quotes a diagnostic
together with its follow-on sentence. Where · pinned by: `lib/verdicts.sh` ·
`tests/verdicts.bats` asserts length and runs `detect` over every verdict text
expecting silence; `tests/hook.bats` asserts the 2 KB cap on an all-verdicts
fixture. Planned.

**FR-7 — Detector catalogue.** Ten detectors, in
[references/detectors.md](references/detectors.md): five measured and shipped
from the pilot, five candidates. A candidate ships under the rule in D-15, with
its corpus figure — hit count, precision, measurement date, pilot-traffic note.
Where · pinned by: the reference's per-detector table · `tests/matchers.bats`
has a `fire-*` and a `quiet-*` fixture per shipped detector. Planned.

**FR-8 — Fixtures come from the corpus.** Every `fire-*` fixture is a verbatim
tool result cut by `tests/extract-fixtures.py` from `~/.claude/projects`; every
`quiet-*` fixture is a recorded near-miss. Hand writing a fixture encodes what
the output was expected to look like. Where · pinned by:
`tests/extract-fixtures.py` · the `fire-*` and `quiet-*` set is reproducible
from the script. Done.

**FR-9 — The symptom-less knowledge is a skill.** `excludedCommands` whole-call
semantics, the two escapes and their costs, strict mode, `$TMPDIR` scoping, a
`claude` or `git` inside a recipe, and how to write a cleanliness gate that
survives the masks fire while an agent is *writing* something, not while reading
output. That is the plugin's one skill, `skills/sandbox-lies/SKILL.md`,
triggered on those authoring moments. Where · pinned by: the skill file ·
`tests/docs.bats` runs `detect` over it. Planned.

**FR-10 — Memory retirement, per section.** The commit that lands a detector or
a skill section deletes the memory section it translates from
`memory/ddaanet/sandbox-effects.md` (D-11). The commit that empties the file
deletes it, both index lines and rewrites its six inbound `[[sandbox-effects]]`
links; the translation map in `references/detectors.md` is the audit that every
paragraph landed. One residue survives as prose: the `!`-expansion
phantom-listing rule, folded into the existing phantom-dotfile bullet of
`memory/ddaanet/shared-claude.md`. Where · pinned by: the tier's index ·
`tests/docs.bats` fails if a live pointer (`hooks/`, `lib/`, `skills/`, `tests/`
outside fixtures, `CLAUDE.md`, `README.md`) still names the retired path.
Planned.

**FR-11 — Self-quiet.** No live file in this repository fires a detector when
read back. Source files build each diagnostic literal from fragments so the
bytes on disk never hold a whole follow-on sentence. Two residuals are exempt by
name: `tests/fixtures/`, and three dated pilot files that quote live diagnostics
(`plans/2026-09-02-sandbox-detector-replay.py`,
`plans/2026-09-02-sandbox-detector-hits.jsonl`,
`plans/2026-09-03-sandbox-matcher-corpus-eval.md`) (D-10). Where · pinned by:
`tests/docs.bats` runs `detect` over every other tracked regular file. Done.

## Non-functional requirements

**NFR-1 — Precision.** A shipped detector holds the precision measured at its
last replay, and every false positive is classified. Corpus figures carry their
date and how much pilot traffic the corpus had absorbed, because the corpus is
self-polluting. Where · pinned by: `references/detectors.md` per detector · the
replay harness under `tests/`. Partial (harness promoted).

**NFR-2 — Portability.** bash 3.2, BSD `grep`/`sed`/`mktemp`, `jq`. The suite
re-runs itself with BSD-strict stubs on `PATH`. Where · pinned by:
`tests/helpers/bsd-stubs.bash` · every bats file loads it. Done.

**NFR-3 — Cost.** No verdict, no output: the hook exits 0 silently, and that
path runs after every Bash call, so its wall time on a quiet result is recorded
in the changelog at each release. With a verdict and no probe, under 100 ms.
Probes are bounded: no recursive `du`, no network, hook timeout 10 s. Where ·
pinned by: `hooks/hooks.json` timeout · `tests/hook.bats` asserts empty stdout
on quiet fixtures. Planned.

**NFR-5 — Size and links.** Every document and script is under 400 lines (a
`SKILL.md` under 200), and every relative markdown link resolves. Where · pinned
by: `scripts/check-line-limits.sh`, `scripts/check-links.sh` · both run in
`just precommit`. Partial (80-column reflow gated; the two scripts pending).

**NFR-4 — Hermetic.** The hook writes nothing (it runs outside the sandbox with
`$TMPDIR` unset) and reads only the repository the call ran in. Where · pinned
by: review; no test. Planned.

## Architecture

```
hooks/hooks.json        PostToolUse + PostToolUseFailure · "Bash" · timeout 10
hooks/annotate.sh       payload → text → detect → probes → one JSON
lib/matchers.sh         matchers + detect          (promoted from the pilot)
lib/probes.sh           probe_<verdict> functions   (layer 3)
lib/verdicts.sh         agent paragraph + human line per verdict
skills/sandbox-lies/    the symptom-less knowledge
.bin/claude             dev shim: `--plugin-dir` this checkout (D-16)
tests/                  matchers, hook, probes, verdicts, docs; fixtures/
scripts/run-bats.sh     failure-only bats wrapper
```

**Flow.** The harness starts `annotate.sh` after every Bash call with the
payload on stdin: `PostToolUseFailure` when the command exited non-zero,
`PostToolUse` otherwise, never both (D-13). The script rebuilds the result text
as the model saw it, pipes it through `detect`, and stops if nothing fires. For
each verdict it calls `probe_<verdict>` if one exists, which prints an outcome
token and its values; `verdict_<name>` prints the agent paragraph and the human
line. The paragraphs concatenate into `additionalContext`, the human lines into
`systemMessage`, and one JSON object goes to stdout with exit 0.

**Why the hook can see what the tool could not.** Hooks are run by the harness,
not through the Bash tool, so they are outside the command sandbox; a stat from
the hook is the "run it unsandboxed" step the memory file asked the agent to
perform. Reopen-if: a hook is ever found sandboxed. A probe that finds a
character device treats it as a mask, never as a file — unsandboxed readers have
seen masks while another session's sandbox was live.

**Paths.** A lock probe takes its path from the error text; git prints it
absolute, and a relative one resolves against the payload's `cwd` (what it holds
after a `cd` inside the call is unrecorded). Phantom masks sit in the session's
project root only, and the `phantom-*` detectors read text and run no probe;
their verdict says where the masks are.

The detector-by-detector mechanism — matcher shape, discriminator, probe,
verdict outcomes, corpus figure — is in
[references/detectors.md](references/detectors.md).

## Design decisions

**D-1 — Output annotation, not command matching.** Every detector reads the tool
result. The pilot's one `PreToolUse` command matcher (sandboxed `claude -p`
dropping `SessionStart` hooks) found zero true positives over 21,453 calls:
every real invocation was already unsandboxed by the `claude:*` exclusion, and
the one uncovered case sat inside a `just` recipe whose command text held no
`claude` token. That failure does not generalise to the output annotators — it
was the only detector whose target produces no output — and it is why the plugin
exists at all: the pilot's rule was "all three hold"; two held decisively and
the third died for a reason specific to its shape. Accepted tradeoff: a symptom
that never reaches the output (the `claude -p` case, `excludedCommands`
semantics) is out of hook reach and goes to the skill.

**D-2 — Annotate only.** No deny, no rewrite. A post-tool hook cannot block
anyway, and `updatedToolOutput` is validated against the tool's output shape;
`additionalContext` carries the correction with no shape contract, at the cost
of leaving the original result beside it. The result staying visible is what the
design wants: the verdict says why it is wrong. Accepted tradeoff: the injected
text reaches the model on the next API call, so a sibling call issued in the
same batch as the failing one runs before the verdict lands.

**D-3 — One hook, one process, one JSON.** Parallel hooks do not see each
other's output, so eleven separate hooks could not compose a single
`additionalContext` under the 2 KB spill. One script, registered on both
post-tool events, runs all matchers over one in-memory copy of the text; each
call fires exactly one of the two events.

**D-4 — Exit status is not a gate.** A `git commit … | tail -20` reports
`tail`'s status. Two real lock failures in the corpus have exit 0. The
discriminator for `git-lock` is git's follow-on sentence, including its final
clause; the store's own quotations of the error truncate before it.

**D-5 — Line-shape anchoring buys precision, not vocabulary.** The 22 masked
names anywhere in output give 207 corpus hits; the same names standing alone on
a `git status` line give 57 with one false positive. `config-lock` and
`phantom-gitadd` anchor at line start for the same reason: the pilot's own
reports echo the strings behind a `> ` marker.

**D-6 — Probes run in the hook and inject the verdict, not the test.** The
memory's longest section taught a three-way test for the lock error whose first
step was an unsandboxed `ls`. The hook performs it. A probe that has never
returned what the memory claims is an assertion, not evidence, so each is proved
once live. Accepted tradeoff: a holder check costs a few hundred milliseconds on
a hook that otherwise costs nothing.

**D-7 — Verdict wording follows the directive rules.** `additionalContext` is a
directive channel, so imperative acts are correct there: "re-run the same
command unsandboxed", "stage explicit paths". Mechanism, rationale and
prohibitions naming things the agent could not otherwise reach are cut. Where an
omission would read as failure, one clause of reassurance stays ("the repository
is healthy"). No verdict instructs removing a lock or a file, even
conditionally: agents remove orphan locks eagerly enough, and a verdict that
reports the lock's state is the whole of what they lack. `systemMessage` is one
lowercase clause with an em-dash, no instruction. Neither channel spells a
diagnostic and its follow-on on one line — the corpus eval report fires
`git-lock` on itself for exactly that.

**D-8 — Sandbox state from the payload.** `tool_input.dangerouslyDisableSandbox`
is on stdin. A lock error on an unsandboxed call is a real lock or the hook-env
leak, not a mask; a `No conversation found` on an unsandboxed call is not the
transcript-persistence failure. Detectors read the flag and either change
wording or stay silent. Accepted tradeoff: a call unsandboxed by
`excludedCommands` carries no flag and nothing in the payload records it, so
that case is indistinguishable from a sandboxed one; the probes cover the
verdicts where it matters (a lock that exists outside the sandbox is reported as
such whichever way the call ran).

**D-9 — The skill lives here and carries the plugin's name.** `craft`'s premise
is facts that fire on a design moment with no token to match; the escapes
knowledge has a moment (writing an exclusion, a recipe, a gate) that is
sandbox-specific, and this repository is the one place that knowledge is
maintained. Sending it to `craft` would split the retirement across two repos,
one of which is read-only from here. As the plugin's only skill it is
`sandbox-lies:sandbox-lies`; a second name would add nothing.

**D-10 — Self-reference is handled at the document, not the matcher.** Every
false positive in the corpus is this project reading its own artefacts back. The
matchers do not special-case that: a command-text suppression would need the
fixture path, which is a convention a matcher should not know. Instead the
repository's live documents are constrained never to fire a detector (FR-11),
and two residuals are accepted by name: fixture reads, and the dated pilot
evidence under `plans/`, which quotes diagnostics verbatim and is frozen.
Accepted tradeoff: `cat tests/fixtures/fire-*.txt` or a read of the layer-2
report from inside this repo annotates itself.

**D-11 — Retire each section the moment its translation lands.** A memory
section and the hook or skill text that replaces it never coexist: the commit
that ships one deletes the other. Waiting for dogfooding would keep two sources
of truth live, and the fixture suite plus the live reproduction are the evidence
a detector works. Accepted tradeoff: a ddaanet repo without the plugin loses the
fact before it gains the hook, until the plugin is released and installed there.

**D-12 — `jq` is a dependency.** Parsing the payload by hand in bash 3.2 is
where hooks go wrong; the release toolkit's version guard already requires it.

**D-13 — Failures arrive on `PostToolUseFailure`.** In the CC 2.1.280 bundle the
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

**D-14 — A lock with no holder check is `unknown`, not `orphan`.** The holder
check is `lsof -t`, then `fuser`; the Linux dev box has only the latter. With
neither, the verdict reports the lock's presence and carries no removal
instruction: a held lock also fails an identical retry, so degrading to `orphan`
would hand it the exact instruction the plugin exists to withhold.

**D-15 — Candidate ship rule.** A candidate ships when the replay finds at least
one true positive and every false positive is classified as self-reference
(D-10) or as a named residual recorded beside the figure. Any other
false-positive class tightens the matcher or keeps it a candidate. A precision
floor was rejected: on two- and four-hit bases a single hit swings precision by
tens of points, so the number would gate on noise while the classification names
what actually fired.

**D-16 — Dogfood through a `--plugin-dir` shim.** `.bin/claude` prepends
`--plugin-dir <this checkout>` and chains to the next `claude` on `PATH` with
its own directory stripped, and `.envrc` adds `.bin` last so it sits ahead of
the gitlore launcher. The marketplace route clones with submodules and aborts on
the memory submodule's relative url, and the flag typed by hand is forgotten.

## Rejected alternatives

**A `PreToolUse` matcher that unsandboxes the call.** The retired
`unsandbox-git-status` plugin pre-approved anything chained beside the
`git status` it rewrote; the `git:*` exclusion covers every git shape without a
hook.

**Prompt-based hooks.** Non-deterministic, a model call per Bash result, and the
discriminators are exact strings a regex settles for free.

**A home in `craft` or `prohibitions`.** `craft` is the wrong trigger axis
(D-9). Every `prohibitions` item forbids an action the agent is about to take;
an annotator enriches a result instead.

**Splitting `sandbox-effects` into hub and siblings first.** The content
survives either route; the file layout would be thrown away. It remains the
fallback if dogfooding shows the hook not firing.

**Filtering phantom names out of a cleanliness gate.** The mask set is
version-dependent and a filter hides real untracked files with those names. The
gate runs unsandboxed or scopes to tracked paths; that is skill content, not a
hook.

**`PostToolBatch`.** A batch carries several results; the verdict must attach to
the one call it explains.

**A `tmp-full` detector.** The one observed event — `/tmp` at 100% with `du`
accounting for a fraction — was read as other sandboxes pinning the tmpfs, but
it cannot be reproduced on demand, and a small tmpfs fills on its own often
enough to explain it. Not a sandbox lie; the memory section retires
untranslated.

**`sandbox-gotchas`, `sandbox-effects` as names.** The first promises a
catalogue, which is what moving this knowledge into hooks stops it being; the
second is the memory file's name and both would exist during the transition.

## Limitations

- **L-1** No hook fires on a `` !`cmd` `` slash-command expansion. The expansion
  executor calls the shell tool directly, below the hook dispatcher. A `/commit`
  `## Context` listing phantom dotfiles is permanently out of reach and stays
  prose.
- **L-2** A call unsandboxed by `excludedCommands` leaves no trace in the
  payload (D-8).
- **L-3** A symptom with no output — `SessionStart` hooks dropped under a
  sandboxed `claude -p`, the classifier refusing a benign compound — cannot be
  annotated.
- **L-4** Hooks load at session start; a change to this plugin needs a restart
  to observe.
- **L-5** The bundle shows the harness appending its own sandbox-violation
  annotation to a sandboxed failure's output; a Linux write refused by the
  allowlist carried none in the 2026-09-23 recording. The recorded payloads
  bound what matchers see.

## Non-goals

- Blocking, rewriting or unsandboxing anything.
- Detecting sandbox state ahead of a call.
- Suppressing this repository's own fixture reads.
