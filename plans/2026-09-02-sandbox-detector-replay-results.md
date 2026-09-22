# Sandbox-detector pilot, layer 1: corpus replay results

2026-09-02. Executes layer 1 of `plans/brief-sandbox-detector-pilot.md`.
Harness: `plans/2026-09-02-sandbox-detector-replay.py`; hit sample (capped at 40
per matcher, regenerable in ~17s) in
`plans/2026-09-02-sandbox-detector-hits.jsonl`.

## Corpus

1,678 JSONL under `~/.claude/projects`, 60 project directories of which 35 carry
transcripts. Reconstructing `tool_use` → `tool_result` pairs by `tool_use_id`
yields **21,272 Bash calls** as the denominator. Sub-denominators for the
conditional rates: 2,573 calls containing a git write subcommand, 2,407
containing a `git status`, 1,856 containing `ls -a`/`find`.

## Verdicts

| detector | best matcher | hits | true | precision | rate |
|---|---|---:|---:|---:|---|
| A `.git/index.lock` | error string **+** git's follow-on sentence | 11 | 9 | 82% | 0.35% of git-write calls |
| A' `.git/config.lock` | `could not lock config file …: File exists` | 5 | 4 | 80% | — |
| B phantom dotfiles | char-device line in a listing | 17 | 17 | **100%** | 0.92% of `ls`/`find` calls |
| B' phantom dotfiles | ≥2 masked names on untracked/status lines | 41 | 41 | **100%** | 1.7% of `git status` calls |
| C sandboxed `claude -p` | segment command word is `claude` + `-p` | 29 | 20 | 69% | 0 of the 20 were uncovered |

**A and B pass. C dies.**

## A — the lockfile detectors

The bare error string is unusable: 87 hits, of which 76 are the *documentation*
of the string, not the string. `sandbox-effects.md` quotes it, so does
`git-hook-env-leak.md`, so does the root `MEMORY.md` index line, so do two bats
files and several transcripts — every `cat`, `grep` or `git diff` that touches
one fires the matcher. Precision 13%.

Two discriminators were measured against it.

*Exit status* — the obvious gate — is wrong. It cuts 87 to 7 but loses two real
failures, both because the git call was piped: `git commit --amend --no-edit
2>&1 | tail -20` reports `tail`'s status, which is the trap
`sandbox-effects` already documents for `just precommit | tail`. A PostToolUse
hook reading `exitCode` inherits that blind spot.

*Git's own follow-on sentence* —
`Another git process seems to be running in this repository` — is the one that
works. 11 hits, 9 of them live git failures across five repos, spanning
`git commit`, `git commit --amend`, `git restore`, `git rebase -i` and a
`git add && git commit` pair. Prose quoting the error almost never carries the
second sentence.

The two false positives are the same class, and it is the interesting one:
**self-reference**. One is a `shell-gotchas` probe script that deliberately
reproduces the error; the other is this session's own replay printing matched
excerpts. Between two runs an hour apart the bare-string count moved 86 → 87 and
the config-lock count 4 → 5, both from this session reading the memory file. Any
detector keyed on a string the store itself contains fires on sessions that read
the store.

A line-anchored variant (`^fatal:` / `^error:`) reaches 100% precision at 7 hits
but drops the two `Rebasing (2/7)error: …` forms, where git prefixes the
diagnostic with progress output on the same line. Follow-on matching dominates
it on recall at a cost of two benign hits.

`.git/config.lock` needs no gating: 5 hits, 4 live, all four the
harness-mounted-config shape (`git config`, `git remote add`,
`just update-plugin-dev`) that the memory's *Harness-mounted config paths*
section covers.

## B — phantom dotfiles

The brief nominated this as the highest false-positive risk and the real test of
the idea. **The replay refutes that at the anchored form and confirms it at the
naive one.**

Counting distinct masked names anywhere in the output: 207 hits, unusable.
Requiring them to sit on a `git status` untracked line (`^?? <name>` or the
long-format indented form): 41 hits, and all 41 are genuine sandbox masks — a
real `git status --porcelain` or `git status --short` listing `.bash_profile`,
`.bashrc` and the `.claude/*` set as untracked. Two ambiguous hits, where the
Bash call also wrote a heredoc, were opened in full and confirmed as real status
output.

So the precision comes from **line-shape anchoring, not the name list**. The
threshold on distinct names buys nothing: ≥2 gives 41, ≥5 gives 40 — the mask
set appears wholesale or not at all.

