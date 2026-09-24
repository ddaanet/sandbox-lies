# Item 2.1 slice 1 — RED

Stub: `scripts/check-line-limits.sh` accepts `[ROOT]`, then unconditionally
`exit 2` with no stdout under `set -euo pipefail`. A distinct status (neither
0 nor 1) with empty output, so both tests below fail on their own status
assertion rather than on a missing file or a bats/harness error.

Suite: `tests/check-line-limits.bats`, two tests, each fixture root a
`git init` temp repo under `$BATS_TEST_TMPDIR` with its file `git add`ed;
loads `helpers/bsd-stubs` per the other suites' convention (unused by these
two assertions — slice 5 exercises it).

## Run

`scripts/run-bats.sh tests/check-line-limits.bats`, foreground:

```
not ok 1 clean tree exits 0 silently
# (in test file tests/check-line-limits.bats, line 30)
#   `[ "$status" -eq 0 ]' failed
not ok 2 oversized markdown is reported
# (in test file tests/check-line-limits.bats, line 42)
#   `[ "$status" -eq 1 ]' failed

bats: 0 passed, 2 failed
```

## Per-test failure

- **`clean tree exits 0 silently`** — fixture: `docs/a.md` 10 lines, staged.
  Expected `status == 0` and empty `output`. Got `status == 2` (the stub's
  fixed exit), failing the first assertion, `[ "$status" -eq 0 ]`, at line 30.
- **`oversized markdown is reported`** — fixture: `docs/a.md` 401 lines,
  staged. Expected `status == 1` and
  `output == "oversized-file: docs/a.md: 401 lines > 400"`. Got `status == 2`,
  failing the first assertion, `[ "$status" -eq 1 ]`, at line 42.

Both failures are assertion failures against the stub's fixed exit 2, not
missing-file or bats-harness errors.

## Left in the tree (uncommitted, per dispatch)

- `scripts/check-line-limits.sh` (stub, executable)
- `tests/check-line-limits.bats` (this slice's two tests)
- this report
