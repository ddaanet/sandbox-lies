# Review: Item 8.0 slice 3 test review — `the probe reports the facts`

**Scope**: `tests/probes-readonly-facts.bats` (new, uncommitted) and
`plans/sandbox-lies/reports/item-8-0-s3-red.md`. `lib/` and `hooks/` are OUT
and were not edited.
**Date**: 2026-09-27
**Mode**: review + fix (test review, per the Item 8.0 dispatch brief)

## Summary

The RED file covers every case the slice lists, and all 13 of its tests
failed on a value assertion against unchanged code. The review found one
wrong-reason defect that would have caused a false red after GREEN
(`index_mtime` on GNU), a fixture that does not match the text git actually
prints, three rules pinned only through a fallback or with no decoy, a
missing BSD-stub case, and one command string that expands `$BATS_TEST_TMPDIR`
unquoted. All are fixed. The file now has 14 tests (370 lines). Every test
still fails on an assertion. A throwaway mock implementation passes all 14,
and each of seven mutants of it fails the test meant to catch it.

**Overall Assessment**: Ready

## Mechanical first check

`scripts/run-bats.sh tests/probes-readonly-facts.bats`, run in the
foreground on unchanged `lib/`, gave 0 passed, 13 failed. Each test failed
on a `grep -qxF` value assertion at the line the RED report names. None
passed and none errored. `$status` was 0 and `$stderr` empty on the calls
before each failure. The RED report's per-test lines match what I saw.

## Issues Found

### Critical Issues

1. **`index_mtime` reads the filesystem's free-block report on GNU**
   - Location: `tests/probes-readonly-facts.bats` `index_mtime`
     (was lines 74-76)
   - Problem: on GNU, `stat -f %m "$1" 2>/dev/null || stat -c %Y "$1"` takes
     `-f` as filesystem mode and `%m` as a missing operand. It still prints
     the filesystem report for the index (free blocks, free inodes) before
     exiting 1, and `||` then adds the mtime. I confirmed this on this box.
     The before and after values therefore include free-block counts that
     any other process on the box can change. After GREEN, the mtime
     assertion would fail even though the probe wrote nothing. The comment
     claimed it matched `lib/probes.sh`, but that code keeps the `-f` value
     only on exit 0 and only when it reads as seconds.
   - Fix: keep BSD's value only when the command exits 0 and the value is
     all digits; otherwise use `stat -c %Y`. The comment now says why.
   - **Status**: FIXED

### Major Issues

1. **The partial-checkout fixture is text a real sandbox cannot produce**
   - Location: `partial_checkout_unlink_error`,
     `partial_checkout_create_error`, and the test `merge=1 fires from git's
     partial-checkout error…`
   - Problem: the builders ended in `Permission denied` and appended git's
     line after the `cp` fixture line. Under the sandbox, git's own line ends
     in the read-only-filesystem message, and git's text is the refusal.
     Git's format strings (git 2.47, `strings $(command -v git)`) are
     `unable to unlink old '%s'` and `unable to create file %s`: the create
     form does **not** quote the path. The builder quoted it.
   - Fix: both builders now use git's shape and end in `erofs_message`, and
     each is still split into two fragments (FR-11). The text is git's line
     alone. The unlink form therefore reads `writable` and the unquoted
     create form reads `nopath`, so each outcome that carries facts is
     covered. The command is now `just sync`, a realistic "any command" that
     is not a reader and not git. I added a paired negative: the `cp`
     refusal on the same path under the same command gives `writable` and
     no `merge=1`.
   - **Status**: FIXED

2. **`match=` had no decoy for the "modified against HEAD" filter**
   - Location: `make_scratch_repo` and the test `target and match select
     files…`
   - Problem: feat changed every tracked file. An implementation that listed
     every file whose working-tree content equals the target's, without the
     "modified against HEAD" filter, would still print exactly `a` and `b`.
   - Fix: added `d`, committed on main and left unchanged by feat. Its
     working-tree content equals feat's, and the test asserts no `match=d`.
     Mutant `nohead` (the mock listing `ls-files`) now fails on
     `match=d`.
   - **Status**: FIXED

