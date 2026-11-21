#!/usr/bin/env bats
# lib/verdicts.sh's _verdict_path_read called directly: its cost in the escape
# count, a literal newline, the letter escapes, the values it reads as no path,
# and the caller's locale on bash 3.2.0. Split from
# tests/verdicts-readonly-path.bats, which covers the verdict built over it.
# No BSD-stub case: lib/verdicts.sh forks no tool (the decoder is bash
# builtins and parameter expansion), so no sed, grep, mktemp, stat or wc differs
# under BSD there. The suite still loads helpers/bsd-stubs per the repo rule.

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/verdicts
load helpers/locale

# decode_seconds <locale> <wire> — CPU seconds (user + system) a fresh bash
# spends sourcing lib/verdicts.sh and running _verdict_path_read on <wire>: the
# least of five runs. CPU time, not wall time: sibling suites share the cores
# under `bats -j`, and a run descheduled for a while inflates wall time but not
# CPU time. python3's resource module is the clock: bash 3.2 has no
# EPOCHREALTIME and BSD date no %N.
decode_seconds() {
  # shellcheck disable=SC2016 # the Python source holds $1/$2 for bash -c
  python3 -I -c '
import os, resource, subprocess, sys
env = dict(os.environ, LC_ALL=sys.argv[1])
best = None
for _ in range(5):
    r0 = resource.getrusage(resource.RUSAGE_CHILDREN)
    subprocess.run(["bash", "-c", ". \"$1\"; _verdict_path_read \"$2\"", "_", sys.argv[3], sys.argv[2]], env=env, check=True)
    r1 = resource.getrusage(resource.RUSAGE_CHILDREN)
    dt = (r1.ru_utime - r0.ru_utime) + (r1.ru_stime - r0.ru_stime)
    best = dt if best is None else min(best, dt)
print("%.4f" % best)
' "$1" "$2" "$VERDICTS"
}

# N is 300 CJK characters (900 octal escapes on the wire), 4N is 1200. Measured
# on CPU time, 12 busy loops on 4 cores: the linear decoder gives a ratio of
# 3.3 to 4.4 and the quadratic one it replaced (re-slicing the remaining body
# per escape) 11 to 12.5, so the limit of 7 sits in the gap with margin both
# ways.
@test "_verdict_path_read time grows no faster than linearly in the escape count" {
  local loc wire_n wire_4n t_n t_4n ratio p_n p_4n
  loc=$(utf8_locale)
  p_n=/x/$(LC_ALL=C python3 -I -c 'import sys; sys.stdout.buffer.write("\u4e00\u4e2d\u6587".encode() * 100)')
  p_4n=/x/$(LC_ALL=C python3 -I -c 'import sys; sys.stdout.buffer.write("\u4e00\u4e2d\u6587".encode() * 400)')
  # shellcheck disable=SC1091 # the production encoder, resolved at run time
  wire_n=$(. "$ROOT/lib/probes-readonly.sh"; _probe_path_line "$p_n"); wire_n=${wire_n#path=}
  # shellcheck disable=SC1091 # as above
  wire_4n=$(. "$ROOT/lib/probes-readonly.sh"; _probe_path_line "$p_4n"); wire_4n=${wire_4n#path=}

  # The decoded value is the original at both sizes, under the locale the
  # timings use, so a decoder that returned nothing quickly cannot pass on
  # speed.
  # shellcheck disable=SC1090,SC2154
  [ "$(trap - DEBUG; LC_ALL=$loc; . "$VERDICTS"; _verdict_path_read "$wire_n"; [ "$_verdict_path_raw" = "$p_n" ] && echo same)" = same ]
  # shellcheck disable=SC1090,SC2030
  [ "$(trap - DEBUG; LC_ALL=$loc; . "$VERDICTS"; _verdict_path_read "$wire_4n"; [ "$_verdict_path_raw" = "$p_4n" ] && echo same)" = same ]

  t_n=$(decode_seconds "$loc" "$wire_n")
  t_4n=$(decode_seconds "$loc" "$wire_4n")
  # Linear is 4, quadratic 16; start-up cost only pulls either ratio down.
  ratio=$(python3 -I -c 'import sys; print("%.2f" % (float(sys.argv[2]) / float(sys.argv[1])))' "$t_n" "$t_4n")
  printf 't(N)=%s s t(4N)=%s s ratio=%s\n' "$t_n" "$t_4n" "$ratio" >&2
  python3 -I -c 'import sys; sys.exit(0 if float(sys.argv[1]) < 7 else 1)' "$ratio"
}

@test "_verdict_path_read keeps a literal newline inside the quoted body" {
  local wire out
  # %q writes \n as an escape, so a literal newline is a forged wire, which
  # the grammar still admits. Stderr joins stdout: a set -u abort on an empty
  # field list would show here as a diagnostic and a missing rc line.
  wire="\$'/x/a"$'\n'"b\\\\c'"
  # shellcheck disable=SC1090 # $VERDICTS is lib/verdicts.sh, resolved above
  out=$(exec 2>&1; . "$VERDICTS"; _verdict_path_read "$wire"; printf 'rc=%s raw=%s' "$?" "$_verdict_path_raw")
  [ "$out" = "rc=0 raw=/x/a"$'\n'"b\\c" ] || { printf 'gave: %s\n' "$out" >&2; return 1; }
}

@test "_verdict_path_read decodes the letter escapes %q writes for control bytes a b f r v" {
  local letter ctl real wire out
  # %q writes bytes 007, 010, 014, 015 and 013 as \a \b \f \r \v. Each path is
  # built, encoded and decoded through the production pair, so the letter in
  # the wire is the one the probe writes; a failure names the letter.
  for letter in a b f r v; do
    case $letter in
      a) ctl=$'\a' ;; b) ctl=$'\b' ;; f) ctl=$'\f' ;; r) ctl=$'\r' ;; v) ctl=$'\v' ;;
    esac
    real="/x/a${ctl}z/f"
    # shellcheck disable=SC1091 # the production encoder, resolved at run time
    wire=$(. "$ROOT/lib/probes-readonly.sh"; _probe_path_line "$real"); wire=${wire#path=}
    [[ $wire == *"\\$letter"* ]] || { printf 'wire %s has no \\%s escape\n' "$wire" "$letter" >&2; return 1; }
    # shellcheck disable=SC1090 # $VERDICTS is lib/verdicts.sh, resolved above
    out=$(exec 2>&1; . "$VERDICTS"; _verdict_path_read "$wire"; printf 'rc=%s raw=%s' "$?" "$_verdict_path_raw")
    [ "$out" = "rc=0 raw=$real" ] || { printf 'letter \\%s: wire %s gave: %s\n' "$letter" "$wire" "$out" >&2; return 1; }
  done
}

