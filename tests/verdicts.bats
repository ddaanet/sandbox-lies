#!/usr/bin/env bats
# lib/verdicts.sh: verdict_<name> [outcome] -> agent paragraph (line 1),
# human line (line 2). A name/outcome row table, one row per verdict and
# outcome (`-` for none), extended by Items 4.1, 4.2 and 6.1.

ROOT="${BATS_TEST_DIRNAME}/.."
VERDICTS="$ROOT/lib/verdicts.sh"
MATCHERS="$ROOT/lib/matchers.sh"

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs

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
resume_lost -
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
  [ "$status" -eq 1 ]
}

# readonly_path_tail — detectors.md's readonly-path `writable`
# paragraph from "If a merge" on, leading blank included: the writable
# paragraph's tail, and the rest of the nopath paragraph, which the doc
# defines as its opening sentence "then the `writable` paragraph from
# `If a merge` on".
readonly_path_tail() {
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  printf '%s' ' If a merge or checkout died, files it wrote sit at the target, HEAD unmoved, blocking a re-run: restore them from HEAD once they match the target. Then re-run the whole call unsandboxed or, if it only read a command-output file (a `*.log`), the command that wrote it. For `.claude/settings.json`, use the `update-config` skill.'
}

@test "verdicts under 400 chars" {
  local name outcome flag text line1 line2 defined rowed
  # "Every row" means every verdict only if no verdict function lacks a row.
  defined=$(bash -c '. "$1" && declare -F' _ "$VERDICTS" \
    | awk '$3 ~ /^verdict_/ { sub(/^verdict_/, "", $3); print $3 }' | sort -u)
  rowed=$(rows | awk 'NF { print $1 }' | sort -u)
  [ -n "$defined" ]
  [ "$defined" = "$rowed" ]
  while read -r name outcome flag; do
    [ -n "$name" ] || continue
    text=$(verdict_text "$name" "$outcome" "$flag")
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
  # `phantom-chardev`, opening "The dotfile entries", with: <addition>" —
  # the chardev paragraph under that subject plus the addition, not that
  # sentence transcribed literally.
  local chardev_para untracked_para addition line1 line2
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
  untracked_para=${chardev_para/#The character-device entries/The dotfile entries}
  [ "$untracked_para" != "$chardev_para" ]
  [ "$line1" = "${untracked_para} ${addition}" ]
  [ "$line2" = 'phantom dotfiles — masks listed as untracked' ]

  line1=$(verdict_text phantom_gitadd - | sed -n '1p')
  line2=$(verdict_text phantom_gitadd - | sed -n '2p')
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$line1" = '`git add` aborted on a sandbox mask, not a file. Stage explicit paths, or re-run the same command unsandboxed.' ]
  [ "$line2" = 'git add — refused a sandbox mask' ]
}

@test "candidate verdict text matches detectors.md" {
  # Transcribed from docs/references/detectors.md's tmpdir-unset, resume-lost
  # and seccomp-init Verdict paragraphs, not copied from lib/verdicts.sh.
  local line1 line2

  line1=$(verdict_text tmpdir_unset - | sed -n '1p')
  line2=$(verdict_text tmpdir_unset - | sed -n '2p')
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$line1" = '`$TMPDIR` expanded empty in this unsandboxed call, so the path collapsed to `/`. Use the literal scratch path `/tmp/claude/<job>` (create it with `mkdir -p`) in this and every unsandboxed or delegated command.' ]
  # shellcheck disable=SC2016 # $TMPDIR is literal prose, not expansion
  [ "$line2" = '$TMPDIR — expanded empty, path collapsed to /' ]

  line1=$(verdict_text resume_lost - | sed -n '1p')
  line2=$(verdict_text resume_lost - | sed -n '2p')
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$line1" = 'The transcript was never written: `~/.claude/projects` is read-only inside the sandbox. Run the entire multi-turn flow in one unsandboxed call.' ]
  [ "$line2" = '--resume — transcript not persisted in sandbox' ]

  line1=$(verdict_text seccomp_init - | sed -n '1p')
  line2=$(verdict_text seccomp_init - | sed -n '2p')
  [ "$line1" = 'The sandbox failed to initialise before the command ran; this is transient. Retry the identical command once; if it fails the same way, split it into smaller calls. Escape the sandbox only after both.' ]
  [ "$line2" = 'sandbox init failed — transient, retry' ]
}

@test "readonly-path writable verdict text matches detectors.md" {
  # Transcribed from docs/references/detectors.md's readonly-path Verdicts
  # list, <path> substituted by the probe's path= stdin line. The path holds
  # a blank and the characters a sed replacement or an eval would act on, as
  # an extracted path may. The path renders in backticks, as the doc writes
  # the placeholder; with no path= line it is "The path".
  local p rest text line1 line2
  p='/r/a b&c\1/x'
  rest=" is writable outside the sandbox, whose allowlist refused it.$(readonly_path_tail)"
  # shellcheck disable=SC1090 # $VERDICTS is lib/verdicts.sh, resolved above
  text=$(printf '%s\n' "path=$p" | ( . "$VERDICTS"; verdict_readonly_path writable ))
  line1=$(printf '%s\n' "$text" | sed -n '1p')
  line2=$(printf '%s\n' "$text" | sed -n '2p')
  [ "$line1" = "\`$p\`$rest" ]
  [ "$line2" = 'read-only — sandbox allowlist, writable outside' ]

  line1=$(verdict_text readonly_path writable | sed -n '1p')
  [ "$line1" = "The path$rest" ]
}

@test "readonly-path readonly verdict text matches detectors.md" {
  # Transcribed from docs/references/detectors.md's readonly-path Verdicts
  # list, <path> interpolated in backticks as the writable case does, and
  # "The path" with no path= line (outside the probe contract, as the
  # row-driven cases call it), so no subjectless sentence.
  local p text line1 line2
  p='/r/a b&c\1/x'

  # shellcheck disable=SC1090 # $VERDICTS is lib/verdicts.sh, resolved above
  text=$(printf '%s\n' "path=$p" | ( . "$VERDICTS"; verdict_readonly_path readonly ))
  line1=$(printf '%s\n' "$text" | sed -n '1p')
  line2=$(printf '%s\n' "$text" | sed -n '2p')
  [ "$line1" = "\`$p\` is not writable outside the sandbox either; this is not a sandbox effect. Unsandboxing will not help: write somewhere writable, or ask before changing its permissions." ]
  [ "$line2" = 'read-only — real' ]

  line1=$(verdict_text readonly_path readonly | sed -n '1p')
  [ "$line1" = 'The path is not writable outside the sandbox either; this is not a sandbox effect. Unsandboxing will not help: write somewhere writable, or ask before changing its permissions.' ]
}

@test "readonly-path nopath verdict text matches detectors.md" {
  # Transcribed from docs/references/detectors.md's readonly-path Verdicts
  # list: nopath's opening sentence, then the writable paragraph from
  # "If a merge" on, as the doc defines it. No path= line: the probe contract
  # gives none for nopath.
  local line1 line2
  line1=$(verdict_text readonly_path nopath | sed -n '1p')
  line2=$(verdict_text readonly_path nopath | sed -n '2p')
  [ "$line1" = "The sandbox's write allowlist most likely refused this write.$(readonly_path_tail)" ]
  [ "$line2" = 'read-only — probably the sandbox, path not checked' ]
}

@test "lock verdict text matches lock-detectors.md" {
  # Transcribed from docs/references/lock-detectors.md's git-lock and
  # config-lock Verdicts lists — mask (both flag values, D-17) and gone
  # (flag-neutral) here; held/orphan/unknown interpolate probe values and are
  # checked in the dedicated interpolation tests below. mask's *Re-run* wording
  # comes from the *Re-run*/*Retry* flag table and never carries the old
  # flag-neutral "if it already ran" clause this replaces.
  local line1 line2

  line1=$(verdict_text git_lock mask false | sed -n '1p')
  line2=$(verdict_text git_lock mask false | sed -n '2p')
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$line1" = 'The lock in this error is a sandbox artefact and the repository is healthy. Re-run the same command with `dangerouslyDisableSandbox: true`. A repeat failure on a commit whose hook stages files is that hook leaking `GIT_INDEX_FILE`, not the sandbox.' ]
  [ "$line2" = 'index.lock — sandbox mask, not a real lock' ]

  line1=$(verdict_text git_lock mask true | sed -n '1p')
  line2=$(verdict_text git_lock mask true | sed -n '2p')
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$line1" = 'The lock in this error is a sandbox artefact and the repository is healthy. Re-run the same command once no sandboxed command is running. A repeat failure on a commit whose hook stages files is that hook leaking `GIT_INDEX_FILE`, not the sandbox.' ]
  [ "$line2" = 'index.lock — sandbox mask, not a real lock' ]

  # Absent $2 reads false (D-17).
  [ "$(verdict_text git_lock mask - | sed -n '1p')" = "$(verdict_text git_lock mask false | sed -n '1p')" ]

  line1=$(verdict_text git_lock gone | sed -n '1p')
  line2=$(verdict_text git_lock gone | sed -n '2p')
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$line1" = 'No lock exists now; git cleaned it after the failure. Retry once. A repeat failure on a commit whose hook stages files is that hook leaking `GIT_INDEX_FILE`, not the sandbox.' ]
  [ "$line2" = 'index.lock — cleared after failure' ]

  line1=$(verdict_text config_lock mask false | sed -n '1p')
  line2=$(verdict_text config_lock mask false | sed -n '2p')
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$line1" = 'The `config.lock` behind this error is a sandbox artefact and the repository is healthy. Re-run the same command with `dangerouslyDisableSandbox: true`.' ]
  [ "$line2" = 'config.lock — sandbox mask, not a real lock' ]

  line1=$(verdict_text config_lock mask true | sed -n '1p')
  line2=$(verdict_text config_lock mask true | sed -n '2p')
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$line1" = 'The `config.lock` behind this error is a sandbox artefact and the repository is healthy. Re-run the same command once no sandboxed command is running.' ]
  [ "$line2" = 'config.lock — sandbox mask, not a real lock' ]

  # The config-lock settings act: a `.claude/settings.json.lock` path
  # replaces *Re-run* with the update-config act, under either flag.
  local settings_text
  # shellcheck disable=SC1090 # $VERDICTS is lib/verdicts.sh, resolved above
  settings_text=$(printf '%s\n' 'path=/r/.claude/settings.json.lock' \
    | ( . "$VERDICTS"; verdict_config_lock mask false ))
  line1=$(printf '%s\n' "$settings_text" | sed -n '1p')
  line2=$(printf '%s\n' "$settings_text" | sed -n '2p')
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$line1" = 'The `config.lock` behind this error is a sandbox artefact and the repository is healthy. Write `.claude/settings.json` through the `update-config` skill.' ]
  [ "$line2" = 'config.lock — sandbox mask, not a real lock' ]

  # shellcheck disable=SC1090
  settings_text=$(printf '%s\n' 'path=/r/.claude/settings.json.lock' \
    | ( . "$VERDICTS"; verdict_config_lock mask true ))
  line1=$(printf '%s\n' "$settings_text" | sed -n '1p')
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$line1" = 'The `config.lock` behind this error is a sandbox artefact and the repository is healthy. Write `.claude/settings.json` through the `update-config` skill.' ]

  line1=$(verdict_text config_lock gone | sed -n '1p')
  line2=$(verdict_text config_lock gone | sed -n '2p')
  [ "$line1" = 'No lock exists now; git cleaned it after the failure. Retry once.' ]
  [ "$line2" = 'config.lock — cleared after failure' ]
}

@test "verdict_git_lock held|orphan|unknown interpolate probe values" {
  # Transcribed from lock-detectors.md's git-lock Verdicts list with the N
  # placeholders substituted by the probe's key=value stdin lines. The lines
  # are keyed, not positional: they arrive here out of the probe's own order,
  # after a path= line holding digits, spaces and sed/eval metacharacters.
  # orphan and unknown's *Retry* clause is worded by the flag (D-17), as
  # mask's *Re-run* is; held ignores the flag.
  local path_line text line1 line2
  path_line='path=/tmp/lock 99/a&b\1/.git/index.lock'

  # shellcheck disable=SC1090 # $VERDICTS is lib/verdicts.sh, resolved above
  text=$(printf '%s\n' "$path_line" 'pid=4242' | ( . "$VERDICTS"; verdict_git_lock held ))
  line1=$(printf '%s\n' "$text" | sed -n '1p')
  line2=$(printf '%s\n' "$text" | sed -n '2p')
  [ "$line1" = 'A process (pid 4242) holds the lock. Wait for it, then retry.' ]
  [ "$line2" = 'index.lock — held by pid 4242' ]

  # shellcheck disable=SC1090
  text=$(printf '%s\n' 'age=12' "$path_line" 'bytes=7' | ( . "$VERDICTS"; verdict_git_lock orphan false ))
  line1=$(printf '%s\n' "$text" | sed -n '1p')
  line2=$(printf '%s\n' "$text" | sed -n '2p')
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$line1" = 'The lock exists outside the sandbox (7 bytes, age 12s) and no process holds it. Retry the command with `dangerouslyDisableSandbox: true`; a second identical failure means the lock predates this session.' ]
  [ "$line2" = 'index.lock — present, no holder' ]

  # shellcheck disable=SC1090
  text=$(printf '%s\n' 'age=12' "$path_line" 'bytes=7' | ( . "$VERDICTS"; verdict_git_lock orphan true ))
  line1=$(printf '%s\n' "$text" | sed -n '1p')
  line2=$(printf '%s\n' "$text" | sed -n '2p')
  [ "$line1" = 'The lock exists outside the sandbox (7 bytes, age 12s) and no process holds it. Retry the command once; a second identical failure means the lock predates this session.' ]
  [ "$line2" = 'index.lock — present, no holder' ]

  # shellcheck disable=SC1090
  text=$(printf '%s\n' 'age=12' "$path_line" 'bytes=7' | ( . "$VERDICTS"; verdict_git_lock unknown false ))
  line1=$(printf '%s\n' "$text" | sed -n '1p')
  line2=$(printf '%s\n' "$text" | sed -n '2p')
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$line1" = 'The lock exists outside the sandbox (7 bytes, age 12s); no holder check is available here. Retry the command with `dangerouslyDisableSandbox: true`.' ]
  [ "$line2" = 'index.lock — present, holder unknown' ]

  # shellcheck disable=SC1090
  text=$(printf '%s\n' 'age=12' "$path_line" 'bytes=7' | ( . "$VERDICTS"; verdict_git_lock unknown true ))
  line1=$(printf '%s\n' "$text" | sed -n '1p')
  line2=$(printf '%s\n' "$text" | sed -n '2p')
  [ "$line1" = 'The lock exists outside the sandbox (7 bytes, age 12s); no holder check is available here. Retry the command once.' ]
  [ "$line2" = 'index.lock — present, holder unknown' ]
}

@test "verdict_config_lock held|orphan|unknown interpolate probe values" {
  # Transcribed from lock-detectors.md's config-lock Verdicts list, N
  # substituted as for git-lock, from lines in the probe's own order.
  # orphan and unknown's *Retry* clause is worded by the flag (D-17), as for
  # git-lock; held ignores the flag.
  local path_line text line1 line2
  path_line='path=/tmp/lock 99/a&b\1/.git/config.lock'

  # shellcheck disable=SC1090 # $VERDICTS is lib/verdicts.sh, resolved above
  text=$(printf '%s\n' 'pid=4242' "$path_line" | ( . "$VERDICTS"; verdict_config_lock held ))
  line1=$(printf '%s\n' "$text" | sed -n '1p')
  line2=$(printf '%s\n' "$text" | sed -n '2p')
  [ "$line1" = 'A process (pid 4242) holds the lock. Wait for it, then retry.' ]
  [ "$line2" = 'config.lock — held by pid 4242' ]

  # shellcheck disable=SC1090
  text=$(printf '%s\n' 'bytes=7' 'age=12' "$path_line" | ( . "$VERDICTS"; verdict_config_lock orphan false ))
  line1=$(printf '%s\n' "$text" | sed -n '1p')
  line2=$(printf '%s\n' "$text" | sed -n '2p')
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$line1" = 'The lock exists outside the sandbox (7 bytes, age 12s) and no process holds it. Retry the command with `dangerouslyDisableSandbox: true`; a second identical failure means the lock predates this session.' ]
  [ "$line2" = 'config.lock — present, no holder' ]

  # shellcheck disable=SC1090
  text=$(printf '%s\n' 'bytes=7' 'age=12' "$path_line" | ( . "$VERDICTS"; verdict_config_lock orphan true ))
  line1=$(printf '%s\n' "$text" | sed -n '1p')
  line2=$(printf '%s\n' "$text" | sed -n '2p')
  [ "$line1" = 'The lock exists outside the sandbox (7 bytes, age 12s) and no process holds it. Retry the command once; a second identical failure means the lock predates this session.' ]
  [ "$line2" = 'config.lock — present, no holder' ]

  # shellcheck disable=SC1090
  text=$(printf '%s\n' 'bytes=7' 'age=12' "$path_line" | ( . "$VERDICTS"; verdict_config_lock unknown false ))
  line1=$(printf '%s\n' "$text" | sed -n '1p')
  line2=$(printf '%s\n' "$text" | sed -n '2p')
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$line1" = 'The lock exists outside the sandbox (7 bytes, age 12s); no holder check is available here. Retry the command with `dangerouslyDisableSandbox: true`.' ]
  [ "$line2" = 'config.lock — present, holder unknown' ]

  # shellcheck disable=SC1090
  text=$(printf '%s\n' 'bytes=7' 'age=12' "$path_line" | ( . "$VERDICTS"; verdict_config_lock unknown true ))
  line1=$(printf '%s\n' "$text" | sed -n '1p')
  line2=$(printf '%s\n' "$text" | sed -n '2p')
  [ "$line1" = 'The lock exists outside the sandbox (7 bytes, age 12s); no holder check is available here. Retry the command once.' ]
  [ "$line2" = 'config.lock — present, holder unknown' ]
}

@test "lock verdicts word the re-run by the flag" {
  # D-17: verdict_git_lock and verdict_config_lock take the flag as $2
  # (absent reads false). mask, orphan and unknown word their re-run/retry
  # clause by it — the dangerouslyDisableSandbox wording under false; under
  # true, mask's *Re-run* "once no sandboxed command is running" and
  # orphan/unknown's *Retry* "Retry the command once" (lock-detectors.md's
  # flag table) — and neither flag value carries the old flag-neutral "if it
  # already ran" clause this replaces.
  local name outcome text true_wording

  for name in git_lock config_lock; do
    for outcome in mask orphan unknown; do
      text=$(verdict_text "$name" "$outcome" false)
      printf '%s' "$text" | grep -qF 'dangerouslyDisableSandbox: true'
      text_lacks "$text" 'once no sandboxed'
      text_lacks "$text" 'if it already ran'

      # Absent $2 reads false: the same text as the explicit false just
      # checked non-empty and flag-worded above.
      [ "$(verdict_text "$name" "$outcome" -)" = "$text" ]

      if [ "$outcome" = mask ]; then
        true_wording='Re-run the same command once no sandboxed command is running'
      else
        true_wording='Retry the command once'
      fi
      text=$(verdict_text "$name" "$outcome" true)
      printf '%s' "$text" | grep -qF "$true_wording"
      text_lacks "$text" 'dangerouslyDisableSandbox: true'
      text_lacks "$text" 'if it already ran'
    done
  done

  # The config-lock settings act: a `.claude/settings.json.lock` path
  # replaces *Re-run* with the update-config act, under either flag; any
  # other path (e.g. `.git/config.lock`) keeps *Re-run* and never mentions
  # update-config.
  local flag
  for flag in false true; do
    # shellcheck disable=SC1090 # $VERDICTS is lib/verdicts.sh, resolved above
    text=$(printf '%s\n' 'path=/r/.claude/settings.json.lock' \
      | ( . "$VERDICTS"; verdict_config_lock mask "$flag" ))
    printf '%s' "$text" | grep -qF 'update-config'
    text_lacks "$text" 'Re-run'

    # shellcheck disable=SC1090
    text=$(printf '%s\n' 'path=/r/.git/config.lock' \
      | ( . "$VERDICTS"; verdict_config_lock mask "$flag" ))
    text_lacks "$text" 'update-config'
  done
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