3. **"Path's repository, else cwd's" was pinned only by the fallback**
   - Location: the test `the repository is the path's nearest existing
     directory's…`
   - Problem: the cwd had no repository (`assert_no_git_above`). An
     implementation that preferred the cwd's repository whenever one exists
     would still pass this test and the nopath test.
   - Fix: the cwd is now a second repository with no `feat` branch. Mutant
     `cwdfirst` now fails on `target=feat`.
   - **Status**: FIXED

4. **The no-write snapshot could miss a same-second rewrite with identical
   bytes**
   - Location: the test `target and match select files…`
   - Problem: the snapshot was taken before `readonly_path_text` rather than
     right around the probe call, and `stat` resolves only to the second.
     If the index was rewritten with identical bytes in the second the
     fixture was made, neither `cmp` nor the mtime would change.
   - Fix: the index is back-dated with `touch -t 200001010000`, which works
     on both BSD and GNU. The copy and mtime are taken immediately before the
     probe, and the output is saved to `$facts` before the checks. I checked
     that the back-dating does not make correct reads write: `git
     --no-optional-locks status`, `git diff`, `diff-files` and `diff-index`
     all left the index identical. I also found a real trap for GREEN:
     `git diff <ref> -- <file>` rewrites the index even with
     `--no-optional-locks` (git 2.47). Mutant `writes`, which uses it, fails
     on the `cmp`.
   - **Status**: FIXED

5. **No BSD-stub case, and `helpers/bsd-stubs` was not loaded**
   - Location: file header and a new last test
   - Problem: the new parsing (readfile quoting, merge detection, match
     listing) would never run under the BSD stubs. A `\b`, a `grep -P` or a
     `sed -i` in GREEN would pass on Linux.
   - Fix: added `load helpers/bsd-stubs` and the test `the facts survive
     BSD grep, sed, stat and wc`. It runs one probe call for each kind of
     fact (ref and files, quoted reader argument, partial-checkout text)
     under `make_bsd_stubs grep sed stat wc`. This follows the
     existing pattern in `tests/probes-readonly.bats`.
   - **Status**: FIXED

6. **Whitespace-safe paths were not exercised, and one command string
   expanded the tmpdir unquoted**
   - Location: the test `merge=1 fires for a git merge-style command
     segment`, and every repository test
   - Problem: `"git -C $BATS_TEST_TMPDIR/repo checkout feat"` put the tmpdir
     into the command unquoted. A tmpdir holding a blank would split `-C`'s
     argument, and a correct probe would then see a different subcommand.
     No repository path and no `match=` file held a blank, so an unquoted
     `git -C $dir` or a word-split file list in GREEN would pass.
   - Fix: the command is now `git -C /r/repo checkout feat`. The command is
     only parsed, and nothing in it needs to exist. Every scratch repository
     is now `…/scratch repo`, and the cwd decoy is `…/other repo`. The
     fixture adds `e f`, unstaged at feat's content, and the tests assert
     `match=e f` as a whole line. The contract says word splitting is safe
     only for `target=`; the only residual for `match=` is a name holding a
     newline. Mutant `staged` also fails on `match=e f` under the BSD stubs.
   - **Status**: FIXED

7. **Only `readfile=` was checked against the readonly outcome**
   - Location: the test `facts appear only under writable and nopath, never
     readonly`
   - Problem: the readonly leg ran only `cat build.log`. An implementation
     that suppressed `readfile=` under readonly but still printed `merge=1`
     would pass.
   - Fix: `git pull` added under both legs: `merge=1` under writable, and
     exactly two lines under readonly for both commands. The redundant
     `run ! grep` after the line count was removed. Mutant `readonly`, which
     prints facts under every outcome, fails on the line count.
   - **Status**: FIXED

### Minor Issues

1. **Test 8's positive was not the same command as its negative**
   - Location: `merge=1 does not fire for a non-merge command or a quoted
     mention`
   - Note: the positive was `git pull`, while the negative was `echo git
     merge feat`. Pairing them means differing only in the trigger, so the
     positive is now `git merge feat`. The test name said "quoted", but the
     command is not quoted, so the name now says "an echoed mention".
     Mutant `anymerge` fails on the negatives.
   - **Status**: FIXED

