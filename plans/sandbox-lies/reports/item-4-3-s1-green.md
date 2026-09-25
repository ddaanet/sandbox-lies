# Item 4.3 slice 1 — GREEN: readonly-path matcher; 4.2 discriminator gaps
# pinned

2026-09-26. Mode GREEN. Batch: the RED/test-review's failing tests in
`tests/matchers.bats` and `tests/matchers-edges.bats` — the four
`fire-readonly-path-*` cases plus the BSD-sweep side effect, and the two
`matchers-edges.bats` cases (`readonly-path fires on a refusal at line
start, not quoted mid-line`, `readonly-path fires on Python's busy-device
form, errno 16`). Item 4.2's four gap tests were already green going in (the
test-review's own mutations proved them); this dispatch grows no code for
them and touches no test file. Out of scope: `probe_readonly_path`, slices
2-5, any readonly-path verdict, memory, other detectors.md restructuring,
design.md — none touched.

## Implementation

`match_readonly_path` in `lib/matchers.sh`, replacing the inert stub, one
`grep -qE` with two top-level alternatives (single stdin read, both
anchored at line start):

```
^[^`|:[:space:]]+: .*: (Read-only file system|Device or resource busy)[[:space:]]*$
```
— a tool prefix (`cp`, `mv`, `rm`, `error`, `/bin/bash`, …: a run free of
blanks, backticks, pipes and colons, then `: `), then anything, then the
kernel's EROFS or EBUSY message ending the line, trailing blanks allowed —
```
^[A-Za-z]+Error: \[Errno (30|16)\] (Read-only file system|Device or resource busy): 
```
— Python's `<Name>Error: [Errno 30|16] <message>: `, not required to end
the line (the fixtures' quoted path follows the trailing colon).

Wired into `detect()` already, in catalogue order, by the RED slice; this
dispatch changed only the function body. No probe, no verdict, no hook
change — the dispatch's own reasoning (`detect` gates a probe on the name
having a verdict) still holds, unexercised by any test in this batch.

## Tests made to pass, one at a time, in order

| # | test | file | result |
|---|---|---|---|
| 1 | `readonly-path fires on a quoted cp refusal under /tmp` | matchers.bats | ok |
| 2 | `readonly-path fires on a background task's output file read` | matchers.bats | ok |
| 3 | `readonly-path fires on a Python OSError errno 30 refusal` | matchers.bats | ok |
| 4 | `readonly-path fires on git's busy-device refusal` | matchers.bats | ok |
| 5 | `readonly-path fires on a refusal at line start, not quoted mid-line` | matchers-edges.bats | ok |
| 6 | `readonly-path fires on Python's busy-device form, errno 16` | matchers-edges.bats | ok |
| 7 | `the whole fixture sweep survives BSD grep, sed and mktemp` | matchers.bats | ok (side effect of 1-4, not separately grown) |

Each ran alone via `direnv exec . bats --filter '<name>' <file>` after the
one implementation edit; no second attempt was needed for any test, and no
test file was touched. The regex was derived directly from
`docs/references/detectors.md`'s `### readonly-path` Matcher paragraph
(recorded discriminator, not discovered by trial), so growth was one edit
verified test-by-test rather than built up across several.

Cross-checked while implementing: the existing quiet fixtures
(`quiet-readonly-path-index-line`, `quiet-memory-file-read`,
`quiet-index-line-read`, `quiet-resume-lost-index-line`) all carry `"Read-only
file system"` or `"Device or resource busy"` in prose or a store index line;
none opens its line with a bare tool-prefix-then-message shape (each is
preceded by a locator, list marker, or leading whitespace before the first
colon), so the line-start anchor keeps every one of them quiet — verified by
the full-suite run below, not by inspection alone.

## Full suite, lint, precommit

```
$ direnv exec . just test
bats: 173 passed, 0 failed
```

No `lint` recipe exists in this repo's `justfile` (only `precommit`, which
folds shellcheck, `bash -n`, `rumdl`, line limits and links into the tests
gate); ran that instead, per the dispatch's own commands.

