#!/usr/bin/env bash
# Agent paragraph and human line per verdict. `verdict_<name> [outcome]`
# reads the probe's key=value lines on stdin (empty when the detector has no
# probe), and prints the agent paragraph on line 1, the human line on line 2.
# Phantom verdicts take no outcome argument. Text from
# docs/references/detectors.md.
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
