# GREEN: Item 2.4 / slice 7 — relative path resolves against cwd

**Scope**: `lib/probes.sh` only. `tests/probes.bats` untouched (no test edit
needed; the RED/test-review batch's test was already correct).
**Date**: 2026-09-25
**Mode**: GREEN

## Batch

One failing test in the batch: `relative path resolves against cwd`
(`tests/probes.bats`, added in slice 7's RED/test-review dispatches,
uncommitted going into this dispatch).

## Growth

Single test, made to pass in one step (the growth itself is a single small
join, not decomposable into a finer sequence):

1. Added `_probe_resolve_path <path> <base>`: `case` on `$1` — a leading `/`
   returns it unchanged, anything else is joined onto `$2` with one `/`
   separator (`printf '%s/%s\n' "$2" "$1"`). Placed immediately above
   `probe_git_lock`, one small function so a later change of the base
   directory (e.g. to the worktree top-level, noted as open in the test
   review) is a one-line edit at the call site.
2. In `probe_git_lock`, right after the existing
   `path=$(printf '%s\n' "$text" | _probe_lock_path)` line, added
   `path=$(_probe_resolve_path "$path" "${2-}")` — `${2-}` per the dispatch,
   so a missing `$2` does not abort under `set -u` (no outcome is chosen for
   that case here; it stays open per the dispatch and the test review's
   items 2–3). Every later check (`-e`/`-L`, `-c`, the holder query, `stat`,
   `wc`) and the final `path=` print already read the reassigned `path`
   variable, so no other line needed touching.
3. Ran `scripts/run-bats.sh tests/probes.bats tests/probes-edges.bats`:
   `bats: 18 passed, 0 failed`. The target test passes on the first
   implementation attempt; no second attempt was needed.

## Full suite, lint, precommit

- `cd /Users/david/code/sandbox-lies && scripts/run-bats.sh tests/probes.bats tests/probes-edges.bats`
  — 18 passed, 0 failed (no regression against the other 17 slice-1–6/8–10
  cases already in the file).
- `just lint` — no such recipe in this repo's `justfile` (`just --list`
  confirms; the gate is `just precommit`, which shellchecks, wraps and lints
  as part of itself). Skipped for that reason.
- `just precommit` (foreground, full suite): **green**.
  ```
  scripts/run-bats.sh tests/
  bats: 113 passed, 0 failed — full log: /tmp/claude-1000/sandbox-lies-bats.0vRt0K
  precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests
  ```
  No warnings emitted by this run (no complexity/line-limit notices to
  record).

## Scope held

Touched only `lib/probes.sh` (`_probe_resolve_path` added, one line added
inside `probe_git_lock`). Untouched: `probe_config_lock` (slice 8), the
shared-helper lift (slice 8), the BSD `stat -f %m` path and `stat`/`wc`
stubs (slice 9), the errored-holder `unknown` case (slice 10), and every
other scope-OUT item the brief and dispatch name. No outcome was chosen for
a missing or empty `$2`; no test was added for either. No test file edited.

## Commit

Staged by name: `lib/probes.sh`, `tests/probes.bats`,
`plans/sandbox-lies/reports/item-2-4-s7-red.md`,
`plans/sandbox-lies/reports/item-2-4-s7-test-review.md`,
`plans/sandbox-lies/reports/item-2-4-s7-green.md`. Subject:
`feat: Item 2.4/7 — a relative lock path resolves against the payload cwd`.
