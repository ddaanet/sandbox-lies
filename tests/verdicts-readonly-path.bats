#!/usr/bin/env bats
# lib/verdicts.sh's verdict_readonly_path path= decoder (Item 1.2): the probe
# prints path= in printf %q form, the verdict reads it back without eval and
# shows the decoded bytes, or the wire form when they hold a control byte. The
# wire values below are the probe's own forms (or forged ones, said so),
# spelled with \$ and \\ in double quotes so the file holds them literally.
# New file: tests/verdicts-readonly.bats sits near the 400-line cap.
# No BSD-stub case: lib/verdicts.sh forks no tool (the decoder is bash
# builtins and parameter expansion, its $(...) subshells run only functions of
# the library), so no sed, grep, mktemp, stat or wc differs under BSD there and
# a stubs-first re-run could not fail for a BSD reason. The suite still loads
# helpers/bsd-stubs per the repo rule, and the tests' own `sed` is a pipeline
# stage outside the code under test.

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/verdicts
load helpers/locale

# path_verdict <outcome> <wire> — verdict_readonly_path's two-line text over a
# probe stdin holding the one path=<wire> line.
path_verdict() {
  # shellcheck disable=SC1090 # $VERDICTS is lib/verdicts.sh, resolved above
  printf 'path=%s\n' "$2" | ( . "$VERDICTS"; verdict_readonly_path "$1" )
}