```
$ direnv exec . just precommit
bats: 173 passed, 0 failed
precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests
```

No warnings emitted by any check — nothing to record under NFR-1's
complexity/line-limit carve-out. `lib/matchers.sh` 189 lines,
`tests/matchers.bats` 371, `tests/matchers-edges.bats` 165 — all under the
400-line cap.

## NFR-1: corpus re-run with the shipped matcher as arbiter

Reused the same 3,765-survivor extraction Item 3.2 and Item 4.2 both reused
(`/tmp/claude/sandbox-lies/eval/survivors`, `manifest.jsonl` from
`tests/corpus-eval.py extract`) — no re-scan of `~/.claude/projects`, one
replay, foreground, sequential:

```
for f in /tmp/claude/sandbox-lies/eval/survivors/*; do
  v=$(bash lib/matchers.sh <"$f") || true
  [ -n "$v" ] && printf '%s\t%s\n' "$(basename "$f")" "$v" >>verdicts.tsv
done
```

`tests/corpus-eval.py aggregate` errored unpatched on a handful of survivors
that fire more than one matcher (e.g. `.mcp.json` both `rm`-refused as
readonly-path and separately masked as phantom-chardev/phantom-untracked, one
file, three verdict lines) — the loop's `printf` puts each verdict on its own
line inside one field, and `aggregate`'s `line.split("\t", 1)` cannot parse
the continuation lines. This is a defect in `tests/corpus-eval.py` itself
(out of this slice's commit list), not in `lib/matchers.sh` or the survivor
data, so it was worked around in scratch rather than fixed in the repo: a
one-off script joined each file's continuation lines back onto its own
tab-separated record (space-joined verdicts) before calling `aggregate`
unmodified. 991 raw lines collapsed to 973 file records, matching "survivor
files with a verdict line: 973" in the aggregate output. Worth a future
ticket; not raised here since the fix touches a file this slice does not
own.

**readonly-path: before vs. after**

| | recorded (`Corpus.`, Item 3.2, scratch arbiter) | measured now (shipped matcher) |
|---|---|---|
| hits | 162 (151 tool-prefix + 11 Python-only, 1 file both) | 162, 0 flagged |
| survivor set | same 3,765-survivor extraction | same (reused, not re-scanned) |

Compared the two hit sets by filename, not just the count: extracted the 162
files each arbiter's tsv named `readonly-path`/`readonly-py` (Item 3.2's own
verdict spelling for the Python-only branch, recovered from
`/tmp/claude/sandbox-lies/eval/verdicts-item32-scratch-arbiter.tsv`, which
that dispatch's scratch run left on disk) and the 162 the shipped matcher
named `readonly-path` in this run. `diff` of the two sorted filename lists is
empty — the identical 162 survivors, not merely the same count. The hit count
did not move, so `docs/references/detectors.md`'s `readonly-path` `Corpus.`
paragraph is untouched (no 2026-09-26 re-record needed); `docs/` is not in
this commit's file list.

## Files touched (uncommitted going in, committed by this dispatch)

- `lib/matchers.sh` — `match_readonly_path`'s body only (the stub → the
  discriminator above); `detect()` wiring and the RED's stub scaffolding were
  already in place.
- `tests/matchers.bats`, `tests/matchers-edges.bats`,
  `tests/extract-fixtures.py`, `tests/helpers/probes.bash` — from the
  RED/test-review dispatches, unchanged by this one.
- `tests/fixtures/fire-readonly-path-git-busy.txt`,
  `tests/fixtures/fire-tmpdir-unset-bash-bare.txt` — from the RED/test-review
  dispatches, unchanged by this one.
- `plans/sandbox-lies/reports/item-4-3-s1-red.md`,
  `item-4-3-s1-test-review.md`, this report.

`docs/references/detectors.md` not touched (NFR-1 found no movement).

No commit hash recorded here: this report rides the commit it names in the
subject line below.
