#!/usr/bin/env bash
# Loaded by every suite that runs git. Cuts the host's git configuration out of
# the picture: the system config is ignored and the global config is a file
# this helper writes, so a host `commit.gpgsign=true`, a `gpg.program`, a
# `core.hooksPath`, an `init.defaultBranch` or a missing identity cannot change
# a case's outcome.
#
# The export runs when the file is loaded, not from a setup() hook, so a
# suite's own setup() cannot skip it. bats loads a test file once to gather the
# test names (no $BATS_TEST_TMPDIR yet, no git runs) and again inside each
# test's process, where $BATS_TEST_TMPDIR exists: the file is written there,
# fresh for every test, and the exports reach every `run`, subshell and child
# process, the hook included. A case that clears the environment with `env -i`
# gets none of it, and must not run git.

if [ -n "${BATS_TEST_TMPDIR:-}" ]; then
  GIT_CONFIG_NOSYSTEM=1
  GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/host-gitconfig"
  printf '[user]\n\tname = test\n\temail = test@example.invalid\n[commit]\n\tgpgsign = false\n' \
    >"$GIT_CONFIG_GLOBAL"
  export GIT_CONFIG_NOSYSTEM GIT_CONFIG_GLOBAL
fi
