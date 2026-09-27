# RED: Item 8.0 slice 4 — list revision after slice 3 pins the code-review fixes

**Scope**: `tests/probes-readonly-pins.bats` (new, 7 `@test`s), `make_scratch_repo`
moved from `tests/probes-readonly-facts.bats` into `tests/helpers/probes.bash`.
No implementation touched (RED mode); the behaviour these tests pin already
exists in `lib/probes-readonly-facts.sh` and `lib/probes-readonly-command.sh`
from Item 8.0/3 and its code-review fixes
(`plans/sandbox-lies/reports/item-8-0-s3-code-review.md`), so every test is
proven non-vacuous by mutation rather than by ordering.

## Helper move

`make_scratch_repo` (HEAD at main, branch `feat` diverging on `a`, `b`, `c`,
`e f`, leaving `d` untouched) moved verbatim from
`tests/probes-readonly-facts.bats` into `tests/helpers/probes.bash`, which both
files already `load`. `tests/probes-readonly-facts.bats`'s 14 tests still pass
unchanged (`scripts/run-bats.sh tests/probes-readonly-facts.bats`: 14 passed,
0 failed) — nothing else in that file was touched.

## Tests written (all pass against the unmutated SUT)

`scripts/run-bats.sh tests/probes-readonly-pins.bats`: 7 passed, 0 failed.

1. `a tracked file stat-dirty with unchanged content never becomes a match,
   and the index is untouched` — `touch d` after backdating `.git/index`;
   asserts `cmp -s` and `index_mtime` unchanged, no `index.lock`, `d` never
   `match=`, exit 0, empty stderr.
2. `a bare git pull gives merge=1 with a clean exit` — outcome pin (see
   Residual below).
3. `merge=1 and no target for a tag on a tree, a tag on a blob, a missing
   gitdir and an unborn HEAD` — four sub-cases, each asserting exit 0, empty
   stderr, `merge=1`, no `target=`.
4. `past 1000 modified files against HEAD, matching the target, gives no
   target` — 1001 files modified against HEAD and matching `feat`'s content;
   asserts no `target=`.
5. `a reader name past character 16384 gives no readfile` — a command whose
   `build.log` argument starts past the tokenizer's cut; asserts no
   `readfile=`.
6. `a newline separates commands but a heredoc body's line does not` — three
   sub-assertions: a heredoc body's `git merge feat` gives no `merge=1`;
   `git fetch` then `git merge feat` on the next line gives `merge=1`;
   `cat build.log` then `rm -rf x` on the next line gives no `readfile=`.
7. `nopath with a relative cwd resolves target within a bound` — the scratch
   repo's `.git` sits at `$BATS_TEST_TMPDIR` itself, two levels above the
   relative cwd passed in (`sub1/sub2/sub3`), so the walk-up has to convert a
   bare relative component to an absolute one to converge; wrapped in
   `timeout`/`gtimeout` (5s) so a regression fails instead of hanging.

## Mutation proof

One mutation per named test, applied as an exact string replacement, restored
by the same replacement with the two strings swapped, and proven restored by
grep (no hit) then a green run of `tests/probes-readonly-pins.bats`.

