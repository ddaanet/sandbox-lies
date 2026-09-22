# Brief: build the `sandbox-lies` plugin

2026-09-03. Written from the gitlore session that ran the detector pilot. This
directory is empty and not a git repository; everything below is the mission.

## What this is

A Claude Code plugin whose hooks watch Bash tool **output** for signs that the
command sandbox has distorted the result, and inject a short note saying what
actually happened.

The sandbox does not merely block things. It returns output that is
confidently, specifically wrong, and nothing in the output marks it as an
artefact. `git commit` reports a lock held by a process that does not exist.
`git status` lists `.bashrc` and `.claude/skills` as untracked files that are
not there, because `/dev/null` is bind-mounted over them. `git checkout` dies
on a healthy repo. `/tmp` reports full while `du` finds nothing.

The failure mode is **misplaced confidence, not an error**: the agent proceeds
and does the wrong thing — deletes a lock that is not stale, commits phantom
files, "fixes" a hook that is not broken. The plugin blocks nothing and fixes
nothing. It annotates a misleading result so the reader stops trusting it.

The name was chosen deliberately over `sandbox-awareness`, `sandbox-signals`,
`sandbox-symptoms` and `sandbox-gotchas`. Both halves carry weight: `sandbox`
fixes the scope, `lies` says the output is *wrong* rather than merely
*blocked*. Do not soften it. `sandbox-gotchas` was rejected because it
promises a catalogue like `shell-gotchas`, which is precisely what moving this
knowledge into hooks exists to stop being; `sandbox-effects` was rejected
because it is the name of the memory file this plugin retires.

## Evidence base — read before writing anything

All of it now lives in this repo, moved out of gitlore. Nothing is committed
anywhere yet.

| path | what it holds |
|---|---|
| `plans/sandbox-detector-pilot/` | `matchers.sh`, `matchers.bats`, `fixtures/` (19 verbatim outputs), `extract-fixtures.py`, `README.md` |
| `plans/brief-sandbox-detector-pilot.md` | the original decisions, the rejected homes (`craft`, `prohibitions`), the three pilot layers |
| `plans/2026-09-02-sandbox-detector-replay-results.md` | layer 1: candidate matchers replayed over the transcript corpus |
| `plans/2026-09-03-sandbox-matcher-corpus-eval.md` | layer 2: the shipped shell matchers replayed, plus the self-pollution measurement |
| `plans/2026-09-02-bang-expansion-hook-decompile.md` | the bundle evidence that no hook fires on the `` !`cmd` `` path |
| `plans/*-replay.py`, `plans/*-eval.py` | the corpus harnesses, both re-runnable in about 20 seconds |
| `scripts/run-bats.sh`, `tests/helpers/bsd-stubs.bash` | carried from gitlore because the suite depends on them |
| `/Users/david/code/gitlore/memory/ddaanet/sandbox-effects.md` | the memory fact being retired; 12 sections, ~31KB. Still in gitlore — retiring it is phase 4. |

Read the pilot `README.md` first — it is the shortest complete account.

The suite runs today, before any repo init:

```sh
scripts/run-bats.sh plans/sandbox-detector-pilot/matchers.bats
```

24 pass and 2 skip. The two skips are the cases that read the live
`sandbox-effects.md`; they activate once the `ddaanet` tier is mounted. Note
that `run-bats.sh` counts a skip under "passed", so read the TAP log rather
than the summary line when that distinction matters.

## What is already measured — do not re-derive

Replayed over **21,453 Bash tool calls** (1,682 JSONL files, 35 projects) with
the real shell matchers as arbiter:

| matcher | hits | true | false | precision |
|---|---:|---:|---:|---:|
| `match_config_lock` | 4 | 4 | 0 | 100% |
| `match_phantom_chardev` | 17 | 17 | 0 | 100% |
| `match_phantom_untracked` | 57 | 56 | 1 | 98% |
| `match_git_lock` | 14 | 9 | 5 | 64% |
| `match_phantom_gitadd` | 3 | 2 | 1 | 67% |

Every false positive is **self-reference**: the pilot's own fixtures, reports
and probe scripts being read back. There is no false positive of the
"unrelated prose" kind — the anchors handle that.

Three findings that cost real work to establish:

- **Exit status is not a usable gate.** It looks obvious and it drops real
  failures, because a `git commit … | tail -20` reports `tail`'s status. The
  discriminator for `git-lock` is git's follow-on sentence *including* its
  trailing `in this repository`.
- **Line-shape anchoring is what buys precision**, not the vocabulary.
  Matching the 22 masked dotfile names anywhere in output gives 207 unusable
  hits; requiring them on a `git status` line gives 57 with one false
  positive.
- **Detector C is dead.** A `PreToolUse` matcher for sandboxed `claude -p`
  found **zero** true positives over the whole corpus: every real invocation
  was already unsandboxed by the baseline `claude:*` exclusion, and the one
  genuinely uncovered case (a `claude` inside a `just` recipe) has no `claude`
  token in the command text. Do not revive it. Nothing in this plugin reads
  commands; it reads output only.

## Hard constraints

- **The injected text must not spell a diagnostic out on one line.** This is
  not theoretical: the layer-2 eval report *fires* `match_git_lock`, because
  it quotes the error with literal `\n` escapes, collapsing the message and
  its follow-on clause onto one physical line. The other pilot documents stay
  quiet only because the markdown formatter wraps their prose. Quote the error
  and the follow-on in separate fragments, or let a formatter wrap them. This
  binds the hook payload first and this repo's own docs second.
