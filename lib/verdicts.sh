#!/usr/bin/env bash
# Agent paragraph and human line per verdict. `verdict_<name> [outcome]`
# reads the probe's key=value lines on stdin (empty when the detector has no
# probe), and prints the agent paragraph on line 1, the human line on line 2.
# Phantom verdicts take no outcome argument. Text from
# docs/references/detectors.md, except git_lock and config_lock, whose text
# comes from docs/references/lock-detectors.md.
set -u

verdict_phantom_chardev() {
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  printf '%s\n' 'The character-device entries in this listing are sandbox masks over dotfiles in the project root, not files in the repository. Leave them out of every add, delete and report. With no sandboxed command running in the background, `ls -a` and `git status` run unsandboxed show the real tree.'
  printf '%s\n' 'phantom dotfiles — sandbox masks in listing'
}

verdict_phantom_untracked() {
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  printf '%s\n' 'The character-device entries in this listing are sandbox masks over dotfiles in the project root, not files in the repository. Leave them out of every add, delete and report. With no sandboxed command running in the background, `ls -a` and `git status` run unsandboxed show the real tree. A cleanliness check that reads these `??` lines as dirty is reading the sandbox, not the tree.'
  printf '%s\n' 'phantom dotfiles — masks listed as untracked'
}

verdict_phantom_gitadd() {
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  printf '%s\n' '`git add` aborted on a sandbox mask, not a file. Stage explicit paths, or re-run the same command unsandboxed.'
  printf '%s\n' 'git add — refused a sandbox mask'
}

verdict_git_lock() {
  case "$1" in
    mask)
      # shellcheck disable=SC2016 # backticks are literal prose, not expansion
      printf '%s\n' 'The lock in this error is a sandbox artefact and the repository is healthy. Re-run the same command with `dangerouslyDisableSandbox: true`; if it already ran that way, re-run it once no sandboxed command is running. A repeat failure on a commit whose hook stages files is that hook leaking `GIT_INDEX_FILE`, not the sandbox.'
      printf '%s\n' 'index.lock — sandbox mask, not a real lock'
      ;;
    gone)
      # shellcheck disable=SC2016 # backticks are literal prose, not expansion
      printf '%s\n' 'No lock exists now; git cleaned it after the failure. Retry once. A repeat failure on a commit whose hook stages files is that hook leaking `GIT_INDEX_FILE`, not the sandbox.'
      printf '%s\n' 'index.lock — cleared after failure'
      ;;
    *) _verdict_lock_present index.lock "$1" ;;
  esac
}

verdict_config_lock() {
  case "$1" in
    mask)
      # shellcheck disable=SC2016 # backticks are literal prose, not expansion
      printf '%s\n' 'The `config.lock` behind this error is a sandbox artefact and the repository is healthy. Re-run the same command with `dangerouslyDisableSandbox: true`; if it already ran that way, re-run it once no sandboxed command is running. Run the `git config` or `git remote` write unsandboxed, or through the `update-config` skill when the target is `.claude/settings.json`.'
      printf '%s\n' 'config.lock — sandbox mask, not a real lock'
      ;;
    gone)
      printf '%s\n' 'No lock exists now; git cleaned it after the failure. Retry once.'
      printf '%s\n' 'config.lock — cleared after failure'
      ;;
    *) _verdict_lock_present config.lock "$1" ;;
  esac
}

# `_verdict_lock_present <lock file> <outcome>` — the held, orphan and unknown
# verdicts, whose text the two lock detectors share but for the file they
# name. Interpolates pid=/bytes=/age= from the probe's remaining lines on
# stdin (path= and any other key ignored). A key that is absent, or whose
# value is not all digits as the probe contract has it, drops its clause
# rather than leaving an empty or foreign value. Any other outcome prints
# nothing.
_verdict_lock_present() {
  local lock="$1" outcome="$2" line pid='' bytes='' age='' size=''
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
      printf '%s\n' "The lock exists outside the sandbox${size} and no process holds it. Retry the command unsandboxed; a second identical failure means the lock predates this session."
      printf '%s\n' "${lock} — present, no holder"
      ;;
    unknown)
      printf '%s\n' "The lock exists outside the sandbox${size}; no holder check is available here. Retry the command unsandboxed."
      printf '%s\n' "${lock} — present, holder unknown"
      ;;
  esac
}

# `verdict_readonly_path <outcome>` — opens the paragraph with the probe's
# path= stdin line in backticks, interpolated by plain expansion, never sed
# or eval, so a path holding blanks, `&` or `\1` passes through byte-exact.
# With no path= line or an empty one, outside the probe contract, the
# paragraph opens with "The path" instead. An outcome with no text here
# prints nothing, as an unmatched lock outcome does.
verdict_readonly_path() {
  local outcome="$1" line path=''
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      path=*) path=${line#path=} ;;
    esac
  done
  case "$outcome" in
    writable)
      if [ -n "$path" ]; then
        # shellcheck disable=SC2016 # backticks are literal prose, not expansion
        printf '`%s`' "$path"
      else
        printf '%s' 'The path'
      fi
      # shellcheck disable=SC2016 # backticks are literal prose, not expansion
      printf '%s\n' ' is writable outside the sandbox, whose allowlist refused the write. Re-run the whole call with `dangerouslyDisableSandbox: true` or, if it only read a command-output file such as a `*.log`, the command that wrote that file. For `.claude/settings.json`, use the `update-config` skill. A merge or checkout that died here may be partial: compare modified files against the target first.'
      printf '%s\n' 'read-only — sandbox allowlist, writable outside'
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
