#!/usr/bin/env bats
# shellcheck disable=SC2218 # bats sources the whole file before any @test runs
# lib/verdicts.sh's config-lock mask verdict, its closing sentence: the rm it
# hands the user for a lock that refuses the re-run, by what the path holds.
# The paragraph's other sentences are in verdicts-locks.bats.

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/verdicts

@test "config-lock mask hands a lock refused again to the user as an rm" {
  # The user pastes the rm into their own shell, so the path is in single
  # quotes, where a blank and a `$` are literal in bash, zsh, dash and fish
  # alike. Line 1 stays under FR-6's 400 characters before the path.
  local flag line1 path="/r/a b/\$HOME/.git/config.lock"
  # shellcheck disable=SC2016 # backticks and $HOME are literal text
  for flag in false true; do
    line1=$(config_lock_mask_line1 '/r/a\ b/\$HOME/.git/config.lock' "$flag")
    [ "If it refuses again${line1##*If it refuses again}" = 'If it refuses again, leave it and tell the user it may be left over from a sandbox that died uncleanly, giving them `rm '\''/r/a b/$HOME/.git/config.lock'\''` to run once they have checked no sandboxed command is running in any session.' ]
    line1=${line1/"$path"/}
    [ "${#line1}" -lt 400 ]
  done
}

@test "config-lock mask prints no rm for a path outside plain printable ASCII" {
  # The rm is printed only for a path of printable ASCII bytes with no single
  # quote, backslash or backtick. Each path= value below, like no path= at
  # all, keeps the report-and-leave sentence: non-ASCII, a byte that is not
  # valid UTF-8, a backtick, a single quote, a backslash, a newline and DEL.
  local flag wire line1 n
  for flag in false true; do
    n=0
    while IFS= read -r wire; do
      line1=$(config_lock_mask_line1 "$wire" "$flag")
      [ "If it refuses again${line1##*If it refuses again}" = 'If it refuses again, it is a real file: report its path to the user and leave it in place.' ]
      n=$((n + 1))
    done <<'CASES'
/r/Dév/.git/config.lock
$'/r/caf\351/.git/config.lock'
/r/a\`b/.git/config.lock
/r/it\'s/.git/config.lock
/r/a\\b/.git/config.lock
$'/r/a\nb/.git/config.lock'
$'/r/a\177b/.git/config.lock'
CASES
    # A loop that read no case would have asserted nothing.
    [ "$n" -eq 7 ]
  done
}

# config_lock_mask_line1 <wire> <flag> — the agent paragraph of
# verdict_config_lock mask for a probe line path=<wire>.
config_lock_mask_line1() {
  local line1
  # shellcheck disable=SC1090 # $VERDICTS is lib/verdicts.sh, from the helper
  IFS= read -r line1 < <(printf 'path=%s\n' "$1" \
    | ( . "$VERDICTS"; verdict_config_lock mask "$2" ))
  printf '%s\n' "$line1"
}
