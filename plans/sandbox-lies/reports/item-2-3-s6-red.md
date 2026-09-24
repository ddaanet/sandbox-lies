# Item 2.3 slice 6 — RED

Malformed-payload and non-string-field coverage for `hooks/annotate.sh`
(FR-3), per `docs/design.md` and the finding 9 / finding 2 notes in
`item-2-3-s1-code-review.md` and `item-2-3-s2-code-review.md`.

## What was added

`tests/hook.bats` was already at 316 lines; adding this slice's cases would
have passed the 400-line cap, so a new file was used instead:
`tests/hook-malformed.bats`, loading `helpers/bsd-stubs` and `helpers/hook`
exactly as `hook.bats` does. Untracked, not yet `git add`ed.

Two `@test`s, each with a paired positive (`assert_fires`: the gitadd
failure fixture through `failure_payload`, asserting non-empty stdout) so a
hook that exits early on everything cannot pass either:

- `"Malformed payload: non-json, scalar, array and textless object"` (named
  exactly as the slice's category phrase) — `not json`, `42`, `[1]`, `{}`,
  and an object with a well-formed `PostToolUse` event whose `tool_response`
  is a bare string.
- `"non-string tool_response.stdout and error fields stay quiet"` (named for
  its behaviour, per slice 2's code review finding 2) — `tool_response.stdout`
  as a number and as an object (`PostToolUse`), `error` as a number and as an
  object (`PostToolUseFailure`).

Each input goes through `assert_quiet <label> <payload>`, asserting status 0,
empty stdout, empty stderr via `run --separate-stderr`, and echoing `<label>`
plus the failing stream on the first assertion an input misses.

`quiet_hook() { printf '%s' "$1" | bash "$HOOK_COPY/hooks/annotate.sh"; }`
replaces the `bash -c '...'` indirection `hook.bats`'s own `run_hook` uses:
with `--separate-stderr` inserted before `bash -c`, shellcheck's SC2016
exemption for `<shell> -c '...'` no longer recognizes the pattern and flags
the quoting as a live substitution bug (verified: identical text without
`--separate-stderr` shellchecks clean; reproduced in isolation). Piping into
a named function sidesteps it — `shellcheck tests/hook-malformed.bats` exits
0.

## Per-input result (this run, unmodified `hooks/` and `lib/`)

Probed directly (`printf '%s' "<payload>" | bash hooks/annotate.sh`) before
writing the assertions, then confirmed through the suite:

| input | status | stdout | stderr | contract |
|---|---|---|---|---|
| `not json` | 0 | empty | `jq: parse error: Invalid numeric literal…` | **reds** |
| `42` | 0 | empty | `jq: error … Cannot index number with string "hook_event_name"` | **reds** |
| `[1]` | 0 | empty | `jq: error … Cannot index array with string "hook_event_name"` | **reds** |
| `{}` | 0 | empty | empty | passes |
| `tool_response` is a string | 0 | empty | `jq: error … Cannot index string with string "stdout"` | **reds** |
| `tool_response.stdout` a number | 0 | empty | empty | passes |
| `tool_response.stdout` an object | 0 | empty | empty | passes |
| `error` a number | 0 | empty | empty | passes |
| `error` an object | 0 | empty | empty | passes |

The event-read jq call (`.hook_event_name // empty`) fails on `not json`,
`42` and `[1]`; the text-read jq call fails on the string `tool_response`.
Both leak the parse/index error to the hook process's stderr before the
`|| exit 0` catches the non-zero status — exactly finding 9's prediction.
`{}` never reaches the text read (`[ -n "$event" ]` is false first). The
`// empty` reads finding 2 flagged let non-string leaves (numbers, `{}`)
through as raw text with no jq error, and `detect` does not fire on `5` or
`{}` alone, so those four cases were already quiet.

## Suite run

`scripts/run-bats.sh tests/hook-malformed.bats`, foreground:

```
not ok 1 Malformed payload: non-json, scalar, array and textless object
#   `assert_quiet "not json" 'not json'' failed
# not json: stderr [jq: parse error: Invalid numeric literal at line 1, column 4]
bats: 1 passed, 1 failed
```

Test 1 stops at its first failing input (`not json`) — bats aborts the test
body on `assert_quiet`'s `return 1` under errexit, so `42`, `[1]` and the
string-`tool_response` case never execute in this run despite also being
broken (confirmed by direct probe above, not by the suite). This is a
genuine red on a failed assertion, not on a missing command; GREEN's fix
will need to clear `not json` before the next run can reach and red on `42`,
in turn, until the type guard covers all four. Test 2 is `1 passed` — none
of its four inputs currently misbehave, so it has no naturally-occurring red.

`scripts/run-bats.sh tests/`: 81 passed, 1 failed (only the new red; every
other suite, including the rest of `hook.bats`, is unaffected).

`scripts/run-bats.sh tests/docs.bats`: 1 passed, 0 failed.

## Mutation run (the one permitted)

Test 2 has no naturally-occurring red, so it needs a mutation proof
(test-discipline). Mutation: in `lib/matchers.sh`, replaced `detect`'s body
with an unconditional `printf 'phantom-gitadd\n'; return 0`. Result:
`scripts/run-bats.sh tests/hook-malformed.bats` reported both tests failing
— test 2 on `tool_response.stdout is a number`, stdout now the full
`phantom-gitadd` verdict JSON instead of empty. The mutation was reverted
with `git checkout -- lib/matchers.sh`, confirmed by `git diff --quiet hooks
lib`, and the suite re-run to confirm the return to `1 passed, 1 failed`
(test 1's genuine red only).

Test 1 needs no mutation proof: it already reds for a real reason (`not
json`), and that red exercises the same `assert_quiet`/`quiet_hook` path the
other four inputs in the test use, so a hook that went permanently silent
would already be caught by `assert_fires`.

## Done-state check

`git status --porcelain` shows only the sandbox's phantom untracked
dotfiles (ignored, per the shared conventions) and
`tests/hook-malformed.bats`. `git diff --quiet hooks lib` confirms both
directories byte-identical to HEAD. Nothing committed.

## Scope

In scope only: the test file above. Slices 7–10, the `hooks/annotate.sh`
implementation, memory retirement and Item 2.4 were not touched.
