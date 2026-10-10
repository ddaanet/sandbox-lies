# Test review — Items 6.1 + 6.2

Files: `tests/corpus-eval.bats`, `tests/extract-fixtures.bats`,
`tests/helpers/corpus.bash`. Tools unedited (`git diff --stat` on both: empty).
Nothing committed.

## Mechanical check

Run once per file against the unchanged tools: corpus-eval 0 passed / 3 failed,
extract-fixtures 0 passed / 2 failed. Each red is an assertion, none passed,
none errored from scaffolding. `docs.bats` 2 passed. shellcheck clean on the
helper and both suites. `git status --short tests/fixtures` empty after the
runs (the cutter runs from a copy in `$BATS_TEST_TMPDIR/scratch/tests/`).
Both suites load `helpers/bsd-stubs`, keep no `make_bsd_stubs` case. HOME is
under `$BATS_TEST_TMPDIR`; both tools resolve `Path.home()`, so no case reads
the host `~/.claude`. Diagnostic text is joined from fragments in the helper.
No `# MUT` or fix text remains.

## Weakness found and fixed

- `aggregate` case (6.1/2): one unmatched line and one matched file both gave 1,
  so a "skipped 1" line could be satisfied by the matched count. Now the
  verdicts file holds one matched and two unmatched lines (`999998.txt`,
  `999999.txt`); the line containing "skipped" must carry a standalone `2`. The
  wording stays free. Test renamed to the plural. Still red at
  `[ "$status" -eq 0 ]` (KeyError at `manifest[f]`).

No other changes. The `!`-negated pipeline was considered and not used (errexit
does not fire on it).

## Per-case: failing state, rival causes

1. `extract drops survivors...` red at `survivors` count (2, not 1). Fails when
   stale `000002.txt` survives. Rival: none; the counter writes only
   `000001.txt` for a one-call corpus. Both stale files are asserted separately
   (count, then `! -e verdicts.tsv`).
2. `aggregate skips...` red at exit status; traceback KeyError on the orphan.
   Rival: a bad manifest ruled out, since the manifest comes from the real
   extract and the matched line is valid.
3. `extract reads a string tool_use input...` red at exit status; the
   AttributeError is at `inp.get("command")`, outline `:152-153`. The string
   `"ls"` is truthy, so `or {}` does not rescue it. The u0 line has no result,
   so it cannot create a survivor; the later valid call is the one counted.
4. extract-fixtures null timestamp: red in `assert_cut_verbatim` status;
   TypeError at `e.get("timestamp","")[:10]` (`:160`). The null line carries a
   dict message with list content, so it reaches that line.
5. extract-fixtures string input: same red; AttributeError at `:165`. The
   timestamp is well-formed, so `:160` cannot be the cause.

Corpus lines are well-formed JSONL for the real reader: with the fixes below the
matching call is found and `cmp` of the cut file against `lock_text` passes.

## Satisfiability and mutation-independence

Each fix applied in place by exact string replacement (each string occurs once),
case run, then reverted by swapping the strings. Restore proved by empty
`git diff --stat` on both tools.

- 6.1/1 full fix (unlink all survivors + unlink `verdicts.tsv`): case green.
  Survivors-only fix: red at `! -e verdicts.tsv`. TSV-only fix: red at the
  survivor count. So a fix removing one of the two stale files is caught.
- 6.1/2 (skip orphan, count it, print `skipped N verdict lines`): green.
- 6.1/3 (non-dict `input` becomes `{}`): green.
- 6.2/1 (`(e.get("timestamp") or "")[:10]`) alone: case 1 green, case 2 red.
- 6.2/2 (non-dict `input` guard) alone: case 2 green, case 1 red.
  Both together: both green. The cases are independent.

## Result

All five cases red on an assertion against the unchanged tools, each satisfiable
by a minimal fix.
