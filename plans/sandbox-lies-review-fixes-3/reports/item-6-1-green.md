# GREEN report: Items 6.1 (slices 1-3) and 6.2 (slices 1-2)

Scope: `tests/corpus-eval.py` (Item 6.1) and `tests/extract-fixtures.py`
(Item 6.2). Tests were not edited.

## Per-test before and after

Before: the RED report and test review (both uncommitted, carried by this
commit) record each case red on its assertion against the unchanged tools.

| Test | Before | After |
| --- | --- | --- |
| corpus-eval: extract drops survivors and verdicts left by an earlier, larger run | red at `survivors` count (2, not 1) | green |
| corpus-eval: aggregate skips verdict lines with no manifest entry and counts them | red at `[ "$status" -eq 0 ]` (KeyError on `manifest[f]`) | green |
| corpus-eval: extract reads a string tool_use input as no command | red at `[ "$status" -eq 0 ]` (AttributeError on `inp.get`) | green |
| extract-fixtures: a null timestamp reads as no day and the cut still lands | red at `assert_cut_verbatim` status (TypeError at the `[:10]` slice) | green |
| extract-fixtures: a string tool_use input reads as no command and the cut still lands | red at `assert_cut_verbatim` status (AttributeError) | green |

Suite results after the edits:

- `scripts/run-bats.sh tests/corpus-eval.bats`: 3 passed, 0 failed.
- `scripts/run-bats.sh tests/extract-fixtures.bats`: 2 passed, 0 failed.

Order: all five fixes were made in one editing pass, then the two suites were
run. I did not re-run each case in isolation between fixes. The per-fix
isolation (each fix alone greens its own case and leaves the other red) was
verified by the test review, not repeated here.

## Changes

`tests/corpus-eval.py`:

- Slice 1: `cmd_extract` empties `survivors/` and unlinks `verdicts.tsv`
  before writing.
- Slice 2: `cmd_aggregate` skips a verdict line whose file has no manifest
  entry, counts it, and prints `verdict lines skipped, no manifest entry: N`.
- Slice 3: a non-dict `input` gives `cmd = None` (the `or {}` default is
  removed).

`tests/extract-fixtures.py`:

- Slice 1: `day = (e.get("timestamp") or "")[:10]`.
- Slice 2: a non-dict `input` gives `c = None`.

No-case edits:

- `tests/corpus-eval.py` docstring: the verdict loop now ends `done >DIR/verdicts.tsv`
  and the `>>` is gone from the `printf`, so a re-run does not duplicate lines.
- `tests/corpus-eval.py` prefilter comment: no longer claims the list is
  broader than every matcher; it names the phantom-chardev exception (`crw-`
  covers only the `/dev/null` mask's mode).
- `tests/extract-fixtures.py` `pick()`: the all-projects branch is removed;
  `pick` iterates `iter_calls(project)` directly.
- `tests/extract-fixtures.py` `main()`: `(project or '*')` became `project`.
  Both fixture suites stay green, which is the guard.

## Mutation proof

Not applicable. The tests were red before the edits, so no mutation was
needed to show they fail on their assertion.

## Gate

- `just lint`: the Justfile has no `lint` recipe (`just --list` shows
  `precommit`, `test`, `format-docs` and others). Precommit is the gate.
- `just precommit` (unsandboxed, foreground): exit status 0.
  Recap line: `precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, python compile, tests`.
  Bats inside it: `bats: 408 passed, 0 failed`. No warnings printed.
- `tmp/.test-sentinel`: not present. `tmp/` holds only `build-baseline`, and no
  recipe or script in the repo writes a sentinel, so no hash can be recorded.
- `# MUT` text: none in `tests/` (`rg` returns no hit).

## Files

Modified: `tests/corpus-eval.py`, `tests/extract-fixtures.py`.
Uncommitted and carried by the commit: `tests/corpus-eval.bats`,
`tests/extract-fixtures.bats`, `tests/helpers/corpus.bash`,
`plans/sandbox-lies-review-fixes-3/reports/item-6-1-red.md`,
`plans/sandbox-lies-review-fixes-3/reports/item-6-1-test-review.md`, and this
report.

Not staged: `.claude/handoff-task.md` and `.claude/handoff-todo.md` (staged by
someone else, left as they are). `inbox/` and the dotfiles were not touched.

No commit hash is recorded here; this report rides the commit that adds it.
