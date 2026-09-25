# RED: Item 2.4 / slice 9 — BSD stat

**Scope**: `tests/helpers/bsd-stubs.bash` (new `stat`/`wc` stubs),
`tests/probes.bats` (`BSD stat`), `tests/probes-edges.bats` (`probe writes
nothing`, plus `load helpers/spy`, a `setup`/`teardown` pair for the held-lock
job it starts), `tests/helpers/probes.bash` (`hold_lock` moved here from
`tests/probes.bats` so both suites can share it). `lib/probes.sh` touched only
for the mutation proof below and restored byte-identical (`git diff --stat
lib/probes.sh` prints nothing).

## Stubs added to `tests/helpers/bsd-stubs.bash`

- `_bsd_stub_stat`, wired into `make_bsd_stubs`'s `case` as `stat`: refuses
  any `-c*` or long (`--*`) option with a BSD-shaped "illegal option -- …"
  message on stderr and exit 1; serves `-f %m <file>` by execing the real
  `stat -c %Y <file>`; anything else execs the real tool. Manually verified
  (outside the suite): `stat -c %Y f` → `stat: illegal option -- c`, rc 1;
  `stat -f %m f` → the real mtime; unstubbed passthrough unexercised beyond
  those two forms since the probe only ever calls those two shapes.
- `_bsd_stub_wc`, wired in as `wc`: for the exact `wc -c` (no operand, stdin)
  form the probe uses, runs the real `wc -c` and reprints the count
  right-justified in a field of 8 (`printf '%8s\n'`); anything else execs the
  real tool. Manually verified: `printf 1234567 | wc -c` under the stub prints
  `       7` (7 leading spaces), vs. GNU's bare `7`.

## Test added to `tests/probes.bats`: `BSD stat`

Repeats slice 3's present-unheld-lock fixture (7-byte lock, mtime backdated
to 2000-01-01) with `make_bsd_stubs stat wc` on `PATH`. Asserts `orphan`,
`bytes=7`, an `age=` line, empty stderr, and `age` within 60s of `now -
real_mtime` (`real_mtime` read with the real `stat -c %Y` before the stub
goes on `PATH`, so the bound is exact rather than the loose `> 86400` slice
3 used) — per the runbook's slice 9 text ("within a minute of now minus the
backdated mtime").

**RED run** (`scripts/run-bats.sh tests/probes.bats -f "BSD stat"`):