# $'' decodes to empty with status 0 on the unchanged code, and the two other
# values below are accepted: the probe's %q never writes any of them. Each is
# its own case so a mutation of one arm shows red on that value alone.
@test "_verdict_path_read reads \$'' as no path" {
  local out
  # shellcheck disable=SC1090,SC2154 # $VERDICTS is lib/verdicts.sh, resolved
  # above; the reader sets the two outputs
  out=$(. "$VERDICTS"; rc=0; _verdict_path_read "\$''" || rc=$?
    printf 'rc=%s raw=[%s] shown=[%s]' "$rc" "$_verdict_path_raw" "$_verdict_path_shown")
  [ "$out" = 'rc=1 raw=[] shown=[]' ]
}

@test "_verdict_path_read reads a relative \$'...' value as no path" {
  local out
  # shellcheck disable=SC1090,SC2154 # as above
  out=$(. "$VERDICTS"; rc=0; _verdict_path_read "\$'rel/x'" || rc=$?
    printf 'rc=%s raw=[%s] shown=[%s]' "$rc" "$_verdict_path_raw" "$_verdict_path_shown")
  [ "$out" = 'rc=1 raw=[] shown=[]' ]
}

@test "_verdict_path_read reads a / value ending in a lone backslash as no path" {
  local out
  # shellcheck disable=SC1090,SC2154,SC1003 # as above; the backslash is the value
  out=$(. "$VERDICTS"; rc=0; _verdict_path_read '/x\' || rc=$?
    printf 'rc=%s raw=[%s] shown=[%s]' "$rc" "$_verdict_path_raw" "$_verdict_path_shown")
  [ "$out" = 'rc=1 raw=[] shown=[]' ]
}

# The legitimate neighbours of the three cases above, so a fix that rejects too
# much turns red: an absolute $'...' value, a / value ending in an escaped
# backslash (read without -r leaves one), and the $'...' form of that path.
@test "_verdict_path_read still reads an absolute \$'...' value and a / value ending in an escaped backslash" {
  local out wire raw
  while IFS='|' read -r wire raw; do
    # shellcheck disable=SC1090,SC2154 # as above
    out=$(. "$VERDICTS"; rc=0; _verdict_path_read "$wire" || rc=$?
      printf 'rc=%s raw=[%s]' "$rc" "$_verdict_path_raw")
    [ "$out" = "rc=0 raw=[$raw]" ] || { printf 'wire %s gave: %s\n' "$wire" "$out" >&2; return 1; }
  done <<'CASES'
$'/x'|/x
/x\\|/x\
$'/x\\'|/x\
CASES
}

# bats does not parse under bash 3.2.0, so this case runs the 3.2.0 build as a
# subprocess. On 3.2.0 `local LC_ALL=C` is not undone on return, so the
# calling shell is left in the C locale; bash 5.2 restores it, so no 5.2 run
# can fail for this. Skipped where the build is absent (rebuild recipe:
# plans/sandbox-lies-review-fixes-3/evidence.md).
@test "the readers leave the caller's locale as it was, on bash 3.2.0" {
  local bash32=${BASH32:-/tmp/claude/bash32/bash} loc fn out
  [ -x "$bash32" ] || skip "no bash 3.2.0 build at $bash32"
  loc=$(utf8_locale)
  # _verdict_has_control and the decoder (_verdict_unescape) each set LC_ALL=C
  # and must put it back. The three calls reach them: x and /x/y reach
  # _verdict_has_control, $'a' reaches the decoder, so a fix to one site leaves
  # the leak of the other and this case stays red.
  for fn in "_verdict_has_control x" "_verdict_path_read /x/y" "_verdict_path_read \$'a'"; do
    # An em dash counts 1 in a UTF-8 locale and 3 bytes in C: the length
    # after the call must equal the length before it. The call is its own
    # two arguments, so the wire form $'a' reaches the reader unexpanded.
    # shellcheck disable=SC2016 # the script is for the child shell
    out=$(LC_ALL="$loc" "$bash32" -c '. "$1"; x="—"; before=${#x}; "$2" "$3"; printf "%s %s" "$before" "${#x}"' _ "$VERDICTS" "${fn%% *}" "${fn#* }")
    [ "$out" = '1 1' ] || { printf '%s left the length %s (before after)\n' "$fn" "$out" >&2; return 1; }
  done
}
