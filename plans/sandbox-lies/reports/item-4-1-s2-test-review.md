# Review: Item 4.1 slices 2-3 — test review

**Scope**: uncommitted changes to `tests/hook-locks.bats` and
`tests/verdicts.bats`, plus the RED report `item-4-1-s2-red.md`.
`lib/verdicts.sh` was in scope for stub completion only. It needed none: the
functions exist, and every outcome already prints two lines.
**Date**: 2026-09-25
**Mode**: review + fix

## Summary

The mechanical check passes. Every new test fails on an assertion; none
passes and none errors.

The RED tests went green for the right reason against a correct
implementation, but also for several wrong ones. The stubs never emitted the
`path=` line that the real probe always emits. Every key arrived in one fixed
order. No case gave exactly one of `bytes=` and `age=`, and nothing covered
`config-lock` interpolation.

I built a simulated GREEN in a scratch copy of the tree and ran six faulty
variants against the revised tests. The original tests would have missed five
of the six. The revised tests red on each one.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

1. **The stub probe output could not come from the real probe (no `path=`)**
   - Location: `tests/hook-locks.bats`, the three new cases; `tests/verdicts.bats`,
     the unit case.
   - Problem: `probe_git_lock` ends every `held`/`orphan`/`unknown` answer with
     `path=<path>`. That path comes from the error text, so it can hold spaces,
     digits, `&` and `\`. The stubs printed only `pid=` or `bytes=`/`age=`, so
     nothing tested the verdict against its real stdin. A GREEN that parses
     stdin with `eval` on each line passed all four RED tests (fault F2).
     `eval` on a path taken from the error text is also code execution on
     attacker-shaped input.
   - Fix: every hook stub now ends with `LOCK_PATH_LINE`,
     `path=/tmp/lock 99/a&b\1/.git/index.lock`. It is defined at the end of the
     file, after the cases that use it; bats evaluates the whole file before
     each test. The unit cases feed an equivalent `path_line`.
     `stub_probe_kv` now `%q`-quotes the outcome and each line into the stub
     body, where it used to single-quote them. Without that, a line containing
     `'` would break the stub.
   - **Status**: FIXED

