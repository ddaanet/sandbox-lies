#!/usr/bin/env bash
# The git-lock and config-lock verdicts, sourced by lib/verdicts.sh, whose
# contract they keep: the agent paragraph on line 1, the human line on line 2,
# the probe's key=value lines on stdin. They also take the flag as a second
# argument (D-17): absent reads false, and it words the
# mask/gone/orphan/unknown re-run/retry clause per lock-detectors.md's flag
# table. Text from the plugin repository's docs/references/lock-detectors.md. _verdict_path_read is in
# lib/verdicts.sh.
set -u

# `_lock_rerun <flag>` / `_lock_retry <flag>` — lock-detectors.md's
# *Re-run*/*Retry* flag table. Any value but "true" reads as false.
# _lock_rerun's result is a full sentence (trailing period), _lock_retry's is
# a clause fragment its caller finishes.
# shellcheck disable=SC2016 # backticks are literal prose, not expansion
_lock_rerun() {
  case "$1" in
    true) printf 'Re-run the same command once no sandboxed command is running.' ;;
    *) printf 'Once no sandboxed command is running, re-run the same command with `dangerouslyDisableSandbox: true`.' ;;
  esac
}

# shellcheck disable=SC2016 # backticks are literal prose, not expansion
_lock_retry() {
  case "$1" in
    true) printf 'Retry the command once' ;;
    *) printf 'Retry the command with `dangerouslyDisableSandbox: true`' ;;
  esac
}

# `verdict_git_lock <outcome> [flag]`
verdict_git_lock() {
  local outcome="$1" flag="${2:-false}"
  case "$outcome" in
    mask)
      printf '%s\n' "The lock in this error is a sandbox artefact and the repository is healthy. $(_lock_rerun "$flag") A repeat failure on a commit whose hook stages files is that hook leaking \`GIT_INDEX_FILE\`, not the sandbox."
      printf '%s\n' 'index.lock — sandbox mask, not a real lock'
      ;;
    gone)
      if [ "$flag" = true ]; then
        # shellcheck disable=SC2016 # backticks are literal prose, not expansion
        printf '%s\n' 'No lock exists now; git cleaned it after the failure. Retry once. A repeat failure on a commit whose hook stages files is that hook leaking `GIT_INDEX_FILE`, not the sandbox.'
        printf '%s\n' 'index.lock — cleared after failure'
      else
        printf '%s\n' "$(_lock_absent_cause) $(_lock_retry "$flag"). A repeat failure on a commit whose hook stages files is that hook leaking \`GIT_INDEX_FILE\`, not the sandbox."
        printf '%s\n' 'index.lock — absent now, mask or released'
      fi
      ;;
    *) _verdict_lock_present index.lock "$outcome" "$flag" ;;
  esac
}

# `verdict_config_lock <outcome> [flag]` — mask, and gone with no flag, read
# the probe's path= line on stdin: a `.claude/settings.json.lock` path swaps
# in the update-config act (lock-detectors.md's config-lock Verdicts); any
# other path, or none, keeps the re-run or retry, worded by the flag as
# git_lock's is.
verdict_config_lock() {
  local outcome="$1" flag="${2:-false}" act
  case "$outcome" in
    mask)
      if _config_lock_is_settings; then
        act=$_CONFIG_LOCK_SETTINGS_ACT
      else
        act=$(_lock_rerun "$flag")
      fi
      printf '%s\n' "The \`config.lock\` behind this error is a sandbox artefact and the repository is healthy. ${act}"
      printf '%s\n' 'config.lock — sandbox mask, not a real lock'
      ;;
    gone)
      if [ "$flag" = true ]; then
        printf '%s\n' 'No lock exists now; git cleaned it after the failure. Retry once.'
        printf '%s\n' 'config.lock — cleared after failure'
      else
        if _config_lock_is_settings; then
          act=$_CONFIG_LOCK_SETTINGS_ACT
        else
          act="$(_lock_retry "$flag")."
        fi
        printf '%s\n' "$(_lock_absent_cause) ${act}"
        printf '%s\n' 'config.lock — absent now, mask or released'
      fi
      ;;
    *) _verdict_lock_present config.lock "$outcome" "$flag" ;;
  esac
}

# `_lock_absent_cause` — gone with no flag: nothing in the payload records an
# excludedCommands exclusion, and a released lock leaves the path as a mask
# does, so the sentence names both causes.
_lock_absent_cause() {
  printf 'No lock exists now: this refusal came from a sandbox mask or from a lock its holder has since released.'
}

# `_config_lock_is_settings` — reads the probe's lines on stdin; true when
# path= names `.claude/settings.json.lock`. No decodable path is false.
_config_lock_is_settings() {
  local line wire=''
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      path=*) wire=${line#path=} ;;
    esac
  done
  _verdict_path_read "$wire" || :
  # shellcheck disable=SC2154 # set by _verdict_path_read in lib/verdicts.sh
  case "$_verdict_path_raw" in
    */.claude/settings.json.lock) return 0 ;;
    *) return 1 ;;
  esac
}

# shellcheck disable=SC2016 # backticks are literal prose, not expansion
_CONFIG_LOCK_SETTINGS_ACT='Write `.claude/settings.json` through the `update-config` skill.'

# `_verdict_lock_present <lock file> <outcome> <flag>` — the held, orphan and
# unknown verdicts, whose text the two lock detectors share but for the file
# they name and the flag they word orphan/unknown's *Retry* clause by (held
# ignores it). Interpolates pid=/bytes=/age= from the probe's remaining lines
# on stdin (path= and any other key ignored). A key that is absent, or whose
# value is not all digits as the probe contract has it, drops its clause
# rather than leaving an empty or foreign value. Any other outcome prints
# nothing.
_verdict_lock_present() {
  local lock="$1" outcome="$2" flag="$3" line pid='' bytes='' age='' size=''
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      *=*[!0-9]*) ;;
      pid=*) pid=${line#pid=} ;;
      bytes=*) bytes=${line#bytes=} ;;
      age=*) age=${line#age=} ;;
    esac
  done
  if [ -n "$bytes" ]; then
    size=" (${bytes} bytes${age:+, age ${age}s})"
  elif [ -n "$age" ]; then
    size=" (age ${age}s)"
  fi
  case "$outcome" in
    held)
      printf '%s\n' "A process${pid:+ (pid ${pid})} holds the lock. Wait for it, then retry."
      printf '%s\n' "${lock} — held${pid:+ by pid ${pid}}"
      ;;
    orphan)
      printf '%s\n' "The lock exists outside the sandbox${size} and no process holds it. $(_lock_retry "$flag"); a second identical failure means the lock predates this session."
      printf '%s\n' "${lock} — present, no holder"
      ;;
    unknown)
      printf '%s\n' "The lock exists outside the sandbox${size}; no holder check is available here. $(_lock_retry "$flag")."
      printf '%s\n' "${lock} — present, holder unknown"
      ;;
  esac
}
