# Item 4.1 slices 2-3 — RED

Batched dispatch: slice 2 (`held interpolates the pid`) and slice 3 (`orphan
and unknown interpolate size and age`, plus the neither-bytes-nor-age case
from Item 2.4 slice 3's code review). No SUT file touched — `lib/verdicts.sh`,
`hooks/annotate.sh` and `lib/probes.sh` are unchanged from slice 1's GREEN;
`verdict_git_lock`/`verdict_config_lock` still carry the literal `N`
placeholder for `held`/`orphan`/`unknown`, so every new assertion below
exercises behaviour genuinely absent from the SUT.

## New file content

### `tests/hook-locks.bats`

- New helper `assert_lacks <haystack> <pattern>` — `run bash -c … grep -qF`
  then `[ "$status" -eq 1 ]`, so a grep-under-`!` (SC2314, not a Bats
  failure) is never used; shellcheck is clean.
- New helper `stub_probe_kv <name> <outcome> [line...]` — sibling to
  `stub_probe`, appends a `probe_<name>` to the copied `lib/probes.sh` that
  prints `<outcome>` then each extra `<line>` (e.g. `pid=4242`, `bytes=7`,
  `age=12`) instead of the fixed `path=stub`, so a case can feed the probe
  key=value lines the hook passes on as the verdict's stdin.
- Three new `@test` cases, all against `fire-lock-add-commit.txt` as a
  failure payload, per the notes:
  - `held interpolates the pid` — `stub_probe_kv git_lock held 'pid=4242'`;
    asserts `additionalContext` contains `pid 4242` and `systemMessage`
    equals `index.lock — held by pid 4242`.
  - `orphan and unknown interpolate size and age` — `stub_probe_kv git_lock
    orphan 'bytes=7' 'age=12'`; asserts `additionalContext` contains
    `7 bytes` and `age 12s`. Same fixture and payload, then `stub_probe_kv
    git_lock unknown 'bytes=7' 'age=12'`; asserts `additionalContext`
    contains `7 bytes`, `age 12s` and `no holder check is available`.
  - `orphan with neither bytes nor age interpolates no empty value` —
    `stub_probe_kv git_lock orphan` (no extra lines); asserts
    `additionalContext` contains none of ` bytes`, `age s`, `()`, `(,`,
    `N bytes`, `age Ns` (empty-interpolation and literal-placeholder
    markers), and still contains `no process holds it` — the sentence reads
    as prose with the parenthetical dropped rather than left empty.

### `tests/verdicts.bats`

- New test `verdict_git_lock held|orphan|unknown interpolate probe values` —
  calls `verdict_git_lock held` fed `pid=4242` on stdin, `verdict_git_lock
  orphan` and `verdict_git_lock unknown` each fed `bytes=7`/`age=12`,
  asserting the exact two-line text transcribed from
  `docs/references/lock-detectors.md`'s git-lock Verdicts list with the `N`
  placeholders substituted by those values (`held`: `A process (pid 4242)
  holds the lock. Wait for it, then retry.` / `index.lock — held by pid
  4242`; `orphan`: `The lock exists outside the sandbox (7 bytes, age 12s)
  and no process holds it. …` / `index.lock — present, no holder`;
  `unknown`: `The lock exists outside the sandbox (7 bytes, age 12s); no
  holder check is available here. …` / `index.lock — present, holder
  unknown`). Per the dispatch note, this covers `verdict_git_lock` only, not
  `verdict_config_lock` — the hook-level cases likewise only exercise
  `git_lock` via the `fire-lock-add-commit` fixture, matching the notes'
  scoping.

## Missing-value wording decided here (for GREEN)

The dispatch left the missing-value wording to this report. Chosen: when a
probe supplies neither `bytes=` nor `age=` (the "neither" case named in the
slice text), the parenthetical clause is dropped entirely rather than filled
with an empty or placeholder value — the orphan paragraph reads "The lock
exists outside the sandbox and no process holds it. Retry the command
unsandboxed; a second identical failure means the lock predates this
session." (and analogously for `unknown`, dropping the `;` clause's
parenthetical). The RED assertions only pin the negative space (no empty
interpolation, no literal `N`) plus that the sentence around it survives
intact (`no process holds it` still present); they do not pin the exact
dropped-clause wording, leaving GREEN free to choose it exactly as long as it
reads as a sentence.

## Per-test output

