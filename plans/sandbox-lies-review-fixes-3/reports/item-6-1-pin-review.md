# Item 6.1 + 6.2 — pin re-check (M6, M9, M10)

Scope: the three cases added by the last commit, re-checked under mutations
different from `item-6-1-pin.md`. No test or implementation edited; no weakness
found.

## Mutation proof

One mutation per case, applied by exact string replacement (each anchor
occurred once), landed proof with `command grep`, one foreground bats process
per file.

| Case | Mutation | Landed | Result |
|---|---|---|---|
| M6 "extract skips scalar and array JSONL lines..." | `corpus-eval.py:145` `isinstance(e, dict)` -> `isinstance(e, (dict, int))` | grep hit line 145 | `not ok 4`, `[ "$status" -eq 0 ]` failed (corpus-eval.bats:88): scalar `42` reaches `e.get` and raises |
| M9 "a scalar and an array JSONL line..." | `extract-fixtures.py:154` `isinstance(e, dict)` -> `isinstance(e, (dict, list))` | grep hit line 154 | `not ok 3`, `assert_cut_verbatim` failed (status assertion; array `[1]` raises) |
| M10 "a null text item..." | `extract-fixtures.py:177` `or ""` -> `or "X"` | grep hit line 177 | `not ok 4`, `cmp` failed at byte 1 (extract-fixtures.bats:87): the cut starts `X`, not `\n` |

Each red is a failed assertion (`[ ]` or `cmp`), not a harness error. M9 and M10
shared one run of extract-fixtures.bats (cases 1-2 stayed `ok`).

Restore: strings swapped back. `command grep -c` for `MUT`, `(dict, int)`,
`(dict, list)`, `or "X"` -> 0 in both files; `git diff --stat -- tests/*.py`
empty; extract-fixtures.bats re-run: 4 passed. No `# MUT` text remains.

## Wrong-reason hunt

- M6/M9 lines: `42` and `[1]` are valid JSON, so `json.loads` succeeds and the
  reader reaches the `isinstance` guard (not the `except` branch). The lines
  precede the matching call, so a guard that stops reading (`return`/`break`)
  also reds (no survivor / no cut). Each half is covered separately: the scalar
  half by a mutant admitting ints, the array half by one admitting lists.
- M6 expected survivor file is produced by `one_call` through the normal path;
  absent guard, the exit status fails first, so the file assertion is not the
  only observable.
- M9 expected bytes equal `lock_text`, the call's recorded result; nothing else
  in the corpus matches the SPEC entry, so a cut from another source cannot
  satisfy `cmp`.
- M10 expected `"\n" + lock_text` follows from `"\n".join(["", text])`. It pins
  the empty replacement (`"X"`, `"None"` via `str()`, and a filter dropping the
  item all change byte 1 or the leading newline) and the raise under
  `x.get("text", "")` (status, per the pin report). The null item is the first
  list element, so the join separator is observable. Length stays inside the
  SPEC window (60..4000).

## Verdict

Ready. No weaknesses found; no fixes applied.
