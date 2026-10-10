# Item 5.2 — line cap covers awk, toml, justfile and json

## What changed

- `scripts/check-line-limits.sh`, `handle_file`: a new arm
  `*.awk | *.toml | justfile | */justfile | *.json` caps the file at 400 lines.
  The arm excludes `tests/fixtures/*` through a nested `case`, so the exclusion
  applies only to these four types and leaves the existing script and markdown
  arms as they were. Root-level `plans/` and `plugin-dev/` stay excluded by the
  earlier arm, for every type.
- `scripts/check-line-limits.sh`, header: the scope sentence now names the four
  new types at any depth, the `tests/fixtures/` exception, and states that
  extensionless files such as `.gitlore/bin/claude` are out of scope.
- `tests/check-line-limits.bats`: one case added, `oversized awk is reported`.
  It writes a 401-line `lib/x.awk` in a fixture root and expects exit 1 and the
  exact line `oversized-file: lib/x.awk: 401 lines > 400`.

## Test counts

- `scripts/run-bats.sh tests/check-line-limits.bats`: before the case was added,
  18 cases; after, 19 passed, 0 failed.
- Full suite under `just precommit`: 401 passed, 0 failed.

No tracked file of the new types exceeds 400 lines: `scripts/check-line-limits.sh`
over the real repo exits 0 with no output, so no blocker arose.

## Mutation proof

Mutation: in `scripts/check-line-limits.sh`, the exact string
`*.awk | *.toml | justfile | */justfile | *.json)` (occurs once) was replaced by
`*.toml | justfile | */justfile | *.json) # MUT`, dropping `*.awk` from the arm.

- Landed: `command grep -n 'MUT'` found line 71 with the marker; `command grep`
  for `\*\.awk` in the script found no match.
- Red: `bats -f 'oversized awk is reported' tests/check-line-limits.bats` gave
  `not ok 1 oversized awk is reported`, failing on
  `[ "$status" -eq 1 ]` at `tests/check-line-limits.bats` line 163.
- Restore: the strings were swapped back by exact replacement (not a backup
  copy, checkout, stash or reset). `command grep -c 'MUT'` on the script returns
  0, and line 71 reads `*.awk | *.toml | justfile | */justfile | *.json)`.
- Green: `bats -f` on the case printed `ok 1 oversized awk is reported`, and the
  full `tests/check-line-limits.bats` run gave 19 passed, 0 failed.

## Precommit

`just precommit` (unsandboxed, foreground): exit status 0.
Recap: precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl,
line limits, links, python compile, tests (full suite 401 passed, 0 failed).
