# RED: Item 2.4 / slice 5 — character device is mask; edge-case suite opens

**Scope**: `tests/probes.bats`, new `tests/probes-edges.bats`, new
`tests/helpers/probes.bash`. No implementation touched except for this
report's mutation proofs, each restored.
**Mode**: RED

## Move: shared helpers out of tests/probes.bats

`git_lock_error` and `run_probe` moved verbatim into new
`tests/helpers/probes.bash`, loaded by both `tests/probes.bats` (`load
helpers/probes`, alongside its existing `load helpers/bsd-stubs`) and the new
`tests/probes-edges.bats`. Ran `scripts/run-bats.sh tests/probes.bats`
before touching anything (baseline) and again right after the move, both
`8 passed, 0 failed` — the move alone changed nothing observable.

## New test in tests/probes.bats: `character device is mask`

A symlink to `/dev/null` at the lock path, flag `false` then `true`, expects
`mask` both times with a `path=` line. Ran alone:

```
not ok 9 character device is mask
# (in test file tests/probes.bats, line 253)
#   `[ -z "$stderr" ]' failed
```

Manual check against the unmodified SUT (`source lib/probes.sh`,
`probe_git_lock false <cwd>` on a symlink-to-`/dev/null` text) printed line 1
`held`, `pid=<n>`, plus stderr noise from `fuser` matching `/dev/null` — as
Item 2.4/4's code review predicted ("Slice 5: `/dev/null` has many holders,
so the result is held, not mask"). The test reds on a real assertion
(`[ -z "$stderr" ]`, and it would also red on `${output%%$'\n'*} = mask`
next), not on a missing symbol. No mutation needed: this is new behaviour
the SUT does not have yet, not an already-existing one.

## New file tests/probes-edges.bats: three cases from slice 3's code review

Each behaviour is already in the SUT (landed with that review, ahead of any
test), so RED mode proves each by mutation rather than an ordinary red. All
three passed unmutated on first write.

### `vanished lock is gone`

A `stat` stub on `PATH` removes its path operand then execs the real `stat`
— the window between the presence test and the mtime read that git's own
lock cleanup can land in. Recreates the 7-byte lock between the two flag
runs (the first run's stub already deletes it, so flag `true` needs a fresh
file to exercise the same window rather than hitting the top-of-function
absent-lock branch). Asserts the exact whole output `gone\npath=<lock>` —
this pins "no `bytes=`/`age=` line" and exact ordering together.

### `non-regular lock has no size`

A FIFO at the lock path. Reading it directly would block in `open(2)`
forever with no writer, which is exactly what a dropped `[ -f ]` guard does
— so this case runs the probe through a bespoke `run_probe_bounded` (backed
by `set -m` + `kill -- "-$pid"`, not `run_probe`), polling for completion up
to 3s (30 × 0.1s) before killing the whole process group and failing the
test on `$status`. Expects `orphan`, no `bytes=` line, empty stderr.

Getting this bound to actually protect the suite took two iterations —
recorded here because a future slice reusing this pattern will hit the same
trap:

- First cut backgrounded the probe and killed only the tracked `$pid`
  (mirroring `probes.bats`' `hold_lock`, closing fd 3). Under the `[ -f ]`
  mutation this reliably reported the test as failed on `$status`, but the
  whole `bats` run then hung past its own 15–30s harness timeout even though
  every TAP line had already printed. `/proc/<pid>/fd` on the leaked,
  reparented (`ppid=1`) grandchild — the shell about to `exec` into `wc`,
  still blocked in `open()` on the FIFO — showed it holding fds 10 and 12 as
  open pipes matching `bats-exec-file`'s own internal fd, inherited because
  killing `$pid` only ends the immediate backgrounded shell, not the
  already-forked descendant blocked several `$(...)` levels down. Closing
  fd 3 (the TAP-stream dup `hold_lock` documents) is not enough: these are
  different fds bats keeps open across the whole file's run.
- Fix: `set -m` before backgrounding, so the job gets its own process group
  (pid == pgid), then `kill -- "-$pid"` on timeout kills the group — the
  actual blocked process, not just its parent. Verified in isolation
  (outside bats, a standalone script) that this leaves zero surviving
  processes, then re-verified inside bats: `scripts/run-bats.sh
  tests/probes.bats tests/probes-edges.bats` completed promptly under the
  `[ -f ]` mutation, red on `$status`, with no lingering `bats-exec-test`
  processes afterward.

### `future mtime is age 0`

`touch -t 209901010000` on a present lock; expects `age=0` exactly.

## Mutation proof

Each mutation was applied, the two named suites run in the foreground
(`scripts/run-bats.sh tests/probes.bats tests/probes-edges.bats`), then
restored by the exact inverse replacement, proved by `grep` finding no hit,
then the suite re-run green.

1. **`vanished lock is gone`** — `lib/probes.sh`:
   ```
   if ! mtime=$(stat -c %Y "$path" 2>&1); then
       if [ ! -e "$path" ] && [ ! -L "$path" ]; then
   ```
   → the inner condition to `if false; then` (removing the branch's absence
   check, so a `stat` failure always falls through to the orphan path
   instead of reporting `gone`).
   - Red: `not ok 10 vanished lock is gone` — `` `[ -z "$stderr" ]' failed ``
     (the captured `stat` error now reaches stderr instead of being
     swallowed by the early `gone` return).
   - Restored: `grep -n "if false; then" lib/probes.sh` → no hit (exit 1).
     Suite back to `11 passed, 1 failed` (only the still-open character-device
     test).

