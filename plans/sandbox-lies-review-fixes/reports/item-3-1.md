# Item 3.1 report

## Added

- `tests/helpers/bsd-stubs.bash`: a `paste` arm in `make_bsd_stubs`
  (`_bsd_stub_paste`). It parses the BSD option set (`-s`, `-d` with a list)
  with getopts, prints the usage line on stderr and exits 1 when no file
  operand follows (`-s`, `-sd:`, `-sd :`), and execs the real `paste` otherwise
  (the explicit `-` operand counts).
- `tests/shim.bats`: no separate stub self-test suite exists, so the stub's own
  cases live here: refusal (`-s`, `-sd:`, `-sd :`, `-d: -s`), and pass-through
  with a file operand and with `-`. The third new case re-runs the shim's
  PATH-stripping with the stub on `PATH`. It asserts only the shim's argv, PATH
  entries and an empty stderr, not incidental lines of `.bin/claude`.

## Faults (scratch copy under /tmp/claude-1000/sl, deleted afterwards)

- F1, trailing `-` removed from `.bin/claude` in the copy, `shim.bats` run from
  the copy: red `the shim strips its directory under a BSD paste, which reads no
  implicit stdin` (`[ "$status" -eq 0 ]` failed).
- F2, stub never refuses (operand check replaced by `true`): red `the stub
  refuses paste -s with no file operand, alone or bundled` (expected exit 1,
  got 0).
- F3, stub parses only `-s` (bundled `-sd:` not understood): red the refusal
  case (stderr check), the pass-through case and the shim case.
- F4, stub always refuses: red `the stub passes paste with a file operand,
  including - for stdin` and the shim case (`$status` check).

## Gate

precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests (bats: 274 passed, 0 failed)
