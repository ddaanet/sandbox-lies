#!/usr/bin/env bash
# Shared by tests/verdicts.bats and tests/verdicts-locks.bats: lib/verdicts.sh:
# verdict_<name> [outcome] -> agent paragraph (line 1), human line (line 2). A
# name/outcome row table, one row per verdict and outcome (`-` for none),
# extended by Items 4.1, 4.2 and 6.1.

ROOT="${BATS_TEST_DIRNAME}/.."
VERDICTS="$ROOT/lib/verdicts.sh"
# shellcheck disable=SC2034 # read by the loading suite, not here
MATCHERS="$ROOT/lib/matchers.sh"

# name outcome [flag] — `-` for a phantom verdict, which takes no outcome. A
# third field is the flag verdict_git_lock/verdict_config_lock take as $2
# (D-17); its absence, as for every other row, calls the verdict with no
# second argument rather than an empty string, so the row exercises the
# documented "absent reads false" default instead of an explicit "false".
rows() {
  cat <<'ROWS'
phantom_chardev -
phantom_untracked -
phantom_gitadd -
git_lock mask
git_lock gone
git_lock held
git_lock orphan
git_lock unknown
git_lock mask true
git_lock orphan true
git_lock unknown true
config_lock mask
config_lock gone
config_lock held
config_lock orphan
config_lock unknown
config_lock mask true
config_lock orphan true
config_lock unknown true
tmpdir_unset -
resume_lost lost
resume_lost found
seccomp_init -
readonly_path writable
readonly_path readonly
readonly_path nopath
ROWS
}

# verdict_text <name> <outcome> [flag] — the two-line text a case checks.
# Stdin is empty, as for a verdict with no probe; left inherited, a verdict
# reading its probe lines would swallow the rest of the row table from the
# caller's loop. [flag], when given, is passed as the verdict's $2, alongside
# <outcome> as $1; omitted (empty, or the rows() sentinel `-`), the verdict is
# called with <outcome> alone, exercising its documented default.
verdict_text() {
  local name="$1" outcome="$2" flag="${3:-}"
  if [ "$outcome" = "-" ]; then
    # shellcheck disable=SC1090 # $VERDICTS is lib/verdicts.sh, resolved above
    ( . "$VERDICTS"; "verdict_$name" ) </dev/null
  elif [ -z "$flag" ] || [ "$flag" = "-" ]; then
    # shellcheck disable=SC1090
    ( . "$VERDICTS"; "verdict_$name" "$outcome" ) </dev/null
  else
    # shellcheck disable=SC1090
    ( . "$VERDICTS"; "verdict_$name" "$outcome" "$flag" ) </dev/null
  fi
}

# all_verdict_text — every row's text concatenated, one call per row. A row
# whose verdict fails fails the whole call: this runs inside a command
# substitution, where errexit does not reach.
all_verdict_text() {
  local name outcome flag text all=""
  while read -r name outcome flag; do
    [ -n "$name" ] || continue
    text=$(verdict_text "$name" "$outcome" "$flag") || return 1
    all="$all
$text"
  done < <(rows)
  printf '%s' "$all"
}

# text_lacks <haystack> <pattern> — <pattern> (fixed string) must not occur in
# <haystack>; a grep exit other than 1 (found, or errored) fails the assertion
# rather than reading as absence, as tests/hook-locks.bats's assert_lacks has
# it.
text_lacks() {
  run bash -c 'printf "%s" "$1" | grep -qF -- "$2"' _ "$1" "$2"
  # shellcheck disable=SC2154 # set by bats' run
  [ "$status" -eq 1 ]
}

# readonly_path_tail — readonly-path.md's readonly-path tail with no facts on
# stdin: the act alone (no readfile=, path= settings.json, or merge=1), which
# is the whole-call re-run, capitalised and leading with a blank, as the
# writable and nopath paragraphs both open onto it. The fact-driven
# compositions (readfile=, the update-config act, the merge clauses) live in
# tests/verdicts-readonly.bats.
readonly_path_tail() {
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  printf '%s' ' Re-run the whole call with `dangerouslyDisableSandbox: true`.'
}
