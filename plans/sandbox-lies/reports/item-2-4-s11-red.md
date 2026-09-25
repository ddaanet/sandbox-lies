# RED report: Item 2.4 / slice 11 (closing follow-up)

**Scope**: `tests/probes-config.bats` (three new cases), `tests/helpers/probes.bash`
(`run_probe_bounded` moved here from being local to `tests/probes-edges.bats`,
so `tests/probes-config.bats` can share the bounded-run technique without
duplicating it — `tests/probes-edges.bats` itself was not touched).
`lib/probes.sh` touched only for the three mutation proofs below; it ends
byte-identical to HEAD (`git diff --quiet lib/probes.sh` passes).
**Mode**: RED
**Date**: 2026-09-25

## Summary

Slice 11 closes Item 2.4 with three cases from slice 8's code review, all
three behaviours already fixed in `lib/probes.sh` at HEAD, so each is proven
by mutation rather than by an initial red:

- `relative cwd terminates at the working directory`
- `a .git file is walked past`
- `trailing slash on cwd`

All three tests pass unmutated (behaviour already present). Each was proven
by mutating the exact line the s8 code review names, confirming the named
test alone reds on its own assertion (never on a missing symbol), restoring
by the inverse replacement, grep-confirming the restore, and rerunning the
full four-file suite green.

## Files

