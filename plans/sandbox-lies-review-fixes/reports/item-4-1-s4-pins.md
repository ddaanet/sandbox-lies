# Item 4.1/4 pins for the code-review fixes

## Runs added

All in test 18 (`uniq with a second operand is a writer, uniq in.log is not`)
of `tests/probes-readonly-operands.bats`; the loop comment was extended to
cover them.

- Positive loop (asserts `readfile=in.log`): `uniq -c in.log 2>&1`.
- Writer loop (asserts no `readfile=` line): `uniq - out.log`,
  `uniq x<in.log out.log`, `uniq -- -x.txt out.log`.

The file is 373 lines; the BSD case is still last.

## Mutation proof

Each mutation was one exact single-occurrence replacement in
`lib/probes-readonly-command.sh`, restored by the inverse replacement.
After each, `git diff --stat lib/` was empty. Test 18 was the only red test.

- Lone `-`: `*'>'* | 0:-?*) ;;` to `*'>'* | 0:-*) ;;`. Reds `uniq - out.log`
  at `assert_no_readfile`, bats line 322 (the second loop).
- `<` prefix: `*[!0-9]*) uops=$((uops + 1)) ;;` to `*[!0-9]*) ;;`. Reds
  `uniq x<in.log out.log` at line 322.
- `--` handling: `0:--) uend=1 ;;` to `0:--) ;;`. Reds
  `uniq -- -x.txt out.log` at line 322.
- Counting a `>` word: `*'>'* | 0:-?*) ;;` to `0:-?*) ;;`. Reds
  `uniq -c in.log 2>&1` at line 315
  (`grep -qxF 'readfile=in.log'` failed).

The grep for the mutation text found no hit after restoring the first three.
For the fourth, the mutated text is a substring of the restored line, so
the grep count is 1 by construction; the empty `git diff --stat lib/` is the
proof.

## Full suite

`just precommit` exit 0: bats 297 passed, 0 failed; plugin.json, hooks.json,
shellcheck, bash -n, rumdl, line limits, links and tests passed.
