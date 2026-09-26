# Item 6.1 slice 2 — RED: writable outcome through the hook

Mode: RED. No SUT change: `verdict_readonly_path` does not exist in
`lib/verdicts.sh` and stays absent (confirmed by `git status` — no diff on
`lib/`). `lib/probes.sh` and `hooks/annotate.sh` also untouched.

Files changed:

- `tests/hook-candidates.bats` — removed `hook silent without a verdict`
  (retired: shipping `verdict_readonly_path` would turn it red, and it is no
  longer the only pin on the "no verdict, no probe" gate — see below); added
  `writable outcome through the hook`.
- `tests/helpers/hook.bash` — `stub_probe_kv` moved here, placed immediately
  after `stub_probe`, body and header comment unchanged from its
  `tests/hook-locks.bats` original.
- `tests/hook-locks.bats` — `stub_probe_kv` deleted (no copy left; `grep -n
  stub_probe_kv` now finds only the six call sites, none in this file's own
  definition).
- `tests/verdicts.bats` — added the `readonly_path writable` row to the
  `rows()` heredoc table only (not `readonly`/`nopath`, per the slice split).

## Retirement check

`tests/hook-locks.bats`'s `no probe without a verdict` (lines 313–339, using
`stub_lib matchers.sh` to fake a `detect` naming `fake`, then defining
`probe_fake`/`verdict_fake`) exists and pins the same "a name with no
verdict contributes nothing, and its probe is never reached" gate
independently of any shipped detector name. Confirmed present before
deleting `hook silent without a verdict` from `tests/hook-candidates.bats`.

## Per-test output

### `tests/hook-candidates.bats`

Run: `direnv exec . scripts/run-bats.sh tests/hook-candidates.bats`
(foreground) — 4 passed, 1 failed.

