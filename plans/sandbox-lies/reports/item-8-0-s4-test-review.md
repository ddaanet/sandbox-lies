# Review: Item 8.0 slice 4 — test review (the probe's review fixes hold)

**Scope**: `tests/probes-readonly-pins.bats` (new), the `make_scratch_repo`
move into `tests/helpers/probes.bash`, and the helper removal in
`tests/probes-readonly-facts.bats`. `lib/` was mutated only for proofs and
restored every time. Each restore inverted the edit at its recorded offset,
and `git diff --quiet lib/` passed after each one.
**Date**: 2026-09-27
**Mode**: review + fix

## Summary

The slice's central pin, "index untouched", was decoration. Its fixture never
made `d` stat-dirty in git's eyes, so reverting the probe to the original
porcelain `git diff` could not red it. The RED report explained this as
`GIT_OPTIONAL_LOCKS=0` suppressing the refresh on tmpfs. That explanation is
wrong. The fixture is now fixed, and the plain porcelain reversion reds the
test in 5 runs out of 5.

Three tests each bundled sub-cases, and one mutation could reach only one of
them. One sub-case was vacuous (unborn HEAD). I split those tests into single
cases. Every bare negative now has a positive control run over the same
fixture.

**Overall Assessment**: Ready.

## Check 2 — why the porcelain reversion did not red, and the fix

**Cause.** git 2.47.3 here is built without `USE_NSEC`, so it compares mtime
and ctime only to the whole second. The fixture did `touch d` a fraction of a
second after `make_scratch_repo`'s `git add` recorded d's stat. Both landed in
the same second, so d stayed stat-clean. Porcelain `git diff` refreshes the
index only when it finds a file that is stat-dirty with unchanged content
(`skip_stat_unmatch`). With no such file there was nothing to refresh and no
write.

The `sleep 1.1` sat after the touch, not between the `git add` and the touch,
and its comment ("racy-git guard") gave the wrong reason. The red was flaky
only when fixture creation happened to cross a second boundary.

Direct evidence, from the same fixture with the index back-dated and
`GIT_OPTIONAL_LOCKS=0 git diff --name-only -z HEAD` run:

| fixture | `ls-files --debug d` mtime vs file mtime | index mtime after |
|---|---|---|
| `touch d; sleep 1.1` (the old test) | 1790510800 / 1790510800 | 946681200 (unchanged) |
| no touch | equal | 946681200 (unchanged) |
| `touch -t 200501010000 d` | 1790510801 / 1104534000 | 1790510801 (rewritten) |

**What the RED report got wrong.**

- `GIT_OPTIONAL_LOCKS=0` does not suppress the refresh. The last row rewrites
  the index with it set, as the slice-3 code review found.
- The `env -u GIT_OPTIONAL_LOCKS git status` red did not depend on d at all.
  With d never touched, that `git status` still rewrote the back-dated index,
  946681200 → 1790511356. The back-dated index makes every entry racy, and
  status writes a racy index back. So the old test pinned "no porcelain status
  refresh" but not the defect it names.

**Fix** (test 1):

- `touch -t 200501010000 "$repo/d"` replaces `touch "$repo/d"; sleep 1.1`. d
  now gets a fixed mtime in a different second, so it is stat-dirty whatever
  the timing, with no sleep.
- `git -C "$repo" diff-files --name-only | grep -qxF d` is asserted after the
  probe. diff-files is plumbing and does not refresh. The check proves the
  fixture was stat-dirty and that the probe left it that way.
- `target=feat` and `match=a` are asserted. These prove the file comparison
  ran, so the absence of `match=d` is not vacuous.

With the old fixture, d was never listed by diff-index, so `match=d` could not
appear whatever the code did.

## Check 1 and 3 — mutation table (each a different mutation from the RED report's)

Every row: exact replacement, the slice's tests run, restored by inverting the
replacement, then `git diff --quiet lib/` passed.

Bats reports a failure inside `assert_merge_without_target` one line late (line
43, the `merge=1` grep). I confirmed by a direct run under the gitdir mutation
that the failing assertion is `[ -z "$stderr" ]`: the output was
`fatal: not a git repository: …`, while status was 0 and `merge=1` was printed.

