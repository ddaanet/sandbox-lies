#!/usr/bin/env bash
# Agent paragraph and human line per verdict. `verdict_<name> [outcome]`
# reads the probe's key=value lines on stdin (empty when the detector has no
# probe), and prints the agent paragraph on line 1, the human line on line 2.
# Phantom verdicts take no outcome argument. verdict_git_lock and
# verdict_config_lock also take the flag as a second argument (D-17): absent
# reads false, and it words the mask/orphan/unknown re-run/retry clause per
# lock-detectors.md's flag table. Text from docs/references/detectors.md,
# except git_lock and config_lock, whose text comes from
# docs/references/lock-detectors.md.
set -u

verdict_phantom_chardev() {
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  printf '%s\n' 'The character-device entries in this listing are sandbox masks over dotfiles in the project root, not files in the repository. Leave them out of every add, delete and report. With no sandboxed command running in the background, `ls -a` and `git status` run unsandboxed show the real tree.'
  printf '%s\n' 'phantom dotfiles — sandbox masks in listing'
}

verdict_phantom_untracked() {
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  printf '%s\n' 'The dotfile entries in this listing are sandbox masks over dotfiles in the project root, not files in the repository. Leave them out of every add, delete and report. With no sandboxed command running in the background, `ls -a` and `git status` run unsandboxed show the real tree. A cleanliness check that reads these `??` lines as dirty is reading the sandbox, not the tree.'
  printf '%s\n' 'phantom dotfiles — masks listed as untracked'
}

verdict_phantom_gitadd() {
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  printf '%s\n' '`git add` aborted on a sandbox mask, not a file. Stage explicit paths, or re-run the same command unsandboxed.'
  printf '%s\n' 'git add — refused a sandbox mask'
}

# `_lock_rerun <flag>` / `_lock_retry <flag>` — lock-detectors.md's
# *Re-run*/*Retry* flag table. Any value but "true" reads as false.
# _lock_rerun's result is a full sentence (trailing period), _lock_retry's is
# a clause fragment its caller finishes.
# shellcheck disable=SC2016 # backticks are literal prose, not expansion
_lock_rerun() {
  case "$1" in
    true) printf 'Re-run the same command once no sandboxed command is running.' ;;
    *) printf 'Re-run the same command with `dangerouslyDisableSandbox: true`.' ;;
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
      # shellcheck disable=SC2016 # backticks are literal prose, not expansion
      printf '%s\n' 'No lock exists now; git cleaned it after the failure. Retry once. A repeat failure on a commit whose hook stages files is that hook leaking `GIT_INDEX_FILE`, not the sandbox.'
      printf '%s\n' 'index.lock — cleared after failure'
      ;;
    *) _verdict_lock_present index.lock "$outcome" "$flag" ;;
  esac
}

# `verdict_config_lock <outcome> [flag]` — mask reads the probe's path= line
# on stdin: a `.claude/settings.json.lock` path swaps in the update-config act
# for *Re-run*, under either flag (lock-detectors.md's config-lock Verdicts);
# any other path, or none, keeps *Re-run*, worded by the flag as git_lock's is.
verdict_config_lock() {
  local outcome="$1" flag="${2:-false}" line path='' act
  case "$outcome" in
    mask)
      while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
          path=*) path=${line#path=} ;;
        esac
      done
      case "$path" in
        */.claude/settings.json.lock)
          # shellcheck disable=SC2016 # backticks are literal prose, not expansion
          act='Write `.claude/settings.json` through the `update-config` skill.'
          ;;
        *) act=$(_lock_rerun "$flag") ;;
      esac
      printf '%s\n' "The \`config.lock\` behind this error is a sandbox artefact and the repository is healthy. ${act}"
      printf '%s\n' 'config.lock — sandbox mask, not a real lock'
      ;;
    gone)
      printf '%s\n' 'No lock exists now; git cleaned it after the failure. Retry once.'
      printf '%s\n' 'config.lock — cleared after failure'
      ;;
    *) _verdict_lock_present config.lock "$outcome" "$flag" ;;
  esac
}

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

# `verdict_readonly_path <outcome>` — writable and readonly open with the
# probe's path= stdin line in backticks, or with "The path" when that line is
# missing or empty, which the probe contract rules out. The path is joined by
# plain expansion — never a printf format, sed or eval — so blanks, `&`, `%`,
# `\1` or a leading `-` pass through byte-exact; a backtick in it closes the
# code span early, bytes intact. nopath has no path= line under the contract
# and opens with its own sentence. detectors.md defines nopath's rest as the
# writable paragraph from "If a merge" on, hence the one `tail` literal. An
# outcome with no text here prints nothing, as an unmatched lock outcome does.
verdict_readonly_path() {
  local outcome="$1" line path='' subject tail
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      path=*) path=${line#path=} ;;
    esac
  done
  if [ -n "$path" ]; then
    subject="\`$path\`"
  else
    subject='The path'
  fi
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  tail=' If a merge or checkout died, files it wrote sit at the target, HEAD unmoved, blocking a re-run: restore them from HEAD once they match the target. Then re-run the whole call unsandboxed or, if it only read a command-output file (a `*.log`), the command that wrote it. For `.claude/settings.json`, use the `update-config` skill.'
  case "$outcome" in
    writable)
      printf '%s\n' "$subject is writable outside the sandbox, whose allowlist refused it.$tail"
      printf '%s\n' 'read-only — sandbox allowlist, writable outside'
      ;;
    readonly)
      printf '%s\n' "$subject is not writable outside the sandbox either; this is not a sandbox effect. Unsandboxing will not help: write somewhere writable, or ask before changing its permissions."
      printf '%s\n' 'read-only — real'
      ;;
    nopath)
      printf '%s\n' "The sandbox's write allowlist most likely refused this write.$tail"
      printf '%s\n' 'read-only — probably the sandbox, path not checked'
      ;;
  esac
}

# The shipped candidates. Each takes no outcome, as the phantom verdicts do;
# text from docs/references/detectors.md's Verdict paragraphs, transcribed
# verbatim.
verdict_tmpdir_unset() {
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  printf '%s\n' '`$TMPDIR` expanded empty in this unsandboxed call, so the path collapsed to `/`. Use the literal scratch path `/tmp/claude/<job>` (create it with `mkdir -p`) in this and every unsandboxed or delegated command.'
  # shellcheck disable=SC2016 # $TMPDIR is literal prose, not expansion
  printf '%s\n' '$TMPDIR — expanded empty, path collapsed to /'
}

verdict_resume_lost() {
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  printf '%s\n' 'The transcript was never written: `~/.claude/projects` is read-only inside the sandbox. Run the entire multi-turn flow in one unsandboxed call.'
  printf '%s\n' '--resume — transcript not persisted in sandbox'
}

verdict_seccomp_init() {
  printf '%s\n' 'The sandbox failed to initialise before the command ran; this is transient. Retry the identical command once; if it fails the same way, split it into smaller calls. Escape the sandbox only after both.'
  printf '%s\n' 'sandbox init failed — transient, retry'
}
