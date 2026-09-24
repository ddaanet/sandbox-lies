# Item 2.2 slice 6 — GREEN

Executed in session by the orchestrator: the slice's tests pin behaviour
earlier code reviews shipped (each proven by mutation in
`item-2-2-s6-red.md`, reproduced differently in
`item-2-2-s6-test-review.md`), so the only implementation left was the
item's wiring.

## Changes

- `justfile` — `report links scripts/check-links.sh` right after the
  `line limits` check, as Item 2.2 specifies.
- `docs/design.md` — NFR-5's status goes from `Partial (80-column reflow and
  line caps gated; the link check pending).` to `Done.`: both scripts named
  in its "pinned by" now run in `just precommit`, which is the legend's
  definition of Done. The file stays at 395 lines after `just format-docs`.
- `tests/check-links-edges.bats` — the slice's five tests as the test review
  left them (301 lines).

## Runs

- Fault injection: a `[x](no-such-file.md)` line appended to
  `docs/design.md` made `just precommit` stop at the new check with
  `broken-link: docs/design.md -> no-such-file.md` and
  ``error: Recipe `precommit` failed with exit code 1``. Removed by
  stripping exactly the appended text (checked it was the file's suffix
  first); `git diff --stat docs/design.md` then showed only the status
  change.
- `just precommit` after the restore: `precommit passed: plugin.json,
  shellcheck, bash -n, rumdl, line limits, links, tests`, with
  `bats: 65 passed, 0 failed`.