| Test | Mutation (file: old → new) | Red on |
|---|---|---|
| 1 stat-dirty / index | facts: `diff-index -z` → `diff --name-only -z` (**the original porcelain defect**) | `cmp -s … index-before`, 5 of 5 runs |
| 1 (match=d) | facts: drop `&& [ "${shas[$i]}" != "${heads[$i]}" ]` | `run ! grep -qxF 'match=d'` |
| 2 git pull | command: drop `pull` from the subcommand list | `grep -qxF 'merge=1'` |
| 3 tag on a tree | facts: `= commit ]` → `= commit ] \|\| [ "$type" = tree ]` | no-target assertion; the blob test stays green |
| 4 tag on a blob | facts: `= commit ]` → `= commit ] \|\| [ "$type" = blob ]` | no-target assertion; the tree test stays green |
| 5 missing gitdir | facts: drop `2>/dev/null` from the `cat-file --batch-check` | `[ -z "$stderr" ]`; the other three stay green |
| 6 unborn HEAD | facts: drop the `HEAD^{}` commit check **and** drop diff-index's `2>/dev/null` | `[ -z "$stderr" ]` |
| 6 unborn HEAD | facts: drop the HEAD check **and** `&& printf '\0'` → `; printf '\0'` | no-target assertion |
| 7 1000-file cap | facts: `-le 1000` → `-le 999` | positive `target=feat` at 1000 |
| 7 1000-file cap | facts: `-le 1000` → `-le 1001` | negative (no target) at 1001 |
| 8 16384 bound | command: `max=16384` → `max=16383` | positive `readfile=build.log` at 16384 chars |
| 8 16384 bound | command: `max=16384` → `max=16394` | negative (no readfile) at 16394 chars |
| 9 heredoc body | command: `-ne 2 ] \|\| heredoc=1` → `-ne 3 ]…` | `run ! grep -qxF 'merge=1'` |
| 10 fetch↵merge | command: newline added to the `' ' \| "$tab"` word arm | `grep -qxF 'merge=1'` |
| 10 fetch↵merge | command: `_readonly_merge_segment`'s `\|` reset `state=start` → `state=skipseg` | `grep -qxF 'merge=1'` |
| 11 cat↵rm | command: newline added to the word arm (as above) | `run ! grep -q '^readfile='` |
| 12 relative cwd | facts: `dir="$PWD/$dir"` → `dir="$OLDPWD/$dir"` | `grep -qxF 'target=feat'` |
| 12 relative cwd | facts: `dir="$PWD/$dir"` → `dir="$dir"` (hang) | `[ "$status" -eq 0 ]` after the 3 s bound, 3.8 s wall time, no leftover process |

**Unborn HEAD has layered defences.** The `HEAD^{}` check and the diff-index
sentinel each withhold `target=`, and each discards its stderr. Dropping the
HEAD check alone leaves the test green (verified). This case can only be
redded by a compound mutation, which is the table's two-part rows. Before the
fix, the sub-case named `sometag`, which does not exist. With that name no
target could appear whatever HEAD was, and diff-index was never reached.

**Missing gitdir has nothing that can resolve**, so its no-target assertion
cannot discriminate by construction. The test pins exit 0 and empty stderr,
which is what the review's Major Issue 3 was about. Its comment says so.

## Issues Found

### Critical Issues

1. **The index-untouched pin did not red on the defect it pins**
   - Location: `tests/probes-readonly-pins.bats`, test 1 (old lines 55–64).
   - Problem: `touch d` in the same second as the `git add` left d stat-clean
     under whole-second comparison, so porcelain `git diff` never refreshed.
     The old red came from the back-dated index under `git status`, not from d.
     `match=d` was vacuous for the same reason.
   - Fix: see Check 2 above.
   - **Status**: FIXED

### Major Issues

1. **Unborn-HEAD sub-case vacuous**
   - Location: old test 3, fourth block.
   - Problem: the candidate `sometag` named nothing, so the result was "no
     target" whatever HEAD was. The diff-index path that used to print a fatal
     was never reached.
   - Fix: its own test. `make_one_commit_repo … feat` plus
     `symbolic-ref HEAD refs/heads/main` gives an unborn HEAD beside a branch
     that resolves, and the candidate is `feat`.
   - **Status**: FIXED

2. **Bundled sub-cases masked each other**
   - Location: old tests 3 (four cases) and 6 (three cases).
   - Problem: the first failing block ended the test, so one mutation reached
     only one sub-case. The RED report redded only tag-on-a-tree and the
     newline case.
   - Fix: split into seven tests: tree, blob, missing gitdir, unborn, heredoc,
     fetch↵merge, cat↵rm. Each now reds alone (table above).
   - **Status**: FIXED

3. **Bare negatives with no positive control**
   - Location: tree and blob tests, 1001 files, 16384, heredoc, cat↵rm, and
     `match=d`.
   - Problem: each would pass if the probe printed nothing at all.
   - Fix: a positive control on the same fixture, differing only in the
     trigger:
     - `commit-tag` gives `target=commit-tag`;
     - restoring `f1001`, leaving 1000 files, gives `target=feat` and
       `match=f1000`, which also pins the cap's position;
     - the same reader command at exactly 16384 characters gives
       `readfile=build.log`, which pins the bound's position;
     - `cat <EOF` in place of `cat <<EOF` gives `merge=1`;
     - `cat x` in place of `rm -rf x` gives `readfile=build.log`;
     - `target=feat` and `match=a` beside `match=d`.
   - **Status**: FIXED

4. **Status and stderr not asserted in the 16384 and newline tests**
   - Location: old tests 5 and 6.
   - Problem: the dispatch's check 4 asks for empty stderr, and these tests
     never asserted it.
   - Fix: every negative run now asserts `[ "$status" -eq 0 ]` and
     `[ -z "$stderr" ]`.
   - **Status**: FIXED

