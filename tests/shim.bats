#!/usr/bin/env bats
# D-16: `.bin/claude` loads this checkout as a plugin and chains to the next
# `claude` on PATH with its own directory stripped, so the next launcher in
# the chain cannot find the shim again.
#
# The next `claude` is a stub that records its argv, one argument per line,
# and the PATH it was given.

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/probes

ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
SHIM="$ROOT/.bin/claude"

setup() {
  NEXT="$BATS_TEST_TMPDIR/next dir"
  mkdir -p "$NEXT"
  cat >"$NEXT/claude" <<STUB
#!/bin/sh
for a in "\$@"; do printf '%s\n' "\$a"; done >"$BATS_TEST_TMPDIR/argv"
printf '%s\n' "\$PATH" >"$BATS_TEST_TMPDIR/path"
STUB
  chmod 755 "$NEXT/claude"
}

@test "the shim prepends --plugin-dir <checkout> and passes every argument through" {
  PATH="$ROOT/.bin:$NEXT:$PATH" run --separate-stderr "$SHIM" -p 'a b' -- '-x'
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  printf '%s\n' --plugin-dir "$ROOT" -p 'a b' -- '-x' >"$BATS_TEST_TMPDIR/want"
  diff "$BATS_TEST_TMPDIR/want" "$BATS_TEST_TMPDIR/argv"
}

@test "the next claude runs with the shim's directory stripped from PATH" {
  PATH="$ROOT/.bin:$NEXT:$PATH:$ROOT/.bin" run --separate-stderr "$SHIM"
  [ "$status" -eq 0 ]
  tr ':' '\n' <"$BATS_TEST_TMPDIR/path" >"$BATS_TEST_TMPDIR/entries"
  grep -qxF "$NEXT" "$BATS_TEST_TMPDIR/entries"
  run ! grep -qxF "$ROOT/.bin" "$BATS_TEST_TMPDIR/entries"
}

@test "an entry naming the shim's directory in another spelling is stripped too" {
  # A trailing slash and a relative `.bin` each name the shim's directory
  # without matching its spelling; either left on PATH re-execs the shim
  # without end, which the bounded run reports as status 124.
  cd "$ROOT"
  PATH="$ROOT/.bin/:.bin:$NEXT:$PATH" run_probe_bounded "$SHIM" -p 'a b' ''
  [ "$status" -eq 0 ]
  printf '%s\n' --plugin-dir "$ROOT" -p 'a b' >"$BATS_TEST_TMPDIR/want"
  diff "$BATS_TEST_TMPDIR/want" "$BATS_TEST_TMPDIR/argv"
  tr ':' '\n' <"$BATS_TEST_TMPDIR/path" >"$BATS_TEST_TMPDIR/entries"
  grep -qxF "$NEXT" "$BATS_TEST_TMPDIR/entries"
  run ! grep -qxF -e "$ROOT/.bin/" -e .bin "$BATS_TEST_TMPDIR/entries"
}

@test "with no other claude on PATH the shim exits 127 and says so" {
  local bare="$BATS_TEST_TMPDIR/bare"
  mkdir -p "$bare"
  local tool
  for tool in sh dirname tr paste; do
    ln -s "$(command -v "$tool")" "$bare/$tool"
  done
  # env, not a prefix assignment: bats' own `run` needs mktemp from PATH
  run -127 --separate-stderr env PATH="$ROOT/.bin:$bare" "$SHIM"
  [ "$status" -eq 127 ]
  [ "$stderr" = "sandbox-lies: no other claude on PATH" ]
}

@test "the stub refuses paste -s with no file operand, alone or bundled" {
  local bsd="$BATS_TEST_TMPDIR/bsd"
  make_bsd_stubs "$bsd" paste
  local args
  for args in -s -sd: "-sd :" "-d: -s"; do
    # shellcheck disable=SC2086 # word-splitting the option list is the point
    PATH="$bsd:$PATH" run --separate-stderr -1 paste $args </dev/null
    [ "$status" -eq 1 ]
    [[ "$stderr" == "usage: paste "* ]]
  done
}

@test "the stub passes paste with a file operand, including - for stdin" {
  local bsd="$BATS_TEST_TMPDIR/bsd"
  make_bsd_stubs "$bsd" paste
  printf 'a\nb\n' >"$BATS_TEST_TMPDIR/two"
  PATH="$bsd:$PATH" run paste -sd: "$BATS_TEST_TMPDIR/two"
  [ "$status" -eq 0 ]
  [ "$output" = "a:b" ]
  PATH="$bsd:$PATH" run bash -c "printf 'a\nb\n' | paste -sd: -"
  [ "$status" -eq 0 ]
  [ "$output" = "a:b" ]
}

@test "the shim strips its directory under a BSD paste, which reads no implicit stdin" {
  local bsd="$BATS_TEST_TMPDIR/bsd"
  make_bsd_stubs "$bsd" paste
  PATH="$bsd:$ROOT/.bin:$NEXT:$PATH" run --separate-stderr "$SHIM" -p 'a b'
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  printf '%s\n' --plugin-dir "$ROOT" -p 'a b' >"$BATS_TEST_TMPDIR/want"
  diff "$BATS_TEST_TMPDIR/want" "$BATS_TEST_TMPDIR/argv"
  tr ':' '\n' <"$BATS_TEST_TMPDIR/path" >"$BATS_TEST_TMPDIR/entries"
  grep -qxF "$NEXT" "$BATS_TEST_TMPDIR/entries"
  run ! grep -qxF "$ROOT/.bin" "$BATS_TEST_TMPDIR/entries"
}
