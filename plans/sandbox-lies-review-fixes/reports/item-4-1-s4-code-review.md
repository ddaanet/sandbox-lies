# Review: Item 4.1 slice 4 — code review (GREEN)

**Scope**: the GREEN commit
`✨ Item 4.1/4 — uniq with an output operand is a writer`: the `uops` block in
`_readonly_readfile_arg` (`lib/probes-readonly-command.sh`), its comment, and
the `|` reset. The header comment and `docs/references/readonly-path.md` belong
to the docs step and were not touched. **Date**: 2026-10-05. **Mode**: review +
fix.

## Summary

GREEN's counter handles the slice's tests and its reset at `|` works. Its skip
rule, though, which skipped any word matching `-*` or `*'<'*`, missed real
operands in three shapes. In each one a writing segment read as a reader, and
the reported `readfile=` could name the file uniq writes. It also counted a
descriptor duplication such as `2>&1` as an operand. I rewrote the skip rule;
every edge case below now gives the safe answer, and precommit passes.

**Overall Assessment**: Ready

## Edge probes

I called `_readonly_readfile_arg` on `_readonly_tokenize` output directly. The
table shows GREEN's result, then the result after the fix.

| Command | GREEN | Fixed | Correct (bash semantics) |
| --- | --- | --- | --- |
| `uniq - out.log` | `out.log` | none | writes out.log: writer |
| `cat a.log \| uniq - out.txt` | `a.log` | none | uniq segment writes |
| `uniq - in.log` | `in.log` | none | writes in.log |
| `uniq x<in.log out.log` | `in.log` | none | reads x, writes out.log |
| `uniq in.log x<y` | `in.log` | none | writes x |
| `uniq -- -x.txt out.log` | `out.log` | none | writes out.log |
| `uniq -c in.log 2>&1` | none | `in.log` | reader |
| `uniq -- in.log out.log` | none | none | writer |
| `uniq <in.log out.log`, `uniq < in.log out.log` | `in.log` | `in.log` | reader of out.log; < target first |
| `uniq 0<in.log out.log` | `in.log` | `in.log` | reader |
| `uniq -c<in.log` | `in.log` | `in.log` | reader |
| `uniq -- a \| uniq -y in.log` | n/a | `in.log` | `uend` resets at `\|` |
| `uniq a b; cat in.log` | none | none | writer in segment 1 |

The `<in.log out.log` rows report the `<` target ahead of out.log, which uniq
actually reads. That comes from the existing first-candidate rule, not from this
slice, and it is not a missed writer.

## Issues Found

### Critical Issues

None.

### Major Issues

1. **A lone `-` was skipped as an option**
   - Location: `lib/probes-readonly-command.sh`, uniq block, pattern `-*`.
   - Problem: `-` is uniq's stdin operand. Skipping it made the output operand
     look like the first operand. `uniq - out.log` printed `readfile=out.log`,
     the file the command writes, which is the wrong-value case.
     `cat a.log | uniq - out.txt` printed `readfile=a.log` for a pipeline that
     writes.
   - Fix: options are matched by `0:-?*`, so a lone `-` falls through and
     counts.
   - **Status**: FIXED

2. **A `<` word's operand prefix was never counted**
   - Location: same block, pattern `*'<'*`.
   - Problem: slice 2 treats text ahead of a `<` that is not a descriptor number
     as an operand (`x` in `x<in.log`), and grep, sed and awk follow that rule.
     GREEN skipped every `<` word, so `uniq x<in.log out.log` and
     `uniq in.log x<y` were readers with `readfile=in.log`, although both write.
   - Fix: a `<` word counts when `${word%%<*}` holds a non-digit. This is the
     same test the pattern-role block uses. An empty prefix (`<in.log`) or a
     descriptor (`0<in.log`) still does not count.
   - **Status**: FIXED

### Minor Issues

1. **Words after `--` were skipped as options**
   - Location: same block.
   - Problem: `uniq -- -x.txt out.log` writes out.log, and GREEN printed
     `readfile=out.log`. The name has to open with `-`, so this is rare. When it
     does happen, though, the output points at the written file.
   - Fix: a new local, `uend`, is set by `--` in a uniq segment and reset at
     `|`. Once it is set, a word opening with `-` counts.
   - **Status**: FIXED

