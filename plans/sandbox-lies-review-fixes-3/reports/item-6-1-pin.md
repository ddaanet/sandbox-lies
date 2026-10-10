# Item 6.1 + 6.2 — survivor pins (M6, M9, M10)

Scope: the three same-class guards from `item-6-1-code-review.md` (the
`isinstance` guard in `tests/corpus-eval.py` `cmd_extract`, the `isinstance`
guard and the null-text read in `tests/extract-fixtures.py` `iter_calls`).
One case added per survivor. No implementation changed. Each mutation run used
one bats process in the foreground.

## Tests added

- `tests/corpus-eval.bats`: "extract skips scalar and array JSONL lines beside
  a survivor" (M6).
- `tests/extract-fixtures.bats`: "a scalar and an array JSONL line beside the
  call do not stop the cut" (M9).
- `tests/extract-fixtures.bats`: "a null text item in a list-form tool_result
  reads as an empty line" (M10).

All three were green on the unmutated code before the mutation runs.

## Mutation proof

### M6 — corpus-eval guard

- Mutation: `                    if not isinstance(e, dict):` → `                    if False:  # MUT`
  (anchor counted once in `tests/corpus-eval.py` before the edit).
- Landed: `command grep -n 'MUT'` → `145:                    if False:  # MUT`.
- Red: `not ok 1 extract skips scalar and array JSONL lines beside a survivor`,
  `[ "$status" -eq 0 ]' failed` (corpus-eval.bats line 88). The reader raises
  on the scalar `42` line; the failure is the exit-status assertion.
- Restore: swap back `if False:  # MUT` → `if not isinstance(e, dict):`.
  Proof: `command grep -c MUT` → 0; `command grep -c 'if False:'` → 0; the case
  is `ok 1`.

### M9 — extract-fixtures guard

- Mutation: `            if not isinstance(e, dict):` → `            if False:  # MUT`
  (anchor counted once in `tests/extract-fixtures.py` before the edit).
- Landed: `154:            if False:  # MUT`.
- Red: `not ok 1 a scalar and an array JSONL line beside the call do not stop
  the cut`, `assert_cut_verbatim' failed` (from line 72; the status assertion
  inside the helper).
- Restore: swap back `if False:  # MUT` → `if not isinstance(e, dict):`.
  Proof: `command grep -c MUT` → 0; `command grep -c 'if False:'` → 0; the case
  is `ok 1`.

### M10 — null text read

- Mutation: `x.get("text") or ""` → `x.get("text", "")` (anchor counted once
  before the edit; the mutant parses, `python3 -c 'ast.parse'` ok).
- Landed: `177:                        t = "\n".join(x.get("text", "") for x in t`.
- Red: `not ok 1 a null text item in a list-form tool_result reads as an empty
  line`, `[ "$status" -eq 0 ]' failed` (line 85). The shape predicted this: the
  `None` item makes the join raise `TypeError`, so the exit status is the
  observable. Isolated reproduction: `sequence item 0: expected str instance,
  NoneType found`. The `cmp` against `"\n" + lock_text` was not reached; no
  adaptation of the assertion was needed.
- Restore: swap back `x.get("text", "")` → `x.get("text") or ""`. Proof:
  `command grep -c 'x.get("text", "")'` → 0; `command grep -c MUT` → 0; the case
  is `ok 1`.

## Fixtures tried and rejected

- M10 first attempt: the mutant carried a trailing `  # MUT` comment inside the
  call (`x.get("text", "")  # MUT`). The comment swallowed `for x in t`, so the
  file failed with a SyntaxError, not the null-text behaviour. Discarded: the
  file was restored to `x.get("text") or ""` (grep proof: 0 `MUT`, 1 original
  form), then M10 was re-applied without the comment, as above.

## Suite results

- `tests/corpus-eval.bats`: 4 passed. `tests/extract-fixtures.bats`: 4 passed.
- `git diff -- tests/corpus-eval.py tests/extract-fixtures.py` matches the
  reviewer's uncommitted guards exactly after the restores (the two `.py` files
  are unchanged apart from those guards).

## Gate

- `just precommit`: exit 0 (`PRECOMMIT_EXIT=0`), run unsandboxed in the
  foreground.
- Recap: `precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl,
  line limits, links, python compile, tests`; bats `411 passed, 0 failed`.
- Warnings printed by precommit: none.