- **`additionalContext` spills to a file past ~2KB.** An injected section must
  be a short paragraph plus a verdict, never a memory section verbatim.
- **No hook fires on the `` !`cmd` `` slash-command expansion path.** Measured
  live on CC 2.1.258 and corroborated from the bundle. The `/commit`
  `## Context` phantom-dotfile case is therefore permanently out of hook
  reach and must stay prose.
- **Hooks load at session start.** Testing a hook change needs a restart
  (`/handoff:restart`), not a reload.
- **macOS is a target**: bash 3.2, BSD `grep`/`sed`/`mktemp`. `matchers.sh` is
  already written to that contract and the suite re-runs itself under
  `tests/helpers/bsd-stubs` with BSD-strict tools on `PATH`. Port that helper
  or an equivalent.

## The five phases

### 1 · Repo init

`git init`, then the standard ddaanet plugin shape — take the layout from a
sibling (`/Users/david/code/prohibitions` is the closest in size): plugin
manifest, `justfile` with `precommit` and `prerelease` recipes, `docs/`,
`tests/`, `README.md`, `LICENSE`, `CLAUDE.md`.

Vendor the release toolkit with `claude-plugin-dev`'s `install.sh` — clone the
toolkit at its newest source tag to get the script, run it from this repo's
root, and let it do the subtree add. Always pin a `dist-vX.Y.Z` tag; a bare
source tag is refused. Run `just --list` afterwards: a toolkit version needing
a consumer-side change makes `just` refuse to compile *any* recipe, and the
breakage is otherwise invisible.

Mount the `ddaanet` memory tier so this repo shares the conventions.

### 2 · Design doc

`docs/design.md`, six-section living-doc structure, as in gitlore. It is the
memory of the design: record decisions there, not in memory files. Keep the
hub thin — Architecture summarises, and a `docs/references/` node holds the
mechanism. Never make a behavioural claim from the hub.

The design must state the detector contract explicitly: a matcher reads a tool
result on stdin and exits 0/1; a hook composes matchers, and for the two cases
with a live discriminator it runs a probe and injects the verdict rather than
the ambiguity.

### 3 · Build

The pilot artifacts are already here. Promote them out of `plans/` into the
plugin's real layout, and wire the suite into `just test`, which is where it
belongs — it was kept out of gitlore's gate only because it was code destined
for this repo.

Then, in order:

1. Wrap the five matchers in a `PostToolUse` Bash hook that emits
   `additionalContext`.
2. Add **layer 3**, which the pilot never ran: the live discriminator probes.
   For `.git/index.lock` the hook must run `ls -la .git/index.lock`
   unsandboxed and inject "mask, re-run unsandboxed" versus "genuinely stale,
   safe to remove" — the three causes share one error string and the correct
   action is opposite between them. Same for `/tmp` full (`du` versus `df`).
   Each probe needs one live run against a real reproduction to prove it
   returns what the memory claims.
3. Convert the remaining sections of `sandbox-effects.md` that have a
   detectable symptom — roughly seven beyond the five already built.

### 4 · Memory retirement

Only after the hooks are live and dogfooded. The `sandbox-effects` index line
is 988 bytes of a 26,171-byte root index measured against a ~24,985-byte
loader cutoff, so retiring it nearly closes the overshoot on its own.

Three loose ends travel with it:

- The `excludedCommands` whole-call-semantics knowledge has **no symptom** —
  it fires while you are writing an exclusion list — so it is a skill, not a
  hook. Its home is open: `craft`, or this plugin. Decide it here.
- A one- or two-line prohibition (never delete, commit or report a phantom
  dotfile) may belong in `memory/ddaanet/shared-claude.md`, since the
  `!`-expansion path is out of hook reach.
- The store still says `PreToolUse` does not run on the `!` path and is silent
  on `PostToolUse`. Both are now measured. Fold the correction in rather than
  editing a file that is about to be split or retired.

`memory/` is a submodule behind a per-commit approval gate. Never commit
inside it; commit the parent and let the pre-commit hook do the rest.

### 5 · Release

`just release` — unsandboxed, because the recipe reaches the network and
`claude:*` does not reach a `claude` inside a recipe. The first release of a
plugin that has never been released takes no bump argument.

## Still open

- **Whether this gets built at all** was the pilot's decision rule: all three
  detectors holding. Two held decisively; C died. This directory existing is
  the answer, but the reasoning belongs in `docs/design.md`: C failed because
  it was the only `PreToolUse` command matcher and the only one whose target
  produces no output, which does not generalise to the nine output annotators.
- `match_phantom_gitadd` has a two-hit true-positive base. Its precision is
  one hit from swinging 33 points. Re-measure once this repo's own traffic
  stops entering the corpus.
- The transcript corpus is **self-polluting**: `git-lock` moved 11 to 14 in a
  day purely from sessions studying the detectors. Any precision figure needs
  its measurement date and a note on how much pilot traffic the corpus had
  absorbed.

## Verification standard

The pilot's suite is 26 cases over 19 fixtures, and green was not taken on
faith: eight deliberate faults each turned the intended assertion red, and
`shellcheck` caught four `! grep` assertions that bats 1.11 treats as inert
when they are not the last command. Hold that line — a fixture suite that has
never been fault-injected is not evidence.
