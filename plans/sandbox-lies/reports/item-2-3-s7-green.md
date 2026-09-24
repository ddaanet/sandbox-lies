# Item 2.3 slice 7 — GREEN

## Test-file fix

Restored `load helpers/bsd-stubs` in `tests/hook-cap.bats`, above
`load helpers/hook`, matching the load order in every other bats file
(`tests/hook.bats`, `tests/hook-malformed.bats`, `tests/verdicts.bats`,
`tests/matchers.bats`) — the runbook's cross-cutting Portability rule
requires every new bats file to load it, and the test review had dropped it
as unused.

## Implementation

`hooks/annotate.sh`'s name loop, in the block that appends a verdict's
paragraph to `context`: the human line is now appended unconditionally
first (it was already unconditional, just reordered ahead of the cap
check), then the candidate context — `context` plus the joining newline
plus the new paragraph, or the paragraph alone when `context` is still
empty — is measured in bytes and only assigned back to `context` when that
measurement is at or under 2048. A paragraph that would take it past 2048
is skipped with `continue`, leaving `context` unchanged so a later, smaller
paragraph can still be tried (skip-and-continue, not stop-at-first-overflow).

Byte counting with no fork: `${#candidate}` counts characters under the
ambient locale, and verdict paragraphs carry multibyte characters (em
dashes), so the count is taken under `LC_ALL=C` instead, where bash treats
the string as single-byte. `LC_ALL` is one of bash's locale special
variables — assigning it re-runs `setlocale()` for the shell — but under
bash 3.2 semantics that takes effect from the *next* simple command on, not
within the one doing the assignment. A scratch probe on this box's bash
(5.2.37) confirmed both the single-line combined form (`LC_ALL=C
candidate_bytes=${#candidate}` as one simple command with two assignments)
and the sequential form read the correct byte count here — so bash 5.2
alone would not have caught a mistake — but the dispatch's bash-3.2 caveat
rules the combined form out for the portability contract this repo holds
every hook script to. The code was written with the save, the `LC_ALL=C`
assignment, the length read, and the restore as four separate statements
from the start, never combined onto one line. The mechanism is documented
inline as a comment at the cap.

No production code beyond that block changed. The comment already present
on the `phantom-chardev` skip was left as-is.

## Order worked

1. Restored the `load helpers/bsd-stubs` line in `tests/hook-cap.bats`.
2. Wrote the cap block in `hooks/annotate.sh` (human line hoisted above the
   cap check; candidate built; `LC_ALL` saved, set to `C`, read, restored
   as four separate statements; drop-and-continue on `-gt 2048`).
3. `scripts/run-bats.sh tests/hook-cap.bats`: 4 passed, 0 failed, first
   attempt — all three previously-red cases and the already-green boundary
   case.
4. `scripts/run-bats.sh tests/`: 86 passed, 0 failed.
5. `just precommit`: `plugin.json, hooks.json, shellcheck, bash -n, rumdl,
   line limits, links, tests` all passed.
6. `git status --porcelain -- hooks lib tests plans/sandbox-lies/reports`
   and `git diff --stat -- hooks lib`: only `hooks/annotate.sh` modified
   (19 insertions, 1 deletion) and the three new/untracked slice-7 files —
   nothing else touched, `lib/` byte-identical to HEAD.

## Checks passed

- `scripts/run-bats.sh tests/hook-cap.bats`: 4 passed, 0 failed
- `scripts/run-bats.sh tests/`: 86 passed, 0 failed
- `just precommit`: plugin.json, hooks.json, shellcheck, bash -n, rumdl,
  line limits, links, tests
- `git status --porcelain -- hooks lib tests plans/sandbox-lies/reports`:
  only the expected files
- `git diff --stat -- hooks lib`: only `hooks/annotate.sh`
