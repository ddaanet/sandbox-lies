# GREEN: Item 2.4 / slice 6 — no holder tool is unknown

**Scope**: `lib/probes.sh` only. No test file touched.
**Date**: 2026-09-25
**Mode**: GREEN

## Batch (from RED + test review)

Five named cases, one failing against the unmodified SUT, four already
passing (landed by slices 4–5's code reviews) and mutation-proven in RED and
in the test review:

1. `no holder tool is unknown` (`tests/probes.bats`) — failing, the batch's
   own new behaviour.
2. `lock vanishing during the holder check reads gone` (`tests/probes-edges.bats`)
3. `unexpected holder-tool stderr is passed through` (`tests/probes-edges.bats`)
4. `lsof decides when present` (`tests/probes-edges.bats`)
5. `dangling symlink lock is a quiet orphan` (`tests/probes-edges.bats`)

Only case 1 needed implementation. Cases 2–5 were re-run to confirm no
regression.

## Implementation

`_probe_holder_pids` reports "no tool to check with" through its own exit
status (`return 2`) rather than through its stdout, which is empty in that
case exactly as it is in the "checked, no holder" case — the two are
otherwise indistinguishable from the caller's point of view. `probe_git_lock`
now captures that status (`holder_status=$?` right after the command
substitution) and, at the point it used to print a hardcoded `orphan`, picks
`unknown` when `holder_status` is `2` and `orphan` otherwise. Everything
downstream of that choice — the `bytes=`/`age=` reads and the `path=` line —
is unchanged: `unknown` goes through the same code path as `orphan`, so it
inherits the same omission rules (no `bytes=` on an unreadable/non-regular
file, no `age=` when `stat` failed for a reason other than the lock
vanishing).

The `held`, `gone`-on-vanish, and stderr-passthrough branches inside
`_probe_holder_pids` and `probe_git_lock` are untouched: they run on the
tool's actual output when a tool exists, and the new `return 2` path is only
reached when neither `lsof` nor `fuser` is on `PATH`, before either is ever
invoked.

## Tests made to pass, in order

1. `no holder tool is unknown` — ran alone
   (`scripts/run-bats.sh tests/probes.bats`, `-f 'no holder tool is unknown'`
   not needed since the two-edit diff above was written in one pass and
   verified against the full file): passed on the first run after the edit.
2. Full two-file suite (`scripts/run-bats.sh tests/probes.bats
   tests/probes-edges.bats`): **17 passed, 0 failed** — confirms cases 2–5
   still pass alongside the new case 1.

No implementation attempt failed; the change went green on the first try.

## Full suite

```
cd /Users/david/code/sandbox-lies && scripts/run-bats.sh tests/probes.bats tests/probes-edges.bats
```
17 passed, 0 failed.

## `just precommit`

```
cd /Users/david/code/sandbox-lies && just precommit
```
```
scripts/run-bats.sh tests/
bats: 112 passed, 0 failed — full log: /tmp/claude-1000/sandbox-lies-bats.lhzxyx
precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests
```
No warnings emitted. No `just lint` recipe exists in this repo's `justfile`
(checked: `just lint` reports `error: Justfile does not contain recipe
'lint'`); `just precommit` is the full gate the brief names.

## Scope

Out of scope, untouched: relative-path resolution against `$2` (slice 7),
`probe_config_lock` and the shared-helper lift (slice 8), the BSD
`stat -f %m` attempt, the `stat`/`wc` stubs and the writes-nothing case
(slice 9). No build-progress comments added.

## Line counts

```
165 lib/probes.sh          (was 152; +13 lines: holder_status capture,
                             outcome selection, doc-comment update)
295 tests/probes.bats
284 tests/probes-edges.bats
 37 tests/helpers/probes.bash
```
All under the 400-line cap.

## Files staged for this commit

`lib/probes.sh`, `tests/probes.bats`, `tests/probes-edges.bats`,
`tests/helpers/probes.bash`, `plans/sandbox-lies/reports/item-2-4-s6-red.md`,
`plans/sandbox-lies/reports/item-2-4-s6-test-review.md`,
`plans/sandbox-lies/reports/item-2-4-s6-green.md`.
