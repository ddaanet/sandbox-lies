#!/usr/bin/env bats
# lib/verdicts.sh's git-lock and config-lock verdicts: transcription against
# lock-detectors.md, held|orphan|unknown probe-value interpolation, and D-17's
# flag-worded re-run/retry clause. Split from tests/verdicts.bats to keep that
# file under the 400-line cap (Item 8.0 slice 1).

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/verdicts

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
