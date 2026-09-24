# Item 2.4 / slice 4 — GREEN report

Dispatch: item-2-4-s4-green. Mode: GREEN.

## Slice (from the runbook, current text)

4. `held lock names the holder` — a background `sleep 30` holding the lock
   open on an fd other than 3, with bats' fd 3 closed (`3>&-`) so the run does
   not wait on it: `held`, `pid=` equal to that job's pid; the job is killed
   in teardown. `held lock under a quoted, spaced path` — the same under
   `$BATS_TEST_TMPDIR/it's here/r`: `held`, `pid=`. The holder check runs
   before the size and age reads, or presence is re-checked after it, so a
   holder exiting mid-check reads `gone`, not `orphan`.

## Batch received (failing tests)

From RED + the test review, the batch was exactly two tests in
`tests/probes.bats`, already fixed up by the test-review dispatch (teardown
`|| :`, the `hold_lock` helper, the pid-count and both-flags assertions):

1. `held lock names the holder`
2. `held lock under a quoted, spaced path`

No test file edits were made in this GREEN dispatch (the prohibition is
absolute for this mode, and none was needed — both tests were already correct
per the test review).

## Implementation

`lib/probes.sh`, `probe_git_lock`'s present-lock branch (the `else` after the
absence check):

- Added `_probe_holder_pid <path>` — decides between `lsof -t` and `fuser` by
  `command -v`, first found on `PATH` wins, the other is never tried. `lsof`
  is absent on this box (confirmed: `command -v lsof` fails here), so that
  branch is unexercised by any test and kept minimal: `lsof -t "$path" | head
  -n 1`, relying on `lsof -t` already printing bare pids one per line and
  nothing when unheld. Documented inline as untestable here.
- Added `_probe_fuser_pid <path>` — runs `fuser "$path"`, capturing its
  stdout (the pid list) via command substitution and its stderr via a
  temp file (`mktemp`, removed immediately after). `fuser` prints
  `"$path:"` on stderr on every call that resolves the path (confirmed by
  hand on this box, holder present and absent, quoted and unquoted); that
  exact line is dropped, any other stderr (e.g. an unquoted path's
  `Specified filename ... does not exist.` lines, confirmed by hand) is
  passed through via `cat "$err_file" >&2`. `fuser`'s exit 1 with empty
  stdout/stderr is the ordinary no-holder result (confirmed by hand),
  handled by the pid parse finding nothing — no special-casing of the exit
  status was needed since only the parsed pid decides the branch. Pids are
  parsed with an unquoted `for first in $out; do break; done`, safe here
  because pids are digit sequences, not paths.
- `probe_git_lock`'s present-lock branch calls `_probe_holder_pid` first,
  before the existing `stat`/size/age code, and returns `held` / `pid=` /
  `path=` immediately when a pid comes back. Placing the holder check first
  means a holder that exits mid-check (found no pid) falls through
  unchanged into the existing `stat`-based vanished-lock check, which
  already reads that as `gone` — satisfying the runbook's ordering
  constraint without a second presence re-check.
- No `bytes=`/`age=` line is printed for `held`, matching the item text and
  both tests (neither asserts them).

Scope held: no character-device rule (slice 5), no `unknown` outcome (slice
6, left as today's fall-through-to-orphan behaviour when neither tool is on
`PATH`), no relative-path resolution against `$2` (slice 7), no
`probe_config_lock` change (slice 8, still the stub), no BSD `stat -f %m` or
`stat`/`wc` stub work (slice 9). No build-progress comments.

## Tests run, one at a time, in order

1. `held lock names the holder` — filtered run
   (`scripts/run-bats.sh tests/probes.bats --filter "held lock names the
   holder"`): **1 passed, 0 failed** on the first implementation attempt.
2. `held lock under a quoted, spaced path` — filtered run: **1 passed, 0
   failed** on the first implementation attempt.
3. Full file (`scripts/run-bats.sh tests/probes.bats`): **8 passed, 0
   failed** — the six slice 1–3 tests plus the two above stayed green
   together.

No test needed a second attempt or was found wrong.

## Full suite, lint, precommit

- `scripts/run-bats.sh tests/probes.bats`: 8 passed, 0 failed.
- No separate `just lint` recipe exists in this repo (`just --list` shows no
  `lint` target); `just precommit` runs shellcheck, `bash -n`, rumdl, line
  limits, links and the full test suite together.
- `just precommit`: `scripts/run-bats.sh tests/` → **103 passed, 0 failed**;
  final line `precommit passed: plugin.json, hooks.json, shellcheck, bash
  -n, rumdl, line limits, links, tests`.
- No warnings were printed by shellcheck, rumdl or the line-limit check for
  the changed file.
- `pgrep -f 'sleep 30'` after the full run and after `just precommit`: the
  only matches were pids 1 and 2, the sandbox's own wrapper shell (its
  command line literally contains the string `sleep 30` from an unrelated
  earlier command of mine); confirmed via `ps aux | grep -i "sleep 30" |
  grep -v grep`, which returned nothing. No `sleep 30` test job was left
  running.

## Scratch cleanup

Manual exploration of `fuser`'s stdout/stderr shape (run before writing the
implementation, to confirm the exact `"$path:"` stderr line and the
exit-1-on-no-holder behaviour) was done under `tmp/probe-s4/`, removed with
`rm -rf` afterward. One of those exploratory commands left two stray files
at the repo root (`err.txt`, `out.txt` — a `cd` into the scratch directory
did not carry over to a backgrounded-job remainder of that same command);
both were untracked scratch artifacts with no relation to the slice, and
were deleted before committing (confirmed absent from `git status
--porcelain`).

## Requirements validation

| Test | Result |
|---|---|
| `held lock names the holder` (both flags, exact `pid=` line, count 1, empty stderr) | Satisfied |
| `held lock under a quoted, spaced path` (same, quoted path) | Satisfied |
| Slices 1–3 (unchanged) | Still green |
| No `2>/dev/null` outside the two named exceptions | Held — the only stderr handling added is `_probe_fuser_pid`'s capture-and-match via a temp file, matching the item text's fuser exception |
| Portability (bash 3.2, no GNU-only flags beyond the named `stat -c` fallback) | Held — no new construct beyond `command -v`, `mktemp`, `for`/`break` word-splitting |
| Path quoting | Held — `"$path"` quoted in every `lsof`/`fuser` call and every `[ ]` test |

## Stop

No commit made before this report was written. This report, `lib/probes.sh`
and `tests/probes.bats` are staged together with the RED and test-review
reports in the slice's single commit.
