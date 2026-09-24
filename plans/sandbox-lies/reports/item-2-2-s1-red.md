# Item 2.2 slice 1 — RED

Stub: `scripts/check-links.sh` accepts `[ROOT]`, then unconditionally
`exit 2` with no stdout under `set -euo pipefail`. A distinct status (neither
0 nor 1) with empty output, so both tests below fail on their own status
assertion rather than on a missing file or a bats/harness error.

Suite: `tests/check-links.bats`, two tests, each fixture root a `git init`
temp repo under `$BATS_TEST_TMPDIR` with its files `git add`ed; loads
`helpers/bsd-stubs` per the other suites' convention (unused by these two
assertions — slice 6 exercises it).

Fixture discrimination:

- `resolving link passes`: `docs/a.md` links `(b.md)`; only `docs/b.md`
  exists, no root-level `b.md`. A script resolving against ROOT or CWD
  instead of the linking file's own directory would miss it and report the
  link broken instead of passing.
- `broken link is reported`: `docs/a.md` holds exactly one link, to
  `missing.md`, and nothing else in the tree — the exact single-line stdout
  assertion has only the one candidate line to come from.

## Run

`scripts/run-bats.sh tests/check-links.bats`, foreground:

```
not ok 1 resolving link passes
# (in test file tests/check-links.bats, line 40)
#   `[ "$status" -eq 0 ]' failed
not ok 2 broken link is reported
# (in test file tests/check-links.bats, line 55)
#   `[ "$status" -eq 1 ]' failed

bats: 0 passed, 2 failed
```

## Per-test failure

- **`resolving link passes`** — fixture: `docs/a.md` linking `(b.md)`,
  `docs/b.md` present (empty), both staged. Expected `status == 0`, empty
  `output`, empty `stderr`. Got `status == 2` (the stub's fixed exit),
  failing the first assertion, `[ "$status" -eq 0 ]`, at line 40.
- **`broken link is reported`** — fixture: `docs/a.md` linking
  `(missing.md)`, staged, `missing.md` absent. Expected `status == 1` and
  `output == "broken-link: docs/a.md -> missing.md"`. Got `status == 2`,
  failing the first assertion, `[ "$status" -eq 1 ]`, at line 55.

Both failures are assertion failures against the stub's fixed exit 2, not
missing-file or bats-harness errors.

## Checks run

- `shellcheck scripts/check-links.sh` — clean.
- `bash -n scripts/check-links.sh` — OK.

## Left in the tree (uncommitted, per dispatch)

- `scripts/check-links.sh` (stub, executable)
- `tests/check-links.bats` (this slice's two tests)
- this report
