# Item 2.2 slice 1: test review

Scope: `tests/check-links.bats` (two tests), the RED report and the stub
`scripts/check-links.sh`. Nothing committed.

## Mechanical check (before fixes)

`scripts/run-bats.sh tests/check-links.bats`, run in the foreground, exit 1: 0
passed, 2 failed. Both tests failed on `[ "$status" -eq … ]` against the stub's
fixed `exit 2`. Neither passed and neither errored. `shellcheck` was clean on
both files.

## Wrong-reason hunt

Before probing, I took the stub's checksum (`sha256 6ae82a3e…e65d`, 750 bytes).
I then replaced the stub's two `echo`/`exit 2` lines with a minimal walk:
`git -C "$ROOT" ls-files -z -- '*.md'`, `grep -o '](…)'`, the fragment stripped,
`[ -e "$ROOT/$dir/$t" ]`, and a `printf` of the report line. A Python driver
applied one mutation at a time as an exact, count-checked string replacement,
ran `bats`, applied the inverse replacement, and asserted that the probe body's
checksum was back at its baseline before moving on.

| probe | original tests | fixed tests |
|---|---|---|
| correct walk | 2 pass | 2 pass |
| M1 resolve against ROOT | t1 red | t1, t2 red |
| M2 resolve target against CWD | t1 red | t1, t2 red |
| M2b resolve `dir/target` against CWD | t1 red (\*) | t1 red |
| M3 report resolved path (`docs/missing.md`) | t2 red | t2 red |
| M3b report absolute resolved path | t2 red | t2 red |
| M4 report to stderr | t2 red | t2 red |
| M5 `./` prefix on the linking file | t2 red | t2 red |
| M6 file of that name anywhere in the tree resolves | **2 pass** | t2 red |
| M7 dir-relative, with fallback to ROOT | **2 pass** | t2 red |
| M8 target's parent directory exists = resolves | t2 red | t2 red |
| M9 walk the CWD, ignore ROOT | t1, t2 red | t1, t2 red |
| M10 no-op, exit 0 | t2 red | t2 red |
| M11 exit 2 on a broken link | t2 red | t2 red |
| M12 `-f` instead of `-e` (directory target broken) | 2 pass | 2 pass |
| M13 dir-relative, with fallback to CWD | **2 pass** | t2 red |

(\*) Red only because this repo has no `docs/b.md`. See finding 2.

### Findings

1. **The broken-link test did not rule out resolving somewhere other than the
   linking file's directory (major).** Test 2's `missing.md` existed nowhere, so
   any resolution rule reported it. Three wrong rules therefore passed both
   tests: a basename match anywhere in the tree (M6), a dir-relative lookup that
   falls back to ROOT (M7), and one that falls back to the CWD (M13). Test 1's
   "no root-level `b.md`" catches only pure ROOT or CWD resolution, never a
   fallback. **Fix:** test 2 now places decoy `missing.md` files where only a
   wrong rule looks: one tracked at the fixture ROOT and one in the CWD. The
   asserted stdout is unchanged, so this departs from the runbook's fixture
   literal but not from its assertion.
2. **Test 1's CWD discrimination depended on this repo's own tree (minor).**
   Bats ran with the repo root as CWD, so a script resolving `docs/b.md` against
   the CWD (M2b) was caught only because the repo has no `docs/b.md`. **Fix:** a
   `setup()` now runs every test from `$BATS_TEST_TMPDIR`, which holds nothing
   but the fixture roots and the finding-1 decoy. This also gives M13's CWD
   decoy a known location. The script is still reached by its absolute `$SCRIPT`
   path, and `load` is resolved before `setup` runs.

### Checked and sound

- **Stream:** `run --separate-stderr` with `bats_require_minimum_version 1.5.0`.
  M4 (report to stderr) turns test 2 red.
- **Exact line:** M3/M3b (resolved path), M5 (`./` prefix) and a duplicate
  report line each fail test 2's full-output equality.
- **Pairing:** test 1 is a negative by nature. A no-op `exit 0` passes it (M10)
  and is caught by test 2, which uses the same link syntax from the same linking
  file. Each test has its own body, so errexit ordering cannot hide either one.
- **ROOT handling:** M9 (ignore ROOT, walk the CWD) turns both tests red.
- **Tracking:** fixture files, and the ROOT decoy, are `git add`ed into their
  own `git init` root. Untracked-file exclusion is slice 2's.
- **Directory targets (M12):** no fixture has a directory target, so `-e` versus
  `-f` is not observable here. It is not a finding. The item text says a link
  resolves "to an existing path", and `docs/design.md` NFR-5 says a link
  "resolves", so a directory target resolving is the contract, not a mutation.
  No slice pins it either way. If it is meant to be pinned, it belongs with
  slice 3's non-file targets.

### Observations outside this slice (not fixed)

- **Default ROOT `.`:** no slice covers it. Only the precommit wiring exercises
  it, the same as for Item 2.1.
- **Exec bit:** the stub is `-rwxr-xr-x` in the working tree and still
  untracked. At commit, `git ls-files -s scripts/check-links.sh` should show
  `100755`.

## Stub

The stub is restored exactly. I restored it by inverting the probe edit, not
from a copy. After the restore, `sha256sum` is `6ae82a3e9a17…e65d`, the same as
before probing, the file is 750 bytes, and `grep -c PROBE` returns 0. The stub
needed no fixes.

## Final red run

`scripts/run-bats.sh tests/check-links.bats`, run in the foreground, exit 1:

```
not ok 1 resolving link passes
# (in test file tests/check-links.bats, line 47)
#   `[ "$status" -eq 0 ]' failed
not ok 2 broken link is reported
# (in test file tests/check-links.bats, line 68)
#   `[ "$status" -eq 1 ]' failed

bats: 0 passed, 2 failed
```

Full suite `scripts/run-bats.sh tests/`: 43 passed, 2 failed. The two failures
are the ones above. `shellcheck` is clean on both files. `lib/matchers.sh`
`detect` stays quiet (exit 1, no output) for the test file, the stub and the RED
report. The test file is 70 lines.
