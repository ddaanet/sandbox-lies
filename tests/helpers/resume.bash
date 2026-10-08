# Shared by tests/probes-resume.bats and tests/probes-resume-tree.bats: the
# session ids of fire-resume-lost-two-turn.txt and the fixture-tree builder
# their probe_resume_lost cases use.

# shellcheck disable=SC2034 # read by the bats files that load this helper
ID_1=37b5f8f7-cd46-44d7-8416-946cf6729b30
# shellcheck disable=SC2034 # read by the bats files that load this helper
ID_2=7ded81f3-920a-40b7-bf8b-5f08e913c333
# shellcheck disable=SC2034 # read by the bats files that load this helper
ID_OTHER=11111111-2222-4333-8444-555555555555

# resume_teardown — for a suite's teardown: the unreadable-tree cases chmod 000;
# bats removes the tree afterwards.
resume_teardown() {
  chmod -R u+rwx "$BATS_TEST_TMPDIR"
}

# transcript <id> [root] [project] — a regular file
# <root>/projects/<project>/<id>.jsonl, root defaulting to the config dir and
# project to -p. It holds one JSON line, as a transcript CC wrote would.
transcript() {
  local root="${2:-$CLAUDE_CONFIG_DIR}" project="${3:--p}"
  mkdir -p "$root/projects/$project"
  printf '{}\n' >"$root/projects/$project/$1.jsonl"
}

