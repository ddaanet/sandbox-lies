# Item 3.2 report

## Cases added

- `tests/check-line-limits.bats`: "git ls-files failure exits 2" (git stub on
  PATH exiting 128; status 2, empty stdout, stderr exactly
  `check-line-limits: git ls-files failed under <root>`); "unreadable file
  exits 2" (mode 000, skipped as root; status 2, empty stdout, last stderr
  line `check-line-limits: cannot read docs/a.md`).
- `tests/check-links-edges.bats`: "git ls-files failure exits 2" (same stub;
  stderr exactly `check-links: git ls-files failed under <root>`).

Difference from the item's wording: on unchanged code the unreadable case's
stderr has two lines, the shell's own "Permission denied" redirect error
(carrying a script line number) and then the script's `cannot read` line. The
test pins the last line exactly rather than the whole of stderr.

## Faults (scratch copy under /tmp/claude-1000/sl/scratch-3-2, deleted)

1. The `if ! git ... ls-files ... fi` guard in `scripts/lib/tracked.sh`
   replaced by the bare call with `|| true`. Red:
   `check-line-limits.bats` "git ls-files failure exits 2"
   (`[ "$status" -eq 2 ]` failed) and `check-links-edges.bats` "git ls-files
   failure exits 2" (`[ "$status" -eq 2 ]` failed).
2. The `if !` read guard in `check_cap` removed
   (`line_count=$(awk ...)` bare). Red: `check-line-limits.bats`
   "unreadable file exits 2" (`[ "$status" -eq 2 ]` failed).

Each fault run alone; the same tests are green on the real tree.

## Gate

precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests (277 passed, 0 failed)
