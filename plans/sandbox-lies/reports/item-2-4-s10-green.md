# GREEN: Item 2.4 / slice 10 — an errored holder check reads `unknown`

**Mode**: GREEN
**Batch**: the four `@test` cases in `tests/probes-tools.bats` (new file,
carried over unmodified from RED plus the test review's fixes). Only one of
the four was red at the start of this dispatch (`errored holder check is
unknown`); the other three already passed against the unchanged SUT, per the
RED and test-review reports' mutation proofs, and this dispatch does not
touch the code paths they pin beyond the shared header comment adjacent to
one of them.

## Implementation

`lib/probes.sh`, two changes, matching the code review's "For the list
revision" sketch:

1. `_probe_holder_pids`: `return 2` added after the passthrough
   `printf '%s\n' "$err" >&2` (its last line). The header comment above the
   function is reworded to say the function returns 2 both when neither tool
   is on `PATH` and when the tool ran but its stderr was unexpected.
2. `probe_git_lock`'s outcome-selection comment and guard: `[ "$holder_status"
   -eq 2 ]` became `[ "$holder_status" -ne 0 ]`, so any nonzero status with no
   pid found reads `unknown`, not only status 2 specifically. The comment
   above it now says "Nonzero: no holder tool on `PATH`, or the holder check
   errored. Zero: a tool ran and named no holder."

No other line changed. `_probe_holder_pids` still ignores the tool's own exit
status entirely — only the pids and the two error-shape checks decide — so
the `held` and quiet-`orphan` branches are unaffected: a pid found still wins
before `holder_status` is read (unchanged control flow), matching the code
review's observation that the `held` cases carry the same dependency already.

## Tests run, in order made to pass

Only one test needed the implementation change; the batch was run as a whole
throughout since the fix is a single coherent two-line change (no partial
implementation state made sense to test in isolation for a change this
small — the earlier RED/review mutation proofs already established the other
three tests were unaffected).

1. `errored holder check is unknown` (`tests/probes-tools.bats`) — isolated
   run after the edit: `scripts/run-bats.sh tests/probes-tools.bats -f
   "errored holder check is unknown"` → `bats: 1 passed, 0 failed`. All three
   sub-cases (quiet-no-pid positive, permission-denied negative, missing-
   interpreter negative) passed on the first run; no second attempt needed.
2. Full three-file suite: `scripts/run-bats.sh tests/probes.bats
   tests/probes-edges.bats tests/probes-tools.bats` → `bats: 24 passed, 0
   failed`.

## Gate

- `just lint` — no such recipe in this repo's `justfile` (`just --list`
  confirms; `precommit`, `test`, `format-docs`, etc. exist, `lint` does not).
  Not run; `just precommit` below runs shellcheck as part of its own steps.
- `just precommit`, final line: `precommit passed: plugin.json, hooks.json,
  shellcheck, bash -n, rumdl, line limits, links, tests` (`scripts/run-bats.sh
  tests/`: 119 passed, 0 failed). No warnings emitted.

## Line counts

- `lib/probes.sh`: 202 lines (was 200 before this dispatch; +2 net —
  the `return 2` line and one comment line added, none removed).

## Scope confirmation

Not touched: `probe_config_lock`, the shared-helper lift, the pathless test
(slice 8), the relative-path base and missing `$2` question, `docs/`,
`hooks/annotate.sh`, `lib/verdicts.sh`, `lib/matchers.sh`. No test file was
edited in this dispatch — `tests/probes-tools.bats` and
`tests/helpers/probes.bash` are exactly as the RED dispatch and its test
review left them (`git status --porcelain` at the end of this dispatch shows
only `lib/probes.sh` and `tests/helpers/probes.bash` as tracked changes, the
latter from the test-review's header-comment fix, plus the new untracked
`tests/probes-tools.bats`). No test looked wrong; no `blocked` condition was
hit.
