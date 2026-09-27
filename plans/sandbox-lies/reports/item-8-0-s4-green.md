# GREEN: Item 8.0 slice 4 — the probe's review fixes hold

**Scope**: no implementation change. The slice pins behaviour the Item 8.0/3
code review already put in `lib/probes-readonly-facts.sh` and
`lib/probes-readonly-command.sh`. The RED report and the test review both
proved every test non-vacuous by mutation of the *already-committed* SUT, then
restored it; the test review additionally rewrote the test file itself (7
tests → 12, plus the `make_scratch_repo` helper move already carried from RED)
while leaving `lib/`, `hooks/`, `docs/` untouched (`git diff --quiet lib/
hooks/ docs/` clean in both reports). This GREEN dispatch's job is to confirm
the current test files pass against the committed SUT with zero implementation
edits, then close the slice.

## Tests run, one file at a time

1. `scripts/run-bats.sh tests/probes-readonly-pins.bats` — 12 passed, 0
   failed, against the unmodified SUT:
   - `a tracked file stat-dirty with unchanged content never becomes a match, and the index is untouched`
   - `a bare git pull gives merge=1 with a clean exit`
   - `a tag on a tree gives merge=1, no target and a clean exit`
   - `a tag on a blob gives merge=1, no target and a clean exit`
   - `a .git file naming a missing gitdir gives merge=1, no target and a clean exit`
   - `an unborn HEAD beside a resolvable branch gives merge=1, no target and a clean exit`
   - `past 1000 modified files against HEAD, matching the target, gives no target`
   - `a reader name past character 16384 gives no readfile`
   - `a heredoc body's git merge line gives no merge`
   - `a git merge on the line after another command gives merge=1`
   - `a writer on the line after a reader gives no readfile`
   - `nopath with a relative cwd resolves target within a bound`
2. `scripts/run-bats.sh tests/probes-readonly-facts.bats` — 14 passed, 0
   failed, unaffected by the `make_scratch_repo` move into
   `tests/helpers/probes.bash`.
3. Both together (the dispatch's exact command):
   `scripts/run-bats.sh tests/probes-readonly-pins.bats
   tests/probes-readonly-facts.bats` — 26 passed, 0 failed.

No test needed a fixture fix in this dispatch — the test review already
carried the one fixture fix the RED report's own non-red surfaced (test 1's
`touch d` timing, Check 2 of the test review). No implementation change was
made or needed.

## Full suite

`scripts/run-bats.sh tests/` (inside `just precommit`): 239 passed, 0 failed
(226 pre-existing + 12 pins + a net +1 from the facts file losing its
duplicated `run_probe_command`/`index_mtime` helpers, which carried no
separate test count).

## `just precommit` check list

`precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line
limits, links, tests` — exit 0, run in the foreground with the sandbox
disabled.

## Files touched this dispatch

None. `git status --porcelain --untracked-files=no` was already clean of
implementation changes before this dispatch ran; this dispatch adds only this
report.

## Commit

Staged by name: `tests/probes-readonly-pins.bats`,
`tests/helpers/probes.bash`, `tests/probes-readonly-facts.bats`,
`plans/sandbox-lies/reports/item-8-0-s4-red.md`,
`plans/sandbox-lies/reports/item-8-0-s4-test-review.md`,
`plans/sandbox-lies/reports/item-8-0-s4-green.md`. No commit hash recorded
here — the orchestrator and the audit identify the commit that adds this file.