1. `writable outcome through the hook` — RED on a genuine assertion:
   ```
   not ok 4 writable outcome through the hook
   # (in test file tests/hook-candidates.bats, line 100)
   #   `[ -f "$PROBE_CALLED" ]' failed
   ```
   `hooks/annotate.sh`'s `declare -F "$fn" >/dev/null || continue` gate
   (line 94) runs before the probe is even looked up, so with no
   `verdict_readonly_path` defined the stubbed `probe_readonly_path` is
   never called — `$PROBE_CALLED` is never created. This is a genuine
   value-of-the-world assertion (probe call recorded or not), not a missing-
   symbol crash: the hook itself never references `verdict_readonly_path` by
   name until a matching `declare -F` succeeds, so no "command not found"
   fires here.
   The other three assertions in the test (context contains `/r/x`, `is
   writable outside the sandbox`, `compare modified files against the
   target`; systemMessage equality) are not reached this run, but would also
   fail on the current SUT: with no verdict firing, `context` and `human`
   both stay empty, so `additionalContext` is `""` and `systemMessage` is
   `""`.
   Existing four cases in the file (`tmpdir-unset flag policy`,
   `resume-lost flag policy`, `seccomp-init flag policy`, `tmpdir-unset flag
   policy survives BSD grep and sed`) stayed green, unaffected by the
   removal/addition.

### `tests/hook-locks.bats`

Run: `direnv exec . scripts/run-bats.sh tests/hook-locks.bats` (foreground)
— 13 passed, 0 failed. All cases that call `stub_probe_kv` (`held
interpolates the pid`, `orphan and unknown interpolate size and age`,
`orphan with neither bytes nor age interpolates no empty value`, `orphan
with one of bytes and age interpolates that one alone`, and the two calls in
the unlisted third case) stayed green after the move — the helper's body is
byte-identical, only its file changed.

### `tests/verdicts.bats`

Run: `direnv exec . scripts/run-bats.sh tests/verdicts.bats` (foreground) —
5 passed, 3 failed.

The row-driven cases feed `verdict_text`/`all_verdict_text` with stdin from
`/dev/null` (explicit `</dev/null` in `verdict_text`) — every row in this
table takes no probe outcome, so no case here reads probe `key=value` lines
on stdin; the `readonly_path writable` row is a probed detector's outcome
argument but `verdict_readonly_path` still takes it as a plain `$1`, not
from stdin, matching the other outcome-bearing rows (`git_lock mask`, etc.).

1. `verdicts under 400 chars` — RED on a genuine assertion:
   ```
   not ok 1 verdicts under 400 chars
   # (in test file tests/verdicts.bats, line 72)
   #   `[ "$defined" = "$rowed" ]' failed
   ```
   `rowed` (from `rows()`) now includes `readonly_path`; `defined` (from
   `declare -F` over the sourced `lib/verdicts.sh`) does not, since
   `verdict_readonly_path` is absent. The mismatch is caught by this
   equality check, which runs *before* the loop that would call
   `verdict_text` on the new row — so this test never reaches a missing-
   symbol crash; it fails on a genuine value comparison.

2. `verdict text is quiet` — reds, but via a missing-symbol abort, **not** a
   failed assertion:
   ```
   not ok 2 verdict text is quiet
   # (in test file tests/verdicts.bats, line 89)
   #   `all=$(all_verdict_text)' failed
   # /Users/david/code/sandbox-lies/tests/verdicts.bats: line 47: verdict_readonly_path: command not found
   ```
   `all_verdict_text`'s loop calls `verdict_text readonly_path writable`,
   which runs `( . "$VERDICTS"; verdict_readonly_path writable )` — the
   subshell hits "command not found" (exit 127), `verdict_text` returns
   that status, `all_verdict_text`'s `text=$(verdict_text …) || return 1`
   catches it and returns 1 cleanly, but the test's own `all=$(all_verdict_text)`
   (a plain, non-`local` assignment) then aborts the test under bats' `set
   -e` before the `[ -n … ]` assertion is ever evaluated. This is the
   "missing function surfacing as a bats error rather than a failed
   assertion" case the dispatch anticipates: reported here rather than
   fixed, since slice 2 must not touch `lib/verdicts.sh`.

3. `no removal instruction` — same shape as `verdict text is quiet`:
   ```
   not ok 8 no removal instruction
   # (in test file tests/verdicts.bats, line 240)
   #   `all=$(all_verdict_text)' failed
   # /Users/david/code/sandbox-lies/tests/verdicts.bats: line 47: verdict_readonly_path: command not found
   ```
   Same `all_verdict_text` abort, same "command not found" line, again
   before this test's own `[ -n … ]` assertion runs.

The five other cases in the file (`candidate verdict text matches
detectors.md`, `lock verdict text matches lock-detectors.md`,
`verdict_git_lock held|orphan|unknown interpolate probe values`,
`verdict_config_lock held|orphan|unknown interpolate probe values`, and the
phantom-verdict `verdict text matches detectors.md`) call `verdict_text`
directly on named rows outside the table and stayed green.

## Self-quiet

`bash lib/matchers.sh < <file>` on each changed file: exit 1, empty stdout,
for all four:

```
tests/hook-candidates.bats  exit=1
tests/hook-locks.bats       exit=1
tests/verdicts.bats         exit=1
tests/helpers/hook.bash     exit=1
```

## Mutation proof

None needed. Every new or newly red assertion fails against the unchanged
SUT for the reason stated above (either a genuine value mismatch or the
reported missing-symbol abort); no test here passed vacuously against
existing behaviour, so nothing required proving by mutation. The cases
carried over unchanged by the `stub_probe_kv` move (`tests/hook-locks.bats`)
were already proven in an earlier slice and are untouched here.

## Line counts

`tests/hook-locks.bats` 358, `tests/hook-candidates.bats` 125,
`tests/verdicts.bats` 252, `tests/helpers/hook.bash` 99 — all under 400.

`shellcheck` over the four changed files: clean, no findings.

No commit made.