```
not ok 1 BSD stat
# (in test file tests/probes.bats, line 315)
#   `[ -z "$stderr" ]' failed
```

Fails on the assertion, not on a missing symbol: the current SUT calls only
`stat -c %Y`, which the stub refuses, sending its BSD-shaped refusal message
to stderr (the probe treats a failed `stat` whose lock is still present as
"surface the text on stderr, leave the `age=` line out" — see
`lib/probes.sh` `probe_git_lock`). `status` stays 0 and `orphan`/`bytes=7`
still print (the refusal doesn't stop the function), so the assertion order
(`status`, `stderr`, line 1, `bytes=`, `age=` pattern, `age` bound, `path=`)
reds on the second check, `[ -z "$stderr" ]`. No mutation needed for this
test: the behaviour it pins (the BSD fallback) does not exist in the SUT yet,
so ordinary execution supplies the red.

Full-file run confirms nothing else regressed:
`scripts/run-bats.sh tests/probes.bats` → `11 passed, 1 failed` (only `BSD
stat` fails).

## Test added to `tests/probes-edges.bats`: `probe writes nothing`

Per slice 4's code review ("Probe writes nothing"). Runs `probe_git_lock` in
three fresh `bash -c` subprocesses (each sourcing `lib/probes.sh` anew) under
`env PATH="$spy:$PATH" TMPDIR="$nonexistent"`, a `mktemp` spy
(`tests/helpers/spy.bash`) on `PATH` and `TMPDIR` naming a directory that
does not exist — the same shape `tests/hook.bats` "hook needs no temp dir"
uses for the hook. Checks an absent lock (`mask`), a 7-byte unheld lock
(`orphan`), and a held lock (`held`, via `hold_lock`, now shared from
`tests/helpers/probes.bash`): each run asserts `status` 0, empty stderr, the
outcome, and `[ ! -e "$calls" ]`.

This test already passes against the unmodified SUT (`probe_git_lock` never
calls `mktemp`), so it is a candidate for vacuous-green and is proven by
mutation rather than by a red.

## Mutation proof

- **Test**: `probe writes nothing` (`tests/probes-edges.bats`)
- **Mutation**: `lib/probes.sh`, in `probe_git_lock` — `text=$(cat)` →
  `text=$(cat); mktemp >/dev/null`. `command grep -c 'text=\$(cat)'
  lib/probes.sh` returned 1 before the edit, confirming the string occurs
  exactly once in the file, so the replacement is unambiguous. This line
  runs before the flag/path split, so it sits on the path shared by all
  three branches (mask, orphan, held) the test exercises.
- **Red observed**:
  ```
  not ok 1 probe writes nothing
  # (in test file tests/probes-edges.bats, line 323)
  #   `[ -z "$stderr" ]' failed
  ```
  (`scripts/run-bats.sh tests/probes-edges.bats -f "probe writes nothing"`).
  The mutant's `mktemp` runs with `TMPDIR` pointing at a missing directory,
  so the real `mktemp` (invoked by the spy after logging the call) fails and
  writes its own error to stderr — the redirect on the mutation
  (`>/dev/null`) only silences its stdout. The test reds on the first
  branch's stderr check, on its own assertion, not on a missing symbol.
- **Restore**: inverse replacement, `mktemp >/dev/null); ` → `` removed
  restoring `text=$(cat)` exactly. Proved by `command grep -c 'mktemp
  >/dev/null' lib/probes.sh` → 0 (grep exit 1), and `git diff --stat
  lib/probes.sh` printing nothing (byte-identical to HEAD).
- **Rerun green**: `scripts/run-bats.sh tests/probes.bats
  tests/probes-edges.bats` → `19 passed, 1 failed` (the one failure is `BSD
  stat`, the test this dispatch intentionally leaves red; every other test
  including `probe writes nothing` is green).

## Deferred mutation (per dispatch instructions)

The `wc` BSD-padding strip (`tr -d '[:space:]'` in `probe_git_lock`'s size
read) is meant to be pinned by `BSD stat`'s `bytes=7` assertion once
`make_bsd_stubs stat wc` is on `PATH`: with the stub's left-padded `wc -c`
output, dropping the `tr -d` strip would leave `bytes=       7` and fail the
exact-match `bytes=7` grep. I did not run this mutation now, because `BSD
stat` is already red on the `stat` refusal (the `[ -z "$stderr" ]` check
above), so removing the `tr` strip today cannot demonstrate a *new* red — the
test is already failing before execution reaches the `bytes=` assertion.
Once slice 9's GREEN adds the `stat -f %m` fallback and the `BSD stat` test
goes green, the GREEN dispatch or the test review should re-run this
mutation (`bytes=$(wc -c <"$path" | tr -d '[:space:]')` →
`bytes=$(wc -c <"$path")`) to confirm `BSD stat` catches it, the way slice
3's code review found the strip unpinned on plain GNU `wc`.

## Other verification

- `scripts/run-bats.sh tests/` (foreground, full suite): `114 passed, 1
  failed` — the one failure is `BSD stat`. No other suite was affected by
  the shared `bsd-stubs.bash`/`probes.bash` helper changes.
- `shellcheck lib/probes.sh tests/helpers/bsd-stubs.bash
  tests/helpers/probes.bash tests/probes.bats tests/probes-edges.bats` → exit
  0, no findings. (Run standalone without `lib/probes.sh` in the argument
  list, `tests/probes.bats`/`tests/probes-edges.bats` each print an SC1091
  info note on their `source "$ROOT/lib/probes.sh"` line — pre-existing,
  unrelated to this dispatch's edits, and absent once `lib/probes.sh` is
  passed alongside them in the same invocation, as `just precommit`'s
  `tracked '*.sh' '*.bash' '*.bats'` does.)
- Self-quiet (`bash lib/matchers.sh < <file>; echo rc=$?`): no output, `rc=1`
  for all four changed files (`tests/helpers/bsd-stubs.bash`,
  `tests/helpers/probes.bash`, `tests/probes.bats`,
  `tests/probes-edges.bats`).
- `wc -l`: `tests/helpers/bsd-stubs.bash` 126, `tests/helpers/probes.bash` 70,
  `tests/probes.bats` 324, `tests/probes-edges.bats` 348 — all under the
  400-line cap.
- `git status --short` shows only the four intended files modified (plus the
  pre-existing untracked sandbox-mask dotfiles and the pre-existing untracked
  `plans/sandbox-lies/reports/build-phase-2.md`, neither touched by this
  dispatch). `git diff --stat lib/probes.sh` is empty.

## Refactor note (in scope: test helpers, not the SUT)

`hold_lock` moved from `tests/probes.bats` into `tests/helpers/probes.bash`
so `tests/probes-edges.bats` can start a held lock for `probe writes
nothing` without duplicating it. `tests/probes.bats` now has a one-line
pointer comment in its place; its own `setup`/`teardown` (which reset and
kill `_probe_holder_pid`) are unchanged. `tests/probes-edges.bats` gained the
same `_probe_holder_pid=` reset in `setup()` and the same guarded `teardown()`
(only this file's new test ever sets `_probe_holder_pid`, so it is a no-op
for every other test there). Ran `tests/probes.bats` alone after the move —
all of its held-lock tests (`held lock names the holder`, `held lock under a
quoted, spaced path`) stayed green, confirming the shared helper works
identically.

## Not done (out of scope for RED)

No implementation change to `probe_git_lock`'s mtime read (the `stat -f %m`
fallback) — that is slice 9's GREEN. `lib/probes.sh` is unchanged from HEAD.
