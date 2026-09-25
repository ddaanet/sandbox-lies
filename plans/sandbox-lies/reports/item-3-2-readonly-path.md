# Item 3.2 — readonly-path ships

2026-09-25. Closes Item 3.2 for `readonly-path`, the one candidate
`plans/sandbox-lies/reports/item-3-2.md` left gated, applying my human
partner's answers to its escalation:

1. False positives 1–4 (reads of a background task's `*.output` file or a
   `*.log` carrying an earlier sandboxed call's refusal) are true positives. A
   read of a file with a conventional command-output name carrying a sandbox
   refusal is a legitimate flag; a `*.md` or other document is material about
   sandbox effects (D-10 self-reference).
2. False positive 5 (an empty variable leaving a path directly under `/`) is the
   named residual, widened.
3. `readonly-path` ships.

## Entry changes — `docs/references/detectors.md`

`Matcher.` residual, reworded in place:

- Before: Expected residual: a genuinely read-only mount.
- After: Expected residual: a path not writable outside the sandbox either.

`Corpus.` paragraph — before (a count line, then a five-item unclassified list
escalated to my human partner):

> 162 hits, 157 true — sandbox refusals under `/tmp`, `~/.cache`, `~/.claude`,
> sibling repositories, harness-mounted config and the masks, 11 of them this
> project's traffic. 97% on 2026-09-25 if these five are false, which are
> escalated to my human partner, unclassified: (three task-output reads, one
> debug-log read, one `mkdir` under `/`)

After:

> 162 hits, 161 true, 1 the residual (`mkdir` of a path directly under `/`, left
> by an empty variable). 99% on 2026-09-25; 11 hits this project's traffic.
> True: sandbox refusals under `/tmp`, `~/.cache`, `~/.claude`, sibling
> repositories, harness-mounted config and the masks, and four reads of a file
> with a command-output name — a background task's `*.output`, a `*.log` —
> carrying an earlier sandboxed call's refusal. Any such name (`*.out`, `*.err`
> and the like too) is a legitimate flag; a `*.md` or other document carrying
> one is material about sandbox effects, self-reference (D-10).

Added after it: `**Decision: ships.**`, the shape `tmpdir-unset`,
`resume-lost` and `seccomp-init` use.

Updated counts: 162 hits, 161 true (157 + the 4 reclassified), 1 residual, 0
false positives outside the residual; precision 161/162 = 99%. No hit had the
flag set.

No other entry touched. `detectors.md`: 397 lines after `just format-docs` (398
before).

## Fixtures

Cut by `tests/extract-fixtures.py` (four new cut-list entries, appended after
the Item 3.2 block) from corpus hits the previous pass's arbiter identified.
Each fixture is byte-identical to its corpus-eval survivor (`cmp`).

| fixture | source (under `~/.claude/projects/`) | why |
|---|---|---|
| `fire-readonly-path-cp-tmp` | handoff 2026-09-18, `…/bf6a6111-…/subagents/agent-aitem-3-1-s2-red-54ab86b5da8b7a16.jsonl:116`, `cp` to `/tmp` | quoted path, the form Item 4.3's probe tests reuse |
| `fire-readonly-path-task-output` | gitlore 2026-09-07, `…/a9bf3102-…/subagents/agent-aitem-1-1-s1-green-2c3c5a1028421824.jsonl:69` (former false positive 2), read of a task `*.output` | encodes decision 1 |
| `fire-readonly-path-python-errno` | gitlore 2026-07-15, `…/3c1de2ab-c7ef-49cf-8d48-0f77b990178a.jsonl:443`, Python `OSError` errno 30 on `hooks/hooks.json` | the matcher's second (Python) alternative |
| `quiet-readonly-path-index-line` | gitlore 2026-08-13, `…/01e89a36-a3b2-41a9-8a58-f7c1961c6ee1.jsonl:304`, `grep -n` of the memory index line | the store naming the message mid-line |

Checked: `lib/matchers.sh` prints nothing on each; the scratch arbiter
(`/tmp/claude/sandbox-lies/candidates.sh`) fires `readonly-path` on the cp and
task-output fixtures, its Python variant on the errno fixture, and nothing on
the quiet fixture. The task-output fixture's path is unquoted (bash redirect),
so the Item 4.3 probe would take `nopath` there.

`tests/matchers.bats`: four `expected_for` rows expecting no verdict, under a
comment that Item 4.3 builds the matcher and flips the `fire-*` rows.

## Commands run

| command | result |
|---|---|
| `free -m` before each corpus run | 1346 MB available, then 1305 MB |
| `python3 tests/extract-fixtures.py` with the four names | pass, 4 cut |
| `cmp` of each fixture against its survivor under `/tmp/claude/sandbox-lies/eval/survivors/` | pass, identical |
| `bash lib/matchers.sh` and the scratch arbiter over each new fixture and each changed file | pass (fixtures as above; changed files quiet under both) |
| `just format-docs` | pass |
| `wc -l docs/references/detectors.md` | 397 |
| `just precommit` | pass: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests (131 bats, 0 failed) |

## Changes

- `docs/references/detectors.md` — `readonly-path` entry only.
- `tests/extract-fixtures.py` — four cut-list entries.
- `tests/fixtures/` — the four fixtures above.
- `tests/matchers.bats` — four `expected_for` rows.
