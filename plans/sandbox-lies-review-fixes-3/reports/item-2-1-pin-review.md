# Item 2.1 pin review — set -e survivor test

Scope: last case in `tests/probes-readonly-resolve.bats` (commit 6f687b3) and
its report `item-2-1-pin.md`. Nothing committed.

## Re-run mutation (different spelling)

- Old string (once in `lib/probes-readonly.sh`): `_readonly_path_line) || line=`
- New string: `_readonly_path_line) || return`
- Landed: `command grep -n '|| return$'` showed line 51
  `line=$(printf '%s\n' "$text" | _readonly_path_line) || return`.
- `bats -f 'under set -e' tests/probes-readonly-resolve.bats`: `not ok 1`,
  `[ "$status" -eq 0 ]' failed` at test line 163 (an assertion, not an error).
- Restore by swapping the strings. Proof: `command grep -c '|| return$'` = 0,
  line 51 reads `... || line=`, `git diff --stat -- lib` empty; the case is
  green in the full-file run below.
- The `base=$(_readonly_git_dir ...) || base="$cwd"` guard was not mutated: the
  no-refusal text never takes the partial-checkout branch, so this test does
  not exercise it (not this pin's survivor).

## Wrong-reason hunt

- Could pass for another reason: the pass needs status 0 and first line
  `nopath`, which only the guarded no-match path prints; `|| return` and the
  pin's unguarded form both give status 1. No other source of `nopath` exists
  for plain text.
- `source` of `lib/probes.sh` under BSD stubs: the file's convention (one case
  re-run with `make_bsd_stubs`) was missing for this case, though the probe runs
  `grep` and `sed`. Weakness: GNU-only coverage of the errexit path.
  FIXED: added `probe_readonly_path under set -e prints nopath through BSD grep
  and sed` (PATH-shadowed stubs for grep and sed, same command and asserts).
  The source works under the stubs (case green).
- cwd argument: `$BATS_TEST_TMPDIR`, an existing directory passed as `$3`
  (positional, quoted), not interpolated into the script string; sound.
- Whitespace: all operands are quoted positionals; the text contains spaces and
  is passed through `printf "%s\n"`. The tmpdir holds no whitespace (setup
  asserts `%q`-clean). Sound.
- No `# MUT` text remains in `lib/` or `tests/`.

## Run

`bats tests/probes-readonly-resolve.bats` (one foreground process): 9 ok,
0 not ok. The new BSD case was not itself mutated (one mutation per dispatch).
