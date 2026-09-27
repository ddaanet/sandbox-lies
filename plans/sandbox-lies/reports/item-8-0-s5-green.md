# Item 8.0/5 GREEN report — the no-target merge clause needs git's error

Slice: `runbook.md` Item 8.0 entry 5. Scope: `lib/probes-readonly-facts.sh`,
`lib/verdicts.sh`, and comment updates in `lib/probes-readonly.sh`.

## Changes per file

### lib/probes-readonly-facts.sh

- `_readonly_partial_checkout_text` gains git's third partial-checkout
  needle, `cannot create directory at`, built from two fragments
  (`'cannot create'` / `'directory at'`) the same way the existing two
  needles are, so the file still holds none of the three phrases whole
  (self-quiet, FR-11).
- `_readonly_print_facts` now tracks whether the text holds any needle in a
  local `partial` flag (0/1, set via `! _readonly_partial_checkout_text
  "$text" || partial=1`), still gating the whole fact block on "a merge
  subcommand or a partial-checkout needle" (`[ -z "$sub" ] && [ "$partial"
  -eq 0 ]` short-circuits as `sub` empty and no needle did before), and
  prints `partial=1` right after `merge=1` when the flag is set. No other
  printed fact or ordering changed.
- Header comment, `_readonly_print_facts`'s own docstring, and
  `_readonly_repo_facts`'s NFR-3 remark on the past-1000-files fallback
  updated to name `partial=1` and to say the generic "restore them from
  HEAD" clause stands in only when the probe printed `partial=1` — matching
  the new verdict-side gating.

### lib/verdicts.sh

- `verdict_readonly_path` parses a new `partial=` stdin key into a local
  `partial` (empty/non-empty, same style as `merge`/`target`).
- The no-target branch of the merge-clause composition (`merge=1` present,
  `target=` absent) now requires `[ -n "$partial" ]` before composing the
  "restore them from HEAD" clause; with no `target=` and no `partial=1` it
  falls through to `rest=" $act"` (the plain, capitalised act), unchanged
  from the pre-slice baseline text. The `target=`-present branches (match
  list, or no clause when no `match=`) are untouched, per the slice's "match=
  lines keep their clause without partial=1" rule.
- Header comment above `verdict_readonly_path` updated to list `partial=1`
  among the stdin facts the tail composes from.

### lib/probes-readonly.sh

- Header comment's fact list (`readfile=/merge=1/target=/match=` →
  `readfile=/merge=1/partial=1/target=/match=`) updated; no code change in
  this file.

## Tests made to pass, in order

1. `tests/probes-readonly-facts.bats`, `partial=1 fires with merge=1 for
   each of git's three partial-checkout errors, not for another tool's
   refusal` — grew `_readonly_partial_checkout_text`'s third needle and
   `_readonly_print_facts`'s `partial=1` emission together (one change, the
   two are the same behaviour); ran the file alone: 15 passed, 0 failed.
2. `tests/verdicts-readonly.bats`, `readonly-path merge alone with no
   partial=1 states the act alone, capitalised` (and the already-green guard
   `readonly-path merge with target, partial=1 and no match still states the
   act alone`) — added the `partial=` parse and the `elif [ -n "$partial"
   ]` gate in `verdict_readonly_path`; ran the file alone: 14 passed, 0
   failed.
3. `tests/hook-candidates.bats`, `the no-target merge clause needs git's own
   partial-checkout error, not any refused write` — no further change
   needed; the probe and verdict changes above already carry the real,
   unstubbed probe through the hook correctly. Ran the file alone: 10
   passed, 0 failed.

Each file was run alone after its own fix, one test at a time as the slice
demanded; no regression appeared in the sibling tests of the same file at
any step (verified by the full per-file pass counts above, which include
every test in each file, not just the new one).

## Full suite and gate

- `scripts/run-bats.sh tests/`: 249 passed, 0 failed.
- `just precommit`: exit 0. Recap line: `precommit passed: plugin.json,
  hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests`. No
  warnings reported by any check (shellcheck, `bash -n`, rumdl, line
  limits, link check all silent beyond the recap).

## Scope check

No `hooks/annotate.sh`, phantom/lock verdict, or matcher file touched.
`lib/probes-readonly-command.sh` untouched — the slice needed no change to
command scanning, only to the text-side needle and the verdict-side gate.
