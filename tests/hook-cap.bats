#!/usr/bin/env bats
# Context cap (docs/design.md FR-6): verdicts compose in catalogue order, and
# a paragraph that would push additionalContext past 2 KB (2048 bytes) is
# dropped while its human line is kept on systemMessage regardless. Split
# from hook.bats to keep that file under the 400-line cap (Item 2.3 slice 7).
#
# Every case runs the porcelain+gitadd failure text, whose two paragraphs
# (phantom-untracked, then phantom-gitadd) are the only pair the phantom
# verdicts can emit, with one of them stubbed to a sized paragraph. Each case
# rules out a cap that the others let through: dropping by position, by
# per-paragraph size, the largest paragraph, an off-by-one at the boundary,
# a total that omits the joining newline, a count in characters.

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/hook

setup() {
  hook_copy_tree
}

# stub_paragraph <marker> <total-bytes> — an ASCII paragraph of exactly
# <total-bytes>, opening with <marker> so a test can grep for it without
# depending on the padding's content.
stub_paragraph() {
  local marker="$1" total="$2" pad
  pad=$(printf '%*s' "$((total - ${#marker}))" '' | tr ' ' 'x')
  printf '%s%s' "$marker" "$pad"
}

# byte_count <string> — its length in bytes whatever the locale; the
# arithmetic drops the padding BSD wc puts before the number.
byte_count() {
  echo "$(($(printf '%s' "$1" | LC_ALL=C wc -c)))"
}

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

# verdict_line <name> <n> — line <n> of the real verdict_<name>, read from
# the copied verdicts.sh before any stub is appended to it.
verdict_line() {
  bash -c '. "$1"; "verdict_$2"' _ "$HOOK_COPY/lib/verdicts.sh" "$1" \
    </dev/null | sed -n "${2}p"
}

# cap_run <verdict-fn> <paragraph> <human> — replaces <verdict-fn> in the
# copied verdicts.sh with one printing <paragraph> and <human>, then runs the
# hook on a failure payload whose text concatenates fire-masks-porcelain and
# fire-masks-gitadd-refused. Both matchers are asserted to fire on that text
# first, so no case can pass because a paragraph was never produced. Sets
# $ctx and $sys to the two output strings exactly: -j adds no newline and the
# `x` sentinel stops $(...) from stripping one the value itself ends with.
cap_run() {
  local fn="$1" para="$2" human="$3" porcelain gitadd text payload
  porcelain=$(cat "$FIXTURES/fire-masks-porcelain.txt")
  gitadd=$(cat "$FIXTURES/fire-masks-gitadd-refused.txt")
  text=$(printf '%s\n%s' "$porcelain" "$gitadd")

  printf '%s\n' "$text" | bash -c '. "$1"; match_phantom_untracked' \
    _ "$HOOK_COPY/lib/matchers.sh"
  printf '%s\n' "$text" | bash -c '. "$1"; match_phantom_gitadd' \
    _ "$HOOK_COPY/lib/matchers.sh"

  stub_lib verdicts.sh "$fn() { printf '%s\n' '$para' '$human'; }"
  payload=$(failure_payload "$text")

  run bash -c 'printf "%s" "$1" | bash "$2"' \
    _ "$payload" "$HOOK_COPY/hooks/annotate.sh"
  [ "$status" -eq 0 ]
  ctx=$(printf '%s' "$output" \
    | jq -j '.hookSpecificOutput.additionalContext' && printf x)
  ctx=${ctx%x}
  sys=$(printf '%s' "$output" | jq -j '.systemMessage' && printf x)
  sys=${sys%x}
}

@test "paragraph past 2 KB is dropped, human line kept" {
  local marker='STUBMARKER-GITADD-1900' stub_human='stub — gitadd 1900'
  local untracked_para untracked_human ctx sys
  untracked_para=$(verdict_line phantom_untracked 1)
  untracked_human=$(verdict_line phantom_untracked 2)
  # Empty expectations would match a hook that printed nothing.
  [ -n "$untracked_para" ]
  [ -n "$untracked_human" ]

  cap_run verdict_phantom_gitadd "$(stub_paragraph "$marker" 1900)" \
    "$stub_human"

  [ "$(byte_count "$ctx")" -lt 2048 ]
  # additionalContext holds the untracked paragraph alone: the stub's would
  # push it past 2 KB, so it is the one dropped.
  [ "$ctx" = "$untracked_para" ]
  case "$ctx" in
    *"$marker"*)
      echo "stub paragraph present in additionalContext, should be dropped" >&2
      return 1 ;;
  esac
  # systemMessage keeps both human lines regardless of the drop.
  [ "$sys" = "$untracked_human $stub_human" ]
}

