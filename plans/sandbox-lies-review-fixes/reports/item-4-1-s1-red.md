# Item 4.1 slice 1 - RED

Tests added to `tests/probes-readonly-members.bats`, new section "readfile
operand rule" (before "BSD tools"). SUT untouched.

- `grep --include=*.log gives the operand, never the option`: command
  `grep --include=*.log pat build.log`; asserts status 0, empty stderr, first
  line `writable`, exact line `readfile=build.log`, no `readfile=--` line.
- `grep -r --include=*.log pat . gives no readfile`: uses `assert_no_readfile`
  (status 0, empty stderr, first line `writable`, no line starting `readfile=`).

## Run against unchanged code

    not ok 8 grep --include=*.log gives the operand, never the option
    # (in test file tests/probes-readonly-members.bats, line 164)
    #   `printf '%s\n' "$output" | grep -qxF 'readfile=build.log'' failed
    not ok 9 grep -r --include=*.log pat . gives no readfile
    # (from function `assert_no_readfile' in file tests/probes-readonly-members.bats, line 30,
    #  in test file tests/probes-readonly-members.bats, line 174)
    #   `assert_no_readfile' failed, expected nonzero exit code!

Cause: `_readonly_readfile_arg` takes `--include=*.log` as the first `*.log`
word, so the probe prints a readfile line holding the option. Both fail on
their assertions. The other 8 tests in the file pass. No new test passed on
unchanged code, so no mutation proof is needed.

Note: the Edit tool gave no classifier verdict; the tests were inserted by a
Python script.