1. **Test**: "a tracked file stat-dirty with unchanged content never becomes a
   match, and the index is untouched"
   **File**: `lib/probes-readonly-facts.sh`
   **Pair**: `git -c core.fsmonitor=false -C "$repo" diff-index -z` ↔
   `env -u GIT_OPTIONAL_LOCKS git -C "$repo" status >/dev/null 2>&1\n        git -c core.fsmonitor=false -C "$repo" diff-index -z`
   (prepends a porcelain `git status` call that bypasses the function's own
   `GIT_OPTIONAL_LOCKS=0` export via `env -u`, reproducing the code review's
   Critical Issue 3 — a porcelain read refreshing `.git/index` — ahead of the
   plumbing `diff-index` call).
   **Result** (5 runs, all red on the same line): `not ok 1 … / (in test file
   tests/probes-readonly-pins.bats, line 70) / `cmp -s "$repo/.git/index"
   "$BATS_TEST_TMPDIR/index-before"' failed`.
   **Note**: two earlier mutation attempts (a plain `git diff --name-only
   HEAD`, then a plain `git status`, both without `env -u`) did *not* red
   reliably — on this box's `$TMPDIR` (tmpfs), `GIT_OPTIONAL_LOCKS=0` alone
   suppresses the porcelain refresh that the code review's git 2.47.3
   reproduction did not suppress, so the exported guard already covers those
   two shapes here; `env -u GIT_OPTIONAL_LOCKS` was needed to bypass it and
   land the intended red. Filed for the test-review's attention as a residual
   worth a doc note (the fix holds against a stronger case than the plain
   porcelain call this box's tmpfs happens to tolerate).
   **Restore proof**: `grep -n "env -u GIT_OPTIONAL_LOCKS" lib/probes-readonly-facts.sh`
   → exit 1 (no hit); `scripts/run-bats.sh tests/probes-readonly-pins.bats` →
   7 passed, 0 failed.

2. **Test**: "a bare git pull gives merge=1 with a clean exit"
   **No mutation** — outcome pin, not a mutation-provable test. See Residual
   below.

3. **Test**: "merge=1 and no target for a tag on a tree, a tag on a blob, a
   missing gitdir and an unborn HEAD"
   **File**: `lib/probes-readonly-facts.sh`
   **Pair**: `if [ "$type" = commit ]; then` ↔
   `if [ "$type" != no-such-object-type ]; then` (the candidate-type guard
   always true, so a tree or blob type is accepted as a target — the code
   review's Major Issue 2).
   **Result**: `not ok 1 … / (in test file tests/probes-readonly-pins.bats,
   line 127) / `run ! grep -q '^target=' <<<"$output"' failed, expected
   nonzero exit code!` (the tag-on-a-tree sub-case).
   **Restore proof**: `grep -n "no-such-object-type" lib/probes-readonly-facts.sh`
   → exit 1; `scripts/run-bats.sh tests/probes-readonly-pins.bats` → 7 passed,
   0 failed.

4. **Test**: "past 1000 modified files against HEAD, matching the target,
   gives no target"
   **File**: `lib/probes-readonly-facts.sh`
   **Pair**: `[ "$n" -le 1000 ] || return 0` ↔
   `[ "$n" -le 100000 ] || return 0` (the code review's Critical Issue 2 cap
   raised past the fixture's 1001 files).
   **Result**: `not ok 1 … / (in test file tests/probes-readonly-pins.bats,
   line 186) / `run ! grep -q '^target=' <<<"$output"' failed, expected
   nonzero exit code!`.
   **Restore proof**: `grep -n "100000" lib/probes-readonly-facts.sh` → exit 1;
   `scripts/run-bats.sh tests/probes-readonly-pins.bats` → 7 passed, 0 failed.

5. **Test**: "a reader name past character 16384 gives no readfile"
   **File**: `lib/probes-readonly-command.sh`
   **Pair**: `local nl=$'\n' tab=$'\t' max=16384` ↔
   `local nl=$'\n' tab=$'\t' max=99999999` (the code review's Critical Issue 1
   cut raised past the fixture's command length).
   **Result**: `not ok 1 … / (in test file tests/probes-readonly-pins.bats,
   line 201) / `run ! grep -q '^readfile=' <<<"$output"' failed, expected
   nonzero exit code!`.
   **Restore proof**: `grep -n "99999999" lib/probes-readonly-command.sh` →
   exit 1; `scripts/run-bats.sh tests/probes-readonly-pins.bats` → 7 passed,
   0 failed.

6. **Test**: "a newline separates commands but a heredoc body's line does not"
   **File**: `lib/probes-readonly-command.sh`
   **Pair**: `"$nl") sep=line ;;` ↔ `"$nl") sep=word ;;` (the code review's
   Major Issue 4 fix reverted — an unquoted newline no longer separates
   command segments).
   **Result**: `not ok 1 … / (in test file tests/probes-readonly-pins.bats,
   line 219) / `printf '%s\n' "$output" | grep -qxF 'merge=1'' failed` (the
   "`git fetch` newline `git merge feat`" sub-case — the two lines no longer
   read as separate segments, so `git` in the second line is skipped as an
   argument of the first, unrecognised segment).
   **Restore proof**: `grep -n '"\$nl") sep=word' lib/probes-readonly-command.sh`
   → exit 1; `scripts/run-bats.sh tests/probes-readonly-pins.bats` → 7 passed,
   0 failed.

7. **Test**: "nopath with a relative cwd resolves target within a bound"
   **File**: `lib/probes-readonly-facts.sh`
   **Pair**: `*) dir="$PWD/$dir" ;;` ↔ `*) dir="$dir" ;;` (the code review's
   Major Issue 8 join dropped — a relative directory is never anchored to
   `$PWD`).
   **Result** (bounded by the test's own `timeout 5`): `not ok 1 … / (in test
   file tests/probes-readonly-pins.bats, line 255) / `[ "$status" -eq 0 ]'
   failed`, wall time ~5.45s (the probe hung until the wrapper killed it,
   rather than the suite hanging).
   **Restore proof**: `grep -n 'dir="\$dir"' lib/probes-readonly-facts.sh` →
   exit 1; `scripts/run-bats.sh tests/probes-readonly-pins.bats` → 7 passed,
   0 failed.

## Residual: test 2 has no mutation

Per `docs/references/detectors.md`'s Residual sentence, the bash 3.2
empty-array abort `git pull` exercises (Major Issue 1 of the code review — an
empty `cands` array under `set -u` on bash < 4.4) does not execute on the
bash 5 this suite runs on: bash 5's `"${cands[@]}"` already tolerates an empty
array under `set -u`, so reverting the safe-expansion pattern
(`${cands[@]+"${cands[@]}"}`) back to a bare `"${cands[@]}"` produces no
observable difference here — confirmed by trying it: reverting the pattern in
`_readonly_merge_segment` and re-running left the test green. This test pins
the outcome (`git pull` gives `merge=1`, exit 0, empty stderr) rather than the
crash path the review fixed; recorded as an outcome pin with no mutation, per
the dispatch's own instruction for exactly this case.

## Verification

- `scripts/run-bats.sh tests/probes-readonly-pins.bats`: 7 passed, 0 failed
  (checked after every restore above).
- `scripts/run-bats.sh tests/probes-readonly-facts.bats`: 14 passed, 0 failed
  (unchanged behaviour after the helper move).
- Full suite, foreground, sandbox disabled:
  `scripts/run-bats.sh tests/` → 234 passed, 0 failed (227 + 7 new).
- `shellcheck` over every tracked `*.sh`/`*.bash`/`*.bats` file plus the new
  untracked `tests/probes-readonly-pins.bats`: exit 0.
- `bash -n lib/probes-readonly-facts.sh lib/probes-readonly-command.sh`: exit
  0.
- `scripts/check-line-limits.sh`: exit 0 (`tests/probes-readonly-pins.bats` is
  259 lines, `tests/helpers/probes.bash` is 214, `tests/probes-readonly-facts.bats`
  is 336 — all under the 400-line cap).
- `git diff --stat lib/ hooks/ docs/`: empty — no lasting change outside the
  test files and the helper move.
- `grep` for every mutation text (`env -u GIT_OPTIONAL_LOCKS`,
  `no-such-object-type`, `-le 100000`, `max=99999999`, `"$nl") sep=word ;;`,
  `dir="$dir" ;;`) across `lib/`: no hit.

## Files touched

- `tests/probes-readonly-pins.bats` (new)
- `tests/helpers/probes.bash` (`make_scratch_repo` added, header comment
  updated)
- `tests/probes-readonly-facts.bats` (`make_scratch_repo` definition removed;
  now loaded from the helper)

No implementation file carries a lasting change; RED mode leaves the tests and
this report uncommitted for the slice's GREEN dispatch to carry.
