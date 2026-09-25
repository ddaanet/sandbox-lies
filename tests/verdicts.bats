#!/usr/bin/env bats
# lib/verdicts.sh: verdict_<name> [outcome] -> agent paragraph (line 1),
# human line (line 2). A name/outcome row table, one row per verdict and
# outcome (`-` for none), extended by Items 4.1, 4.2 and 6.1.

ROOT="${BATS_TEST_DIRNAME}/.."
VERDICTS="$ROOT/lib/verdicts.sh"
MATCHERS="$ROOT/lib/matchers.sh"

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs

# name outcome — `-` for a phantom verdict, which takes no outcome.
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
config_lock mask
config_lock gone
config_lock held
config_lock orphan
config_lock unknown
ROWS
}

# verdict_text <name> <outcome> — the two-line text a case checks. Stdin is
# empty, as for a verdict with no probe; left inherited, a verdict reading its
# probe lines would swallow the rest of the row table from the caller's loop.
verdict_text() {
  local name="$1" outcome="$2"
  if [ "$outcome" = "-" ]; then
    # shellcheck disable=SC1090 # $VERDICTS is lib/verdicts.sh, resolved above
    ( . "$VERDICTS"; "verdict_$name" ) </dev/null
  else
    # shellcheck disable=SC1090
    ( . "$VERDICTS"; "verdict_$name" "$outcome" ) </dev/null
  fi
}

# all_verdict_text — every row's text concatenated, one call per row. A row
# whose verdict fails fails the whole call: this runs inside a command
# substitution, where errexit does not reach.
all_verdict_text() {
  local name outcome text all=""
  while read -r name outcome; do
    [ -n "$name" ] || continue
    text=$(verdict_text "$name" "$outcome") || return 1
    all="$all
$text"
  done < <(rows)
  printf '%s' "$all"
}

@test "verdicts under 400 chars" {
  local name outcome text line1 line2 defined rowed
  # "Every row" means every verdict only if no verdict function lacks a row.
  defined=$(bash -c '. "$1" && declare -F' _ "$VERDICTS" \
    | awk '$3 ~ /^verdict_/ { sub(/^verdict_/, "", $3); print $3 }' | sort -u)
  rowed=$(rows | awk 'NF { print $1 }' | sort -u)
  [ -n "$defined" ]
  [ "$defined" = "$rowed" ]
  while read -r name outcome; do
    [ -n "$name" ] || continue
    text=$(verdict_text "$name" "$outcome")
    # Exactly two lines, both non-empty: an empty verdict or paragraph must
    # fail here, not slip through as vacuously short.
    [ "$(printf '%s\n' "$text" | awk 'END { print NR }')" -eq 2 ]
    line1=$(printf '%s\n' "$text" | sed -n '1p')
    line2=$(printf '%s\n' "$text" | sed -n '2p')
    [ -n "$line1" ]
    [ "${#line1}" -lt 400 ]
    printf '%s' "$line2" | grep -qF -- ' — '
  done < <(rows)
}

