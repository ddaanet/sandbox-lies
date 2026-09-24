# Item 2.4 / slice 1 — RED report

Dispatch: item-2-4-s1-red. Mode: RED.

## Slice

1. External contract: `absent lock, sandboxed, is mask` — error text naming
   `$BATS_TEST_TMPDIR/r/.git/index.lock` (absent), flag `false`: line 1
   `mask`, a `path=` line naming that path.

## SUT stub created

`lib/probes.sh` did not exist before this dispatch. Created as an importable
but inert stub: `probe_git_lock` and `probe_config_lock` each consume stdin
(`cat >/dev/null`) and return 0 with no output, plus a header comment stating
the A-3 contract (flag as `$1`, cwd as `$2`, outcome token on line 1, then
`key=value` lines). No real probe logic.

## Test written

`tests/probes.bats`, one test (`load helpers/bsd-stubs`; sources
`lib/probes.sh` in `setup()`):

```bash
#!/usr/bin/env bats
ROOT="${BATS_TEST_DIRNAME}/.."

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs

setup() {
  source "$ROOT/lib/probes.sh"
}

git_lock_error() {
  local path="$1" text
  text="fatal: Unable to create '"
  text="${text}${path}': File exists."
  printf '%s\n' "$text"
}

@test "absent lock, sandboxed, is mask" {
  local repo="$BATS_TEST_TMPDIR/r" lock output
  mkdir -p "$repo/.git"
  lock="$repo/.git/index.lock"

  output=$(git_lock_error "$lock" | probe_git_lock false "$repo")

  [ "$(printf '%s\n' "$output" | sed -n '1p')" = "mask" ]
  printf '%s\n' "$output" | grep -qF "path=$lock"
}
```

Self-quiet (FR-11): `git_lock_error` builds git's lock diagnostic from two
shell-string fragments at run time (as `lib/matchers.sh` `match_git_lock`
builds its follow-on), so the file never holds `Unable to create '...': File
exists` whole; the follow-on sentence about "another git process" is left out
entirely, per the item text ("the probe does not read git's follow-on"). The
lock path is asserted absent — only `$repo/.git` is created, never the lock
file.

## Run: `scripts/run-bats.sh tests/probes.bats`

```
Exit code 1
not ok 1 absent lock, sandboxed, is mask
# (in test file tests/probes.bats, line 36)
#   `[ "$(printf '%s\n' "$output" | sed -n '1p')" = "mask" ]' failed

bats: 0 passed, 1 failed — full log: /tmp/claude-1000/sandbox-lies-bats.uWg8sD
```

The test reds on its own assertion: `probe_git_lock`'s stub prints nothing,
so `output`'s first line is empty, not `mask` — a wrong value, never
`ImportError`/`AttributeError`-equivalent (no missing-symbol or load
failure; the function is defined and sourced cleanly).

## Mutation proof

None performed. The stub has no real behaviour (`probe_git_lock` is a bare
`cat >/dev/null`; the slice text and the stub source both show this), so the
test's failure against the unmodified stub is itself the red evidence — there
is no passing-but-vacuous state to interrogate by mutation.

## shellcheck

```
$ shellcheck lib/probes.sh tests/probes.bats
(no output — clean)
```

## Scope note

Only `lib/probes.sh` (stub) and `tests/probes.bats` (this one test) were
touched. `tests/helpers/bsd-stubs.bash` (the `stat` stub, slice 9) and every
other slice are untouched.
