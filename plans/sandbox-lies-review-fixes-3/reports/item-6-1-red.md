# RED report — Items 6.1 (slices 1-3) and 6.2 (slices 1-2)

Files (uncommitted): `tests/corpus-eval.bats`, `tests/extract-fixtures.bats`,
and one shared helper `tests/helpers/corpus.bash` (shellcheck clean; used by
both suites). Both suites load `helpers/bsd-stubs`, keep no `make_bsd_stubs`
case. Tools untouched; nothing under `tests/fixtures/` written (the cutter runs
from a copy in `$BATS_TEST_TMPDIR/scratch/tests/`). Diagnostic text is joined
from fragments in the helper; `tests/docs.bats`: 2 passed, 0 failed.

## Results against the unchanged tools

corpus-eval.bats: 0 passed, 3 failed. extract-fixtures.bats: 0 passed, 2
failed. All five red on an assertion; no case is green, so no mutation proof.

### corpus-eval.bats

1. `extract drops survivors and verdicts left by an earlier, larger run`
   Red line: `[ "${#survivors[@]}" -eq 1 ]` failed (line 48). The `status -eq
   0` and `-e 000002.txt` checks before it pass; the second extract leaves
   `000002.txt` plus `verdicts.tsv`.
   State that fails it: stale `survivors/000002.txt` from the earlier run is
   not removed (and the TSV likewise). Else: extract writing an extra file of
   its own (no: the corpus has one call, counter reaches 1 only).
   Luck: the count is exactly 1 only if the stale file is removed; the TSV
   check is a separate assertion that also reds today.
2. `aggregate skips a verdict line with no manifest entry and counts it`
   Red line: `[ "$status" -eq 0 ]` failed (line 61); output
   `Traceback ... KeyError: '999999.txt'` (from `manifest[f]`).
   State that fails it: a verdict line naming a file absent from the manifest.
   Else: any other aggregate crash (bad manifest) — the manifest here is
   written by the real extract and the other TSV line is valid, and the
   traceback names the key.
   Count pin: a line containing `skipped` (case-insensitive) that has the
   standalone digit 1 (999999.txt is the one unmatched line; the matched
   file count is also 1, so the pin is tied to the `skipped` line, not to the
   "survivor files in manifest: 1" line). Also asserts the output carries
   `-> 000001.txt`, so the valid line still renders. Not reachable by luck:
   needs exit 0 (which today never occurs) and a line with both words.
   Weakness to note: a skipped line printing "skipped 1" with a different
   unrelated 1 also passes; wording stays free.
3. `extract reads a string tool_use input as no command`
   Red line: `[ "$status" -eq 0 ]` failed (line 76); output `Traceback ...
   AttributeError: 'str' object has no attribute 'get'`. The exit status is
   the honest red here, as the Python raises before any survivor file.
   State that fails it: a Bash tool_use with `input` a JSON string (`"ls"`,
   truthy, so `or {}` does not rescue it). Else: none identified — exact
   traceback shown. After the status check, the survivor count is 1 and
   `000001.txt` exists (the later valid call), asserted for after the fix.

### extract-fixtures.bats

Both cases cut SPEC entry `fire-lock-commit-amend` (project
`-Users-david-code-claude-plugin-dev`, day 2026-08-13, command substring `git
commit --amend --no-edit`, output contains the lock refusal's opening words,
60..4000 bytes). The helper's call is 98 bytes. I checked by hand that on a
corpus holding only the matching call the cutter exits 0 and the cut file is
byte-identical to the output (`cmp`), so a red here is not scaffolding.

1. `a null timestamp reads as no day and the cut still lands`
   Red line: `[ "$status" -eq 0 ]` in `assert_cut_verbatim` failed (line 37 of
   the file, called from the test at line 50); output `TypeError: 'NoneType'
   object is not subscriptable` (`e.get("timestamp","")[:10]`).
   State that fails it: a line with `"timestamp": null` and a dict message
   with list content before the matching call. Else: nothing (traceback
   shown). Not luck: the `cmp` of the cut file against the output follows.
2. `a string tool_use input reads as no command and the cut still lands`
   Red line: same status assertion (line 61 call site); output
   `AttributeError: 'str' object has no attribute 'get'`.
   State that fails it: a Bash tool_use with string `input` before the
   matching call. Else: nothing. Exit status is the honest red (Python
   raises before the file is written).

## Fixtures tried and rejected

None beyond the first drafts: a plain `{}`-input line was not used since it is
already green (`or {}`); the string `"ls"` was chosen because it is truthy.
A `null` timestamp line was given a dict message with list content, otherwise
the cutter skips it before reaching `[:10]`.

## Summary

corpus-eval.bats 0 pass / 3 fail; extract-fixtures.bats 0 pass / 2 fail;
docs.bats 2 pass / 0 fail. No `# MUT` text anywhere; no mutations were made.