@test "verdict text is quiet" {
  local all
  all=$(all_verdict_text)
  # An empty verdict set must fail here, not read as trivially quiet.
  [ -n "$(printf '%s' "$all" | tr -d '[:space:]')" ]
  run bash -c 'printf "%s\n" "$1" | bash "$2"' _ "$all" "$MATCHERS"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "verdict text matches detectors.md" {
  # Transcribed from docs/references/detectors.md's Verdict paragraphs, not
  # copied from lib/verdicts.sh: a mismatch between the two must red here.
  # The phantom-untracked paragraph is documented there as "As
  # `phantom-chardev`, with: <addition>" — the chardev paragraph plus the
  # addition, not that sentence transcribed literally.
  local chardev_para addition line1 line2
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  chardev_para='The character-device entries in this listing are sandbox masks over dotfiles in the project root, not files in the repository. Leave them out of every add, delete and report. With no sandboxed command running in the background, `ls -a` and `git status` run unsandboxed show the real tree.'
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  addition='A cleanliness check that reads these `??` lines as dirty is reading the sandbox, not the tree.'

  line1=$(verdict_text phantom_chardev - | sed -n '1p')
  line2=$(verdict_text phantom_chardev - | sed -n '2p')
  [ "$line1" = "$chardev_para" ]
  [ "$line2" = 'phantom dotfiles — sandbox masks in listing' ]

  line1=$(verdict_text phantom_untracked - | sed -n '1p')
  line2=$(verdict_text phantom_untracked - | sed -n '2p')
  [ "$line1" = "${chardev_para} ${addition}" ]
  [ "$line2" = 'phantom dotfiles — masks listed as untracked' ]

  line1=$(verdict_text phantom_gitadd - | sed -n '1p')
  line2=$(verdict_text phantom_gitadd - | sed -n '2p')
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$line1" = '`git add` aborted on a sandbox mask, not a file. Stage explicit paths, or re-run the same command unsandboxed.' ]
  [ "$line2" = 'git add — refused a sandbox mask' ]
}

@test "lock verdict text matches lock-detectors.md" {
  # Transcribed from docs/references/lock-detectors.md's git-lock and
  # config-lock Verdicts lists — mask and gone only; held/orphan/unknown
  # interpolate probe values and are checked in slices 2 and 3.
  local line1 line2

  line1=$(verdict_text git_lock mask | sed -n '1p')
  line2=$(verdict_text git_lock mask | sed -n '2p')
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$line1" = 'The lock in this error is a sandbox artefact and the repository is healthy. Re-run the same command with `dangerouslyDisableSandbox: true`; if it already ran that way, re-run it once no sandboxed command is running. A repeat failure on a commit whose hook stages files is that hook leaking `GIT_INDEX_FILE`, not the sandbox.' ]
  [ "$line2" = 'index.lock — sandbox mask, not a real lock' ]

  line1=$(verdict_text git_lock gone | sed -n '1p')
  line2=$(verdict_text git_lock gone | sed -n '2p')
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$line1" = 'No lock exists now; git cleaned it after the failure. Retry once. A repeat failure on a commit whose hook stages files is that hook leaking `GIT_INDEX_FILE`, not the sandbox.' ]
  [ "$line2" = 'index.lock — cleared after failure' ]

  line1=$(verdict_text config_lock mask | sed -n '1p')
  line2=$(verdict_text config_lock mask | sed -n '2p')
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$line1" = 'The lock in this error is a sandbox artefact and the repository is healthy. Re-run the same command with `dangerouslyDisableSandbox: true`; if it already ran that way, re-run it once no sandboxed command is running. Run the `git config` or `git remote` write unsandboxed, or through the `update-config` skill when the target is `.claude/settings.json`.' ]
  [ "$line2" = 'config.lock — sandbox mask, not a real lock' ]

  line1=$(verdict_text config_lock gone | sed -n '1p')
  line2=$(verdict_text config_lock gone | sed -n '2p')
  [ "$line1" = 'No lock exists now; git cleaned it after the failure. Retry once.' ]
  [ "$line2" = 'config.lock — cleared after failure' ]
}

@test "no removal instruction" {
  local all stripped phrase
  all=$(all_verdict_text)
  # An empty verdict set must fail here, not read as vacuously clean.
  [ -n "$(printf '%s' "$all" | tr -d '[:space:]')" ]
  # D-7: the one sanctioned "delete" (detectors.md's phantom-chardev
  # verdict, "every add, delete and report") is stripped before checking.
  phrase="add, delete and report"
  stripped=$(printf '%s' "$all" | sed "s/${phrase}//g")
  # `rm ` only as a word: "confirm " and "form " are not instructions. Status
  # 1 exactly, so a grep that errored cannot read as "no match".
  run bash -c 'printf "%s" "$1" | grep -qiE "(^|[^[:alpha:]])rm |remove|delete"' \
    _ "$stripped"
  [ "$status" -eq 1 ]
}