`bats tests/hook-locks.bats tests/verdicts.bats`:

```
1..12
ok 1 mask outcome through the hook
ok 2 mask paragraph is flag-neutral under flag true
ok 3 mask outcome through the hook under BSD stubs
not ok 4 held interpolates the pid
# (in test file tests/hook-locks.bats, line 133)
#   `printf '%s' "$ctx" | grep -qF 'pid 4242'' failed
not ok 5 orphan and unknown interpolate size and age
# (in test file tests/hook-locks.bats, line 146)
#   `printf '%s' "$ctx" | grep -qF '7 bytes'' failed
not ok 6 orphan with neither bytes nor age interpolates no empty value
# (from function `assert_lacks' in file tests/hook-locks.bats, line 44,
#  in test file tests/hook-locks.bats, line 171)
#   `assert_lacks "$ctx" ' bytes'' failed
ok 7 verdicts under 400 chars
ok 8 verdict text is quiet
ok 9 verdict text matches detectors.md
ok 10 lock verdict text matches lock-detectors.md
not ok 11 verdict_git_lock held|orphan|unknown interpolate probe values
# (in test file tests/verdicts.bats, line 161)
#   `[ "$line1" = 'A process (pid 4242) holds the lock. Wait for it, then retry.' ]' failed
ok 12 no removal instruction
```

All four new tests fail on their stated assertion:

- Test 4 (`held interpolates the pid`): `grep -qF 'pid 4242'` finds no match
  — the context still carries the literal `pid N`.
- Test 5 (`orphan and unknown interpolate size and age`): `grep -qF
  '7 bytes'` finds no match at the first (`orphan`) sub-case — the context
  still carries the literal `N bytes`. (The `unknown` sub-case is not
  reached once the first assertion in the test fails; both interpolate
  through the same unimplemented mechanism in `verdict_git_lock`, so there
  is no smaller increment that reds one sub-case without the other.)
- Test 6 (`orphan with neither bytes nor age interpolates no empty value`):
  `assert_lacks "$ctx" ' bytes'` fails because the literal `(N bytes, age
  Ns)` clause — always emitted regardless of stdin today — does contain the
  substring ` bytes` (from `N bytes`) and, later in the same string, `N
  bytes` and `age Ns` verbatim; none of these must survive once GREEN reads
  the probe's stdin.
- Test 11 (unit-level `verdict_git_lock`): the string comparison fails
  because `verdict_git_lock` does not read stdin at all — `pid=4242` on
  stdin is silently unread and the output still carries the literal `N`.

None of the four fails on a missing symbol or an unhandled event (`ImportError`/`AttributeError`-equivalent for
bash would be an `unbound variable` or `command not found`); each is a plain
string/substring mismatch, confirmed by reading the failure lines above —
every one names a `grep -qF`/`[` comparison, never a sourcing or `declare -F`
error.

Full suite (`scripts/run-bats.sh tests/`, 139 tests): only the same four
tests fail (renumbered 48-50 and 138 in the full run); the pre-existing 135
stay green — no regressions.

## Mutation proof

None required. Every new assertion targets pid/bytes/age interpolation and
the neither-value wording, none of which exist in `lib/verdicts.sh` today
(`verdict_git_lock` takes only `$1` and never reads stdin; its `held`/
`orphan`/`unknown` branches print the literal `N` regardless of what a probe
would have supplied) — per `craft:test-discipline`, a mutation proof is
needed only where the asserted behaviour already exists in the SUT, and here
it does not (same reasoning slice 1's RED report used for its own new
assertions).

## Verification

- `shellcheck tests/hook-locks.bats tests/verdicts.bats lib/verdicts.sh` —
  clean (no findings; the `assert_lacks` helper exists specifically so no
  bare `!` before a piped `grep` trips SC2314).
- Line counts: `tests/hook-locks.bats` 178, `tests/verdicts.bats` 193,
  `lib/verdicts.sh` 83 (unchanged) — all well under the 400-line cap.
- `git status --short`: only `tests/hook-locks.bats` and `tests/verdicts.bats`
  modified; no SUT file touched.

## Scope note

No commit. `lib/verdicts.sh`, `hooks/annotate.sh` and `lib/probes.sh` are
untouched. `verdict_config_lock`'s `held`/`orphan`/`unknown` interpolation,
slices 4-9 of Item 4.1, and Items 4.2/4.3 are untouched — out of scope per
the dispatch.