2. **`non-regular lock has no size`** — `lib/probes.sh`:
   `if [ -f "$path" ] && [ -r "$path" ]; then` → `if [ -r "$path" ]; then`
   (drops the `-f` guard; a readable FIFO now reaches `wc -c <"$path"`).
   - Red: `not ok 11 non-regular lock has no size` —
     `` `[ "$status" -eq 0 ]' failed `` (the probe hangs past
     `run_probe_bounded`'s 3s bound; `run_probe_bounded` reports `status=124`
     rather than letting the suite hang — see the iteration notes above).
   - Restored: `grep -n 'if \[ -r "\$path" \]; then' lib/probes.sh` → no hit
     (exit 1). `git diff --stat lib/probes.sh` empty (byte-identical to
     HEAD). Suite back to `11 passed, 1 failed`.

3. **`future mtime is age 0`** — `lib/probes.sh`:
   ```
   age=$((now - mtime))
   # An mtime in the future (clock skew) reads as just written.
   if [ "$age" -lt 0 ]; then
       age=0
   fi
   printf 'age=%s\n' "$age"
   ```
   → clamp removed (`age=$((now - mtime))` followed directly by the
   `printf`).
   - Red: `not ok 12 future mtime is age 0` —
     `` printf '%s\n' "$output" | grep -qxF "age=0"' failed `` (age comes
     out negative).
   - Restored: `grep -n 'if \[ "\$age" -lt 0 \]; then' lib/probes.sh` → hit
     at line 134 (clamp back), `git diff --stat lib/probes.sh` empty. Suite
     back to `11 passed, 1 failed`.

Final state of `lib/probes.sh`: `git status --short lib/probes.sh` and
`git diff lib/probes.sh` both empty — untouched relative to HEAD.

## Final gate for this dispatch

- `scripts/run-bats.sh tests/probes.bats tests/probes-edges.bats`:
  ```
  not ok 9 character device is mask
  # (in test file tests/probes.bats, line 253)
  #   `[ -z "$stderr" ]' failed

  bats: 11 passed, 1 failed
  ```
  (11 = 8 pre-existing `probes.bats` cases + 3 new `probes-edges.bats` cases;
  the 1 failure is the new, not-yet-implemented `character device is mask`.)
- `shellcheck tests/probes.bats tests/probes-edges.bats
  tests/helpers/probes.bash`: one SC1091 info note per file that `source`s
  `lib/probes.sh` (`Not following: ./lib/probes.sh was not specified as
  input`) — pre-existing on the committed `tests/probes.bats` too (checked
  against `git show HEAD:tests/probes.bats`), not introduced here. No other
  findings.
- Self-quiet: `bash lib/matchers.sh < tests/probes.bats`,
  `< tests/probes-edges.bats`, `< tests/helpers/probes.bash` — no output,
  `rc=1` each of the three.
- `wc -l`: `tests/probes.bats` 263, `tests/probes-edges.bats` 124,
  `tests/helpers/probes.bash` 22 — all under the 400-line cap.

## Per-test failing output (the red batch GREEN must clear)

- `character device is mask` (`tests/probes.bats`): `` `[ -z "$stderr" ]'
  failed `` — real SUT prints `held`/`pid=<n>` plus fuser stderr noise for
  the symlink-to-`/dev/null` case; wants `mask` both flags, no stderr.

No other test in either file is red; the three `probes-edges.bats` cases are
green against the unmodified SUT and were proved non-vacuous by mutation
above.

## Scope note

Touched: `tests/probes.bats`, `tests/probes-edges.bats`,
`tests/helpers/probes.bash`. `lib/probes.sh` was edited three times, each
time restored to its committed content before moving to the next mutation;
its final state is byte-identical to HEAD. No character-device
implementation was written. Slices 6–9 and everything the brief lists as
scope OUT were not touched.
