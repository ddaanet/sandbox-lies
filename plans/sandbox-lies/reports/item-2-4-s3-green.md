# Item 2.4 / slice 3 — GREEN report

Dispatch: item-2-4-s3-green. Mode: GREEN.

## Slice (from the runbook, current text)

3. `present unheld lock is orphan` — the lock written with 7 bytes, flag
   `false` and `true` (slice 2's reviews: without the `true` run a probe
   answering `gone` to every unsandboxed call passes the list): `orphan`,
   `bytes=7`, an `age=` integer ≥ 0. `unexpected flag reads as sandboxed`
   (slice 2's code review; proven by mutation) — slice 1's absent lock with
   the flag `""` and then `TRUE`: `mask` and its `path=` line both times.
   `quote and space in the lock path` (slice 1's code review) — the same
   under `$BATS_TEST_TMPDIR/it's here/r`: `orphan`, `path=` the full path.

## Batch received (failing before this dispatch)

`scripts/run-bats.sh tests/probes.bats`, before any implementation change:

```
not ok 4 present unheld lock is orphan
#   `[ "${output%%$'\n'*}" = orphan ]' failed
not ok 6 quote and space in the lock path
#   `[ "${output%%$'\n'*}" = orphan ]' failed

bats: 4 passed, 2 failed
```

`unexpected flag reads as sandboxed` was already green (behaviour pinned in
slice 2), per the test review — untouched here.

## Implementation

Added one `else` branch to `probe_git_lock` in `lib/probes.sh`, taken when the
lock path exists (present-lock case; the absent-lock guard's `if` covers
`mask`/`gone` as before):

```sh
    else
        local bytes mtime now age
        # BSD wc left-pads its count with spaces; strip before printing.
        bytes=$(wc -c <"$path" | tr -d '[:space:]')
        mtime=$(stat -c %Y "$path")
        now=$(date +%s)
        age=$((now - mtime))
        printf 'orphan\n'
        printf 'bytes=%s\n' "$bytes"
        printf 'age=%s\n' "$age"
        printf 'path=%s\n' "$path"
    fi
```

`wc -c` and `stat -c %Y` both take the quoted `"$path"`, so the quote-and-space
fixture's path is not split. No `2>/dev/null` added — none of the added calls
are expected to fail on this branch (the path is already known to exist).
The holder check, the BSD `stat -f %m` attempt, the character-device rule, and
`probe_config_lock` are untouched, per the scope-out list.

## Tests made to pass, in order

1. `present unheld lock is orphan` — ran alone
   (`scripts/run-bats.sh tests/probes.bats --filter "present unheld lock is
   orphan"`) after adding the branch above: `bats: 1 passed, 0 failed`.
2. `quote and space in the lock path` — ran alone with the same filter
   pattern: `bats: 1 passed, 0 failed`. No further change needed; the same
   branch satisfies both.

No second implementation attempt was needed for either test.

## Full suite

`scripts/run-bats.sh tests/probes.bats`:

```
bats: 6 passed, 0 failed
```

All six tests pass: `absent lock, sandboxed, is mask`, `absent lock,
unsandboxed, is gone`, `non-UTF-8 byte in the path`, `present unheld lock is
orphan`, `unexpected flag reads as sandboxed`, `quote and space in the lock
path`.

## `just precommit`

`just lint` does not exist as a recipe in this repo's `justfile` (`error:
Justfile does not contain recipe 'lint'`); `just precommit` was run in its
place, which is the gate this repo defines.

```
scripts/run-bats.sh tests/
bats: 101 passed, 0 failed
precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests
```

No warnings emitted by shellcheck, `bash -n`, rumdl, or the line-limit check.

## Scope held

Only `lib/probes.sh` changed for implementation (one `else` branch, 11 lines
added). `probe_config_lock`, the holder check (`lsof`/`fuser`), the BSD
`stat -f %m` fallback, and the character-device rule were not touched, as the
dispatch scopes them to later slices. No test file edited.

## Stop

Committing next: `lib/probes.sh`, `tests/probes.bats`,
`plans/sandbox-lies/reports/item-2-4-s3-red.md`,
`plans/sandbox-lies/reports/item-2-4-s3-test-review.md`,
`plans/sandbox-lies/reports/item-2-4-s3-green.md`.
