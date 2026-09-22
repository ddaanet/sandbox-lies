# Sandbox-detector pilot, layer 2: fixture suite

Layer 2 of `plans/brief-sandbox-detector-pilot.md`. Recorded output in, decision
out.

## Contents

| file | role |
|---|---|
| `matchers.sh` | the candidate matchers; each reads a Bash tool result on stdin and exits 0 when the symptom is present |
| `matchers.bats` | 26 cases asserting the full verdict set per fixture |
| `fixtures/` | 19 verbatim Bash tool results cut from `~/.claude/projects` |
| `extract-fixtures.py` | cuts them, so the set is reproducible rather than curated by hand |

Run it:

```sh
scripts/run-bats.sh plans/sandbox-detector-pilot/matchers.bats
```

The suite carries two files from gitlore that it depends on:
`scripts/run-bats.sh` (shows only `not ok` blocks and stashes the full TAP
stream, so a truncated tail cannot crop the one failing line) and
`tests/helpers/bsd-stubs.bash`. Both need folding into this repo's own
`justfile` at repo init, so `just test` reaches the suite — it was kept out of
gitlore's gate only because it was code destined for here.

Two cases read the live `memory/ddaanet/sandbox-effects.md` and **skip** until
the `ddaanet` memory tier is mounted. They are neither passes nor failures;
mounting the tier at repo init activates them.

## Why the fixtures come from the replay

Hand-writing them first would encode what the output was *expected* to look
like. Layer 1 replayed the naive matchers over 21,272 recorded Bash calls
(`plans/2026-09-02-sandbox-detector-replay-results.md`); these are the outputs
it found. Two of them carry shapes nobody would have invented:

- `fire-lock-rebase-inline` — git prefixes the diagnostic with rebase progress
  on the same line (`Rebasing (2/7)error: Unable to create …`), so a
  line-anchored matcher misses it.
- `fire-lock-piped-tail` — the failing `git commit` was piped through `tail`, so
  the recorded exit status is 0. This is why no matcher gates on exit status.

## What the suite pins

Each `fire-*` case asserts the exact verdict set, not just presence, so a
matcher that starts firing on a neighbour's symptom fails here rather than
double-reporting.

The `quiet-*` half is the load-bearing half, because the largest false-positive
class in the corpus is **the store documenting its own error strings**.
`sandbox-effects.md`, the always-loaded index and a changelog entry all quote
the exact diagnostics the matchers look for. Two cases run against the *live*
`memory/ddaanet/sandbox-effects.md` rather than a snapshot, so the guard tracks
the file as it is edited — the file this plugin is built to retire.

Three discriminators carry the design, and each has a case that goes red without
it:

1. **git's follow-on clause, including `in this repository`.** The store's
   quotation stops short of it — because `just format-docs` wraps the sentence
   across two lines. That is an accident the suite converts into a checked
   property.
2. **Line anchoring** for the config-lock and `git add` refusals. The `error: `
   prefix looks sufficient and is not: the pilot's own layer-1 report echoes
   four prefixed config-lock lines behind a `> ` marker.
3. **Status-line shape** for the masked-dotfile names. Matching the names
   anywhere in the output gives 207 corpus hits and is unusable; requiring them
   to stand alone on a `git status` line gives 41 and no false positive.

## Verification performed

- 26 cases pass under `scripts/run-bats.sh`.
- Eight deliberate faults — six in `matchers.sh`, one in the live store, three
  in fixtures — each turned the intended assertion red. Each fault asserts it
  applied before running, after one early attempt silently failed to patch and
  reported a false green.
- `shellcheck -s bash` clean on both files. `SC2314` caught four `! grep`
  assertions that bats 1.11 treats as inert when they are not the last command;
  all four are now `run !` and were re-proved with fixture-level faults.
- The whole sweep re-runs under `tests/helpers/bsd-stubs` with BSD-strict
  `grep`, `sed` and `mktemp` on `PATH`.

## Not implemented

**Detector C (sandboxed `claude -p`).** Layer 1 found no true positive for it:
every real invocation in the corpus was already unsandboxed by the baseline
`claude:*` exclusion, and the genuinely uncovered case sits inside a recipe
whose command text contains no `claude` token. Nothing here reads commands at
all. `quiet-heredoc-claude-p` keeps its false-positive class as evidence.

**Layer 3, the live discriminator probes.** `match_git_lock` reports that the
symptom is present; deciding *mask vs. stranded vs. genuinely stale* needs the
unsandboxed `ls -la .git/index.lock` probe, which has to run against a real
reproduction.
