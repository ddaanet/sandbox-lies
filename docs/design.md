# sandbox-lies — design

**Status:** Built and tested: the hook, the `phantom-*` and lock verdicts, the
hook's lock and `resume-lost` probe calls, the recovery script
`bin/sandbox-lies-recover`, the `tmpdir-unset`, `resume-lost` and `seccomp-init`
verdicts, the `readonly-path` verdicts composed from their probe's facts, the
`SessionStart` `jq` check, and the skill. Dogfooded 2026-09-27 on CC 2.1.283,
before the `resume-lost` probe, the `printf %q` `path=` form with its decoder,
and the worktree-top join; no later dogfood run is recorded.

This document is a hub; `references/` holds one node per mechanism — per
detector in [references/detectors.md](references/detectors.md), the hook at run
time in [references/hook.md](references/hook.md), each requirement's pins in
[references/requirements-coverage.md](references/requirements-coverage.md),
verdict wording in
[references/verdict-wording.md](references/verdict-wording.md), self-quiet files
in [references/self-quiet.md](references/self-quiet.md). Read the node before
making a claim about, or changing, the mechanism it argues; never make a
behavioural claim from this hub that a node does not carry.

## Now

- **Do not re-litigate:** output annotation over command matching (D-1); hooks
  do not block or rewrite (D-2); exit status is not a gate (D-4); the skill
  lives here, not in `craft` (D-9); no verdict instructs a removal (D-7);
  retirement is immediate per section (D-11); the script decides conditions
  (D-17).

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

Every symptom, discriminator and corpus figure here was recorded on Linux, where
the sandbox is bubblewrap. NFR-2 makes the scripts portable to macOS tools, but
the macOS sandbox's messages and masks are unverified.

## Functional requirements

**FR-1 — Annotate, never intervene.** One hook script, registered on
`PostToolUse` and `PostToolUseFailure` with matcher `Bash`. No `PreToolUse`, no
`permissionDecision`, no `updatedInput`, no `updatedToolOutput`. The original
result stays in context beside the verdict. A second script, `hooks/check-jq.sh`
on `SessionStart`, annotates nothing: it speaks only when `jq` is missing
(D-12). Done.

**FR-2 — Matcher contract.** A matcher is a shell function that reads one Bash
tool result on stdin and exits 0 when its symptom is present, 1 when it is not.
It reads output text only — never the command, never the exit status. `detect`
runs the set over one in-memory copy and prints one verdict name per firing
matcher. Done.

**FR-3 — One hook composes everything.** The hook script parses the payload,
rebuilds the tool-result text — the `error` string on a failure payload, stdout
then stderr from `tool_response` on a success payload — holds it in memory, runs
`detect`, runs the probe for each verdict that has one, and emits a single JSON
document. Any parse or runtime failure exits 0 with no output. Done.

**FR-4 — Probes.** For each verdict whose correct action depends on state the
tool could not see, the hook runs a discriminator outside the sandbox and the
verdict names the outcome. A probe reads the result text on stdin, takes the
flag (FR-5), the payload `cwd` and `tool_input.command` as its arguments, prints
an outcome token on its first line and `key=value` lines after it (a `path=`
value is printed in `printf %q` form); the verdict function reads both, and the
flag. Four probes: lock existence and holder (`git-lock`, `config-lock`), path
writability (`readonly-path`), which also reports the command facts and the
partial-merge files its acts depend on (D-17), and transcript existence
(`resume-lost`). Each probe is proved once against a live reproduction before it
ships; the reproduction is recorded in `references/` (for `resume-lost`, CC's
behaviour its probe reads, not a run of the probe on a live refusal). Done.

**FR-5 — Sandbox-state awareness.** The payload's
`tool_input.dangerouslyDisableSandbox` (absent means false) decides wording: a
symptom on a call that ran unsandboxed has a different cause, and the verdict
says so or the detector stays silent, except `resume-lost`, whose probe decides
under either value (D-8). Every detector states its flag policy in
`references/`; the gating lives in the hook or the verdict, never in a matcher.
Done.