2. **"Unresolvable ref gives no target" was a bare negative**
   - Location: `an unresolvable ref gives merge=1 and no target`
   - Note: I added a paired positive on the same fixture. `git merge feat`
     gives `target=feat`, and the test now fails there today. Mutant
     `noresolve`, which prints the first word without resolving it, fails
     on `no target=`.
   - **Status**: FIXED

3. **Probe exit and stderr were not pinned where git runs**
   - Location: the merge-segment test (no repository at the cwd), the
     repository tests, and the BSD test
   - Note: the suite's probe tests pin `[ "$status" -eq 0 ]` and
     `[ -z "$stderr" ]` (A-3 contract, `tests/probes-readonly.bats`). A
     probe that runs `git rev-parse` outside a repository would leak
     `fatal: not a git repository` to stderr. These assertions are added
     where the probe may run git. They pass today, and each test still
     fails at its fact assertion.
   - **Status**: FIXED

4. **`target=` implies `merge=1`, but the test did not check it**
   - Location: `target and match select files…`
   - Note: added a whole-line `merge=1` check. The test now fails there
     first today.
   - **Status**: FIXED

## Checked and sound (no change)

- Every case the slice lists is present. Readfile covers `cat /w/build.log`
  and `tail -n 50 "/w/a b.output" | grep -i error` → `/w/a b.output`.
  Each readfile negative (`cat notes.md`, `sed -i`, `> copy.txt`,
  `make 2>&1 | tee`, `npm test && cat`) is followed by a positive over the
  same fixture. Merge covers `git merge --ff-only feat`, `git -C <repo>
  checkout feat`, `git pull`, the partial-checkout error under any command,
  and the negatives `git log --merges` and `echo git merge feat`. The
  scratch-repo tests cover `match=a`, `match=b`, never `c`, the
  unresolvable ref, path-repo versus cwd-repo, and index byte, mtime and
  `index.lock`.
- Fixture state, checked by hand after the edit: HEAD is `main`. `a` has
  index and working tree at feat. `b` and `e f` have the working tree at
  feat and the index at HEAD. `c` differs from both feat and HEAD. `d` has
  working tree, HEAD and feat all equal. `git status --porcelain` shows
  `M  a`, ` M b`, ` M c`, ` M "e f"`.
- Every `match=`, `target=`, `merge=1` and `readfile=` check is a whole-line
  `grep -qxF` (or an anchored `^…$`).
- No `run !` reads a second-hand `$output`. Each negative herestring reads
  either the probe run just before it or the saved `$facts`. Without that,
  the second of two consecutive `run !` lines would test the first one's
  empty output.
- nopath takes the repository from the cwd (`nopath falls back to the cwd's
  repository`).
- bash 3.2: no `[[ =~ ]]`, no arrays in the file, `${m//[0-9]/}`,
  `<<<`, `local`. `wc -l`'s BSD padding is compared with `-eq`, which
  accepts leading blanks.

## Fixes Applied

- `tests/probes-readonly-facts.bats` header: the comment now names
  `erofs_message`; added `load helpers/bsd-stubs`.
- `partial_checkout_unlink_error` / `partial_checkout_create_error`: git's
  real shapes (create form unquoted), ending in `erofs_message`, still two
  fragments each.
- `make_scratch_repo`: added `d` (the unchanged decoy) and `e f` (a spaced
  name, unstaged at feat).
- `index_mtime`: the BSD value is kept only on exit 0 and when it is all
  digits; otherwise `stat -c %Y`.
- The readonly-leg test: `git pull` added under both legs; line count
  checked for both commands.
- The merge-segment test: `git -C /r/repo checkout feat`; status and stderr
  pinned.
- The non-merge test: positive `git merge feat`; renamed to "echoed
  mention".
- The partial-checkout test: git-only texts (writable and nopath), `just
  sync`, and a paired negative.
- The target/match test: scratch repo under a blank-holding path; index
  back-dated and snapshotted around the probe call only; `$facts` saved;
  status, stderr and `merge=1` pinned; `match=e f` required; `match=d`
  forbidden.
- The unresolvable-ref test: paired `git merge feat` → `target=feat`.
- The path-versus-cwd test: the cwd is a second repository with no feat;
  the repository paths hold blanks.
- The nopath test: blank-holding repository path; status and stderr pinned.
- New test `the facts survive BSD grep, sed, stat and wc`.

