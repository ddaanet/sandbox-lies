# Item 2.1 report

Cases added to `tests/hook-malformed.bats` (158 -> 216 lines), each stubbing
the function twice (return 0 for `check_fires`, then return 1 for
`check_quiet`, a later definition winning) and asserting through
`assert_no_failures`:

- "probe dying after output stays quiet" (`fire-readonly-path-cp-tmp`, flag
  absent; also asserts the called marker exists).
- "verdict dying after a probe stays quiet" (`fire-lock-add-commit`,
  `stub_probe git_lock mask`; asserts `PROBE_CALLED` exists).
- "probe-less verdict dying stays quiet" (`fire-masks-gitadd-refused`,
  `verdict_phantom_gitadd` stub).

Adaptation: the probe stub is written inline with `stub_lib` (not
`stub_probe`), since it must print `path=/r/x` and return 1. No helper changed.

Green on the real tree: all 7 tests ok.

Faults, each alone, in a scratch copy under /tmp/claude-1000/sl/scratch-2-1
(deleted):

- annotate.sh line 112 `|| exit 0` -> `|| true`: red test 5 "probe dying
  after output stays quiet"; failing assertion line 183 (assert_no_failures),
  message "probe returning 1 after output: stdout [{...".
- line 123 -> `|| true`: red test 6 "verdict dying after a probe stays
  quiet"; line 201, "verdict returning 1 after output: stdout [{...".
- line 125 -> `|| true`: red test 7 "probe-less verdict dying stays quiet";
  line 215, "verdict returning 1 after output: stdout [{...".

Other tests stayed ok in each run.

Added a `check_reached <label> <marker>` helper in the same file (shellcheck
SC2030/SC2031 flagged `failures+=` written directly in a test body). Line
numbers above are from the final file.

Gate: `precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl,
line limits, links, tests` (bats: 254 passed, 0 failed).
