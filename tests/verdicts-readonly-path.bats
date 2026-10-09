#!/usr/bin/env bats
# lib/verdicts.sh's verdict_readonly_path path= decoder (Item 1.2): the probe
# prints path= in printf %q form, the verdict reads it back without eval and
# shows the decoded bytes, or the wire form when they hold a control byte. The
# wire values below are the probe's own forms (or forged ones, said so),
# spelled with \$ and \\ in double quotes so the file holds them literally.
# New file: tests/verdicts-readonly.bats sits near the 400-line cap.

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/verdicts

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
  # outside it and show decoded.
  for byte in $'\001' $'\t' $'\033' $'\037' $'\177'; do
    real="/x/a${byte}b/f"
    wire=$(LC_ALL=C printf '%q' "$real")
    [ "${wire#\$\'}" != "$wire" ]
    text=$(path_verdict writable "$wire")
    [ "$(printf '%s\n' "$text" | sed -n '1p')" = "\`$wire\` is writable outside the sandbox, whose allowlist refused it.$(readonly_path_tail)" ] \
      || { printf 'byte %s gave: %s\n' "$wire" "$text" >&2; return 1; }
    [ "$(printf '%s\n' "$text" | sed -n '$=')" = 2 ]
  done
  for byte in $'\200' $'\377'; do
    real="/x/a${byte}b/f"
    wire=$(LC_ALL=C printf '%q' "$real")
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
  for real in "/x/caf${eacute}'s\\n/f" "/x/caf${eacute}\\'s/f" "/x/caf${eacute}'\\/f"; do
    wire=$(LC_ALL=C printf '%q' "$real")
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
  wire=$(LC_ALL=C printf '%q' "/x/\$(touch $sentinel)")
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
  line1=$(path_verdict writable "\$'a\\'\$(touch $sentinel)'" | sed -n '1p')
  [ "$line1" = "\`a'\$(touch $sentinel)\` is writable outside the sandbox, whose allowlist refused it.$(readonly_path_tail)" ]
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
    wire=$(LC_ALL=C printf '%q' "$real")
    line1=$(path_verdict writable "$wire" | sed -n '1p')
    [ "$line1" = "\`$real\` is writable outside the sandbox, whose allowlist refused it.$(readonly_path_tail)" ] \
      || { printf 'wire %s gave: %s\n' "$wire" "$line1" >&2; return 1; }
  done
}

# stubbed_verdict <outcome> <wire> — path_verdict with the stubs made by the
# case first on PATH.
stubbed_verdict() {
  local PATH="$BATS_TEST_TMPDIR/bsd:$PATH"
  path_verdict "$@"
}

@test "readonly-path decodes the same with the BSD stubs first on PATH" {
  local wire plain stubbed eacute=$'\303\251'
  make_bsd_stubs "$BATS_TEST_TMPDIR/bsd" grep sed stat wc
  for wire in '/x/a\ b\&c/f' "\$'/x/caf\\303\\251\\'s/f'" "\$'/x/a\\nb/f'" "\$'a'b"; do
    plain=$(path_verdict writable "$wire")
    [ "$(printf '%s\n' "$plain" | sed -n '$=')" = 2 ]
    stubbed=$(stubbed_verdict writable "$wire")
    [ "$stubbed" = "$plain" ] || { printf 'wire %s differs\n' "$wire" >&2; return 1; }
  done
  # The stubbed run decodes: the equality above holds for an unchanged reader.
  stubbed=$(stubbed_verdict writable "\$'/x/caf\\303\\251\\'s/f'" | sed -n '1p')
  [ "$stubbed" = "\`/x/caf${eacute}'s/f\` is writable outside the sandbox, whose allowlist refused it.$(readonly_path_tail)" ]
  stubbed=$(stubbed_verdict writable '/x/a\ b\&c/f' | sed -n '1p')
  [ "$stubbed" = "\`/x/a b&c/f\` is writable outside the sandbox, whose allowlist refused it.$(readonly_path_tail)" ]
}
