# Minor batch C, code review (findings 9, 29)

## Verdict

The two .py changes are correct. Two defects fixed: the changelog parked at
its cap, and a finding-9 test that did not pin the `not sep` clause.

## Code

- `tests/corpus-eval.py`: `use_id` / `tid` must be strings before they key
  `bash_cmds`; the unlink loop skips directories; `aggregate` uses
  `partition("\t")` and counts `not sep` with the unknown-file skips. No broad
  exception catch anywhere. A skipped use is not counted in `bash_uses`, so
  the denominators count only keyed uses. Skipped-count semantics match the
  existing counter. Valid neighbours unchanged (every kept case carries one).
- `tests/extract-fixtures.py`: `id`, `tool_use_id`, `timestamp` and the list
  `text` item guarded by `isinstance`; no catch.

## Defects fixed

1. **Changelog at its cap.** Commit 142140a took `docs/changelog.md` from 394
   to exactly 400, the new entry having been condensed to three lines (the
   earlier entries were not touched). Split: entries 2026-09-22 to 2026-09-27
   moved verbatim to `docs/changelog-2026-09.md` (231 lines), pointer and
   link in `docs/changelog.md` (185 lines), and the batch C entry restored to
   full length. Inbound references: none in live files (only frozen plans and
   comments name `docs/changelog.md`, which stays). `just format-docs`
   re-wrapped the archive's two-line intro.
2. **Finding-9 test left `not sep` unpinned.** The tab-less line was
   `notabhere`, which the manifest check skips anyway, so removing `not sep`
   stayed green. The line is now `000001.txt` (a manifest file with no tab):
   only the missing tab can make it skipped.

## Mutation proof

One mutation per new test; each replaced a string occurring once, the new
text was found by `command grep`, the test went red, then the swapped
replacement restored it and the test was green again (the restore grep found
no mutation text; for the two whose mutated text is a substring of the
original, `cmd = cmds.get(tid)` and `day = ts[:10]`, the count is the one
original occurrence).

| Test | Mutation | Red on |
|---|---|---|
| corpus-eval: aggregate no tab | drop `not sep or ` | the `skipped: 1` line assertion |
| corpus-eval: tool_use id list | drop the `use_id` clause | `run -0`, TypeError unhashable list |
| corpus-eval: tool_use_id list | drop the `isinstance(tid, str)` clause | `run -0`, TypeError |
| corpus-eval: subdirectory | `if not stale.is_dir():` to `if True:` | `run -0`, IsADirectoryError |
| extract-fixtures: id list | drop the `b.get("id")` clause | Traceback assertion |
| extract-fixtures: tool_use_id list | `cmds.get(tid)` unguarded | Traceback assertion |
| extract-fixtures: integer timestamp | `day = ts[:10]` | Traceback assertion |
| extract-fixtures: integer text item | `x.get("text") or ""` | Traceback assertion |

The aggregate mutation was green with the original `notabhere` line, which is
why the test was changed (defect 2).

## Gate

`just format-docs`, then `just precommit`: exit 0 (446 passed).
