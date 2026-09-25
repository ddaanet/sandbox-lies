# Shared helpers for tests/probes.bats and tests/probes-edges.bats: the error
# builder and the `run` wrapper both files' probe_git_lock cases use.

# Self-quiet (FR-11): git's lock error is built from two fragments at run
# time, as lib/matchers.sh match_git_lock builds its follow-on, so no test
# file holds the diagnostic whole. The follow-on sentence is left out
# entirely — the probe does not read it.
git_lock_error() {
  local path="$1" text
  text="fatal: Unable to create '"
  text="${text}${path}': File exists."
  printf '%s\n' "$text"
}

# run_probe <probe> <flag> <cwd> <text> — the probe under bats' run with
# <text> on stdin: stdout in $output, stderr in $stderr, exit in $status.
# stderr is kept apart so it cannot shift the outcome off line 1. Line 1 is
# read as ${output%%$'\n'*}, never ${lines[0]}: bats drops empty lines from
# lines, so a stray blank first line would pass for the token.
run_probe() {
  run --separate-stderr "$1" "$2" "$3" <<<"$4"
}

# tools_only_path <dir> — symlinks into <dir> every external tool
# probe_git_lock calls other than the holder tools (lsof, fuser), plus
# mktemp for bats' own `run --separate-stderr` (test_functions.bash), taken
# from this host's own `command -v` so the case runs on any box. A PATH set
# to exactly <dir> can then never see lsof or fuser unless a test writes one
# there itself. The tool list lives here once, so a new probe call site
# updates one place.
tools_only_path() {
  local dir="$1" tool
  mkdir -p "$dir"
  for tool in cat sed head stat wc tr date mktemp; do
    ln -s "$(command -v "$tool")" "$dir/$tool"
  done
}
