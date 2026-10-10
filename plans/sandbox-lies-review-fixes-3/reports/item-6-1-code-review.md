# Code review — Items 6.1 + 6.2 (`tests/corpus-eval.py`, `tests/extract-fixtures.py`)

Scope: `git show HEAD` for the two tools. Tests not edited. Nothing committed.
Requirements validation skipped beyond the outline (NFR-1, FR-8 named there).

**Overall Assessment**: Ready (three same-class guards added, uncommitted;
survivors listed below for a cheaper agent).

## Against the outline

- Slice fixes (survivor/TSV removal, unmatched-verdict skip with count,
  non-dict `input` in both tools, null timestamp): match the outline.
- Docstring loop: `>` once after `done`, the `printf` has no `>>`. Correct.
- Prefilter comment: says `crw-` covers only the `/dev/null` mask's mode.
  Truthful.
- `pick()`: all-projects branch gone, `(project or '*')` became `project`.
  Every `SPEC` entry names a project (tuple unpack in `main()`), and `main()`
  is the only caller, passing it. Correct.

## Issues found (all in the same functions, same defect class)

1. **Non-dict JSONL line kills the reader** (jsonl-reader-type-guard).
   `json.loads` returning a scalar or list survived the `except`, then
   `e.get("message")` raised `AttributeError`. Sites: `cmd_extract`
   (`corpus-eval.py` message read) and `iter_calls` (`extract-fixtures.py`).
   **Status**: FIXED — `if not isinstance(e, dict): continue` before the read,
   in both.
2. **`null` `text` in a list-form tool_result** (`extract-fixtures.py`
   `iter_calls`): `x.get("text", "")` returns `None` for an explicit null and
   `"\n".join` raises `TypeError`. **Status**: FIXED — `x.get("text") or ""`
   (keeps the old empty-string contribution for a missing key, so re-cut
   bytes are unchanged).
3. **Noted, not changed**: `cmd_aggregate` `line.split("\t", 1)` raises
   `ValueError` on a tab-less verdict line. The documented loop always emits a
   tab and the outline names only unmatched files; treating it as skipped is a
   behaviour choice. **Status**: DEFERRED — outside the outline's slice 2.
   `corpus-eval.py` `ts = e.get("timestamp", "")` with a null is stored and
   printed as `None`; no crash, not a defect.

## Mutation testing

Method: exact replacement of a once-occurring string, `command grep` proof it
landed, one bats process foreground, swap-back restore, `command grep` proof
(new text 0, old text 1). No mutation marker text remains in `tests/`. Final
`git diff --stat` shows only the fixes above (2 + 4 lines); the HEAD code is
otherwise untouched.

| # | Mutation | Result |
| --- | --- | --- |
| M1 | `stale.unlink()` -> `pass` | RED (survivor count 2, `corpus-eval.bats` case 1) |
| M2 | TSV `.unlink(missing_ok=True)` -> `pass` | RED (`! -e verdicts.tsv`) |
| M3 | `if fname not in manifest:` -> `if False:` | RED (exit status, KeyError) |
| M4 | `skipped += 1` -> `skipped += 0` | RED (count `2` assertion) |
| M5 | corpus-eval `isinstance(inp, dict)` guard removed | RED (exit status) |
| M6 | corpus-eval `isinstance(e, dict)` guard (new) -> `if False:` | SURVIVED |
| M7 | `(e.get("timestamp") or "")` -> `e.get("timestamp", "")` | RED (case 1) |
| M8 | extract-fixtures `isinstance(inp, dict)` guard removed | RED (case 2) |
| M9 | extract-fixtures `isinstance(e, dict)` guard (new) -> `if False:` | SURVIVED |
| M10 | `x.get("text") or ""` -> `x.get("text", "")` | SURVIVED |

First M10 attempt appended a comment that swallowed `for x in t` (SyntaxError,
both cases red): invalid mutant, discarded and rerun without the comment.

## Survivors

All three guards are mine, added in this review, with no test (tests are
out of scope here).

- **M6** — `tests/corpus-eval.py`: replace
  `                    if not isinstance(e, dict):` with
  `                    if False:`. Test shape: corpus holds a line `42` and a
  line `[1]` (scalar and array) beside one valid survivor; `extract` exits 0
  and writes the survivor. Add to `tests/corpus-eval.bats`.
- **M9** — `tests/extract-fixtures.py`: replace
  `            if not isinstance(e, dict):` with `            if False:`. Test
  shape: a `42` line and a `[1]` line before the matching call; exit 0 and the
  cut bytes equal the call's output (reuse `assert_cut_verbatim`).
- **M10** — `tests/extract-fixtures.py`: replace `x.get("text") or ""` with
  `x.get("text", "")`. Test shape: the matching call's result `content` is a
  list `[{"type":"text","text":null},{"type":"text","text":"<lock_text>"}]`;
  exit 0 and the cut file equals `"\n" + lock_text` (the null item contributes
  an empty line, joined by newline).

## Gate

`python3 -m py_compile` on both: ok. `scripts/run-bats.sh` corpus-eval 3
passed, extract-fixtures 2 passed. `just precommit` exit 0: 408 passed, 0
failed.

## Fixes applied

- `tests/corpus-eval.py` `cmd_extract` — dict guard on parsed line.
- `tests/extract-fixtures.py` `iter_calls` — dict guard on parsed line; null
  `text` read as empty.
