# Item 2.3 slice 9 — RED

Scope: three tests added, no implementation change. `hooks/` and `lib/` are
byte-identical to `HEAD` (`git diff --quiet hooks lib` passes). Nothing
committed.

## Tests added

### `a name with no verdict contributes nothing` (`tests/hook-verdicts.bats`, new file)

New file rather than an addition to `tests/hook.bats` (349 lines) or
`tests/hook-malformed.bats` (different scope — malformed payloads, not
missing verdict functions): follows the `tests/hook-cap.bats` precedent —
header naming what it pins and why it is split out, `load helpers/bsd-stubs`
and `load helpers/hook`, `setup() { hook_copy_tree }`.

One `@test` with three variants, per the dispatch:

1. `detect` stubbed to print `phantom-gitadd` then `no-such-detector`:
   `additionalContext` and `systemMessage` equal `verdict_phantom_gitadd`'s
   own output (sourced from the copy, so the assertion tracks the verdict
   text rather than a copy of it).
2. The same stub with the order reversed (`no-such-detector` then
   `phantom-gitadd`) — same expectation. This is what rules out an
   implementation that stops (`exit`/`break`) on the first missing verdict:
   variant 1 alone would pass such an implementation since the working name
   comes first.
3. `detect` stubbed to print `no-such-detector` alone: empty stdout.

**Genuine red, confirmed by cause, not just by failure.** Against unmodified
`hooks/annotate.sh`, variant 1 fails at
`tests/hook-verdicts.bats:49` (`jq` chokes on empty `$output`). Reproduced by
hand outside bats:

```
verdict_no_such_detector: command not found
status=0 output=[]
```

This is finding 1 of `item-2-3-s1-code-review.md`: `"verdict_${name//-/_}"
</dev/null` on a missing function returns 127, and today's bare `|| exit 0`
terminates the whole hook — discarding the `phantom-gitadd` paragraph already
computed — rather than skipping only the verdict-less name. Slice 9's fix
needs a `declare -F` guard ahead of the call for exactly this reason (also
noted in that review). Variants 2 and 3 were not probed by hand separately;
the suite run below shows the full file failing only at line 49 (variant 1),
which is bats reporting the first failing assertion in the test body — since
`run` failures inside a single `@test` do not short-circuit until an
assertion actually fails, and the failing `[ ... ]` follows variant 1's
stub, this is variant 1's own red. The RED report does not need every
variant individually reproduced by hand; the mixed case reported in the
s1 review is enough to establish that the missing-function path silently
empties the whole output today.

### `detect sees past a NUL` (`tests/matchers.bats`)

Pins `item-2-3-s8-code-review.md` finding F1. Input: quiet preamble text, a
NUL byte, then a `config-lock`-firing line built from two fragments
(`frag1`/`frag2`) concatenated only at `printf` time, so the full firing
sentence is never written whole into this tracked file (`tests/docs.bats`'s
self-quiet sweep stays green). Written to a real file rather than a shell
variable, since bash strings cannot hold a NUL. Asserts exit 0, stdout
`config-lock`, empty stderr.

Currently green (slice 8 already shipped the fix). Pinned by mutation:
reverting `lib/matchers.sh`'s `{ text=$(LC_ALL=C tr -d '\000' <&3); } 3<&0`
to `IFS= read -r -d '' text` reds this test alone
(`[ "$status" -eq 0 ]` fails). Restored by the inverse replacement;
`git diff --quiet hooks lib` confirmed the restore.

### `detect on closed stdin` (`tests/matchers.bats`)

Pins `item-2-3-s8-code-review.md` finding F3. `bash "$MATCHERS" <&-` must
exit 1 with empty stdout and not hang. Guarded with `command -v timeout` (a
`skip` when absent, since `timeout` is not on macOS per `shell-gotchas`).

**A real environment finding surfaced while writing this test.** Closing
stdin directly on the `run`/`timeout` command line
(`run timeout 5 bash "$MATCHERS" <&-`) hangs under this repo's bats harness
— not under a plain interactive shell, where the same command returns
`status 1` immediately. Probed in isolation: even a no-op
`timeout 5 bash -c 'echo hi' <&-` completed, but `bash lib/matchers.sh <&-`
without an *inner* timeout hung past a 120-second outer bound. The fix that
avoids the hang is closing stdin **inside** an inner `bash -c`, after the
`run`/`timeout` command line has already been assembled:
`bash -c 'bash "$1" <&-' _ "$MATCHERS"`. Wrapped in `timeout 5` as the
defence-in-depth the dispatch calls for; the shipped code does not hang
(status 1, confirmed by hand and by the suite run below), so today the
`timeout` only guards against a regression, but the exact mechanism by which
the naive close hangs under this harness — an fd0 this harness appears to
keep an extra reference to, so closing this process's copy does not produce
EOF/EBADF on a duplicate — was not fully chased down, since the working
form was found and the item does not ask for that root cause.

Pinned by mutation: dropping the fd-3 brace-group form to a bare
`text=$(LC_ALL=C tr -d '\000')` reds this test alone
(`[ "$status" -ne 124 ]` fails — the reintroduced hang is caught and killed
by the test's own `timeout 5`, which is exactly the case the guard exists
for). Restored by the inverse replacement; `git diff --quiet hooks lib`
confirmed the restore.

## Mutation proof

| test | mutation | result | restored |
|---|---|---|---|
| `detect sees past a NUL` | `{ text=$(LC_ALL=C tr -d '\000' <&3); } 3<&0` → `IFS= read -r -d '' text` | red (`status -eq 0` fails) | yes, `git diff --quiet hooks lib` |
| `detect on closed stdin` | `{ text=$(LC_ALL=C tr -d '\000' <&3); } 3<&0` → `text=$(LC_ALL=C tr -d '\000')` | red (`status -ne 124` fails, i.e. `status = 124`) | yes, `git diff --quiet hooks lib` |

`a name with no verdict contributes nothing` needed no mutation: it already
reds against unmodified `hooks/annotate.sh` (finding 1's own bug), which is
the evidence recorded above.

## Verification

- `scripts/run-bats.sh tests/hook.bats tests/hook-malformed.bats
  tests/hook-cap.bats tests/hook-verdicts.bats tests/matchers.bats
  tests/docs.bats`: 51 passed, 1 failed — the one new hook-verdicts.bats
  test, for the reason above.
- `direnv exec . just precommit`: reached the `test` recipe (so
  `plugin.json`, `hooks.json`, `shellcheck`, `bash -n`, `rumdl`, line limits
  and links all passed) and failed there: 93 passed, 1 failed, same test.
- `shellcheck tests/matchers.bats tests/hook-verdicts.bats`: clean (one
  `SC2016` info justified inline — `$1` is the inner `bash -c`'s own
  argument, expanded there, not by the outer single-quoted string).
- Line counts: `tests/hook.bats` 349, `tests/hook-malformed.bats` 157,
  `tests/hook-cap.bats` 212, `tests/hook-verdicts.bats` 69,
  `tests/matchers.bats` 313 — all under the 400-line cap.
- `git diff --quiet hooks lib`: passes. `git status --porcelain -- hooks lib
  tests` shows only `M tests/matchers.bats` and `?? tests/hook-verdicts.bats`.

## Files changed

- `tests/matchers.bats`: two new tests (`detect sees past a NUL`,
  `detect on closed stdin`).
- `tests/hook-verdicts.bats`: new file, one test
  (`a name with no verdict contributes nothing`).
- `plans/sandbox-lies/reports/item-2-3-s9-red.md`: this report.