@test "a paragraph bringing the context to exactly 2 KB is kept" {
  # "Past 2 KB" is over 2048 bytes: a context of exactly 2048, the join
  # newline counted, keeps both paragraphs. Fails a cap that drops the
  # second or any stubbed paragraph, one over 400 bytes, one at 2048 bytes
  # (-ge for -gt) or one at 2000.
  local marker='STUBMARKER-GITADD-FILL' stub_human='stub — gitadd fill'
  local untracked_para untracked_human stub_para ctx sys
  untracked_para=$(verdict_line phantom_untracked 1)
  untracked_human=$(verdict_line phantom_untracked 2)
  [ -n "$untracked_para" ]
  [ -n "$untracked_human" ]
  stub_para=$(stub_paragraph "$marker" \
    "$((2048 - $(byte_count "$untracked_para") - 1))")

  cap_run verdict_phantom_gitadd "$stub_para" "$stub_human"

  [ "$ctx" = "$untracked_para"$'\n'"$stub_para" ]
  [ "$(byte_count "$ctx")" -eq 2048 ]
  [ "$sys" = "$untracked_human $stub_human" ]
}

@test "the paragraph that crosses 2 KB is dropped, not the largest" {
  # The big paragraph comes first in catalogue order here (a stubbed
  # untracked), and the real gitadd paragraph after it brings the context to
  # 2049 bytes: gitadd is the one that would push it past, so gitadd goes.
  # Fails a cap that drops the largest paragraph, one over 400 bytes, or one
  # whose running total omits the join newline (2048 without it).
  local marker='STUBMARKER-UNTRACKED-BIG' stub_human='stub — untracked big'
  local gitadd_para gitadd_human stub_para ctx sys
  gitadd_para=$(verdict_line phantom_gitadd 1)
  gitadd_human=$(verdict_line phantom_gitadd 2)
  [ -n "$gitadd_para" ]
  [ -n "$gitadd_human" ]
  stub_para=$(stub_paragraph "$marker" \
    "$((2048 - $(byte_count "$gitadd_para")))")

  cap_run verdict_phantom_untracked "$stub_para" "$stub_human"

  [ "$ctx" = "$stub_para" ]
  [ "$sys" = "$stub_human $gitadd_human" ]
}

@test "the 2 KB cap counts bytes, not characters" {
  # A stub gitadd paragraph of 1600 characters, 400 of them three-byte em
  # dashes: the context is 1970 characters but 2770 bytes, so the stub goes.
  # The hook runs under a UTF-8 locale, where bash's ${#var} counts
  # characters; a cap counting that way keeps the stub.
  local marker='STUBMARKER-GITADD-UTF8' stub_human='stub — gitadd utf8'
  local loc untracked_para untracked_human dashes pad stub_para ctx sys
  loc=$(utf8_locale)
  untracked_para=$(verdict_line phantom_untracked 1)
  untracked_human=$(verdict_line phantom_untracked 2)
  [ -n "$untracked_para" ]
  [ -n "$untracked_human" ]
  dashes=$(printf '%*s' 400 '')
  pad=$(printf '%*s' "$((1600 - 400 - ${#marker}))" '' | tr ' ' 'x')
  stub_para="$marker${dashes// /—}$pad"
  # The fixture straddles the cap: under it in characters, over it in bytes.
  [ "$(($(printf '%s\n%s' "$untracked_para" "$stub_para" \
    | LC_ALL="$loc" wc -m)))" -le 2048 ]
  [ "$(byte_count "$untracked_para"$'\n'"$stub_para")" -gt 2048 ]

  LC_ALL="$loc" cap_run verdict_phantom_gitadd "$stub_para" "$stub_human"

  [ "$ctx" = "$untracked_para" ]
  [ "$sys" = "$untracked_human $stub_human" ]
}