**FR-6 — Verdict text.** Each verdict is a short paragraph of acts the agent
performs, under 400 characters before a probe value (a path, a pid) is
interpolated, stating only the acts the script found apply (D-17), and no
verdict instructs removing anything (D-7). Verdicts compose in catalogue order;
the two `phantom-*` listing verdicts share one paragraph when both fire, and a
paragraph that would push `additionalContext` past 2 KB is dropped while its
human line is kept. The human line on `systemMessage` is one lowercase clause.
No verdict quotes a diagnostic together with its follow-on sentence. Done.

**FR-7 — Detector catalogue.** Ten detectors, in
[references/detectors.md](references/detectors.md): five measured and shipped
from the pilot, five candidates. A candidate ships under the rule in D-15, with
its corpus figure — hit count, precision, measurement date, pilot-traffic note.
Done (four candidates shipped; `zellij-socket` stays a candidate under D-15).

**FR-8 — Fixtures come from the corpus.** Every `fire-*` fixture is a verbatim
tool result cut by `tests/extract-fixtures.py` from `~/.claude/projects`; every
`quiet-*` fixture is a recorded near-miss. Hand writing a fixture encodes what
the output was expected to look like. Done.

**FR-9 — The symptom-less knowledge is a skill.** Which calls an
`excludedCommands` entry unsandboxes (only one whose every command it covers),
the two escapes and their costs, strict mode, `$TMPDIR` scoping, a `claude` or
`git` inside a recipe, and how to write a cleanliness gate that survives the
masks fire while an agent is *writing* something, not while reading output. That
is the plugin's one skill, `skills/sandbox-lies/SKILL.md`, triggered on those
authoring moments. Done.

**FR-10 — Memory retirement, per section.** The commit that lands a detector or
a skill section deletes the memory section it translates from
`memory/ddaanet/sandbox-effects.md` (D-11). Every section the plugin carries is
retired. The file keeps what it does not: the phantom-dotfile leak, and the
zellij section, whose detector stays a candidate under D-15. One residue
survives as prose: the `!`-expansion phantom-listing rule, folded into the
existing phantom-dotfile bullet of `memory/ddaanet/shared-claude.md`. Done
(prose).

**FR-11 — Self-quiet.** No live file in this repository fires a detector when
read back. Source files build each diagnostic literal from fragments so the
bytes on disk never hold a whole follow-on sentence. Two residuals exempt by
name, listed in [references/self-quiet.md](references/self-quiet.md) (D-10).
Done.

**FR-12 — Recovery script.** `bin/sandbox-lies-recover` carries out the recovery
of a `git checkout <branch>` or `git merge --ff-only <commit-ish>` that a
sandbox refusal killed part-way. Without `--apply` it prints the plan and
changes nothing; with `--apply` it runs each act as it prints it. Exit 0 is
nothing left to do, a plan carried out or a dry run printed; 1 a failed re-run
or act; 2 a usage error or a state it cannot tell. Its use is in
`skills/sandbox-lies/references/refused-merge-recovery.md`. Done.

## Non-functional requirements

**NFR-1 — Precision.** A shipped detector holds the precision measured at its
last replay, and every false positive is classified. Corpus figures carry their
date and how much pilot traffic the corpus had absorbed, because the corpus is
self-polluting. Done (not gated).

**NFR-2 — Portability.** bash 3.2, BSD `grep`/`sed`/`mktemp`/`stat`/`wc`, `jq`.
A suite whose code under test calls one of those five tools keeps one case
re-run with BSD-strict stubs on `PATH`. The code under test is what the suite's
assertions are about: a library it only runs to build its input
(`verdicts*.bats` pipe text through `lib/matchers.sh`) is covered by its own
suites. Done.

**NFR-3 — Cost.** No verdict, no output: the hook exits 0 silently, and that
path runs after every Bash call. With a verdict and no probe, a mean under 100
ms. Probes are bounded: no recursive `du`, no network, hook timeout 10 s, the
`SessionStart` check's too. Done (not gated).

**NFR-4 — Hermetic.** The hook writes nothing (it runs outside the sandbox,
where `$TMPDIR` may be unset). It reads only what the result names: the
repository holding a refused path, possibly a sibling worktree rather than the
call's, or with no path the payload `cwd`'s; the lock paths the error names; and
whether each session id a `--resume` refusal names has a transcript, never
opening one. Done (partly not gated).