## Re-run after fixes

`scripts/run-bats.sh tests/probes-readonly-facts.bats` gave 0 passed, 14
failed. Each test fails on a fact assertion:

| # | test | first failing assertion |
|---|---|---|
| 1 | readfile … single reader | `readfile=/w/build.log` |
| 2 | readfile … quoted … pipeline | `readfile=/w/a b.output` |
| 3 | facts … never readonly | `readfile=build.log` (writable leg) |
| 4 | readfile requires … extension | `readfile=build.log` (positive) |
| 5 | readfile excludes … editor … redirected | `readfile=build.log` (positive) |
| 6 | readfile requires every command … reader | `readfile=build.log` (positive) |
| 7 | merge=1 … merge-style segment | `merge=1` (status and stderr passed first) |
| 8 | merge=1 does not fire … | `merge=1` (the `git merge feat` positive) |
| 9 | merge=1 … partial-checkout error | `merge=1` (after `writable` passed) |
| 10 | target and match … | `merge=1` (after the index checks, status, stderr and `writable` passed) |
| 11 | unresolvable ref … | `target=feat` (paired positive) |
| 12 | repository is the path's … | `target=feat` |
| 13 | nopath falls back … | `target=feat` |
| 14 | facts survive BSD … | `target=feat` |

`cd /Users/david/code/sandbox-lies && bash -c '. lib/matchers.sh; detect' <
tests/probes-readonly-facts.bats` printed nothing and exited 1 (FR-11
self-quiet).

## Satisfiability and mutation check (throwaway, outside the repo)

I copied `lib/` and `tests/` to `$TMPDIR` and appended a mock
`probe_readonly_path` that implements the facts table. It passed all 14
tests. Each mutant failed exactly the test meant to catch it:

| mutant | fails |
|---|---|
| facts printed under readonly | 3 (line count) |
| `merge` substring anywhere in the command | 8 (negative) |
| cwd's repository preferred when one exists | 12 (`target=feat`) |
| target printed without resolving | 11 (`no target=`) |
| no "modified against HEAD" filter | 10 (`match=d`) |
| staged files only | 10 (`match=b`), 14 (`match=e f`) |
| `git diff <ref> -- <f>` per file | 10 (`cmp` of the index) |

I deleted the copy afterwards. No repository file other than the two named
below was touched.

## Requirements Validation

| Requirement | Status | Evidence |
|---|---|---|
| detectors.md `merge=1` row | Satisfied | tests 3, 7, 8, 9, 11, 14 |
| detectors.md `target=` row | Satisfied | tests 10, 11, 12, 13, 14 |
| detectors.md `match=` row | Satisfied | test 10 (`a`, `b`, `e f`; never `c`, `d`), 12-14 |
| detectors.md `readfile=` row | Satisfied | tests 1-6, 14 |
| Facts only under writable and nopath | Satisfied | test 3 |
| Repository: path's nearest existing directory, else cwd's | Satisfied | tests 12, 13 |
| Writes nothing (NFR-4) | Satisfied | test 10 |
| NFR-2 BSD tools | Satisfied | test 14 |
| FR-11 self-quiet | Satisfied | `detect` silent over the file |

## Positive Observations

- The RED report records where each mixed test lands its red, and it put
  test 8's positive first so the test could not red vacuously.
- `run_probe_command` stays local and leaves `helpers/probes.bash`
  unchanged. `readonly_path_text` and `erofs_message` are reused.
- The fixture's `c` edited to a third value is the right decoy against an
  implementation that lists every file modified against HEAD.

## Recommendations

- For GREEN: `git diff <ref> -- <file>` rewrites the index even with
  `--no-optional-locks` (git 2.47). Compare blobs with `git cat-file blob
  <ref>:<file>` against the working-tree file, and list the files with
  `git --no-optional-locks diff --name-only -z HEAD`, read with NUL
  delimiters.
- Near-miss left open: "nearest existing directory" differs from "the
  path's parent" only when the path is an existing directory, since a
  missing parent reads `readonly`. No test separates the two.

Files: `/Users/david/code/sandbox-lies/tests/probes-readonly-facts.bats`
(edited), this report. Nothing committed.