5. **The relative-cwd test used GNU `timeout`/`gtimeout` and skipped without
   them**
   - Location: old test 7.
   - Problem: `helpers/probes.bash`'s `run_probe_bounded` says "No GNU
     timeout: this repo's portability target excludes it". On a stock macOS box
     the test would skip, which is a silent pass.
   - Fix: `run_probe_bounded` takes an optional fifth argument `<command>`,
     passed on as the probe's third argument (`${5+"$5"}`). The test now does
     `cd "$BATS_TEST_TMPDIR"` and passes `sub1/sub2/sub3`, as
     `tests/probes-config.bats`' relative-cwd test does. The hang mutation reds
     it within the 3 s bound.
   - **Status**: FIXED

### Minor Issues

1. **Duplicated helpers** — the new file's header says it shares helpers
   "rather than duplicating them", yet it carried its own copies of
   `run_probe_command` and `index_mtime`, identical to
   `tests/probes-readonly-facts.bats`'. Both copies now live in
   `tests/helpers/probes.bash`, and both bats files lost their copies.
   **Status**: FIXED

2. **Wrong comments** — the "two levels above" comment was wrong: `.git` is
   three levels above `sub1/sub2/sub3`. The "racy-git guard" rationale for
   `sleep 1.1` was also wrong. Both were rewritten. **Status**: FIXED

3. **Stale header paragraph** — the partial-checkout fragment note in
   `probes-readonly-pins.bats`' header named helpers the file never used.
   Dropped. **Status**: FIXED

## Check 4 — wrong-reason hunting, remaining items

- **stderr**: every test captures it with `run --separate-stderr` (or the
  bounded runner's own file) and asserts it empty. The test file contains no
  `2>/dev/null`. The only one is `index_mtime`'s `stat -f %m` probe, a moved
  existing pattern whose reason is written inline.
- **Relative cwd**: the probe gets the literal `sub1/sub2/sub3`, and its `$PWD`
  is `$BATS_TEST_TMPDIR`. The `$OLDPWD` anchoring mutation shows the answer
  depends on the join to `$PWD`.
- **16384**: the command is `cat ` (4) + 16380 × `a` + ` ` + `build.log`, so
  `build.log` starts at character 16386. A command over the bound gives no
  `readfile=` whatever the reader's position, because a cut scan withholds it
  by design. The positive at exactly 16384 characters is what shows the
  boundary.
- **1001 files**: HEAD has `v1`, feat and the working tree have `v2`. The
  1000-file positive prints `match=f1000`, so the files really match.
- **Test 2 (`git pull`)**: an outcome pin, as the runbook states. Dropping
  `pull` reds it, but no mutation here can reach the bash 3.2 empty-array
  abort. The residual is unchanged.

## Fixes Applied

- `tests/probes-readonly-pins.bats`: rewritten, 7 tests → 12. Test 1's fixture
  was fixed and its assertions extended. Tests 3 and 6 were split. Positive
  controls, status and stderr assertions were added. The relative-cwd test
  moved onto `run_probe_bounded`. Local helpers: `make_tag_repo`,
  `make_one_commit_repo` and `assert_merge_without_target`. These sit above
  the tests because shellcheck flags a helper read after the `@test`
  subshells (SC2030/2031), and the other bats files order them the same way.
  294 lines.
- `tests/helpers/probes.bash`:
  - `run_probe_command` and `index_mtime` moved in;
  - `run_probe_bounded` gained the optional `<command>`;
  - the header and "Shared by" lines were updated.

  237 lines.
- `tests/probes-readonly-facts.bats`: its `run_probe_command` and `index_mtime`
  copies were removed. 314 lines.

## Verification

- `scripts/run-bats.sh tests/probes-readonly-pins.bats
  tests/probes-readonly-facts.bats tests/probes-edges.bats
  tests/probes-config.bats` against the committed SUT: 46 passed, 0 failed.
- Full suite, foreground, sandbox disabled, `scripts/run-bats.sh tests/`: 239
  passed, 0 failed.
- `shellcheck -x` on the three touched test files: clean.
- `scripts/check-line-limits.sh`: passed. All touched files are under 400
  lines.
- `git diff --quiet lib/ hooks/ docs/`: clean, so no lasting change outside
  the tests.
- Harness incident, recovered: my first mutation harness restored by replacing
  the *first* occurrence of the replacement text. For the `match=d` mutation
  (replacement `; then`), that re-inserted the guard at line 38 instead of
  line 230. The harness's `git diff --quiet lib/` check flagged it at once. I
  restored both spots by inverse replacement until `git diff --quiet lib/`
  passed, fixed the harness to invert at the recorded offset, and re-ran that
  whole batch. The results above come from the re-run.

## Positive Observations

- The slice covers every review fix the runbook names. The RED report flagged
  its own non-red on the porcelain reversion instead of hiding it, and that is
  what led to the fixture fix.
- `make_scratch_repo` was moved verbatim, and the facts suite stays green.
