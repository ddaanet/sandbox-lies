# Item 2.2 slice 2 — GREEN

## Change

`scripts/check-links.sh`:

- `handle_file` no longer keeps its own `docs/*.md)` case. It calls the
  shared `markdown_in_scope` (`scripts/lib/tracked.sh`, already used by
  `scripts/check-line-limits.sh`) and only then `check_links_in`:

  ```sh
  handle_file() {
      if markdown_in_scope "$1"; then
          check_links_in "$1"
      fi
  }
  ```

  Written as `if … ; then … ; fi`, not `markdown_in_scope "$1" &&
  check_links_in "$1"`: the test review's W10 finding — the `&&` form
  returns 1 for an out-of-scope file, and `walk_tracked_files` runs under
  `set -e`, so the whole run would abort 1 on the first in-scope-negative
  file instead of continuing the walk.
- The header comment's slice-progress note ("Slice 1: docs/*.md only.
  Later slices add …") is deleted. The header now says the scope is
  `markdown_in_scope`, shared with `check-line-limits.sh`, with no mention
  of slices.

`markdown_in_scope` itself is unchanged, per the dispatch's scope.

## Checks run

- `scripts/run-bats.sh tests/check-links.bats` — 4 passed, 0 failed (the
  slice's previously-red `broken links in scope are reported` now passes,
  along with the other three).
- `scripts/run-bats.sh tests/` — 47 passed, 0 failed.
- `just precommit` — `precommit passed: plugin.json, shellcheck, bash -n,
  rumdl, line limits, tests`.
- `scripts/check-links.sh` (no argument, repo root) — exit 0, no output:
  the real tree has no broken links in scope.

## Left in the tree

- `scripts/check-links.sh` (this slice's change)
- `tests/check-links.bats` (already modified by the red/test-review steps)
- `plans/sandbox-lies/reports/item-2-2-s2-red.md`,
  `item-2-2-s2-test-review.md` (already present, uncommitted)
- this report

All five committed together, per dispatch.
