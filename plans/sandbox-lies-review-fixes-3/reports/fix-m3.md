# Fix M3: plans/ and plugin-dev/ exclusions for the four new types

Added `plans/ and plugin-dev/ are out of the awk, TOML, JSON and justfile cap`
to `tests/check-line-limits-types.bats` (now about 160 lines). For each of
`plans` and `plugin-dev` it builds a fixture root per type (`x.awk`, `x.toml`,
`x.json`, `justfile`, `sub/justfile`), 401 lines, tracked with `git add`, and
asserts exit 0 with empty stdout and stderr. Failures are collected across
all types and the failure message names every capped path.

State that fails it: any of those ten files reported by the script. Nothing
else produces a report: each root holds one tracked file.

## Mutation proof

Mutant: `handle_file` first arm, `plans/* | plugin-dev/*) ;;` replaced by an
arm exempting script types only (`plans/*.sh | plans/*.bash | plans/*.bats |
plans/*.py` and the same under `plugin-dev/`).

1. Replaced by exact string replacement (string occurred once).
2. Landed: `command grep -c 'plans/\*\.sh'` printed 1.
3. Red on its own assertion (case 7 of 8):
   `capped despite exclusion: plans/x.awk plans/x.toml plans/x.json
   plans/justfile plans/sub/justfile plugin-dev/x.awk plugin-dev/x.toml
   plugin-dev/x.json plugin-dev/justfile plugin-dev/sub/justfile`.
   All four types die, at both roots. (A first draft returned at the first
   failure and named only `plans/x.awk`; rewritten to collect.)
4. Restored by the swapped replacement.
5. Restore proof: `command grep -c` printed 0; `git diff` on
   scripts/check-line-limits.sh empty; suite 8 passed, 0 failed.

The suite's BSD-stub case (`oversized script survives BSD mktemp`) is
unchanged; the new case exercises the same code path with no stubbed tool of
its own.

## Precommit recap

`just precommit` unsandboxed, foreground: exit 0. Passed: plugin.json,
hooks.json, shellcheck, bash -n, rumdl, line limits, links, python compile,
tests (415 passed, 0 failed).