The char-device matcher is likewise 17/17. Every hit is
`crw-rw-rw- 1 nobody nogroup 1, 3`, across eight repos, and about half are
incidental `ls -la` where the agent was not investigating the sandbox at all —
precisely the injections worth making. It would false-positive on a genuine
device listing (`ls -la /dev`); zero such calls exist in the corpus, and
anchoring to `CLAUDE_PROJECT_DIR` closes it.

`error: <file>: can only add regular files` is rare — 4 hits, 2 live
`git add -A` failures, 2 self-reference — but it is not subsumed by the other
two: a `git add` that aborts prints neither a listing nor a char device, so it
is the only shape that sees the symptom on that path. Line anchoring is the
discriminator, and it is the only one available, since the store's changelog
quotes the error and git's `fatal: adding files failed` follow-on in one
sentence.

## C — sandboxed `claude -p`

This one fails on every axis the replay can measure.

*As written, it matches text it should not read.* Scanning the whole command
string gives 56 hits of which 9 are invocations; the other 47 are heredoc
bodies, Python scripts and greps that merely contain `claude -p`. Rewriting the
matcher to compare only each top-level segment's command word — which is what
`excludedCommands` actually does — gives 29 hits, 20 genuine. The remaining 9
false positives are all one session writing memory prose containing
`(cd /path && claude -p ping)`: the segment splitter cuts at the `&&`
*inside the heredoc* and hands back `claude -p ping)`. A real tree-sitter parse
treats a heredoc body as one token and would drop them, so 69% is a floor, not a
ceiling.

*But there is nothing left to warn about.* All 20 genuine invocations are
top-level `claude` segments, bare or behind `timeout` — every one already
unsandboxed by the baseline `claude:*` exclusion.
**True positives for the condition the detector exists to catch: zero.**

*And the case that is genuinely uncovered is invisible to a command matcher.*
`claude:*` does not reach a `claude` inside a recipe, but `just release`
contains no `claude` token. Catching it needs a hardcoded recipe list, which is
configuration rather than detection — and the over-broad `just
(evals|release|prerelease|precommit)` probe returned 821 hits of which 626 were
`just precommit`, which runs no `claude` at all.

*And the symptom is silent, as documented.* On 2026-08-11, the day
`sandbox-effects` records the `SessionStart` drop, nothing fired.

## Dated-incident recall

Of the eight dated incidents in `sandbox-effects`,
**five are in the corpus and all five are caught** by A or B: 2026-07-20 and
2026-07-21 (micro, stranded lock and masked status), 2026-08-11 (config.lock in
prohibitions, mask listings in three repos), 2026-08-15 (the mask measurement
itself), 2026-08-16 and 2026-08-28 (masked status under an unmatched heredoc
segment).

Three are **absent from the corpus entirely** — not merely from Bash results:
2026-05-24 (`/commit` `## Context`), 2026-07-21 gitlore (stranded lock) and
2026-07-23 (`.git/config.lock` genuinely stale). The corpus has a hole: sessions
start in 2025-12 (108) and 2026-01 (758), then nothing until 2026-07 (7),
2026-08 (556) and 2026-09 (123). gitlore's own transcripts begin 2026-08-03. The
recall check therefore ran against five of eight, and no conclusion about the
missing three follows from their absence.

Two of those three are out of `PostToolUse`-on-`Bash` reach by construction
anyway: the `/commit` case surfaces in prompt context via `` !`cmd` `` expansion
(no hook on that path), and the 2026-07-23 lock surfaced from gitlore's
`SessionStart` hook rather than a Bash call.

## What this decides, and what it does not

Per the brief's rule, A and B each clear a hit count and a false-positive rate
over real history, at 100% precision for B and 82% for A with the discriminator
the corpus selected. C fires almost entirely on innocuous input and has no true
positive at all, so it dies.

The brief's condition for creating the plugin was all three holding. It reads as
not met — but C failed for a reason that does not generalize to the remaining
nine sections. C was the *only* `PreToolUse` command matcher of the three, and
the only one whose target produces no output to match. The nine others are
`PostToolUse` output annotators, the class that went 2 for 2 here.

One consequence to carry into whichever design wins:
**the hook's own injected text must not repeat the literal error strings**, or
the store's new home recreates the false-positive class the replay just found in
its old one.

## Layer 2

The fixture suite this produced is in `plans/sandbox-detector-pilot/`: 26 cases
over 19 verbatim outputs, with the discriminators above pinned by deliberate
faults. See its `README.md`.

## Open

- Whether "two of three, and the third was structurally different" satisfies the
  decision rule, or the fallback (split `sandbox-effects` in memory, send the
  `excludedCommands` skill to `craft`) applies as written.
- Whether the `claude -p` knowledge stays prose, alongside the `/commit`
  `## Context` case that is already prose-only.
