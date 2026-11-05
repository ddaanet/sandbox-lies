#!/usr/bin/env bats
# lib/verdicts.sh's git-lock and config-lock verdicts, D-17's flag-worded
# re-run/retry clause: mask, orphan, unknown and gone worded by both flag
# values, and the config-lock settings.json.lock update-config act. Text
# transcription and probe-value interpolation are in verdicts-locks.bats.

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/verdicts

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
      text_lacks "$text" 'same command once no sandboxed'
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

  # gone words the retry by the flag as well: false names both causes and
  # carries the dangerouslyDisableSandbox retry, true keeps the git-cleaned-it
  # text; neither asserts a sandbox artefact.
  for name in git_lock config_lock; do
    text=$(verdict_text "$name" gone false)
    printf '%s' "$text" | grep -qF 'dangerouslyDisableSandbox: true'
    printf '%s' "$text" | grep -qF 'a lock its holder has since released'
    text_lacks "$text" 'sandbox artefact'
    [ "$(verdict_text "$name" gone -)" = "$text" ]

    text=$(verdict_text "$name" gone true)
    printf '%s' "$text" | grep -qF 'git cleaned it after the failure'
    text_lacks "$text" 'dangerouslyDisableSandbox: true'
    text_lacks "$text" 'holder has since released'
  done

  # The config-lock settings act: a `.claude/settings.json.lock` path
  # replaces *Re-run* with the update-config act, under either flag; any
  # other path (e.g. `.git/config.lock`) keeps *Re-run* and never mentions
  # update-config. gone false takes the act the same way, and gone true never.
  local flag
  for flag in false true; do
    # shellcheck disable=SC1090 # $VERDICTS is lib/verdicts.sh, resolved above
    text=$(printf '%s\n' 'path=/r/.claude/settings.json.lock' \
      | ( . "$VERDICTS"; verdict_config_lock mask "$flag" ))
    printf '%s' "$text" | grep -qF 'update-config'
    text_lacks "$text" 'the same command'

    # shellcheck disable=SC1090
    text=$(printf '%s\n' 'path=/r/.git/config.lock' \
      | ( . "$VERDICTS"; verdict_config_lock mask "$flag" ))
    text_lacks "$text" 'update-config'
  done

  # shellcheck disable=SC1090
  text=$(printf '%s\n' 'path=/r/.claude/settings.json.lock' \
    | ( . "$VERDICTS"; verdict_config_lock gone false ))
  printf '%s' "$text" | grep -qF 'update-config'
  text_lacks "$text" 'dangerouslyDisableSandbox'
  # shellcheck disable=SC1090
  text=$(printf '%s\n' 'path=/r/.git/config.lock' \
    | ( . "$VERDICTS"; verdict_config_lock gone false ))
  text_lacks "$text" 'update-config'
  printf '%s' "$text" | grep -qF 'dangerouslyDisableSandbox: true'
  # shellcheck disable=SC1090
  text=$(printf '%s\n' 'path=/r/.claude/settings.json.lock' \
    | ( . "$VERDICTS"; verdict_config_lock gone true ))
  text_lacks "$text" 'update-config'
}
