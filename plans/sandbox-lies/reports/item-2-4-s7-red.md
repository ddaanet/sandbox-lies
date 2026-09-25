# RED: Item 2.4 / slice 7 — relative path resolves against cwd

**Scope**: `tests/probes.bats` only. `lib/probes.sh` untouched (`git diff
--stat` shows no entry for it; no mutation was needed — see below).
**Date**: 2026-09-25
**Mode**: RED

## Test written

`tests/probes.bats` — `relative path resolves against cwd` (new file total:
324 lines, under the 400-line cap).

The text names the lock by the path relative to git's own cwd
(`.git/index.lock`), built via the existing `git_lock_error` fragment
builder (self-quiet: no literal diagnostic on disk). `$2` is a repo dir
(`$BATS_TEST_TMPDIR/r`) holding a present, unheld 7-byte lock at
`.git/index.lock`. The probe itself is run from a third, freshly made,
unrelated directory (`$BATS_TEST_TMPDIR/elsewhere`) that holds no `.git` at
all, so the relative path cannot resolve there — only `$2` can supply it.

To make the probe's own process cwd differ from the test's, the probe runs
inside a nested `bash -c` invocation that first `cd`s to the unrelated
directory, then sources `lib/probes.sh` and calls `probe_git_lock false
"$repo"` — a subshell rather than a `cd` in the test body itself, so the
test needs no teardown to restore cwd (bats already isolates each `@test` in
its own subshell, but this keeps the intent explicit as the dispatch asked).
`$1`/`$2`/`$3` inside the single-quoted `bash -c` script are that nested
script's own positional params (unrelated dir, `$ROOT`, repo dir), not this
test's shell variables, so they are deliberately left unexpanded by the
outer shell; a `shellcheck disable=SC2016` comment sits directly above with
a one-line reason, on its own line so shellcheck can still parse the
directive (an inline `-- reason` on the same line as the directive made
shellcheck fail to parse it — SC1073/SC1072 — during a first attempt; fixed
by moving the reason to a comment line above the directive).

`path=` is asserted with `grep -qxF "path=$lock"` where `$lock` is the
literal `$repo/.git/index.lock` (`$repo="$BATS_TEST_TMPDIR/r"`), not a
`realpath` of it: the item text says the path "resolves against `$2`", and
`$2` is used as given rather than canonicalised, so the expectation names
the same literal path `$2` was constructed from, consistent with how every
other case in this file builds and asserts `path=`.

## Run: full suite, current SUT (uncommitted test, unmodified `lib/probes.sh`)

`cd /Users/david/code/sandbox-lies && scripts/run-bats.sh tests/probes.bats tests/probes-edges.bats`
(foreground): **17 passed, 1 failed**.

```
1..18
ok 1 absent lock, sandboxed, is mask
ok 2 absent lock, unsandboxed, is gone
ok 3 non-UTF-8 byte in the path
ok 4 present unheld lock is orphan
ok 5 unexpected flag reads as sandboxed
ok 6 quote and space in the lock path
ok 7 held lock names the holder
ok 8 held lock under a quoted, spaced path
ok 9 character device is mask
ok 10 no holder tool is unknown
not ok 11 relative path resolves against cwd
# (in test file tests/probes.bats, line 322)
#   `[ "${output%%$'\n'*}" = orphan ]' failed
ok 12 vanished lock is gone
ok 13 non-regular lock has no size
ok 14 future mtime is age 0
ok 15 lock vanishing during the holder check reads gone
ok 16 unexpected holder-tool stderr is passed through
ok 17 lsof decides when present
ok 18 dangling symlink lock is a quiet orphan
```

### `relative path resolves against cwd` — the new, unimplemented case

Fails on its own assertion (`[ "${output%%$'\n'*}" = orphan ]`, line 322),
not on a missing symbol or an ImportError/AttributeError-equivalent. Manual
run of the same nested-`bash -c` shape confirms what the current SUT prints:

```
mask
path=.git/index.lock
```

— i.e. `probe_git_lock` resolves the relative path against its own process
cwd (the unrelated directory, where no lock exists), reads it as absent, and
reports `mask` with the unresolved relative `path=` line — exactly the
failure mode the item and the dispatch name (slice 2's code review: the
probe runs from a working directory unrelated to `$2`, so a probe that
resolves against process cwd instead of `$2` cannot pass this test).

## Mutation proof

None needed. The test fails directly against the unmodified `lib/probes.sh`
on its own assertion (not vacuously passing), so RED mode's mutation-proof
step does not apply: the behaviour under test (resolving a relative path
against `$2`) does not yet exist in the SUT — it is slice 7's own GREEN
work, out of scope here. `git diff --stat lib/probes.sh` confirms the file
was never touched during this dispatch.

## shellcheck

```
cd /Users/david/code/sandbox-lies && shellcheck tests/probes.bats
```
One `SC1091 (info)` notice on the pre-existing `source "$ROOT/lib/probes.sh"`
line (`tests/probes.bats:16`) — the same notice the slice 6 RED report
recorded, unrelated to this dispatch's edit and resolved when shellcheck runs
over the whole tracked set (as `just precommit` does). No other finding.

A first draft of the new test's `shellcheck disable=SC2016` comment put the
justification inline on the same line as the directive
(`# shellcheck disable=SC2016 -- reason`); shellcheck could not parse that
(`SC1073`/`SC1072`, reported by the PostToolBatch hook after the edit) and
was fixed by moving the reason to its own comment line directly above the
bare `# shellcheck disable=SC2016` line. Re-run of `shellcheck
tests/probes.bats` after the fix shows only the pre-existing SC1091 info
notice above.

## Self-quiet check

```
cd /Users/david/code/sandbox-lies && bash lib/matchers.sh < tests/probes.bats; echo rc=$?
```
No stdout; `rc=1`.

## Line count

```
324 tests/probes.bats
```
Under the 400-line cap.

## Scope

Touched only `tests/probes.bats` (one new `@test` block, 29 inserted lines).
`lib/probes.sh`, `tests/probes-edges.bats`, `tests/helpers/probes.bash`, the
resolution implementation, and slices 8–10 were not touched. Nothing
committed.
