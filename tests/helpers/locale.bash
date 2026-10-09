#!/usr/bin/env bash
# Shared by tests/hook-cap.bats, tests/probes.bats and
# tests/probes-lock-newline.bats: the three cases that need a UTF-8 locale.
# Its own file because tests/hook-cap.bats loads helpers/hook, not
# helpers/probes, so the function has no home that all three already load.

# utf8_locale — prints the first UTF-8 locale this system provides, checked
# by bash counting an em dash as one character under it; fails when none is,
# rather than letting the bytes-not-characters case pass under a byte locale.
utf8_locale() {
  local loc
  for loc in C.UTF-8 en_US.UTF-8; do
    if [ "$(LC_ALL="$loc" bash -c 'x="—"; printf %s "${#x}"')" = 1 ]; then
      printf '%s\n' "$loc"
      return 0
    fi
  done
  echo "no UTF-8 locale found" >&2
  return 1
}
