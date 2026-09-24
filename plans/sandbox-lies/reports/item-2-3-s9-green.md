# Item 2.3 slice 9 — GREEN

Scope: make `a name with no verdict contributes nothing` (and the two
`tests/matchers.bats` tests, already green per the RED report) pass, per the
test review's note for GREEN.

## Fix

`hooks/annotate.sh`, name loop: added a guard ahead of the verdict call,

```
declare -F "verdict_${name//-/_}" >/dev/null || continue
out=$("verdict_${name//-/_}" </dev/null) || exit 0
```

`declare -F` is a bash builtin (no fork, bash 3.2 has it). A detected name
with no `verdict_<name>` function now `continue`s past it instead of hitting
the missing-function `command not found` on stderr and the subsequent
`|| exit 0` that discarded every already-computed paragraph (finding 1 of
`item-2-3-s1-code-review.md`). The existing `|| exit 0` on the call itself is
unchanged and still covers a verdict that exists but fails, per that same
finding. Comment above the guard names the source paragraph (Item 2.3) and
the slice.

This is exactly the minimal fix the test review named in its "Note for
GREEN".

## Verification

- `scripts/run-bats.sh tests/hook.bats tests/hook-malformed.bats
  tests/hook-cap.bats tests/hook-verdicts.bats tests/matchers.bats
  tests/docs.bats`: 52 passed, 0 failed.
- `scripts/run-bats.sh tests/`: 94 passed, 0 failed.
- `direnv exec . just precommit`: exit 0, `precommit passed: plugin.json,
  hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests`.
- `git status --porcelain -- hooks lib tests plans/sandbox-lies/reports`:
  `M hooks/annotate.sh`, `M tests/matchers.bats`, `?? …/item-2-3-s9-red.md`,
  `?? …/item-2-3-s9-test-review.md`, `?? tests/hook-verdicts.bats` — no
  other files touched.

## Files changed

- `hooks/annotate.sh`: `declare -F` guard added ahead of the verdict call.
- (carried from RED, unchanged here) `tests/matchers.bats`,
  `tests/hook-verdicts.bats`, the two RED/test-review reports.
