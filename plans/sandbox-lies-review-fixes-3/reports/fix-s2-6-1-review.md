# Review: pins 6.1/2 and 6.1/3 (commits 37faedb, 8df8cd4)

Verdict: no defect. Both cases kill their mutant on their own assertion.
`tests/corpus-eval.bats` is 120 lines and `tests/corpus-eval.py` 278, both
under 400.

## Inputs

Both cases build their input at run time: the verdicts file by `printf`
into `$OUTDIR`, the corpus lines by `corpus_use_raw_input` under a scratch
`HOME`. No hand-written fixture; no case reads the host `~/.claude`.

## Mutation proof

Baseline: 6 of 6 green before any mutation. Each mutant was an exact
replacement of a string occurring once, proved landed with `command grep`,
restored by the swapped replacement, restore proved by a grep count of 0,
and the suite green after.

6.1/2, `cmd_aggregate`:
`skipped += 1` replaced by `skipped += len(vs.split())` (counts
verdicts, not lines). Only case 3 failed, at its `grep -Fxq "verdict lines
skipped, no manifest entry: 2"` line (79). Case 2, with one verdict per
line, stayed green, so the new case is the one that tells the two apart.
The failing state: an unmatched line with three verdicts and one with none
give 3 under the mutant against 2 by lines.

6.1/3, `cmd_extract`: guard `isinstance(inp, dict) else None`.
Each mutant failed only case 6, at its `[ "$status" -eq 0 ]` line (116),
because the mutated guard calls `.get` on a non-dict and `extract` exits 1:

| mutant | shape that crashes |
| --- | --- |
| `not isinstance(inp, str)` (the finding's mutant) | list, number |
| `isinstance(inp, (dict, list))` | list |
| `isinstance(inp, (dict, int))` | number |
| `isinstance(inp, (dict, type(None)))` | null |

The guard exists to route every non-dict input to no command. The case
carries a list, a number and a null on separate lines, so a mutant
admitting any one shape is caught; the string shape stays in its own
case 4. The fixture lines have no paired result, so the crash is the only
signal, and it is a status assertion, not an error from a missing probe.

## Result

No change to tests or code. The tree under `tests/` is clean after the
runs. Only this report is committed.
