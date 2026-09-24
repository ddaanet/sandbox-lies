# Item 2.4 / slice 4 — RED report

Dispatch: item-2-4-s4-red. Mode: RED.

## Slice (from the runbook, current text)

4. `held lock names the holder` — a background `sleep 30` holding the lock
   open on an fd other than 3, with bats' fd 3 closed (`3>&-`) so the run does
   not wait on it: `held`, `pid=` equal to that job's pid; the job is killed
   in teardown. `held lock under a quoted, spaced path` (slice 3's reviews:
   the only case pinning the holder tools' quoting) — the same under
   `$BATS_TEST_TMPDIR/it's here/r`: `held`, `pid=`. The holder check runs
   before the size and age reads, or presence is re-checked after it, so a
   holder exiting mid-check reads `gone`, not `orphan` (slice 3's code
   review, implementation-ordering constraint for GREEN — not a test written
   here).

## Tests added (`tests/probes.bats`)

Two tests, exactly as the slice names them, plus a `teardown()` (none
existed before) and a `_probe_holder_pid=` reset added to `setup()`.

1. **`held lock names the holder`** — writes a 7-byte lock under
   `$BATS_TEST_TMPDIR/r/.git/index.lock`, then backgrounds
   `sleep 30 4<"$lock" 3>&- &`, recording `$!` as `_probe_holder_pid`. Runs
   `probe_git_lock false <cwd>` and asserts line 1 `held` and an exact-line
   `pid=$_probe_holder_pid`.
2. **`held lock under a quoted, spaced path`** — identical shape, lock under
   `$BATS_TEST_TMPDIR/it's here/r/.git/index.lock`.

Both assert `status -eq 0` and empty `stderr`, matching the suite's existing
style. `teardown()` kills and waits on `$_probe_holder_pid` when set, a no-op
for every other test since `setup()` resets it to empty each time.

`lib/probes.sh` was not touched (no mutation was needed — see below).

## Verifying the fd-3 / pid mechanism on this box (before writing the tests)

Two things the dispatch asked to confirm rather than assume, checked in a
scratch directory (removed afterward) and not shipped in any test:

1. **A background job inheriting bats' fd 3 stalls the run for the sleep's
   full duration; closing it (`3>&-`) returns immediately.** A one-test
   scratch file backgrounding `sleep 5 4<file` with fd 3 left open made
   `bats` take 5.15s for a test whose own body finishes instantly; the same
   job with `3>&-` added made the run finish in 0.19s. `bats-exec-test`
   itself does `exec 3<&1` at top level (duplicating the suite's original
   stdout onto fd 3), which is the fd a leaked background job holds open.
2. **`$!` for `sleep 30 4<"$lock" 3>&- &` is the pid the holder tool
   reports.** Confirmed twice: once with a plain background job and `fuser`
   in an ordinary shell (`$!` was 5, `fuser "$lock"` printed `…lock:     5`),
   and once inside an actual `bats` `@test` body using `run --separate-stderr
   fuser "$lock"` (`$!` was 43; `fuser`'s stdout was `    43`, its stderr the
   path line) — matching the item text's note that `fuser` prints the path
   on its own stderr on every call. bash execs a simple backgrounded command
   directly, so no forked subshell sits between `$!` and the process the
   holder tool sees.

Both checks ran with the sandbox as given (not disabled): `fuser` sees the
job fine inside the command sandbox, so no re-run with the sandbox disabled
was needed.

## Suite run (foreground, `scripts/run-bats.sh tests/probes.bats`)

```
not ok 7 held lock names the holder
# (in test file tests/probes.bats, line 204)
#   `[ "${output%%$'\n'*}" = held ]' failed
not ok 8 held lock under a quoted, spaced path
# (in test file tests/probes.bats, line 225)
#   `[ "${output%%$'\n'*}" = held ]' failed

bats: 6 passed, 2 failed
```

Full run took ~1.1s wall clock (`time scripts/run-bats.sh tests/probes.bats`),
confirming no 30s stall from either held job.

Per-test outcome:

- `held lock names the holder` — **fails** on
  `[ "${output%%$'\n'*}" = held ]` (line 204): the current SUT has no holder
  check, so a present lock always falls into the `orphan` branch; line 1
  reads `orphan`, not `held`. Assertion failure, not a missing-symbol error.
  `status` was 0 and `stderr` was empty going into that assertion, so the
  test did not error earlier for the wrong reason.
- `held lock under a quoted, spaced path` — **fails** the same way, same
  line-1 assertion (line 225), same reason.
- `absent lock, sandboxed, is mask`, `absent lock, unsandboxed, is gone`,
  `non-UTF-8 byte in the path`, `present unheld lock is orphan`,
  `unexpected flag reads as sandboxed`, `quote and space in the lock path`
  (slices 1–3, unchanged) stayed green throughout.

No lingering `sleep 30` process after the run (`ps aux | grep 'sleep 30'`
empty): teardown's `kill`/`wait` reaped both jobs.

## Mutation proof

None. Both tests assert `held`, a behaviour the current SUT does not
implement anywhere (no `lsof`/`fuser` call exists in `lib/probes.sh`), so
each reds on its own assertion without any mutation needed. `lib/probes.sh`
is untouched — `git diff --stat -- lib/probes.sh` is empty.

## Self-quiet check

`bash lib/matchers.sh < tests/probes.bats` → no output, `rc=1`.

## Line count

`wc -l tests/probes.bats` → 227 (cap 400).

## Scope held

Only `tests/probes.bats` changed on disk (`git status --porcelain`:
`M tests/probes.bats`, nothing else tracked touched). `lib/probes.sh` is
byte-identical to HEAD. No implementation of the holder check, no other
slice's tests, and no `bsd-stubs.bash`/`stat`/`wc` stub work (slice 9's
scope) were added.

## Stop

No commit made. This report and the uncommitted test additions are the
designed end state of this RED dispatch.
