# Item 8.0/1 — split tests/verdicts.bats under the line cap

## Problem

`just precommit` failed after commit "Item 8.0/1 — lock verdicts word the
re-run by the flag" with `oversized-file: tests/verdicts.bats: 468 lines >
400`.

## Change

- New `tests/helpers/verdicts.bash` (99 lines): the shared row table
  (`rows`), `verdict_text`, `all_verdict_text`, `text_lacks`,
  `readonly_path_tail`, and the `ROOT`/`VERDICTS`/`MATCHERS` setup. Loaded
  with `load helpers/verdicts`, the way other suites load `helpers/bsd-stubs`.
- New `tests/verdicts-locks.bats` (223 lines, 4 `@test`): every lock-verdict
  test — `lock verdict text matches lock-detectors.md`,
  `verdict_git_lock held|orphan|unknown interpolate probe values`,
  `verdict_config_lock held|orphan|unknown interpolate probe values`, `lock
  verdicts word the re-run by the flag` — each test's body and comments
  unchanged, only the shared helpers now coming from `load helpers/verdicts`.
- `tests/verdicts.bats` (166 lines, 8 `@test`): kept the length, quiet,
  detectors.md transcriptions (phantom, candidate, readonly-path), and
  no-removal tests, unchanged apart from now loading `helpers/verdicts`
  instead of defining the helpers inline. Well under the 400-line cap,
  leaving headroom for the readonly-path composition tests the next slice
  adds.
- Test count: 12 `@test` lines before (in `tests/verdicts.bats`), 12 after
  (8 in `tests/verdicts.bats` + 4 in `tests/verdicts-locks.bats`). No test's
  name, body, or assertions changed.
- `docs/design.md` FR-6's "Where · pinned by" line: added
  `tests/verdicts-locks.bats` asserting the D-17 flag wording for the lock
  verdicts, alongside the unchanged `tests/verdicts.bats` and
  `tests/hook-cap.bats` citations (the latter two remained accurate as
  written, since the length/quiet properties they describe stayed in
  `tests/verdicts.bats`). Ran `.venv/bin/rumdl fmt -q --no-cache docs/`
  after editing, which reflowed the touched paragraph; `docs/design.md` is
  398 lines, at/under the 400-line cap.
- `grep -rn "verdicts.bats" --include=*.md --include=*.bats --include=*.sh .`
  outside `plans/` now shows only `docs/design.md`'s pinning line and
  `tests/verdicts-locks.bats`'s own header comment noting the split; no
  other non-plans reference needed updating.

## Verification

- `shellcheck tests/verdicts.bats tests/verdicts-locks.bats
  tests/helpers/verdicts.bash`: clean.
- `direnv exec . scripts/run-bats.sh tests/verdicts.bats
  tests/verdicts-locks.bats`: 12 passed, 0 failed.
- `just precommit`: exit 0 — `scripts/run-bats.sh tests/`: 200 passed, 0
  failed; `precommit passed: plugin.json, hooks.json, shellcheck, bash -n,
  rumdl, line limits, links, tests`.

## Files touched

- /Users/david/code/sandbox-lies/tests/verdicts.bats (modified)
- /Users/david/code/sandbox-lies/tests/verdicts-locks.bats (new)
- /Users/david/code/sandbox-lies/tests/helpers/verdicts.bash (new)
- /Users/david/code/sandbox-lies/docs/design.md (modified)

## Commit

`89e6824` — `test: Item 8.0/1 — split verdicts.bats under the line cap`,
staged with explicit pathspecs (`docs/design.md tests/verdicts.bats
tests/helpers/verdicts.bash tests/verdicts-locks.bats`).