**NFR-5 — Size and links.** Every document, script, awk, TOML or JSON file and
`justfile` is at most 400 lines (a `SKILL.md` at most 200), and every inline
relative link resolves (reference style unchecked). Done.

## Architecture

```
hooks/hooks.json        PostToolUse + PostToolUseFailure · "Bash" · timeout 10;
                        SessionStart · no matcher · timeout 10
hooks/annotate.sh       payload → text → detect → probes → one JSON
hooks/check-jq.sh       SessionStart: a notice when jq is missing; annotates nothing
bin/sandbox-lies-recover  recovery of a refused checkout or ff-only merge (FR-12)
lib/matchers.sh         matchers + detect          (promoted from the pilot)
lib/probes.sh           probe_<verdict> functions   (layer 3)
lib/probes-readonly*.sh probe_readonly_path, its D-17 facts and command scan
lib/verdicts.sh         agent paragraph + human line per verdict
lib/verdicts-locks.sh   the same, for git-lock and config-lock
skills/sandbox-lies/    the symptom-less knowledge
manual/                 user documentation: the detectors, the hook
tests/                  matchers, hook, probes, verdicts, docs; fixtures/
plugin-dev/run-bats.sh   failure-only bats wrapper (vendored toolkit)
scripts/check-*.sh      link gate, NFR-5
```

The harness starts `annotate.sh` outside the command sandbox, so a probe's stat
is the unsandboxed step the memory file asked the agent to take (reopen-if: a
hook is ever found sandboxed), and a character device at a probed path is a
mask. The call flow and that argument are in
[references/hook.md](references/hook.md).

The detector-by-detector mechanism — matcher shape, discriminator, probe, corpus
figure — is in [references/detectors.md](references/detectors.md); what the hook
and each detector say is in the manual, [`manual/`](../manual/detectors.md).

## Design decisions

**D-1 — Output annotation, not command matching.** Every detector reads the tool
result; the pilot's one command matcher found no true positive. Argued in
[references/hook.md](references/hook.md). Accepted tradeoff: a symptom that
never reaches the output (the `claude -p` case, `excludedCommands` semantics) is
out of hook reach and goes to the skill.

**D-2 — Annotate only.** No deny, no rewrite. A post-tool hook cannot block
anyway, and `updatedToolOutput` is validated against the tool's output shape;
`additionalContext` carries the correction with no shape contract, at the cost
of leaving the original result beside it. The result staying visible is what the
design wants: the verdict says why it is wrong. Accepted tradeoff: the injected
text reaches the model on the next API call, so a sibling call issued in the
same batch as the failing one runs before the verdict lands.

**D-3 — One hook, one process, one JSON.** Parallel hooks do not see each
other's output, so nine separate hooks, one per shipped detector, could not
compose a single `additionalContext` under the 2 KB spill. One script,
registered on both post-tool events, runs all matchers over one in-memory copy
of the text; each call fires exactly one of the two events.

**D-4 — Exit status is not a gate.** A `git commit … | tail -20` reports
`tail`'s status. Two real lock failures in the corpus have exit 0. The
discriminator for `git-lock` is git's follow-on sentence, including its final
clause; the store's own quotations of the error truncate before it.

**D-5 — Line-shape anchoring buys precision, not vocabulary.** The 22 masked
names anywhere in output gave 207 hits in the pilot's layer-1 replay
(2026-09-02); the same names standing alone on a `git status` line give 57 with
one false positive over the 2026-09-03 corpus `references/detectors.md` names.
`config-lock` and `phantom-gitadd` anchor at line start for the same reason: the
pilot's own reports echo the strings behind a `> ` marker.

**D-6 — Probes run in the hook and inject the verdict, not the test.** Each
probe is proved once live before it ships. Argued in
[references/hook.md](references/hook.md).

**D-7 — Verdict wording follows the directive rules.** No verdict instructs a
removal; `additionalContext` is a directive channel, so imperative acts are
correct there. Argued in
[references/verdict-wording.md](references/verdict-wording.md).

**D-8 — Sandbox state from the payload.** Detectors read
`tool_input.dangerouslyDisableSandbox` and either change wording or stay silent.
`resume-lost` ignores it: its probe tests the transcript itself. Accepted
tradeoff: a call an exclusion unsandboxed carries no flag, so a covered `git`
whose lock was gone by probe time reads `gone`, which with the flag absent names
both causes and whose retry is harmless. Argued in
[references/sandbox-state.md](references/sandbox-state.md).

