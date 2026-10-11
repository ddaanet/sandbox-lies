# Fix 12 — split tests/check-line-limits.bats

- `tests/check-line-limits.bats`: 280 lines, 15 cases (was 400 lines, 21).
  Markdown caps (clean tree, oversized markdown, SKILL.md, skills nodes,
  root markdown, markdown elsewhere, skills/ top level) plus the walk's
  behaviour (untracked, deleted, whitespace, unterminated line, extra
  argument, BSD mktemp, git ls-files failure, unreadable file).
- `tests/check-line-limits-types.bats` (new): 153 lines, 7 cases. Script
  types, awk, fixtures exclusion, justfile/TOML, plans/ and plugin-dev/
  exclusions, and one new case re-run with `make_bsd_stubs`. It loads
  `helpers/bsd-stubs`.
- Comment restored: the fixtures case again carries the three original lines
  recovered from `git show 4b80e0c`; the one line 4b80e0c added (lib/ and
  tests/ itself are capped) is kept after them, nothing else shortened.
- Deviation: the script never calls `wc` (it counts with `awk`); what it
  calls, through `scripts/lib/tracked.sh`, is `mktemp`. The stub case in the
  new file therefore stubs `mktemp`, as the existing case does. This case is
  the only addition (a smoke run, not mutation-proven).
- No case lost: sorted `@test` lines before vs the union after differ only
  by the added `oversized script survives BSD mktemp`; `bats --count` was
  21 before, 22 after (15 + 7). Both files pass via `scripts/run-bats.sh`.
- Referencing files: only plans, `.claude/handoff-todo.md` and generic
  mentions of the script name; no file cites the suite by path, so no edit.

## Precommit

`just precommit`, exit 0: plugin.json, hooks.json, shellcheck, bash -n, rumdl,
line limits, links, python compile, tests (414 passed, 0 failed).