2. **A positional stdin parser passed (keys always in the probe's order)**
   - Location: `tests/verdicts.bats`, `verdict_git_lock held|orphan|unknown
     interpolate probe values`.
   - Problem: the interface says the probe's remaining lines, which are
     key=value, become the verdict's stdin. The RED unit case always fed
     `pid=` alone, or `bytes=` then `age=`. Two GREENs passed:
     - one that reads line 1 as bytes (or pid) and line 2 as age (F1);
     - one that takes the first run of digits in stdin as the pid (F5).
   - Fix: the git-lock unit case now feeds `held` as `path=…` then `pid=4242`,
     and `orphan`/`unknown` as `age=12`, `path=…`, `bytes=7`. The expected text
     is unchanged. The `path=` value contains `99`, which acts as a decoy for a
     digit-grabbing parser.
   - **Status**: FIXED

3. **No case gave only one of `bytes=`/`age=`**
   - Location: `tests/hook-locks.bats`.
   - Problem: slice 3 notes that the probe omits `bytes=` and `age=`
     *independently*: `bytes=` for a non-regular or unreadable lock, `age=`
     when `stat` fails. `lib/probes.sh` confirms it: each line is printed under
     its own `if`. Only the "neither" case was tested. A GREEN that prints the
     full `(N bytes, age Ns)` clause whenever either key is present passed
     every RED test (F4), and would ship `(7 bytes, age s)`.
   - Fix: new case `orphan with one of bytes and age interpolates that one
     alone`, with two runs:
     - `bytes=7` alone: context contains `7 bytes` and `no process holds it`,
       and lacks `age s`, `age Ns`, `, )` and `,)`.
     - `age=12` alone: context contains `age 12s` and `no process holds it`,
       and lacks ` bytes`, `(,` and `( `.
     Each negative is paired with the positive for the same run.
   - **Status**: FIXED

4. **`config-lock` interpolation was never tested**
   - Location: `tests/verdicts.bats`.
   - Problem: Item 4.1 ships `git-lock` and `config-lock` verdicts "for all
     five outcomes, text from `detectors.md`". `verdict_config_lock` carries
     the same literal `N` placeholders. None of slices 4-9 covers its
     `held`/`orphan`/`unknown` output: slice 5 checks `mask` only, and slice 7
     checks the `mask` human line. With `verdict_config_lock` left
     uninterpolated, every test passed (F6), so the literal `N` would have
     shipped.
   - Fix: new unit case `verdict_config_lock held|orphan|unknown interpolate
     probe values`. It uses the exact text of `lock-detectors.md`'s
     config-lock list, fed in the probe's own key order with a `config.lock`
     `path=` line. I added it at unit level only; the hook route is shared
     with git-lock and is already pinned.
   - **Status**: FIXED

### Minor Issues

1. **Cases 5 and 6 did not assert the probe was reached**
   - Location: `tests/hook-locks.bats`, `orphan and unknown interpolate size and
     age`, `orphan with neither bytes nor age interpolates no empty value`.
   - Note: on this fixture the real probe answers `mask`, and the `mask`
     paragraph lacks both `7 bytes` and `no process holds it`. So the positives
     already implied the stub ran, and the cases were not wrong-reason.
     Adding `[ -f "$PROBE_CALLED" ]` brings them in line with the rest of the
     file and makes the reason for a failure explicit.
   - **Status**: FIXED

2. **The "neither" case put its only positive after the negatives**
   - Location: `tests/hook-locks.bats`, `orphan with neither …`.
   - Note: this is a bare-negative shape. A paragraph that was dropped entirely
     would fail only on the last line, after six `assert_lacks` calls had
     passed. I moved `grep -qF 'no process holds it'` first, so the negatives
     only run against the orphan paragraph. The case still reds on
     `assert_lacks ' bytes'`, as before.
   - **Status**: FIXED

## Considered, not added

- **`held` with no `pid=`**: `probe_git_lock` prints `held` only when
  `holder_pid` is non-empty (`lib/probes.sh`, `[ -n "$holder_pid" ]`), so the
  real pipeline cannot produce this input. The slice contract does not name
  it, and a test for it would pin hand-authored data the write path cannot
  produce. GREEN still has to print two non-empty lines for it, because the
  existing `verdicts under 400 chars` row loop runs `git_lock held` and
  `config_lock held` with empty stdin. That test already pins that
  requirement.
- **Interpolated values containing metacharacters**: `pid`, `bytes` and `age`
  are digits by construction (`holder_pid=${pids%%[!0-9]*}`, `wc -c | tr`,
  arithmetic). The value that can break a naive substitution or `eval` is the
  neighbouring `path=` line. Major issue 1 covers it.

## Fixes Applied

- `tests/hook-locks.bats` `stub_probe_kv`: the outcome and each line are
  `%q`-quoted into the stub body.
- `tests/hook-locks.bats`: `LOCK_PATH_LINE` constant at end of file. It is
  appended to every `stub_probe_kv` call.
- `tests/hook-locks.bats`: `[ -f "$PROBE_CALLED" ]` added to the
  orphan/unknown and neither cases. The positive now comes first in the
  neither case.
- `tests/hook-locks.bats`: new case `orphan with one of bytes and age
  interpolates that one alone`.
- `tests/verdicts.bats` git-lock unit case: out-of-order key lines with an
  awkward `path=` line.
- `tests/verdicts.bats`: new case `verdict_config_lock held|orphan|unknown
  interpolate probe values`.

Line counts: `tests/hook-locks.bats` 217, `tests/verdicts.bats` 224.
`shellcheck` is clean on both.

## Per-test result (post-fix, unchanged SUT)

`cd /Users/david/code/sandbox-lies && bats tests/hook-locks.bats tests/verdicts.bats`,
run in the foreground:

| # | test | result | failing assertion |
|---|---|---|---|
| 1-3 | pre-existing mask cases | ok | — |
| 4 | held interpolates the pid | not ok | `grep -qF 'pid 4242'` |
| 5 | orphan and unknown interpolate size and age | not ok | `grep -qF '7 bytes'` |
| 6 | orphan with neither bytes nor age … | not ok | `assert_lacks "$ctx" ' bytes'` |
| 7 | orphan with one of bytes and age … (new) | not ok | `grep -qF '7 bytes'` |
| 8-11 | pre-existing verdicts cases | ok | — |
| 12 | verdict_git_lock held\|orphan\|unknown … | not ok | `[ "$line1" = 'A process (pid 4242) …' ]` |
| 13 | verdict_config_lock held\|orphan\|unknown … (new) | not ok | `[ "$line1" = 'A process (pid 4242) …' ]` |
| 14 | no removal instruction | ok | — |

Each of the six new tests fails on a string comparison or a `grep`. None
passes, and none fails on a missing function, a sourcing error or a jq error.
The eight pre-existing tests pass.

## Discrimination check (simulated GREEN, scratch copy under `$TMPDIR`, deleted after)

I wrote a correct GREEN in a copy of `lib/verdicts.sh`. It parses stdin by
`case` on the key prefix, and builds the parenthetical from whichever of
bytes/age is present, dropping it when neither is. All 14 tests pass against
it.

Each fault below was appended as an override on top of that correct GREEN.
The last column is my reading of the RED-version tests, not a run: I could not
restore those files without `git stash`/`checkout`.

| fault | tests that redded | caught by RED version? |
|---|---|---|
| F1 positional parser (line 1 → pid/bytes, line 2 → age) | 7, 12 | no |
| F2 `eval` each stdin line | 4, 5, 6, 7 (path= line puts stderr into the hook output) | no |
| F3 full clause always, empties included | 6, 7 | yes (6) |
| F4 full clause when either key present | 7 | no |
| F5 pid = first digit run in stdin | 12 | no |
| F6 `verdict_config_lock` left with literal `N` | 13 | no |

## Self-quiet

`detect` from `lib/matchers.sh` over the working-tree text of both test files
exits 1, meaning nothing fired. `tests/docs.bats` passes. The new text is
verdict prose, key=value lines and a synthetic path. It quotes no diagnostic.

## Positive Observations

- `assert_lacks` insists on grep status 1 exactly, so a grep error cannot read
  as absence, and it avoids SC2314.
- Test 5's distinct values (7 and 12) already rule out a bytes/age swap.
- The unit case transcribes `lock-detectors.md` exactly, where it could have
  copied `lib/verdicts.sh`.

## Recommendations

- For GREEN: parse stdin by key (`case "$l" in pid=*)…`). Never use `eval` or
  line position. Drop the parenthetical piece by piece: `(7 bytes)`,
  `(age 12s)`, or nothing.
- The RED report's "New file content" section describes the pre-review tests.
  Where they differ, this report is the current description.