- `tests/probes-config.bats`: 300 lines (was 228). Under the 400-line cap.
- `tests/helpers/probes.bash`: 126 lines (was 85). Under the cap. Gained
  `run_probe_bounded`, moved verbatim (plus `# shellcheck disable=SC2034`
  comments the cross-file move needs — see Shellcheck below) from
  `tests/probes-edges.bats`, which still carries its own copy unchanged
  (out of this dispatch's scope); the duplication is a candidate for the
  test review to fold, not something RED mode may act on.

## Tests added (per-test output)

### `relative cwd terminates at the working directory`

Runs from a `.git`-free `$BATS_TEST_TMPDIR/w` (checked first, walking every
ancestor up to `/`), then calls `probe_git_lock false rel …` and
`probe_git_lock false rel/x …` with relative git-lock text
(`.git/index.lock`), through `run_probe_bounded` (background job + `kill`,
30 × 0.1 s bound) so a walk-up regression fails the test instead of hanging
the suite. Expects `mask`, `path=$BATS_TEST_TMPDIR/w/rel/.git/index.lock` for
the first call and `path=$BATS_TEST_TMPDIR/w/rel/x/.git/index.lock` for the
second (the walk-up finds no `.git` anywhere, so `base` stays at each call's
own unshrunk starting directory — `rel` and `rel/x` resolve to different
paths, matching the code review's own worked examples).

Unmutated: passed.

### `a .git file is walked past`

`<r>/.git` a directory, `<r>/sm/.git` a file (`gitdir: x`), `$2` =
`<r>/sm/d`, config-lock text naming `.git/config`, lock present at
`<r>/.git/config.lock`. Expects `orphan`, `path=<r>/.git/config.lock` — the
walk must not stop at the `.git` file in `<r>/sm`.

Unmutated: passed.

### `trailing slash on cwd`

`$2` = `<repo>/` with `<repo>/.git` present, relative git-lock text. Expects
`mask`, `path=<repo>/.git/index.lock` exactly (via `grep -qxF`, which fails
outright on a doubled `/`).

Unmutated: passed.

### Full run before any mutation

```
bats: 35 passed, 0 failed
```
(32 pre-existing across `tests/probes.bats`, `tests/probes-edges.bats`,
`tests/probes-tools.bats`, `tests/probes-config.bats`, plus the 3 new).

## Mutation proof

One mutation per named test, applied to `lib/probes.sh`, run, restored,
restore grep-proven, then the full four-file suite rerun green. All runs
in the foreground via
`scripts/run-bats.sh tests/probes.bats tests/probes-edges.bats tests/probes-tools.bats tests/probes-config.bats`
(mutated runs used `tests/probes-config.bats` alone first, to see the single
failure cleanly, per test below; the full four-file suite was rerun green
after each restore).

### 1. `relative cwd terminates at the working directory`

- **Mutation**: removed the anchoring `case` block —
  ```
  case "$dir" in
      /*) ;;
      *) dir="$PWD/$dir" ;;
  esac
  ```
  → deleted (nothing left between `dir="${2:-$PWD}"` and `base="$dir"`).
- **Run**: `not ok 9 relative cwd terminates at the working directory` —
  ``  `[ "$status" -eq 0 ]' failed`` — the bound (30 × 0.1 s) turned the
  infinite loop into `status=124` within the run's ~4.7 s wall time; the
  other 10 cases in the file passed. Confirmed no stray process afterwards:
  `pgrep -fa "probe_git_lock\|bats-exec\|_probe_resolve_path"` and
  `pgrep -fa "sleep 30"` found nothing but the `pgrep` invocation itself.
- **Restore**: re-added the same `case` block (swap the two strings).
  `grep -c 'dir="$PWD/$dir"' lib/probes.sh` → `1`; `git diff --quiet
  lib/probes.sh` → identical to HEAD.
- **Rerun**: full four-file suite, `bats: 35 passed, 0 failed`.

### 2. `a .git file is walked past`

- **Mutation**: `if [ -d "$dir/.git" ]; then` → `if [ -e "$dir/.git" ]; then`
  (the exact replacement the s8 code review names; it occurs once in the
  file).
- **Run**: `not ok 10 a .git file is walked past` —
  ``  `[ "${output%%$'\n'*}" = orphan ]' failed`` — the walk stopped at the
  `.git` file and answered `mask`/`gone` for the ancestor lock's presence
  instead of `orphan`; only this test failed (10 others passed).
- **Restore**: swapped back to `if [ -d "$dir/.git" ]; then`.
  `grep -c 'if \[ -e "$dir/.git" \]; then' lib/probes.sh` → `0`;
  `grep -c 'if \[ -d "$dir/.git" \]; then' lib/probes.sh` → `1`;
  `git diff --quiet lib/probes.sh` → identical to HEAD.
- **Rerun**: full four-file suite, `bats: 35 passed, 0 failed`.

### 3. `trailing slash on cwd`

- **Mutation**: `printf '%s/%s\n' "${base%/}" "$1"` →
  `printf '%s/%s\n' "$base" "$1"`.
- **Run**: `not ok 11 trailing slash on cwd` —
  ``  `printf '%s\n' "$output" | grep -qxF "path=$lock"' failed`` — the
  unmutated assertion's exact-match `grep -qxF` failed against the
  doubled-slash path the un-stripped join produced; only this test failed
  (10 others passed).
- **Restore**: swapped back to `"${base%/}"`.
  `grep -c '"${base%/}"' lib/probes.sh` → `1`; a search for the mutated form
  (`printf .%s/%s\n. "$base" "$1"`) → `0`; `git diff --quiet lib/probes.sh` →
  identical to HEAD.
- **Rerun**: full four-file suite, `bats: 35 passed, 0 failed`.

## Gates

- `scripts/run-bats.sh tests/probes.bats tests/probes-edges.bats
  tests/probes-tools.bats tests/probes-config.bats` (foreground, final run
  after all mutations restored): `bats: 35 passed, 0 failed`.
- Shellcheck on the two changed files individually reports only an
  informational `SC1091` (`source "$ROOT/lib/probes.sh"` not followed) on
  `tests/probes-config.bats`, which is pre-existing in every probe suite file
  (also present unmodified in `tests/probes.bats`, `tests/probes-edges.bats`)
  and disappears when shellcheck runs over the full tracked `*.sh`/`*.bash`/
  `*.bats` set together, as `just precommit` does (`lib/probes.sh` is then in
  the same invocation and gets followed). Confirmed:
  `git ls-files -z -- '*.sh' '*.bash' '*.bats' | xargs -0 shellcheck` → `rc=0`.
- `tests/helpers/probes.bash` alone: moving `run_probe_bounded` out of a
  single test file introduced three genuine (not pre-existing) `SC2034`
  warnings, since `status`/`output`/`stderr` are read only by the caller in
  another file. Fixed with `# shellcheck disable=SC2034 # read by the
  calling test, not here` on each, matching the existing convention in
  `tests/helpers/fixture-root.bash:15`. `shellcheck tests/helpers/probes.bash`
  now exits 0.
- `direnv exec . just precommit` (foreground, full gate): `precommit passed:
  plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links,
  tests`, with bats at `130 passed, 0 failed` (127 before this slice + 3).
- Self-quiet: `bash lib/matchers.sh < tests/probes-config.bats` → no output,
  `rc=1`.
- `git diff --quiet lib/probes.sh` → passes (byte-identical to HEAD, no
  residual mutation).

## Not done here (out of scope for RED)

- No implementation change (all three behaviours already correct at HEAD;
  RED mode wrote tests only).
- `tests/probes-edges.bats` was not edited; its own local `run_probe_bounded`
  copy still exists there, now duplicated in `tests/helpers/probes.bash`. Left
  for the test review to decide whether to consolidate (touching that file
  was outside this dispatch's stated IN scope).
- Residuals the item text names as not-to-be-tested (a config path holding
  `: File exists` or a non-UTF-8 byte, a symlinked base, a base inside a
  gitdir) were left untested, per the runbook.

## Stop conditions hit

None. No commit made.
