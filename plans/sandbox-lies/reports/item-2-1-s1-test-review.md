# Item 2.1 slice 1: test review

Scope: `tests/check-line-limits.bats` (two tests), the RED report and the stub
`scripts/check-line-limits.sh`. Nothing committed.

## Mechanical check (before fixes)

`scripts/run-bats.sh tests/check-line-limits.bats`, run in the foreground:
0 passed, 2 failed. Both tests failed on `[ "$status" -eq … ]` against the
stub's fixed `exit 2`. Neither passed and neither errored. `shellcheck` was
clean on both files. `lib/matchers.sh` printed nothing for the test file, the
stub or the RED report, so the files follow the self-quiet rule that
`tests/docs.bats` enforces.

## Wrong-reason hunt

To check what the tests can tell apart, I swapped the stub's `exit 2` for a
minimal walk: `git ls-files -z -- 'docs/*.md'`, then `wc -l`, then
`-gt 400`, with overage lines printed via `printf`. I ran it once as written
and then with one mutation at a time. After each mutation I reversed the edit
and grepped to confirm the mutation text was gone.

| probe | original tests | fixed tests |
|---|---|---|
| correct walk | 2 pass | 2 pass |
| cap compared with `-ge` (off-by-one) | **2 pass** | test 1 red (status) |
| overage line written to stderr | **2 pass** | test 2 red (output) |
| stray stderr note on a clean run | n/a | test 1 red (`$stderr`) |

### Findings

1. **The clean fixture did not test the cap boundary (major).** With a
   10-line `docs/a.md`, anything from a 10-line cap to a 400-line cap passed,
   and so did `>=` in place of `>`. The 401-line case alone cannot catch
   `-ge 400` either, because that still reports 401 as `> 400`.
   **Fix:** the clean fixture is now exactly 400 lines. The two tests now
   differ by a single line, so each one's fixture is the other's pair. This
   departs from the runbook's literal "10-line `docs/a.md`" and does not
   change what the test asserts.
2. **The test did not check which stream the overage line goes to (major).**
   A plain `run` merges stderr into `$output`, so a script that printed the
   overage line to stderr passed. The contract says that line goes to
   **stdout**, and slice 5 compares stdout.
   **Fix:** both tests now use `run --separate-stderr`, with
   `bats_require_minimum_version 1.5.0`, which is how `tests/matchers.bats`
   does it. `$output` is now stdout only.
3. **"Silently" was not fully asserted (minor).** Test 1 is named "exits 0
   silently" but only checked stdout. **Fix:** it now also asserts
   `[ -z "$stderr" ]`.

### Checked and sound

- **Tracking:** each fixture file is `git add`ed into its own `git init`
  root, so `git ls-files` lists it.
- **Pairing:** the clean test cannot tell apart a script that does nothing
  and `exit 0`s. It is a negative test by nature, paired with test 2 over the
  same fixture. Each is in its own test body, so errexit ordering cannot hide
  either one.
- **ROOT handling:** a script that ignores ROOT and walks the CWD fails
  test 2, since the repo tree has no oversized `docs/a.md`. A `./docs/a.md`
  path of the kind a `find` walk prints fails the exact-output match.
- **Conventions:** `load helpers/bsd-stubs` is present. Every expansion is
  quoted. Fixture data is written with `printf '%s\n'` or `seq`, both of
  which BSD has.

### Observations outside this slice (not fixed)

- **Default ROOT `.`:** none of slices 1–5 covers it. Only the precommit
  wiring exercises it. It does fail loudly, because a script that requires
  ROOT exits 2 and the gate goes red.
- **Exec bit:** the test calls the script by path, so it relies on the exec
  bit. The working-tree file is `-rwxr-xr-x` and `core.fileMode` is `true`.
  At commit, `git ls-files -s scripts/check-line-limits.sh` should show
  `100755`.
- **Foreign repos:** this suite is the first to run `git` in repos other
  than this one. Today no git hook runs the suite, so inherited `GIT_*`
  variables are not a live risk. If a hook ever runs it, the test would need
  `git rev-parse --local-env-vars` unset.

## Stub

The stub needed no change: it is still the inert `exit 2`. Removing the
probe was proven two ways: `grep -c PROBE-MUTANT` returns 0, and the file is
back at 668 bytes.

## Final red run

`scripts/run-bats.sh tests/check-line-limits.bats`, run in the foreground,
exit 1:

```
not ok 1 clean tree exits 0 silently
# (in test file tests/check-line-limits.bats, line 37)
#   `[ "$status" -eq 0 ]' failed
not ok 2 oversized markdown is reported
# (in test file tests/check-line-limits.bats, line 50)
#   `[ "$status" -eq 1 ]' failed

bats: 0 passed, 2 failed
```

Full suite `scripts/run-bats.sh tests/`: 27 passed, 2 failed. The two
failures are the ones above. `shellcheck` is clean on both files, and
`lib/matchers.sh` prints nothing for the edited test file.
