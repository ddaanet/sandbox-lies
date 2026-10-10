# Item 2.1 + 3.1 GREEN report

Mode GREEN, one slice group: Item 2.1 (`probe_readonly_path` partial-checkout
join, design §B) and Item 3.1 (phantom wording, design §C). The tests are the
RED dispatch's and the test review's, unchanged. No test file was edited.

## Tests: before and after

Before is the unchanged lib, from the RED report and the test review. After is
this dispatch's tree, run with `scripts/run-bats.sh` in the foreground.

`tests/probes-readonly-resolve.bats` (7 cases)

| # | Test | Before | After |
| --- | --- | --- | --- |
| 1 | partial-checkout path joins onto the worktree top, not the cwd | FAIL (`path=$repo/d/f`) | pass |
| 2 | partial-checkout directory path joins onto the worktree top | FAIL (`path=$repo/d/n`) | pass |
| 3 | partial-checkout path joins onto a linked worktree's top from a subdirectory | FAIL (`path=$wt/d/f`) | pass |
| 4 | partial-checkout path resolves through BSD grep and sed | FAIL (`path=$repo/d/f`) | pass |
| 5 | a cp refusal naming a relative path still joins onto the cwd | pass | pass |
| 6 | a partial-checkout line elsewhere in the text does not move a cp refusal's join | pass | pass |
| 7 | a partial-checkout path with no .git above the cwd joins onto the cwd | pass | pass |

Before: 3 passed, 4 failed. After: 7 passed, 0 failed.

`tests/verdicts.bats` (11 cases)

| Test | Before | After |
| --- | --- | --- |
| verdict text matches detectors.md (line 61, chardev paragraph) | FAIL | pass |
| phantom-untracked opens without naming a location (line 86) | FAIL | pass |
| all other cases, including `verdicts under 400 chars` | pass | pass |

Before: 9 passed, 2 failed. After: 11 passed, 0 failed.

## Order of the work

Test order was the RED report's: 2.1 cases 1, 2, 3, 4 (the four red cases),
with 5 to 7 as regressions that had to stay green. The lib change is one
edit to `probe_readonly_path` covering the whole §B rule, not four separate
growths, because all four red cases read the same branch. I ran the resolve
file after that edit: 7 of 7 green. Then the two verdicts edits (§C, lines 16
and 22) and the verdicts file: 11 of 11 green.

## Lib changes

`lib/probes-readonly.sh`, `probe_readonly_path`:

- The matching line is captured once (`line=$(… | _readonly_path_line) || line=`).
  The `|| line=` keeps a no-match from becoming the assignment's status under
  `set -e`, as the existing comment required.
- `path=` is extracted from that line alone.
- `base` is `cwd`. When `_readonly_partial_checkout_text "$line"` holds, `base`
  becomes `_readonly_git_dir "$cwd"`, or stays `cwd` when the walk finds no
  `.git` entry.
- `path` is resolved onto `base`. `line base` are added to the `local`
  declaration.
- The `_probe_readonly_resolve` comment now says the caller picks the base; the
  function no longer documents a walk it does not do.

`lib/verdicts.sh`, lines 16 and 22: the phrase "over dotfiles in the project
root" is removed from both phantom paragraphs. Each now reads "…are sandbox
masks, not files in the repository." Both stay under 400 characters (the
existing length loop passes).

## Docs edit (conditional, §C)

`docs/references/detectors.md`, the `phantom-chardev` Verdict paragraph: the
same sentence change, "sandbox masks over dotfiles in the project root, not
files" to "sandbox masks, not files". The `phantom-untracked` paragraph inherits
it by reference ("As `phantom-chardev`, opening …"), so it needed no edit.

Why this was needed: test 3's comment says the transcribed text must match
`detectors.md`, so a mismatch must red it. With the doc unchanged, lib and test
agreed while the doc still named the project root, and the test could not
catch it. Not a test that reads the doc at runtime: the transcription is inline.

`just format-docs` was run. It re-filled that paragraph to 80 columns (rumdl
MD013 fixed one line, 83). `detectors.md` is 352 lines, `docs/design.md` is 399
(untouched, not grown).

Not touched, reported as §C follow-up: `docs/references/hook.md` lines 103 to
105 still say the phantom masks "name the project root, the usual case". The
design's §C says that sentence "goes with it". It breaks no test, and changing
it is a docs edit outside this dispatch's scope (Items 7.x), so it is left for
that item.

## Gate

`just precommit`, run unsandboxed in the foreground (through the harness,
which moved the call to background after 120 seconds; the notification was
received and the exit status read from the log):

- exit status 0 (`precommit-exit=0`)
- bats: 398 passed, 0 failed
- recap: `precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, python compile, tests`
- no warnings printed.

`just lint`: this repo's justfile has no `lint` recipe (the RED report says the
same); `just precommit` is the gate.

`tmp/.test-sentinel`: does not exist in this repo, and no recipe or script
here writes it (grepped `justfile`, `scripts/`, `.githooks/`). Recorded as
absent, not as a hash.

`grep -rn '# MUT'` over `lib tests docs skills hooks`: no matches (exit 1).

## Files changed

- `lib/probes-readonly.sh`
- `lib/verdicts.sh`
- `docs/references/detectors.md`
- `tests/probes-readonly-resolve.bats` (untracked from the RED dispatch, unchanged)
- `tests/verdicts.bats` (RED dispatch, unchanged)
- `tests/helpers/probes.bash` (test review, unchanged)
- `tests/probes-readonly-facts.bats` (test review, unchanged)
- `plans/sandbox-lies-review-fixes-3/reports/item-2-1-red.md` (RED, committed here)
- `plans/sandbox-lies-review-fixes-3/reports/item-2-1-test-review.md` (committed here)
- `plans/sandbox-lies-review-fixes-3/reports/item-2-1-green.md` (this file)

Left out of the commit: `.claude/handoff-task.md` and `.claude/handoff-todo.md`
(staged, not this job's), `inbox/`, and every zero-byte or character-device
dotfile.
