# Item 2.3 slice 6 — test review

Scope: `tests/hook-malformed.bats` (untracked) and
`item-2-3-s6-red.md`. Everything was fixed in the test file. `hooks/` and
`lib/` are byte-identical to HEAD (`git diff --quiet hooks lib`). Nothing is
committed.

## Findings

### 1. Name — fixed

The RED named the test `Malformed payload: non-json, scalar, array and
textless object`. It is renamed to the runbook's
`non-json, scalar, array and textless object`.

### 2. The red run showed one of four broken inputs — fixed

Test 1 stopped at `not json` under errexit, so `42`, `[1]` and the string
`tool_response` were never reached. A GREEN that fixed only the event read
would have revealed them one run at a time, and a GREEN that fixed only `not
json` could not see the rest. Both tests now collect their misses:
`check_quiet` and `check_fires` append one line per missed contract to
`$failures` and never fail themselves. `assert_no_failures` is the single
assertion at the end, and it prints the whole list. The red run below names
all four broken inputs in test 1. The positives are collected the same way,
so a failing positive no longer hides the negatives behind it
(non-vacuous-negatives, ordering under errexit).

### 3. Test 2 passed for a fixture reason — fixed, now a genuine red

The non-string cases were `stdout` set to `5` or `{}`, and `error` set to
`42` or `{}`. The current hook reads every one of them as text: `// empty`
passes numbers and objects through as JSON (slice 2 code review, finding 2).
They stayed quiet only because `5` and `{}` contain nothing that fires, so
any implementation, typed or untyped, passed. The RED's mutation (`detect`
always prints `phantom-gitadd`) reds every quiet assertion whatever the
input. It therefore shows that the assertion can fail. It does not show that
the non-string input is what matters.

The fix is that each negative now differs from its positive only in the
field's type:

- The phantom matchers are line-anchored. jq renders an object or an array
  with every line indented or bracketed, so no phantom text inside one can
  fire (slice 2 code review, probe). `git-lock` is unanchored and does fire
  from inside JSON, but it has no verdict until Item 4.1. The test therefore
  uses `stub_lib verdicts.sh` to append a two-line `verdict_git_lock`. This
  is the helper's documented purpose, and slice 7 does the same. A later
  definition wins, so the stub still applies once Item 4.1 ships the real
  verdict.
- Positives: `fire-lock-add-commit` as a string `error` (`failure_payload`)
  and as a string `tool_response.stdout` (`post_payload`). Both fire.
- Negatives: the same text as `{text: $t}` in `stdout` and in `error`, and
  as `[$t]` in `error`. Each is built with `jq` over the same recorded
  payload fixture. The number cases (`stdout` 5, `error` 42) stay as the
  runbook lists them. A number cannot carry text, so they pin only "no leak,
  no crash". Mutations M3 and M4 prove that.

Result against the unchanged hook: the three object and array cases red on
stdout, because the stub verdict JSON is emitted. That is exactly the
behaviour the slice 6 contract forbids. For GREEN, this means the fix has to
be strings-only reads, for example
`.tool_response | objects | (.stdout | strings), (.stderr | strings)` and
`.error | strings` (finding 2's suggested shape). Adding a quiet parse
without type-guarding the fields leaves test 2 red.

### 4. `{}` never reaches the text read — fixed by adding the textless payloads

`{}` exits at `[ -n "$event" ]`, so "textless" was never tested at the text
read. Two inputs are added: `payload-failure.json` with `del(.error)`, and
`payload-post.json` with `del(.tool_response)`. Both carry a valid event and
reach `[ -n "$text" ]` with nothing in the text field. `{}` stays, since the
runbook lists it. M1 and M2 show that each input reaches its own guard and
not the other one's.

### 5. The string `tool_response` held no text — fixed

It was `"just a string"`. That reds today only through jq's index error on
stderr. A GREEN that silenced the error by reading a string `tool_response`
as the text would still have passed. The string is now the
`fire-masks-porcelain` text, and the positive is the same text via
`post_payload`. M6 shows the difference.

### 6. Pairing and invocation — checked, no change needed

Every positive and negative goes through the same `quiet_hook`
(`printf '%s' | bash "$HOOK_COPY/hooks/annotate.sh"`) under
`run --separate-stderr`, the same way production calls it: stdin payload,
the copied tree's own `lib/`. Every non-string case asserts that stderr is
empty (M3 and M4 red on stderr alone). The positives now also assert empty
stderr. The RED's reason for switching from `bash -c '…'` to a named
function (SC2016 with `--separate-stderr`) stands. `shellcheck
tests/hook-malformed.bats` exits 0.

## Mutation reproductions

Each mutation is an exact, unique string replacement in `hooks/annotate.sh`.
Each is restored by the inverse replacement and proven by
`git diff --quiet hooks lib` together with a grep for the mutant text
(no hit). Each "caught by" list below names only the labels that changed
against the baseline red.

| # | replace | with | newly red |
|---|---|---|---|
| M1 | `[ -n "$event" ] \|\| exit 0` | `… \|\| { echo "MUTANT-M1 no event" >&2; exit 0; }` | `textless object` only (both textless payloads unaffected) |
| M2 | `[ -n "$text" ] \|\| exit 0` | `… \|\| { echo "MUTANT-M2 no text" >&2; exit 0; }` | `failure payload without error`, `success payload without tool_response` (`{}` unaffected) |
| M3 | `'.tool_response.stdout // empty, …'` | `'(.tool_response.stdout // empty \| explode \| implode), …'` | `tool_response.stdout is a number` (stderr); positives still fire |
| M4 | `jq -r '.error // empty'` | `jq -r '.error // empty \| explode \| implode'` | `error is a number` (stderr); positives still fire |
| M5 | `payload=$(cat) \|\| exit 0` | `…; exit 0 # MUTANT-M5` | all four positives, and no negative (hook quiet on everything) |
| M6 | `'.tool_response.stdout // empty, …'` | `'.tool_response \| if type == "string" then . else (.stdout // empty, .stderr // empty) end'` | `tool_response is a string` now on **stdout** (read as text) instead of stderr |

Every quiet input that passes today is caught by a mutation aimed at it:
`{}` by M1, the textless payloads by M2, the numbers by M3 and M4. Every
input that is red today reds on an assertion.

## Final red run (unmodified `hooks/` and `lib/`)

`scripts/run-bats.sh tests/hook-malformed.bats`:

```
not ok 1 non-json, scalar, array and textless object
# not json: stderr [jq: parse error: Invalid numeric literal at line 1, column 4]
# scalar: stderr [jq: error (at <stdin>:0): Cannot index number with string "hook_event_name"]
# array: stderr [jq: error (at <stdin>:0): Cannot index array with string "hook_event_name"]
# tool_response is a string: stderr [jq: error (at <stdin>:18): Cannot index string with string "stdout"]
not ok 2 non-string tool_response.stdout and error fields stay quiet
# tool_response.stdout is an object: stdout [{ …stub lock verdict JSON… }]
# error is an object: stdout [{ …stub lock verdict JSON… }]
# error is an array: stdout [{ …stub lock verdict JSON… }]
bats: 0 passed, 2 failed
```

`scripts/run-bats.sh tests/`: 80 passed, 2 failed (only the two reds above).
`scripts/run-bats.sh tests/docs.bats`: 1 passed, 0 failed. The file is 112
lines.

## Done state

`git status --porcelain`, ignoring the sandbox's phantom root dotfiles, shows
only `tests/hook-malformed.bats` and the two slice 6 reports. `git diff
--quiet hooks lib` exits 0. Nothing is committed.
