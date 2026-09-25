# Review: Item 4.3 slices 2-5 — test review (batched)

**Scope**: uncommitted test changes — `tests/probes-readonly.bats` (new),
`tests/hook-candidates.bats`, `tests/hook-locks.bats`,
`tests/helpers/hook.bash`, `tests/helpers/probes.bash` — plus the inert
`probe_readonly_path` stub in `lib/probes.sh` (stub completion only).
**Date**: 2026-09-26
**Mode**: review + fix (TDD test review)

## Summary

The RED batch was sound in shape: every probe test reds on an assertion
against the inert stub, and slice 5's pass-before-implementation is covered
by a mutation proof. The gaps were in what the unreached assertions would
tell apart once GREEN lands. No test separated testing the file from testing
its parent when the file exists. None put a decoy quoted path off the
matching line, or a second quoted path on it. No path held a blank. The
relative-path case could not tell a plain cwd join from the lock probes' walk
up to `.git`, so its result depended on the host. Five fixes to tests, three
new tests. Every test was then run against a scratch reference probe and
nine wrong ones, with the stub restored after each run.

**Overall Assessment**: Ready (for GREEN)

## Relative-path interpretation — confirmed, precedent corrected

The RED reads a relative quoted path as resolved against the payload cwd.
That reading is **confirmed**: the Probe paragraph says `test -w` on the
extracted path, and the producers in the matcher's scope resolve a relative
path against their own process cwd — Python (the cut fixture's own shape),
`cp`, `mv`, `touch`, bash. The payload cwd is the hook's closest proxy for
that directory.

The cited precedent is **corrected**. `_probe_resolve_path` does not just
join onto the cwd. It walks up to the nearest `.git` directory and joins
there, and its own comment justifies the walk by how git prints a *lock*
path. Carried over, the walk would resolve a Python path from a repo
subdirectory against the top-level, which names a file no error named. The
RED's fixture had no `.git` above its cwd, so it passed either way, or failed
either way if an ancestor of `$BATS_TEST_TMPDIR` held a `.git`. The test now
puts a `.git` directory one level above a `sub/` cwd, which pins the plain
join. This is a review decision, taken because the slice's own test would
otherwise let GREEN settle it silently. It is overridable, and undoing it
costs one fixture line: git's own top-level-relative quoted paths are the
case it trades away. The whole corpus's paths are absolute apart from the
Python one.

## Issues Found

### Critical Issues

None.

### Major Issues

1. **File vs parent not discriminated for an existing file**
   - Location: `tests/probes-readonly.bats` (slices 2-3)
   - Problem: `writable path` uses a writable file in a writable directory,
     so a probe that always tests the parent (or the parent whenever it
     exists) passes every test. The spec tests the file itself when it
     exists.
   - Fix: new test `existing file checks the file itself`. A `chmod 444`
     file in a writable directory must read `readonly`. A writable file in a
     `chmod 555` directory must read `writable`. In each half the file and
     its parent disagree.
   - **Status**: FIXED

2. **First quoted path of the *matching line* not pinned**
   - Location: `tests/probes-readonly.bats`
   - Problem: every refusal text carried exactly one single-quoted path, on
     the matching line. A probe taking the first quoted string anywhere in
     the text, or the last one on the line, passed.
   - Fix: two new tests.
     - `first quoted path on the line`: two quoted paths substituted into the
       cut fixture's segment, as `mv`'s two-path shape has them; asserts
       `path=` is the first.
     - `quoted path off the matching line is ignored`: a decoy line with its
       own quoted path, placed ahead of the refusal line. The positive half
       names a target path. The negative half's refusal line names none and
       must stay `nopath` with no `path=` line.
   - **Status**: FIXED

3. **Relative-path case host-dependent and non-discriminating**
   - Location: `tests/probes-readonly.bats` `relative path resolves against
     cwd`
   - Problem: see the section above. The comment cited
     `_probe_resolve_path` as the rule, which it is not.
   - Fix: cwd `$BATS_TEST_TMPDIR/repo/sub` with `repo/.git` present; comment
     rewritten to state the plain join and why the walk is excluded.
   - **Status**: FIXED

4. **No path with a blank** (whitespace safety)
   - Location: `writable path`, `writable path survives BSD grep and sed`
   - Problem: a path gets quoted because it may hold a blank, and neither
     test gave it one. An extraction that splits on blanks passed.
   - Fix: both targets now live under `$BATS_TEST_TMPDIR/a dir/`.
   - **Status**: FIXED

### Minor Issues

1. **`chmod 555` skip keyed on the uid, not the precondition**
   - Location: `absent file checks its parent`
   - Problem: `id -u` = 0 is only one way the mode goes unenforced. A
     capability, or a filesystem that ignores modes, leaves the directory
     writable with a non-zero uid, and then the `readonly` assertion reds for
     the wrong reason.
   - Fix: local helper `ro_dir <dir>` — mkdir, `chmod 555`, record in
     `RO_DIR` for the existing teardown, `skip` when `[ -w ]` still holds.
     The new 444 half checks `[ -w ]` directly in the same way.
   - **Status**: FIXED

2. **Readonly half asserted no `path=` line**
   - Location: `absent file checks its parent`
   - Fix: added `grep -qxF "path=$path"` after the `readonly` assertion.
   - **Status**: FIXED

3. **Slice 5 stub printed an outcome outside the contract**
   - Location: `tests/hook-candidates.bats` `hook silent without a verdict`
   - Problem: `stub_probe readonly_path mask`, where `mask` is a lock
     outcome. The stub is never reached, but its outcome should belong to
     the probe it stands in for.
   - Fix: `stub_probe readonly_path writable`.
   - **Status**: FIXED

4. **`readonly_path_text` overstated "verbatim"**
   - Location: `tests/helpers/probes.bash`
   - Problem: sed reads a replacement holding `#`, `&` or a backslash, so
     none of those is inserted verbatim.
   - Fix: added a residual clause to the comment.
   - **Status**: FIXED

### Checked, no finding

- **`nopath` absence of `path=`**: `run ! grep -q '^path=' <<<"$output"` is
  present and sits beside positive cases using the same fixture with a path.
  A probe printing an empty `path=` line reds it (variant below).
- **BSD case under stubs**: `PATH="$bsd:$PATH" run_probe …` exports the
  prefix for the function's duration, and `run`'s subshell inherits it. This
  is the pattern `tests/probes.bats` and `tests/probes-tools.bats` already
  use. The stubs cover grep and sed. Whether GREEN calls either is up to
  GREEN.
- **Teardown**: `RO_DIR` is reset in `setup` and restored to 755
  unconditionally. The 444 file sits in a writable directory, so bats can
  remove it.
- **`stub_probe` move**: no other suite defines `stub_probe`, and
  `stub_probe_kv` stays local to `hook-locks.bats`. `hook-locks.bats`
  passes 1..18 as before (all ok).
- **Stub completion**: `probe_readonly_path` drains stdin, prints nothing,
  exits 0, and every test reds on its first-line assertion rather than
  erroring. Complete as a stub.
- **Self-quiet**: `detect` from `lib/matchers.sh` run over every changed or
  new file, including the RED report, fires on none. `tests/docs.bats` is
  ok, but it covers tracked files only, so the untracked new suite was
  checked directly.

## Fixes Applied

- `tests/probes-readonly.bats`:
  - Added the `ro_dir` helper.
  - `writable path` and the BSD case: target path holds a blank.
  - `relative path…`: `.git`-above fixture, comment rewritten.
  - `absent file…`: uses `ro_dir` and asserts `path=`.
  - New tests: `existing file checks the file itself`, `first quoted path on
    the line`, `quoted path off the matching line is ignored`.
- `tests/hook-candidates.bats`: stub outcome `mask` → `writable`.
- `tests/helpers/probes.bash`: residual clause on `readonly_path_text`.

## Mechanical check

`bats tests/probes-readonly.bats tests/hook-candidates.bats
tests/hook-locks.bats`, foreground, after the fixes: 1..26. Tests 1-8 (the
probe suite) are all not ok, each on its first-line assertion; none errors,
and none skipped at uid 1000. Tests 9-26 are all ok.

| test | fails on |
|---|---|
| writable path | `= writable` |
| relative path resolves against cwd | `= writable` |
| absent file checks its parent | `= writable` |
| existing file checks the file itself | `= readonly` |
| first quoted path on the line | `= writable` |
| quoted path off the matching line is ignored | `= writable` |
| no quoted path | `= nopath` |
| writable path survives BSD grep and sed | `= writable` |

`shellcheck -x` on all six files: exit 0. `just test`: 174 passed, 8 failed.
The 8 are exactly the cases above.

## Unreached assertions — variant runs

The inert stub never reaches past line 1, so the `chmod 555` half, the
decoy's negative half and each `path=` check would otherwise go unexercised
until GREEN. A scratch script swapped the stub body for a reference probe
(the matcher's line regex, first single-quoted segment, plain cwd join, file
or else parent `test -w`), then for single-edit wrong variants of it. Each
run was exact-string, inverted afterwards. `git diff lib/probes.sh` after
all runs shows only the stub, blob `bab1f85` as received.

| variant | reds | on |
|---|---|---|
| reference | none — 8/8 ok | — |
| always test the parent | existing file | `= readonly` |
| no parent fallback | absent file | `= writable` |
| absent path always reads writable | absent file (`chmod 555` half) | `= readonly` |
| first single-quoted line in the text | off-matching-line | `path=$target` |
| fall back to text when the line has no path | off-matching-line (negative half) | `= nopath` |
| last quoted path on the line | first quoted path | `path=$first` |
| `_probe_resolve_path` walk | relative path | `= writable` (see note) |
| split path on blanks | writable path, BSD case | `path=$target` |
| empty `path=` on nopath | no quoted path, off-matching-line | `run ! grep '^path='` |

Note on the walk row: the walk names `repo/hooks/hooks.json`, which does not
exist. Its parent `repo/hooks` does not exist either, so the reference's
parent test reads `readonly` and the first-line assertion reds before the
`path=` check. Both lines discriminate. The "absent always writable" variant
also perturbed the existing-file test. That is an artefact of how it was
written, and the row records only the target case.

## Slice 5 mutation proof (a different mutation from the RED's)

The RED let the verdict gate fall through, and the test redded on
`[ -z "$output" ]`. This proof instead runs the probe *before* the gate, with
its output discarded. That is the plausible wrong ordering the slice exists
to rule out, and it isolates the `$PROBE_CALLED` assertion.

| step | detail |
|---|---|
| mutation | in `hooks/annotate.sh`, exact string `  declare -F "$fn" >/dev/null \|\| continue` (1 occurrence) replaced by a line calling `probe_${name//-/_}` on the text when defined, output to /dev/null, followed by the original line |
| red | `hook silent without a verdict` (4) not ok on `[ ! -f "$PROBE_CALLED" ]` — status 0 and empty output both held, so only the call-recorded assertion caught it; `no probe without a verdict` (17, `hook-locks.bats`) not ok on `[ ! -f "$called" ]`, the same shared gate; the other 16 ok |
| restore | inverse exact-string replace; `grep -cF` of the inserted text in `hooks/annotate.sh` → 0 (the same pattern counts 1 on a line holding it); `git diff --stat hooks/annotate.sh` empty; `git status --short hooks/` clean; re-run 1..18 all ok |

## Requirements Validation

| Requirement | Status | Evidence |
|---|---|---|
| Interfaces: `writable\|readonly\|nopath`, `path=` when extracted, exit 0 | Pinned | all 8 probe tests assert `$status` 0 and line 1; the `path=` presence and absence cases |
| Slice 2 `writable path` | Pinned | `writable path` |
| Slice 3 `absent file checks its parent` | Pinned | `absent file checks its parent`, plus the existing-file counterpart |
| Slice 4 `no quoted path` | Pinned | `no quoted path`, off-matching-line negative half |
| Slice 5 `hook silent without a verdict` | Pinned, mutation-proved | `hook-candidates.bats` |
| Portability (runbook cross-cutting) | Pinned | BSD grep/sed case |
| Spec "first quoted path from the matching line" | Pinned | two new tests |

## Positive Observations

- Refusal text is built at run time from the cut fixtures, so the new suite
  stays self-quiet without hand-held fragments.
- The RED report flagged its own interpretation rather than presenting it
  as spec, and proved slice 5's already-green test instead of leaving it.
- `stub_probe` moved to the shared helper intact, with the dispatch's reuse
  rule followed.

## Recommendations

- GREEN: extract the matching line with the matcher's own regex
  (`match_readonly_path`'s pattern) rather than a looser grep; the
  off-matching-line test depends on it.
- If the orchestrator prefers the `.git` walk for relative paths, drop the
  `repo/.git` fixture line and the comment's exclusion sentence; nothing
  else in the suite depends on it.
