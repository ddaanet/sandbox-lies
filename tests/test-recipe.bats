#!/usr/bin/env bats
# The `test` recipe asks bats for parallel jobs only where GNU parallel is what
# `parallel` runs: bats -j without it runs no test and fails the gate. The real
# justfile runs in a scratch copy of the tree whose plugin-dev/run-bats.sh is a
# spy, on a PATH of symlinks holding only what the recipe needs plus, per case,
# a stand-in `parallel`.

ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs

setup() {
  TREE="$BATS_TEST_TMPDIR/tree"
  BIN="$BATS_TEST_TMPDIR/bin"
  JUST=$(type -P just)
  ARGS="$BATS_TEST_TMPDIR/args"
  mkdir -p "$TREE/plugin-dev" "$BIN"
  cp "$ROOT/justfile" "$TREE/"
  cp "$ROOT/plugin-dev/release.just" "$ROOT/plugin-dev/gates.just" "$TREE/plugin-dev/"
  spy_exits 0
  local tool real
  for tool in bash env getconf sh; do
    real=$(type -P "$tool")
    ln -s "$real" "$BIN/$tool"
  done
}

# The spy records each argument on its own line and exits with the status given.
spy_exits() {
  cat >"$TREE/plugin-dev/run-bats.sh" <<SPY
#!$(type -P bash)
printf '%s\n' "\$@" >"$ARGS"
exit $1
SPY
  chmod +x "$TREE/plugin-dev/run-bats.sh"
}

# A stand-in `parallel` whose --version prints $1 and exits with $2.
parallel_prints() {
  cat >"$BIN/parallel" <<STUB
#!$(type -P bash)
printf '%s\n' "$1"
exit $2
STUB
  chmod +x "$BIN/parallel"
}

run_recipe() {
  PATH="$BIN" run "$JUST" --justfile "$TREE/justfile" test
}

@test "GNU parallel present: the suites run at twice the CPU count" {
  local cpus
  cpus=$(getconf _NPROCESSORS_ONLN)
  parallel_prints 'GNU parallel 20240222' 0
  run_recipe
  [ "$status" -eq 0 ]
  [ "$(cat "$ARGS")" = "-j
$((cpus * 2))
tests/" ]
}

@test "no parallel on PATH: the suites run serially" {
  run_recipe
  [ "$status" -eq 0 ]
  [ "$(cat "$ARGS")" = "tests/" ]
}

@test "a parallel that does not say it is GNU: the suites run serially" {
  parallel_prints 'parallel [OPTIONS] command -- arguments' 0
  run_recipe
  [ "$status" -eq 0 ]
  [ "$(cat "$ARGS")" = "tests/" ]
}

@test "a parallel whose --version fails: the suites run serially" {
  parallel_prints 'GNU parallel 20240222' 1
  run_recipe
  [ "$status" -eq 0 ]
  [ "$(cat "$ARGS")" = "tests/" ]
}

@test "a failing bats run fails the recipe, with jobs and without" {
  spy_exits 3
  run_recipe
  [ "$status" -eq 3 ]
  parallel_prints 'GNU parallel 20240222' 0
  run_recipe
  [ "$status" -eq 3 ]
}
