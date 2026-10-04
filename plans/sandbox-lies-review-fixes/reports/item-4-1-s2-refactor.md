# Item 4.1/2 refactor: operand-rule cases split out

Flag: tests/probes-readonly-members.bats near the 400-line cap.

## What moved

- The "readfile operand rule" section (11 cases from Item 4.1 slices 1-2 and
  their reviews) moved verbatim to the new tests/probes-readonly-operands.bats,
  with the same load lines and `setup`, and a header naming outline D4 and
  docs/references/readonly-path.md.
- `assert_no_readfile` (used by both files) moved to tests/helpers/probes.bash;
  that file's header list now names both files.
- tests/probes-readonly-members.bats header updated; its BSD case is unchanged.
- New case "the operand rule survives BSD grep, sed, stat and wc" in the new
  file (grep --include and sed program cases under `make_bsd_stubs`).

## Verification

- `bats --count`: 21 before; 21 (members) minus 11 moved plus 11 in operands
  plus the new BSD case = 22 across both files.
- Sorted test-name lists before/after differ only by the added BSD case; no
  assertion text changed.
- Lines: members 378 -> 170; operands 240.
- Gate: precommit passed (291 bats passed, 0 failed).
