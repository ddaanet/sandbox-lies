# Item 4.2 slice 1 - RED

SUT untouched; no migration of existing `match=` assertions; nothing committed.

## New tests

1. `tests/probes-readonly-members.bats` - "match= names are absolute from a
   subdirectory cwd" (now 190 lines). Scratch repo plus `$repo/sub`, refused
   path `<repo>/a`, command `git merge feat`, cwd `<repo>/sub`; asserts exit 0,
   empty stderr, then `match=<repo>/a`, `match=<repo>/b`, `match=<repo>/e f`.
   Fails: `printf '%s\n' "$output" | grep -qxF "match=$repo/a"` failed (line
   76), on the assertion, not setup.
2. `tests/hook-writes.bats` - "hook restore clause names the match by absolute
   path" (now 126 lines). Real probe, flag absent (the file's
   `hook_copy_tree` and `readonly_payload_file`, payload cwd rewritten to
   `<repo>/sub`). Asserts the `additionalContext` contains the restore list
   of `<repo>/a`, `<repo>/b`, `<repo>/e f` in backticks, followed by "from
   HEAD". Fails on that grep (line 125). The actual context read, via a
   temporary echo that was removed, listed the bare names `a`, `b`, `e f`, so
   the failure is the relative names.

## Placement and choices

- Hook case went in `tests/hook-writes.bats`, not `tests/hook-candidates.bats`
  (375 of 400 lines; its cases stub the probe). hook-writes already has the
  real-probe payload builder.
- `make_scratch_repo` already produces `e f` and `feat` touches a, b and
  `e f`; the shared helper is unedited. `sub` is made in each test.
- The hook assertion matches the whole restore list, not just `<repo>/a`: the
  clause's subject is the refused path `<repo>/a`, so a bare `<repo>/a` needle
  passed before any change (first draft, vacuous).
- Existing tests still pass (the one red in each file is the new test).
  `shellcheck -x` clean on both files.
