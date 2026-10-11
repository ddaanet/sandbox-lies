# Minor batch C green

## Changes

- `tests/corpus-eval.py`: `extract` skips a Bash `tool_use` whose `id` is not
  a string and a `tool_result` whose `tool_use_id` is not a string; clearing
  `survivors/` leaves a subdirectory alone (no `IsADirectoryError`);
  `aggregate` uses `partition("\t")`.
- `tests/extract-fixtures.py`: non-string `timestamp` reads as an empty day,
  non-string `id` / `tool_use_id` skipped, non-string `text` in a list-form
  result reads as an empty line.
- `docs/changelog.md`: one entry (condensed so the file stays at the
  400-line cap).
- `tests/corpus-eval.bats`, `tests/extract-fixtures.bats`: new cases.

## Finding 9

A tab-less verdict line in `aggregate` is counted as skipped, in `verdict
lines skipped, no manifest entry`, like a line naming an unknown file. No
broad `except Exception`.

## Shellcheck directive

`# shellcheck disable=SC2154 # set by bats' run --separate-stderr` added above
each `[[ "$stderr" != *Traceback* ]]` line (4 in each bats file), the form in
`tests/matchers-edges.bats`. No other test edit.

## Verification

- `scripts/run-bats.sh tests/corpus-eval.bats`: 10 passed.
- `scripts/run-bats.sh tests/extract-fixtures.bats`: 8 passed.
- First `just precommit` failed on `oversized-file: docs/changelog.md: 410 > 400`;
  the changelog entry was condensed to 400 lines.
- `just precommit`: exit 0; plugin.json, hooks.json, shellcheck, bash -n,
  rumdl, line limits, links, python compile, tests (446 passed).
