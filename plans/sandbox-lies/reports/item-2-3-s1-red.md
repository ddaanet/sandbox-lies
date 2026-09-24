# Item 2.3 slice 1 — RED

Mode: RED. Nothing committed; stubs, tests and this report are left
uncommitted per the dispatch.

## Stubs written (importable but inert)

- `hooks/annotate.sh` — reads stdin, exits 0, prints nothing.
- `lib/verdicts.sh` — `verdict_phantom_chardev`, `verdict_phantom_untracked`,
  `verdict_phantom_gitadd` defined, each printing nothing.
- `hooks/hooks.json` — `{"hooks":{}}`, valid JSON registering nothing.

## Tests written

- `tests/hook.bats` — the three external-contract tests.
- `tests/verdicts.bats` — the three verdict tests, row table holding the
  three phantom verdicts, outcome `-`.
- `tests/helpers/hook.bash` — `failure_payload`, `post_payload`, `stub_lib`
  per the Interfaces, plus `hook_copy_tree` (necessary plumbing, not itself
  a named interface) which copies `hooks/` and `lib/` under
  `$BATS_TEST_TMPDIR/hook-copy` and sets `HOOK_COPY`; `hook.bats` runs
  `bash "$HOOK_COPY/hooks/annotate.sh"`.

All three new files load `helpers/bsd-stubs` per the cross-cutting
Portability rule (no BSD-stubbed case yet — that's slice 10).

## `scripts/run-bats.sh tests/hook.bats tests/verdicts.bats`

```
not ok 1 gitadd failure payload yields one verdict
# (in test file tests/hook.bats, line 26)
#   `printf '%s' "$output" | jq -e . >/dev/null' failed with status 4
not ok 3 hooks.json names both events
# (in test file tests/hook.bats, line 62)
#   `[ "$status" -eq 0 ]' failed
not ok 4 verdicts under 400 chars
# (in test file tests/verdicts.bats, line 52)
#   `[ -n "$text" ]' failed
not ok 5 verdict text is quiet
# (in test file tests/verdicts.bats, line 64)
#   `[ -n "$(printf '%s' "$all" | tr -d '[:space:]')" ]' failed
not ok 6 no removal instruction
# (in test file tests/verdicts.bats, line 74)
#   `[ -n "$(printf '%s' "$all" | tr -d '[:space:]')" ]' failed

bats: 1 passed, 5 failed
```

Test 2, `quiet fixture yields nothing`, is the one that passed (1 passed
above). Per the dispatch this is expected and by design: an inert hook
yields empty stdout on any input, so this case is a negative by nature and
gets its red only paired with test 1 (same hook script, same invocation
path) — it was **not** weakened to force a false red.

Each failing case fails on a real assertion against the stub, not on the
stub being absent/non-executable:

- Test 1 (`gitadd …`): the hook exits 0 (as a stub must), but its empty
  stdout is not valid JSON, so `jq -e .` fails with status 4 — the first
  assertion downstream of "did the hook run" is what goes red.
- Test 3 (`hooks.json names both events`): `hooks/hooks.json` parses (it is
  valid JSON) but registers nothing, so the `jq -e` query evaluates to
  `false` and exits 1 — `[ "$status" -eq 0 ]` catches it.
- Tests 4–6 (`verdicts.bats`): each asserts the row's/rows' text is
  non-empty *before* checking length, quietness or the removal-instruction
  pattern, exactly so an empty stub verdict fails there rather than passing
  vacuously (`verdict_phantom_*` currently returns nothing).

## `scripts/run-bats.sh tests/docs.bats`

```
bats: 1 passed, 0 failed
```

The self-quiet guard stays green: none of the five new files (three stubs,
two test files, one helper) hold a diagnostic whole. Diagnostic text used
by the hook test (the gitadd fixture's error text) is read from
`tests/fixtures/fire-masks-gitadd-refused.txt` at run time via `cat`, never
inlined in `tests/hook.bats`; the verdict tests build their text by calling
`verdict_phantom_*` at run time, never quoting verdict prose in the source.

## Full suite (regression check)

`scripts/run-bats.sh tests/` — 66 passed, 5 failed (exactly the five above);
no other suite regressed.

## Lint

`shellcheck` over `hooks/annotate.sh`, `lib/verdicts.sh`,
`tests/helpers/hook.bash`, `tests/hook.bats`, `tests/verdicts.bats`; `bash -n`
over the three `.sh`/`.bash` files; `jq empty hooks/hooks.json` — all clean.

## Scope confirmation

No implementation code, no `justfile` change, no memory-file edit, no work
on slices 2–10, Item 2.4, or any later item. `git status` shows only the
five new files under `hooks/`, `lib/`, `tests/` (plus the pre-existing
sandbox-mask dotfiles at the repo root, ignored).