@test "readonly-path shows a UTF-8 path byte-exact from the \$'...' form" {
  local line1 expected eacute=$'\303\251'
  expected="\`/x/caf${eacute}/f\` is writable outside the sandbox, whose allowlist refused it."
  line1=$(path_verdict writable "\$'/x/caf\\303\\251/f'" | sed -n '1p')
  [ "$line1" = "$expected$(readonly_path_tail)" ]

  # The readonly outcome shows the decoded path too.
  line1=$(path_verdict readonly "\$'/x/caf\\303\\251/f'" | sed -n '1p')
  [ "${line1#"\`/x/caf${eacute}/f\` is not writable outside the sandbox either;"}" != "$line1" ]
}

@test "readonly-path shows the wire form for a path holding a newline, in two lines" {
  local text
  text=$(path_verdict writable "\$'/x/a\\nb/f'")
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$(printf '%s\n' "$text" | sed -n '1p')" = "\`\$'/x/a\\nb/f'\` is writable outside the sandbox, whose allowlist refused it.$(readonly_path_tail)" ]
  [ "$(printf '%s\n' "$text" | sed -n '$=')" = 2 ]
}

@test "readonly-path shows the wire form for every control byte, the decoded form past them" {
  local text byte real wire
  # \001 and \037 bound the range, \177 is the extra one; \200 and \377 sit
  # outside it and show decoded, and so does U+0080 (\302\200), a C1 control
  # that is valid UTF-8 text and that [:cntrl:] matches under a UTF-8 locale.
  for byte in $'\001' $'\t' $'\033' $'\037' $'\177'; do
    real="/x/a${byte}b/f"
    wire=$(LC_ALL=C; printf '%q' "$real")
    [ "${wire#\$\'}" != "$wire" ]
    text=$(path_verdict writable "$wire")
    [ "$(printf '%s\n' "$text" | sed -n '1p')" = "\`$wire\` is writable outside the sandbox, whose allowlist refused it.$(readonly_path_tail)" ] \
      || { printf 'byte %s gave: %s\n' "$wire" "$text" >&2; return 1; }
    [ "$(printf '%s\n' "$text" | sed -n '$=')" = 2 ]
  done
  for byte in $'\200' $'\377' $'\302\200'; do
    real="/x/a${byte}b/f"
    wire=$(LC_ALL=C; printf '%q' "$real")
    [ "${wire#\$\'}" != "$wire" ]
    text=$(path_verdict writable "$wire")
    [ "$(printf '%s\n' "$text" | sed -n '1p')" = "\`$real\` is writable outside the sandbox, whose allowlist refused it.$(readonly_path_tail)" ] \
      || { printf 'byte %s gave: %s\n' "$wire" "$text" >&2; return 1; }
  done
}

@test "readonly-path matches the settings.json suffix on the decoded value" {
  local line1 act eacute=$'\303\251'
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  act='Write `.claude/settings.json` through the `update-config` skill.'
  line1=$(path_verdict writable "\$'/h/jos\\303\\251/.claude/settings.json'" | sed -n '1p')
  text_lacks "$line1" 'dangerouslyDisableSandbox'
  [ "$line1" = "\`/h/jos${eacute}/.claude/settings.json\` is writable outside the sandbox, whose allowlist refused it. $act" ]

  # A control byte in the directory: the wire form is shown, and the decoded
  # value still decides the act.
  line1=$(path_verdict writable "\$'/h/a\\nb/.claude/settings.json'" | sed -n '1p')
  [ "$line1" = "\`\$'/h/a\\nb/.claude/settings.json'\` is writable outside the sandbox, whose allowlist refused it. $act" ]

  # Same shape, another file name: the generic act.
  line1=$(path_verdict writable "\$'/h/jos\\303\\251/.claude/settings.jsonx'" | sed -n '1p')
  [ "$line1" = "\`/h/jos${eacute}/.claude/settings.jsonx\` is writable outside the sandbox, whose allowlist refused it.$(readonly_path_tail)" ]
}

@test "readonly-path reads an escaped quote in the \$'...' form" {
  local line1 real wire eacute=$'\303\251'
  line1=$(path_verdict writable "\$'/x/it\\'s/f'" | sed -n '1p')
  [ "$line1" = "\`/x/it's/f\` is writable outside the sandbox, whose allowlist refused it.$(readonly_path_tail)" ]

  # The probe's own forms: a quote, and a quote after a literal backslash, next
  # to a UTF-8 byte (which is what puts %q in the $'...' form); a literal
  # backslash and "n" is two characters, never a newline.
  # Two quotes in one value: every \' is swapped, not the first alone.
  for real in "/x/caf${eacute}'s\\n/f" "/x/caf${eacute}\\'s/f" "/x/caf${eacute}'\\/f" \
    "/x/caf${eacute}'a'b/f" "/x/caf${eacute}''\\'/f"; do
    wire=$(LC_ALL=C; printf '%q' "$real")
    [ "${wire#\$\'}" != "$wire" ]
    line1=$(path_verdict writable "$wire" | sed -n '1p')
    [ "$line1" = "\`$real\` is writable outside the sandbox, whose allowlist refused it.$(readonly_path_tail)" ] \
      || { printf 'wire %s gave: %s\n' "$wire" "$line1" >&2; return 1; }
  done
}

@test "readonly-path decodes the backslash form without running what it holds" {
  local sentinel="$BATS_TEST_TMPDIR/sentinel" wire line1
  # The sentinel's directory is writable, so a decoder that ran the
  # substitution would create the file and the absence below could fail.
  [ -d "$BATS_TEST_TMPDIR" ] && [ -w "$BATS_TEST_TMPDIR" ]
  [ ! -e "$sentinel" ]
  wire=$(LC_ALL=C; printf '%q' "/x/\$(touch $sentinel)")
  line1=$(path_verdict writable "$wire" | sed -n '1p')
  [ "$line1" = "\`/x/\$(touch $sentinel)\` is writable outside the sandbox, whose allowlist refused it.$(readonly_path_tail)" ]
  [ ! -e "$sentinel" ]
}

@test "readonly-path reads a malformed path value as no path" {
  local value line1
  # The settings.json suffix on a value that reads as no path must not select
  # the update-config act: the last two end in the suffix on the wire.
  for value in "\$'a'b" "\$'a'b'" "\$'a" "\$'" "\$'a\\'" "relative/path" \
    "relative/.claude/settings.json" "\$'x'/.claude/settings.json"; do
    line1=$(path_verdict writable "$value" | sed -n '1p')
    [ "$line1" = "The path is writable outside the sandbox, whose allowlist refused it.$(readonly_path_tail)" ] \
      || { printf 'value %s gave: %s\n' "$value" "$line1" >&2; return 1; }
  done
}

@test "_verdict_path_read empties both outputs for a malformed value after a good read" {
  local result
  # shellcheck disable=SC1090,SC2154 # $VERDICTS is lib/verdicts.sh, resolved
  # above; the reader sets the two outputs
  result=$(. "$VERDICTS"
    _verdict_path_read "\$'/x/caf\\303\\251/f'"
    if _verdict_path_read "\$'a'b"; then printf 'accepted '; fi
    printf '[%s][%s]' "$_verdict_path_raw" "$_verdict_path_shown")
  [ "$result" = '[][]' ]
}

@test "readonly-path never runs a forged value, well-formed or not" {
  local sentinel="$BATS_TEST_TMPDIR/forged" line1 value
  [ -w "$BATS_TEST_TMPDIR" ]
  [ ! -e "$sentinel" ]
  # Not the probe's form (it escapes the $): the backslash form shows it
  # literally.
  line1=$(path_verdict writable "/x/\$(touch $sentinel)" | sed -n '1p')
  [ "$line1" = "\`/x/\$(touch $sentinel)\` is writable outside the sandbox, whose allowlist refused it.$(readonly_path_tail)" ]
  [ ! -e "$sentinel" ]
  # Fails the $'...' grammar through its inner quote, so it reads as no path.
  for value in "\$'a'\$(touch $sentinel)''" "\$'a'; touch $sentinel; '"; do
    line1=$(path_verdict writable "$value" | sed -n '1p')
    [ "$line1" = "The path is writable outside the sandbox, whose allowlist refused it.$(readonly_path_tail)" ] \
      || { printf 'value %s gave: %s\n' "$value" "$line1" >&2; return 1; }
    [ ! -e "$sentinel" ]
  done
  # Well-formed, with an escaped quote ahead of the substitution: decoded and
  # shown, never run.
  line1=$(path_verdict writable "\$'/a\\'\$(touch $sentinel)'" | sed -n '1p')
  [ "$line1" = "\`/a'\$(touch $sentinel)\` is writable outside the sandbox, whose allowlist refused it.$(readonly_path_tail)" ]
  [ ! -e "$sentinel" ]
}

@test "readonly-path shows each character %q escapes, byte-exact" {
  local real wire line1 eacute=$'\303\251'
  # Several are format, regex or expansion syntax in some reader: %, &, \1, \,
  # quotes, $ and a trailing blank. The last two sit next to a UTF-8 byte,
  # which puts %q in the $'...' form.
  # shellcheck disable=SC2016 # the paths are literal, nothing expands
  for real in '/x/a&b/f' '/x/100%s/f' '/x/\1/f' '/x/a\b/f' "/x/a'b\"c/f" \
    '/x/${HOME}/`id`/f' '/x/*?[a]{b}#!/f' '/x/-n/f' '/x/f ' '/x/two  blanks/f' \
    "/x/caf${eacute}100%s%d&\\1\\n/f" "/x/caf${eacute}\$(id)\`id\`/f"; do
    wire=$(LC_ALL=C; printf '%q' "$real")
    line1=$(path_verdict writable "$wire" | sed -n '1p')
    [ "$line1" = "\`$real\` is writable outside the sandbox, whose allowlist refused it.$(readonly_path_tail)" ] \
      || { printf 'wire %s gave: %s\n' "$wire" "$line1" >&2; return 1; }
  done
}

@test "_verdict_path_read keeps the octal digit that follows a control-byte escape" {
  local real wire result eacute=$'\303\251'
  # %q writes \001-\037 as \0NN, and printf %b reads \0 plus up to three more
  # digits: a digit after the escape (here 6 after \004, which %b reads as
  # \0046, a literal &) must stay a separate character. The last path holds a
  # literal backslash and 0046, next to a UTF-8 byte so %q uses the $'...'
  # form.
  for real in "/x/a"$'\004'"6/f" "/x/a"$'\001'"7/f" "/x/a"$'\037'"0/f" \
    "/x/caf${eacute}1/f" "/x/caf${eacute}\\0046/f"; do
    wire=$(LC_ALL=C; printf '%q' "$real")
    [ "${wire#\$\'}" != "$wire" ]
    # shellcheck disable=SC1090 # $VERDICTS is lib/verdicts.sh, resolved above
    result=$(. "$VERDICTS"; _verdict_path_read "$wire"; printf '%s' "$_verdict_path_raw")
    [ "$result" = "$real" ] || { printf 'wire %s decoded to %s\n' "$wire" "$result" >&2; return 1; }
  done
  # The paragraph shows the wire form for the control byte, not a wrong path.
  # shellcheck disable=SC2030 # the subshell sets LC_ALL (bash 3.2: no temporary assignment before a builtin)
  wire=$(LC_ALL=C; printf '%q' "/x/a"$'\004'"6/f")
  [ "$(path_verdict writable "$wire" | sed -n '1p')" = "\`$wire\` is writable outside the sandbox, whose allowlist refused it.$(readonly_path_tail)" ]
}

@test "_verdict_path_read decodes \\\" and reads an escape %q never writes as no path, silently" {
  local wire out
  # shellcheck disable=SC1090 # $VERDICTS is lib/verdicts.sh, resolved above
  out=$(. "$VERDICTS"; _verdict_path_read "\$'/x/a\\\"b'"; printf 'rc=%s raw=%s' "$?" "$_verdict_path_raw")
  [ "$out" = 'rc=0 raw=/x/a"b' ]
  # Forged escapes the grammar admits: the decoded prefix must not survive,
  # and %b must not see \x or \c (it complains about the first and stops at
  # the second). Stderr joins stdout inside the substitution, so a diagnostic
  # fails the comparison.
  for wire in "\$'/x/ok\\x41'" "\$'/x/ok\\cA'" "\$'/x/ok\\12'" "\$'/x/ok\\q'"; do
    # shellcheck disable=SC1090
    out=$(exec 2>&1; . "$VERDICTS"; _verdict_path_read "$wire"; printf 'rc=%s raw=%s shown=%s' "$?" "$_verdict_path_raw" "$_verdict_path_shown")
    [ "$out" = 'rc=1 raw= shown=' ] || { printf 'wire %s gave: %s\n' "$wire" "$out" >&2; return 1; }
  done
}

# decode_seconds <locale> <wire> — wall seconds a fresh bash takes to source
# lib/verdicts.sh and run _verdict_path_read on <wire>: the least of three
# runs, so a loaded box (other sessions share it) inflates neither side of
# the ratio. python3's perf_counter is the clock: bash 3.2 has no
# EPOCHREALTIME and BSD date no %N.
decode_seconds() {
  # shellcheck disable=SC2016 # the Python source holds $1/$2 for bash -c
  python3 -I -c '
import os, subprocess, sys, time
env = dict(os.environ, LC_ALL=sys.argv[1])
best = None
for _ in range(3):
    t0 = time.perf_counter()
    subprocess.run(["bash", "-c", ". \"$1\"; _verdict_path_read \"$2\"", "_", sys.argv[3], sys.argv[2]], env=env, check=True)
    dt = time.perf_counter() - t0
    best = dt if best is None else min(best, dt)
print("%.4f" % best)
' "$1" "$2" "$VERDICTS"
}

# N is 300 CJK characters (900 octal escapes on the wire), 4N is 1200.
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
  # shellcheck disable=SC1090
  [ "$(LC_ALL=$loc; . "$VERDICTS"; _verdict_path_read "$wire_n"; [ "$_verdict_path_raw" = "$p_n" ] && echo same)" = same ]
  # shellcheck disable=SC1090,SC2030
  [ "$(LC_ALL=$loc; . "$VERDICTS"; _verdict_path_read "$wire_4n"; [ "$_verdict_path_raw" = "$p_4n" ] && echo same)" = same ]

  t_n=$(decode_seconds "$loc" "$wire_n")
  t_4n=$(decode_seconds "$loc" "$wire_4n")
  # Linear is 4, quadratic 16. Process start-up only pulls the ratio down.
  ratio=$(python3 -I -c 'import sys; print("%.2f" % (float(sys.argv[2]) / float(sys.argv[1])))' "$t_n" "$t_4n")
  printf 't(N)=%s s t(4N)=%s s ratio=%s\n' "$t_n" "$t_4n" "$ratio" >&2
  python3 -I -c 'import sys; sys.exit(0 if float(sys.argv[1]) < 9 else 1)' "$ratio"
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
