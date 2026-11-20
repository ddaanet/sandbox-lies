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
      printf '%s\n' "The lock in this error has the shape of a sandbox mask and most likely is one. $(_lock_rerun "$flag") If it refuses again, it is a real file: report its path to the user and leave it in place. A repeat failure on a commit whose hook stages files is that hook leaking \`GIT_INDEX_FILE\`, not the sandbox."
      printf '%s\n' 'index.lock — shaped like a sandbox mask'
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
      printf '%s\n' "The \`config.lock\` behind this error has the shape of a sandbox mask and most likely is one. ${act} $(_config_lock_refused_again)"
      printf '%s\n' 'config.lock — shaped like a sandbox mask'
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

# `_config_lock_refused_again` — after _config_lock_is_settings, which leaves
# the decoded path in _verdict_path_raw: the mask paragraph's closing
# sentence. It hands a lock that refuses the re-run to the user as a possible
# leftover of a sandbox that died uncleanly, with `rm` of the path in single
# quotes, which the user pastes into their own shell. Only a path
# _config_lock_pastes passes gets the command: any other, like no path at
# all, keeps git-lock's report-and-leave sentence.
# shellcheck disable=SC2016 # backticks are literal prose, not expansion
_config_lock_refused_again() {
  local path=$_verdict_path_raw
  if [ -z "$path" ] || ! _config_lock_pastes "$path"; then
    printf 'If it refuses again, it is a real file: report its path to the user and leave it in place.'
    return 0
  fi
  printf 'If it refuses again, leave it and tell the user it may be left over from a sandbox that died uncleanly, giving them `rm '\''%s'\''` to run once they have checked no sandboxed command is running in any session.' "$path"
}

# `_config_lock_pastes <path>` — succeeds when every byte of path is printable
# ASCII (0x20-0x7E) and none is a single quote, a backslash or a backtick.
# Such a path, single-quoted inside a code span, reaches the user's shell as
# printed and reads the same in bash, zsh, dash and fish. A single quote ends
# the quoted word, fish reads a backslash inside one as an escape, and a
# backtick closes the code span. A byte outside the range is not sure to
# arrive: jq writes U+FFFD for one that is not valid UTF-8, and a control
# byte does not survive a paste. LC_ALL=C makes the range a byte range; the
# caller's locale is put back on return (see _verdict_unescape).
_config_lock_pastes() {
  local saved=${LC_ALL-} had=${LC_ALL+x} rc=0
  LC_ALL=C
  case "$1" in
    *[!\ -~]* | *[\'\\\`]*) rc=1 ;;
  esac
  if [ -n "$had" ]; then LC_ALL=$saved; else unset LC_ALL; fi
  return "$rc"
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
