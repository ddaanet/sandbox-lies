# Item 2.4 / slice 2 — RED report

Dispatch: item-2-4-s2-red. Mode: RED.

## Slice (from the runbook, current text)

2. `absent lock, unsandboxed, is gone` — same text, flag `true`: `gone`.
   `non-UTF-8 byte in the path` (slice 1's code review; proven by mutation of
   the extractor's `LC_ALL=C`) — an absent lock under a directory whose name
   holds byte `\351`, flag `false`, run under `LC_ALL=C.UTF-8`: `path=`
   byte-exact.

## SUT

`lib/probes.sh` is untouched except for the mutation-proof round trip in this
dispatch (applied and restored — see below). No implementation was added.

## Tests written

Both added to `tests/probes.bats`, reusing slice 1's `run_probe` helper and
`git_lock_error` fragment-builder, and the test review's style (unrelated
`$2`, `run --separate-stderr`, line 1 via `${output%%$'\n'*}`, exact-line
`path=` match via `grep -qxF`).

```bash
@test "absent lock, unsandboxed, is gone" {
  local repo="$BATS_TEST_TMPDIR/r" cwd="$BATS_TEST_TMPDIR/elsewhere" lock
  mkdir -p "$repo/.git" "$cwd"
  lock="$repo/.git/index.lock"

  run_probe probe_git_lock true "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = gone ]
}

# The directory name holds a raw non-UTF-8 byte (octal 351). Run under
# LC_ALL=C.UTF-8: under that locale GNU sed's "." does not match an invalid
# byte, which is exactly why the extractor forces LC_ALL=C internally. The
# path is asserted byte-exact via an exact-line path= match.
@test "non-UTF-8 byte in the path" {
  local repo cwd lock
  repo="$BATS_TEST_TMPDIR/r$(printf '\351')n/r"
  cwd="$BATS_TEST_TMPDIR/elsewhere"
  mkdir -p "$repo/.git" "$cwd"
  lock="$repo/.git/index.lock"

  LC_ALL=C.UTF-8 run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  printf '%s\n' "$output" | grep -qxF "path=$lock"
}
```

Neither test's source ever holds git's diagnostic whole: both build the error
text through `git_lock_error`, the same fragment-built helper slice 1 wrote
(self-quiet, FR-11).

## Run 1: `scripts/run-bats.sh tests/probes.bats` — both new tests as written

```
not ok 2 absent lock, unsandboxed, is gone
# (in test file tests/probes.bats, line 63)
#   `[ "${output%%$'\n'*}" = gone ]' failed

bats: 2 passed, 1 failed
```

- **`absent lock, unsandboxed, is gone`**: FAILED on its own assertion.
  `probe_git_lock`'s flag-`true` branch is unimplemented (the `if` guard in
  the current SUT only matches `flag = false`), so it falls through and
  prints nothing; `${output%%$'\n'*}` is empty, not `gone` — a wrong value,
  never a missing-symbol error.
- **`non-UTF-8 byte in the path`**: PASSED. Slice 1's code review already
  added `LC_ALL=C` to `_probe_lock_path` for exactly this reason, so the
  byte survives extraction even under an outer `LC_ALL=C.UTF-8`. This test
  named itself vacuous per the RED-mode rule and needed mutation proof
  rather than being left as a bare pass.
- **`absent lock, sandboxed, is mask`** (slice 1, untouched): still passed
  (1 of the "2 passed").

## Mutation proof

**Test:** `non-UTF-8 byte in the path`
**Strings swapped:** `LC_ALL=C sed` ↔ `sed` (in `lib/probes.sh`,
`_probe_lock_path`; confirmed occurring exactly once in the file before
mutating: `grep -n "LC_ALL=C sed" lib/probes.sh` → one hit, line 22).

1. Applied: `LC_ALL=C sed -n "s/.../\1/p"` → `sed -n "s/.../\1/p"`.
2. Reran `scripts/run-bats.sh tests/probes.bats`:

   ```
   not ok 2 absent lock, unsandboxed, is gone
   # (in test file tests/probes.bats, line 63)
   #   `[ "${output%%$'\n'*}" = gone ]' failed
   not ok 3 non-UTF-8 byte in the path
   # (in test file tests/probes.bats, line 81)
   #   `printf '%s\n' "$output" | grep -qxF "path=$lock"' failed

   bats: 1 passed, 2 failed
   ```

   `non-UTF-8 byte in the path` reds on its own assertion (the `path=`
   exact-line match): with the `LC_ALL=C` override gone, `sed` inherits the
   caller's `LC_ALL=C.UTF-8`, GNU sed's `.` no longer matches the invalid
   byte, the capture group is empty, and `path=` comes out empty rather than
   byte-exact. (`absent lock, unsandboxed, is gone` stays red throughout,
   unaffected by this mutation — expected.)
3. Restored: `sed -n "s/.../\1/p"` → `LC_ALL=C sed -n "s/.../\1/p"`.
4. Proved the restore: `grep -n "^    sed -n" lib/probes.sh` → no hit (rc 1);
   `grep -n "LC_ALL=C sed" lib/probes.sh` → one hit, line 22, matching the
   pre-mutation state.
5. Reran `scripts/run-bats.sh tests/probes.bats` after restore:

   ```
   not ok 2 absent lock, unsandboxed, is gone
   # (in test file tests/probes.bats, line 63)
   #   `[ "${output%%$'\n'*}" = gone ]' failed

   bats: 2 passed, 1 failed
   ```

   `non-UTF-8 byte in the path` is green again (2 of the "2 passed" —
   slice 1's test and this one); `absent lock, unsandboxed, is gone` is the
   sole remaining failure, as designed for this dispatch.

No second mutation attempt was needed — the first (removing the `LC_ALL=C`
override) reproduced the code review's own finding directly and reds the
test cleanly.

## shellcheck

`shellcheck tests/probes.bats` (file alone, as the dispatch specified):

```
In tests/probes.bats line 15:
  source "$ROOT/lib/probes.sh"
         ^-------------------^ SC1091 (info): Not following: ./lib/probes.sh was not specified as input (see shellcheck -x).
```
exit 1.

This is not a new problem: `SC1091` fires whenever `tests/probes.bats` is
checked in isolation, because shellcheck can't follow `source` without the
sourced file also given as an argument — the `justfile`'s `precommit` target
runs shellcheck over every tracked `*.sh`/`*.bash`/`*.bats` file in one
invocation, which resolves it. Confirmed: `shellcheck lib/probes.sh
tests/probes.bats` → no output, exit 0.

## Self-quiet check

`bash lib/matchers.sh < tests/probes.bats` → no output, rc 1 (as expected:
no output, exit 1). Neither test's source holds a whole lock diagnostic.

## Scope held

Only `tests/probes.bats` gained the two named tests. `lib/probes.sh` is
byte-identical to its state before this dispatch (`git status --short` shows
`M tests/probes.bats` only). No implementation of `gone` was written; no
other slice was touched.
