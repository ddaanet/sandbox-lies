# Item 2.4 / slice 3 — RED report

Dispatch: item-2-4-s3-red. Mode: RED.

## Slice (from the runbook, current text)

3. `present unheld lock is orphan` — the lock written with 7 bytes, flag
   `false` and `true` (slice 2's reviews: without the `true` run a probe
   answering `gone` to every unsandboxed call passes the list): `orphan`,
   `bytes=7`, an `age=` integer ≥ 0. `unexpected flag reads as sandboxed`
   (slice 2's code review; proven by mutation) — slice 1's absent lock with
   the flag `""` and then `TRUE`: `mask` and its `path=` line both times.
   `quote and space in the lock path` (slice 1's code review) — the same
   under `$BATS_TEST_TMPDIR/it's here/r`: `orphan`, `path=` the full path.
   Not pinned (slice 1's code review): text with no lock line — [left open].

## Tests added (`tests/probes.bats`)

Three tests, exactly as the slice names them. `present unheld lock is orphan`
runs both flag values inside one test (the slice's own parenthetical ties the
`true` run to the same named test, not a second one).

1. **`present unheld lock is orphan`** — writes the lock with `printf
   '1234567' >"$lock"` (exactly 7 bytes, no holder process), then runs
   `probe_git_lock false <cwd>` and `probe_git_lock true <cwd>` in turn, each
   asserting line 1 `orphan`, an exact-line `bytes=7`, and an `age=` line
   matching `^age=[0-9]+$`.
2. **`unexpected flag reads as sandboxed`** — reuses slice 1's absent-lock
   fixture (repo/cwd/lock exactly as `absent lock, sandboxed, is mask`), runs
   the probe with flag `""` then flag `TRUE`, asserting `mask` and the exact
   `path=$lock` line both times.
3. **`quote and space in the lock path`** — same 7-byte lock, under
   `$BATS_TEST_TMPDIR/it's here/r/.git/index.lock`, flag `false`: asserts
   `orphan` and the exact `path=$lock` line.

`lib/probes.sh` was not edited except for the mutation proof below, applied
and fully reverted before this report was written.

## Suite run (foreground, `scripts/run-bats.sh tests/probes.bats`)

Pre-mutation, current SUT:

```
not ok 4 present unheld lock is orphan
# (in test file tests/probes.bats, line 104)
#   `[ "${output%%$'\n'*}" = orphan ]' failed
not ok 6 quote and space in the lock path
# (in test file tests/probes.bats, line 151)
#   `[ "${output%%$'\n'*}" = orphan ]' failed

bats: 4 passed, 2 failed
```

Per-test outcome:

- `present unheld lock is orphan` — **fails** on
  `[ "${output%%$'\n'*}" = orphan ]`: the SUT's absent-lock guard
  (`[ ! -e "$path" ] && [ ! -L "$path" ]`) is false for a present lock, so the
  function falls through and prints nothing; line 1 reads `""`, not
  `orphan`. Assertion failure, not a missing-symbol error.
- `unexpected flag reads as sandboxed` — **passes** as committed (the
  behaviour it asserts is already in the SUT per slice 2's code review: only
  the literal `true` reads as unsandboxed). Proof by mutation below.
- `quote and space in the lock path` — **fails** on the same
  `[ "${output%%$'\n'*}" = orphan ]` assertion, same reason (present lock,
  no `orphan` branch yet).
- `absent lock, sandboxed, is mask`, `absent lock, unsandboxed, is gone`,
  `non-UTF-8 byte in the path` (slices 1–2, unchanged) stayed green
  throughout.

## Mutation proof

**Test: `unexpected flag reads as sandboxed`.** String pair: `[ "$flag" =
true ]` → `[ "$flag" != false ]` (occurs once in `lib/probes.sh`, confirmed
by `grep -c`).

- Applied the replacement to `lib/probes.sh` line 36.
- Ran `scripts/run-bats.sh tests/probes.bats`:

  ```
  not ok 4 present unheld lock is orphan
  #   `[ "${output%%$'\n'*}" = orphan ]' failed
  not ok 5 unexpected flag reads as sandboxed
  # (in test file tests/probes.bats, line 128)
  #   `[ "${output%%$'\n'*}" = mask ]' failed
  not ok 6 quote and space in the lock path
  #   `[ "${output%%$'\n'*}" = orphan ]' failed

  bats: 3 passed, 3 failed
  ```

  `unexpected flag reads as sandboxed` reds on its own `mask` assertion (the
  mutated condition reads `""` and `TRUE` as unsandboxed too, so the probe
  answers `gone` instead of `mask`). The three already-green tests from
  slices 1–2 (`absent lock, sandboxed, is mask`, `absent lock, unsandboxed,
  is gone`, `non-UTF-8 byte in the path`) stayed green under the mutation, as
  expected — none of them exercises a flag value other than the literal
  `false`/`true`.
- Restored by the inverse replacement (`[ "$flag" != false ]` →
  `[ "$flag" = true ]`).
- Proved the restore: `grep -n '!= false' lib/probes.sh` → no hit, exit 1.
  Reran `scripts/run-bats.sh tests/probes.bats`: back to `bats: 4 passed, 2
  failed`, the same two (still-unimplemented) failures as the pre-mutation
  run above — the replacement exiting 0 was not treated as the evidence.

## Self-quiet check

`bash lib/matchers.sh < tests/probes.bats` → no output, `rc=1`, as required.

## Scope held

Only `tests/probes.bats` changed on disk (`git diff --stat`: 64 insertions,
0 deletions, that file only). `lib/probes.sh` is byte-identical to HEAD
(mutation applied and reverted within this dispatch; no diff remains). No
implementation of the `orphan` outcome, holder check, size/age, or any other
slice was added.

## Stop

No commit made. This report and the uncommitted test additions are the
designed end state of this RED dispatch.