**D-9 — The skill lives here and carries the plugin's name.** The escapes
knowledge is maintained here, not in `craft`; as the plugin's only skill it is
`sandbox-lies:sandbox-lies`. Argued in
[references/rejected-alternatives.md](references/rejected-alternatives.md).
*Rejected:* a home in `craft` or `prohibitions`; `sandbox-gotchas` or
`sandbox-effects` as names.

**D-10 — Self-reference is handled at the document, not the matcher.** The
repository's live documents never fire a detector (FR-11), and the matchers do
not special-case self-reading. Accepted tradeoff: a read of a `fire-*` fixture
or of the dated pilot evidence from inside this repo annotates itself. Argued in
[references/self-quiet.md](references/self-quiet.md).

**D-11 — Retire each section the moment its translation lands.** A memory
section and the hook or skill text that replaces it never coexist: the commit
that ships one deletes the other. Waiting for dogfooding would keep two sources
of truth live, and the fixture suite plus the live reproduction are the evidence
a detector works. Accepted tradeoff: a ddaanet repo without the plugin loses the
fact before it gains the hook, until the plugin is released and installed there.

**D-12 — `jq` is a dependency.** Parsing the payload by hand in bash 3.2 is
where hooks go wrong; the release toolkit's version guard already requires it.
Without `jq` every annotation is lost and nothing would say so, so
`hooks/check-jq.sh` tells the user and the agent at each session start, built
with no `jq` itself. Argued in [references/hook.md](references/hook.md).

**D-13 — Failures arrive on `PostToolUseFailure`.** A non-zero exit fires
`PostToolUseFailure` with the text in `error`, a success `PostToolUse`; the hook
takes both. Argued in [references/hook.md](references/hook.md).

**D-14 — A lock with no holder check is `unknown`, not `orphan`.** It reports
presence with no removal instruction. Argued in
[references/lock-detectors.md](references/lock-detectors.md).

**D-15 — Candidate ship rule.** A candidate ships when the replay finds a true
positive and every false positive is classified, not when it clears a precision
floor. Argued in [references/detectors.md](references/detectors.md).

**D-16 — Dogfood through the toolkit's shim.** `plugin-dev/bin/claude` syncs the
plugin into `dist/plugin/` and chains to the next `claude` on `PATH` with that
copy as its plugin dir. Argued in [references/hook.md](references/hook.md).

**D-17 — The script decides conditions.** Text a hook emits for the agent
carries no conditional the script could evaluate itself. The probe or the
verdict decides which acts apply — from the flag, the command, the path and
probed state — and the paragraph states only those, probed values filled in: a
lock mask names the re-run its flag calls for, a partial merge names the files
that match its target. A condition the stateless hook cannot see stays in the
text: a repeat failure, which only a second call reveals. The command shapes
wording only; detection never reads it (D-1). Accepted tradeoff: the wording
depends on parsing a shell command, whose residuals `references/` names beside
each fact.

## Rejected alternatives

See [references/rejected-alternatives.md](references/rejected-alternatives.md)
for each argument; D-9 names two more.

- **A `PreToolUse` matcher that unsandboxes the call** — it pre-approves
  whatever is chained beside the command; a `git *` exclusion needs no hook.
- **Prompt-based hooks** — non-deterministic; a model call per Bash result.
- **Splitting `sandbox-effects` into hub and siblings first** — the layout would
  be thrown away; the fallback if the hook does not fire.
- **Filtering phantom names out of a cleanliness gate** — the mask set is
  version-dependent and the filter hides real files; skill content instead.
- **`PostToolBatch`** — the verdict must attach to the one call it explains.
- **A `tmp-full` detector** — not reproducible and not a sandbox lie.

## Limitations

- **L-1** No hook fires on a `` !`cmd` `` slash-command expansion. The expansion
  executor calls the shell tool directly, below the hook dispatcher. A `/commit`
  `## Context` listing phantom dotfiles is permanently out of reach and stays
  prose.
- **L-2** A call unsandboxed by `excludedCommands`, one whose every command an
  entry covers, carries no flag or other trace in the payload (D-8).
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
