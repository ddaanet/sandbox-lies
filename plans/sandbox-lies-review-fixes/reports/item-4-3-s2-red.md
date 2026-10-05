# Item 4.3 slice 2 — RED

Tests: `tests/check-jq.bats` (101 lines; uncommitted). SUT untouched
(`hooks/check-jq.sh` is the inert stub).

## Per-test output (`bats tests/check-jq.bats`)

- ok 1 `jq present: the registered SessionStart command is silent` (slice 1,
  still passes)
- not ok 2 `jq absent: one SessionStart JSON object, style reset first, naming
  jq` — `assert_notice` line 52: `jq -e -s 'length == 1 and (.[0] | type ==
  "object")'` prints `false` on empty stdout. Status 0 and empty stderr passed
  first.
- not ok 3 `jq absent: TMPDIR naming a missing directory gives the same stdout`
  — same assertion, first `assert_notice` (test line 85).
- not ok 4 `jq absent: a re-run with BSD stubs ahead on PATH gives the same
  stdout` — same assertion, first `assert_notice` (test line 95).

All three fail on an assertion, not an ERROR. `shellcheck -x` clean.

## Choices

- jq-less PATH: `$BATS_TEST_TMPDIR/nojq-bin` with symlinks to `bash sed grep
  mktemp stat wc cat dirname` (`NOJQ_TOOLS`, resolved from the test's PATH);
  no `jq`, and the only PATH entry besides the optional BSD stub dir. `printf`
  is a builtin. GREEN may narrow or must extend `NOJQ_TOOLS` if it needs more.
- Real `jq` resolved to absolute `JQ` before PATH changes; assertions use it.
- Command: registered string via absolute `bash -c`, under `env
  CLAUDE_PLUGIN_ROOT=$ROOT PATH=...`, cwd `$BATS_TEST_TMPDIR`, stdin
  `/dev/null`, `run --separate-stderr`.
- ESC built as `$'\033'` and passed to jq as `--arg esc`.
- TMPDIR case: `TMPDIR=$BATS_TEST_TMPDIR/no-such-dir`; compares `$output` to
  the plain run.
- BSD case: `make_bsd_stubs $BATS_TEST_TMPDIR/bsd-bin sed grep mktemp stat wc`,
  dir prefixed to PATH; compares `$output` to the plain run. Header's pending
  note replaced.
- `$output` comparison drops trailing newlines (bats `run`); a trailing-newline
  difference is not checked.
- No Mutation proof needed: every new case reds against the stub.
