# Minor batch C, RED (findings 9 and 29)

Source unchanged, nothing committed. Added cases: `tests/corpus-eval.bats`
(120 to 170 lines) and `tests/extract-fixtures.bats` (93 to 147 lines). Both
already load `helpers/bsd-stubs`; neither tool calls a stubbed tool.
`tests/docs.bats` green with the new cases.

## Finding 9: holds

`cmd_aggregate` does `fname, vs = line.split("\t", 1)`; a line with no tab
raises ValueError (seen: traceback, exit 1). Existing treatment of a bad
verdict line: skipped and counted in `verdict lines skipped, no manifest
entry: N` (an unmatched file name). A no-tab line has no manifest entry
either, so the test pins that same counter. Case: "aggregate counts a verdict
line with no tab as skipped, without a traceback" (one good line, one
`notabhere`; asserts exit 0, no Traceback on stderr, exact line `... entry:
1`, and the good file's hit still printed).

- Fails on unchanged code: `run -0` exit status assertion (expected 0, got 1),
  ValueError on stderr.
- Fails in the world where: a no-tab line crashes, or is dropped without
  counting (count 0), or is counted with the matched file (count 2 or more).
  The exact-line match on 1 distinguishes these; the good line alone cannot
  produce a skipped count of 1.

## Finding 29: holds in part

Reached and fatal on unchanged code (each red on `run -0` status or the
`Traceback` assertion; traceback text seen for the corpus-eval ones):

- corpus-eval "extract skips a Bash tool_use whose id is a list": TypeError
  unhashable `list` at `bash_cmds[b.get("id")]`.
- corpus-eval "extract skips a tool_result whose tool_use_id is a list":
  TypeError at `tid not in bash_cmds`.
- corpus-eval "extract leaves a subdirectory in survivors and still drops the
  stale files": IsADirectoryError at `stale.unlink()`. Asserts exit 0, no
  Traceback, the new survivor cut, a stale regular file removed. It does not
  pin what becomes of the subdirectory (left or removed), only that extract
  completes.
- extract-fixtures: list `id` on a tool_use, list `tool_use_id` on a
  tool_result, integer `timestamp`, integer `text` item in a list-form
  tool_result (4 cases). Each fails on the `Traceback` stderr assertion.
  The first three then require the cut to equal the call's output verbatim
  (`assert_cut_verbatim`); the integer-text case only requires exit 0 and the
  lock text contained in the cut, since dropping the item and reading it as an
  empty line (as the null guard does) are both fair.

Does NOT hold for `cmd_extract`: integer `text` and integer `timestamp`.
`result_text` already guards with `isinstance(..., str)` and `ts` is only
dumped into the manifest by `json.dumps`. I wrote both cases; they were green
on unchanged code, so they were removed (nothing to fix; no mutation proof
wanted for a path the tool does not reach).

State of the world that fails each, and what else could produce the result:

- list id/tool_use_id cases: green only if the corpus line with the list is
  skipped and the later normal call is still processed. A crash fails;
  clearing all state or aborting the file would also lose the sibling call,
  and the sibling's survivor/cut assertion catches that.
- subdirectory: green needs exit 0 and the stale regular file gone, so
  skipping only the unlink loop altogether (leaving the stale file) fails.
- integer timestamp/text: as above; the `Traceback` check is the assertion
  because a crash is the failure, and exit status alone is also asserted by
  the later checks.

Mutation proof: none needed; every kept case is red on unchanged code.