2. **`2>&1` and `>&2` were counted as operands**
   - Location: same block.
   - Problem: `uniq -c in.log 2>&1` was a writer and lost its `readfile=` line.
     That is the safe side, but it is wrong. A word holding `>` is a
     redirection. When it is anything other than a pure descriptor duplication,
     the `>` check below already sets `all_ok=0`, so leaving it out of the count
     is never unsafe.
   - Fix: `*'>'*` is excluded from the count.
   - **Status**: FIXED

3. **The increment was duplicated across arms**
   - Note: with two counting arms, `[ $((uops += 1)) -lt 2 ] || seg_ok=0` would
     have appeared twice. The arms now do `uops=$((uops + 1))`, and one
     `[ "$uops" -lt 2 ] || seg_ok=0` follows the `case`. This is also plainer
     for Bash 3.2 and `set -u` than an assignment inside `[ ]`. GREEN's form was
     valid there too.
   - **Status**: FIXED

## Fixes Applied

- `lib/probes-readonly-command.sh` `_readonly_readfile_arg`:
  - `uend=0` is added to the locals and to the `|` reset.
  - The uniq block is rewritten as `case "$uend:$word"`:
    - `0:--` sets `uend`.
    - `*'>'*` and `0:-?*` are skipped.
    - A `*'<'*` word counts only when its prefix has a non-digit.
    - Any other word counts.

    A single `[ "$uops" -lt 2 ] || seg_ok=0` follows.
  - The comment states the operand rule: a lone `-`, words after `--`, `>`
    words, and the `<` prefix.
- `Edit` returned no classifier verdict. I applied the change through
  `/tmp/claude-1000/sl/put.py` from a staged copy.

## Mutated-SUT runs

Each mutation was an in-place exact replacement. Each was restored by its
inverse, and `cmp` against the staged fixed copy then reported the file
identical.

- **Operand-counting mutation** (`*'>'* | 0:-?*) ;;` → `*'>'*) ;;`, which makes
  options count): test 18 reds at line 313, the `uniq -c in.log` positive. The
  other 19 tests pass. The positive pins that an option is not an operand,
  against the counting code itself.
- **Test review Minor 1's mutation** (`sort:-o* \` → `sort:-o* | uniq:-c \`):
  test 18 reds at line 313, and the other 19 tests pass.
- No test pins the four fixes above. Reverting them would leave the suite green;
  see Recommendations.

## Checks requested

- Writer interaction: setting `seg_ok=0` feeds the existing `all_ok` roll-up at
  `|`, as `sort -o` does. Probes show that a uniq writer in any segment
  withholds `readfile=` for the whole command.
- Reset: `uops` and `uend` both reset at `|`. Probed with
  `uniq -- a | uniq -y in.log`, which gives `in.log`.
- Bash 3.2 / `set -u`: both locals are initialised, there is plain `$(( ))`
  arithmetic, and `${word%%<*}` is used. No `2>/dev/null` was added.
  `shellcheck -x` is clean.
- `just precommit`: exit 0. It reported bats 297 passed, 0 failed, and passed
  plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links and
  tests. The file is 291 lines.

## Requirements Validation

| Requirement | Status | Evidence |
| --- | --- | --- |
| FR-4 / D4 uniq second operand writes | Satisfied | uniq block; test 18; probes above |
| NFR-2 Bash 3.2 / set -u | Satisfied | no new constructs beyond 3.2 |

## Positive Observations

- GREEN reused `not_op`, so the command word and the name after a lone `<` were
  already excluded. The `|` reset sits with the other per-segment state.
- Writer marking goes through `seg_ok`, the same path as `sort -o`, rather than
  a new mechanism.

## Recommendations

- Test gaps, for the orchestrator to schedule. All are one-line negatives in
  test 18's loop, each paired with the existing positive:
  - `uniq - out.log`
  - `uniq x<in.log out.log`
  - `uniq -- -x.txt out.log`
  - a positive `uniq -c in.log 2>&1`

  Each one reds against GREEN's original block.
- Docs step residuals:
  - `uniq -<in.log out.log` is a lone `-` glued to a redirection. It is still
    skipped as an option.
  - A uniq option with a separate argument (`-f 1`, `-s 2`) counts that argument
    and errs toward writer, per the orchestrator decision.
