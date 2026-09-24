# Item 2.3 slice 10 — RED

## Test added

`tests/hook.bats`, `@test "hook under BSD stubs"` (before `"the command is not
read"`; file now 380 lines, under the 400-line cap).

Reuses slice 1's gitadd failure payload
(`tests/fixtures/fire-masks-gitadd-refused.txt`, `failure_payload`). Computes
the hook's stdout in the same run without stubs via `run_hook`, asserts it
non-empty, then re-runs the identical payload with `make_bsd_stubs grep` on
`PATH` and asserts the stubbed run's stdout is exactly equal to the unstubbed
one. Only `grep` is stubbed — `hooks/annotate.sh` calls no `sed` (slice 1's
code review), and `mktemp` left the `detect` path at slice 8 — matching the
slice 10 text verbatim.

## Mutation proof

`lib/matchers.sh`, `match_phantom_gitadd`: `grep -qE '...'` → `grep -qP
'...'`.

- Under GNU grep this is silent: `-P` matches the same literal pattern as
  `-E` here (no lookaround, no backreferences), so the hook's output for
  every fixture is byte-identical and the rest of the suite — including the
  other 12 cases in `tests/hook.bats` — stays green.
- Under the BSD `grep` stub, `-qP` is refused outright (`grep: invalid
  option -- -qP`, exit 2), so `match_phantom_gitadd` stops firing,
  `phantom-gitadd` is dropped from `detect`'s output, and the hook goes
  silent for this fixture — the new test's exact-equality assertion reds.

Verified by hand, three runs of `scripts/run-bats.sh tests/hook.bats`:

1. Baseline (HEAD `lib/matchers.sh`): 13 passed, 0 failed.
2. `-qE` → `-qP` via `Edit`, same command: **12 passed, 1 failed** — only
   `not ok 12 hook under BSD stubs` fails (`[ "$output" = "$expected" ]`);
   every other case, including the pre-existing gitadd cases that don't
   stub `grep`, stays green.
3. Reverted `-qP` → `-qE` via `Edit`: 13 passed, 0 failed again; `git diff
   --quiet hooks lib` confirmed the tree is back to byte-identical with
   HEAD before this report was written.

Note: this same mutation also reds `tests/matchers.bats`'s existing
`"the whole fixture sweep survives BSD grep, sed and mktemp"` (a
matcher-layer stub test already in the suite) — expected, since both tests
exercise the same `match_phantom_gitadd` code path at different layers; it
does not disqualify the mutation, since the "every other test green" bar is
about unstubbed/GNU-grep runs, which stayed green throughout.

## Runs

- `scripts/run-bats.sh tests/hook.bats` — 13 passed, 0 failed (final state).
- `scripts/run-bats.sh tests/docs.bats` — 1 passed, 0 failed.
- `scripts/run-bats.sh tests/` (full suite) — 95 passed, 0 failed.

## Scope

Out of scope for this dispatch, left to the orchestrator's GREEN: memory
retirement, design status flips, changelog wall times. Item 2.4 untouched.

## Done state

`git status --porcelain --untracked-files=no` shows only `M tests/hook.bats`.
`git diff --quiet hooks lib` passes (byte-identical to HEAD). Nothing
committed. Untracked zero-byte/char-device dotfiles at the repo root are
sandbox masks (`[[sandbox-effects]]`), not part of this diff.
