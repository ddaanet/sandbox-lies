# GREEN: Item 2.4 / slice 5 — character device is mask

**Scope**: `lib/probes.sh` only. Tests untouched (received as the failing
batch from RED + test review).
**Mode**: GREEN

## Batch received

12 tests across `tests/probes.bats` (9) and `tests/probes-edges.bats` (3),
11 already passing against the unmodified SUT (3 pinned by mutation in RED,
1 more — the character-device control half — pinned by mutation in the test
review). The one red test: `character device is mask` in `tests/probes.bats`,
failing on `[ -z "$stderr" ]` (fuser noise for `/dev/null`) or on the `mask`
token, depending on run.

## Implementation

One test to make pass, one change: added a character-device check inside
`probe_git_lock`'s "path exists" branch, ahead of the holder-pid check, size
read and mtime read:

```sh
if [ -c "$path" ]; then
    printf 'mask\n'
    printf 'path=%s\n' "$path"
    return 0
fi
```

Placed immediately after entering the `else` branch (path exists), before
`local pids holder_pid` and `_probe_holder_pids`, so a character device never
reaches the holder tool, `stat`, or `wc` — matching the item text's "Place the
check so no holder tool, `stat` or `wc` runs on the device." `[ -c ]` follows
a symlink (POSIX), so the symlink-to-`/dev/null` fixture lands here without
resolving the link itself; `path=` still prints `$path` (the symlink), not a
resolved target, satisfying the test's `path=$lock` assertion. The mask
applies under both flag values, matching docs/references/detectors.md's
git-lock table row ("flag false, path absent outside the sandbox, or it stats
as a character device" — the character device is unconditional on flag).

## One test at a time

Only one test was red, so there was one growth step:

1. `character device is mask` (`tests/probes.bats`) — added the `[ -c ]`
   branch above. Ran `tests/probes.bats` alone first:
   `scripts/run-bats.sh tests/probes.bats` → `9 passed, 0 failed`. The
   control half (symlink to a 7-byte regular file → `orphan`, `bytes=7`)
   stayed green, confirming the branch is keyed on what the path stats as,
   not on `[ -L ]`.

No other test in the batch needed any implementation change; all 11 others
were already green and stayed green throughout.

## Full suite and gates

- `scripts/run-bats.sh tests/probes.bats tests/probes-edges.bats`:
  `bats: 12 passed, 0 failed`.
- `just lint`: no such recipe in this repo's justfile (`error: Justfile does
  not contain recipe 'lint'`) — `just precommit` is this repo's gate and
  covers shellcheck.
- `just precommit`:
  ```
  scripts/run-bats.sh tests/
  bats: 107 passed, 0 failed
  precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests
  ```
  Full suite (107, all test files) green, no regressions elsewhere.

## Precommit warnings

None — `just precommit` printed only the passing-checks recap above, no
warning lines.

## Scope note

Touched: `lib/probes.sh` (the one `[ -c ]` branch, 8 lines including its
comment). No test file edited. Slice 6 (`unknown`, holder-tool stubs), slice 7
(relative-path resolution), slice 8 (`probe_config_lock`), slice 9 (BSD
`stat`, the writes-nothing case) untouched — `probe_config_lock` is still the
one-line `cat >/dev/null` stub.
