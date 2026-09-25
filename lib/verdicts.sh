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

# held/orphan/unknown read pid=/bytes=/age= from the probe's remaining lines
# on stdin (path= and any other key ignored) and interpolate them; a key
# that is absent drops its clause rather than leaving an empty value.
verdict_git_lock() {
  local outcome="$1" line pid='' bytes='' age=''
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      pid=*) pid=${line#pid=} ;;
      bytes=*) bytes=${line#bytes=} ;;
      age=*) age=${line#age=} ;;
    esac
  done
  case "$outcome" in
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
    held)
      local held_clause='' held_line='index.lock — held'
      if [ -n "$pid" ]; then
        held_clause=" (pid ${pid})"
        held_line="index.lock — held by pid ${pid}"
      fi
      printf '%s\n' "A process${held_clause} holds the lock. Wait for it, then retry."
      printf '%s\n' "$held_line"
      ;;
    orphan)
      local size_clause=''
      if [ -n "$bytes" ] && [ -n "$age" ]; then
        size_clause=" (${bytes} bytes, age ${age}s)"
      elif [ -n "$bytes" ]; then
        size_clause=" (${bytes} bytes)"
      elif [ -n "$age" ]; then
        size_clause=" (age ${age}s)"
      fi
      printf '%s\n' "The lock exists outside the sandbox${size_clause} and no process holds it. Retry the command unsandboxed; a second identical failure means the lock predates this session."
      printf '%s\n' 'index.lock — present, no holder'
      ;;
    unknown)
      local size_clause=''
      if [ -n "$bytes" ] && [ -n "$age" ]; then
        size_clause=" (${bytes} bytes, age ${age}s)"
      elif [ -n "$bytes" ]; then
        size_clause=" (${bytes} bytes)"
      elif [ -n "$age" ]; then
        size_clause=" (age ${age}s)"
      fi
      printf '%s\n' "The lock exists outside the sandbox${size_clause}; no holder check is available here. Retry the command unsandboxed."
      printf '%s\n' 'index.lock — present, holder unknown'
      ;;
  esac
}

verdict_config_lock() {
  local outcome="$1" line pid='' bytes='' age=''
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      pid=*) pid=${line#pid=} ;;
      bytes=*) bytes=${line#bytes=} ;;
      age=*) age=${line#age=} ;;
    esac
  done
  case "$outcome" in
    mask)
      # shellcheck disable=SC2016 # backticks are literal prose, not expansion
      printf '%s\n' 'The lock in this error is a sandbox artefact and the repository is healthy. Re-run the same command with `dangerouslyDisableSandbox: true`; if it already ran that way, re-run it once no sandboxed command is running. Run the `git config` or `git remote` write unsandboxed, or through the `update-config` skill when the target is `.claude/settings.json`.'
      printf '%s\n' 'config.lock — sandbox mask, not a real lock'
      ;;
    gone)
      printf '%s\n' 'No lock exists now; git cleaned it after the failure. Retry once.'
      printf '%s\n' 'config.lock — cleared after failure'
      ;;
    held)
      local held_clause='' held_line='config.lock — held'
      if [ -n "$pid" ]; then
        held_clause=" (pid ${pid})"
        held_line="config.lock — held by pid ${pid}"
      fi
      printf '%s\n' "A process${held_clause} holds the lock. Wait for it, then retry."
      printf '%s\n' "$held_line"
      ;;
    orphan)
      local size_clause=''
      if [ -n "$bytes" ] && [ -n "$age" ]; then
        size_clause=" (${bytes} bytes, age ${age}s)"
      elif [ -n "$bytes" ]; then
        size_clause=" (${bytes} bytes)"
      elif [ -n "$age" ]; then
        size_clause=" (age ${age}s)"
      fi
      printf '%s\n' "The lock exists outside the sandbox${size_clause} and no process holds it. Retry the command unsandboxed; a second identical failure means the lock predates this session."
      printf '%s\n' 'config.lock — present, no holder'
      ;;
    unknown)
      local size_clause=''
      if [ -n "$bytes" ] && [ -n "$age" ]; then
        size_clause=" (${bytes} bytes, age ${age}s)"
      elif [ -n "$bytes" ]; then
        size_clause=" (${bytes} bytes)"
      elif [ -n "$age" ]; then
        size_clause=" (age ${age}s)"
      fi
      printf '%s\n' "The lock exists outside the sandbox${size_clause}; no holder check is available here. Retry the command unsandboxed."
      printf '%s\n' 'config.lock — present, holder unknown'
      ;;
  esac
}
