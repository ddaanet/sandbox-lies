# Item 2.3 slices 4-5 — RED

Scope: slices 4 and 5, run as one cycle (per the revised list, neither adds
behaviour beyond slices 1-3 — both are proven by mutation). Three tests added
to `tests/hook.bats`: `phantom verdicts ignore the flag`, `every quiet
fixture is silent`, `the command is not read`. No implementation touched;
`hooks/` and `lib/` are byte-identical to HEAD at every checkpoint below.

`tests/hook.bats` is 301 lines after the addition, under the 400-line cap, so
no new `tests/hook-sweeps.bats` was needed.

## Fixture derivation (not by hand)

Ran `detect` (from the tracked `lib/matchers.sh`) over every
`tests/fixtures/fire-masks-*.txt` file:

```
fire-masks-chardev-explicit.txt: phantom-chardev
fire-masks-chardev-incidental.txt: phantom-chardev
fire-masks-gitadd-refused.txt: phantom-gitadd
fire-masks-porcelain.txt: phantom-untracked
fire-masks-two-names.txt: phantom-untracked
```

All five `fire-masks-*` fixtures fire one of the three shipped phantom
detectors (`phantom-chardev`, `phantom-untracked`, `phantom-gitadd`), so
"each phantom fire fixture" is exactly this glob. No other `fire-*` fixture
(`fire-lock-*`, `fire-configlock-*`) has a `verdict_*` function yet (Item 4.1
wires those), so the hook stays silent on them regardless and they are out of
scope for this sweep.

`quiet-*.txt` fixtures, confirmed silent under `detect`: `quiet-bats-fixture-grep`,
`quiet-clean-ls`, `quiet-clean-status`, `quiet-heredoc-claude-p`,
`quiet-index-line-read`, `quiet-memory-file-read`, `quiet-pilot-report-echo`
— 7 fixtures.

## Test 1: `phantom verdicts ignore the flag`

Iterates `tests/fixtures/fire-masks-*.txt` at run time (glob, not a hardcoded
list). Per Item 2.3's sweep rule, a fixture whose first line is `Exit code`
(only `fire-masks-gitadd-refused.txt`) goes into a failure payload's
`error`; the other four go into a success payload's `tool_response.stdout`.
For each fixture: runs the hook with the flag absent (asserts non-empty —
this is what catches a fixture that stops firing, since an empty sweep would
otherwise pass every equality trivially), then with `false` and `true`,
asserting byte-identical stdout against the absent run. Asserts the fixture
count processed is non-zero.

## Test 2: `every quiet fixture is silent`

Iterates `tests/fixtures/quiet-*.txt` at run time. For each fixture, runs the
hook in both payload shapes (`post_payload` with the text on
`tool_response.stdout`, `failure_payload` with the text as `error`) crossed
with the flag absent and `true` — four hook invocations per fixture, 28
total. Asserts empty stdout each time, and that the fixture count is
non-zero (an empty glob must not pass).

## Test 3: `the command is not read`

Paired: first runs `fire-masks-porcelain`'s text through `post_payload` as
before (the same shape slice 2's "porcelain on stdout fires untracked" case
uses) and asserts non-empty stdout — the positive control, so the test
cannot pass on a hook that has stopped firing altogether. Then builds a
quiet payload (`quiet-clean-status`'s text) in both shapes and overwrites
`tool_input.command` with the firing text via `jq`, asserting empty stdout
in both shapes.

## Mutation proof

Each mutation applied by exact-string `Edit`, run against `tests/hook.bats`,
then reverted by the inverse edit; `git diff --quiet hooks lib` checked after
every restore.

| test | mutation | result |
|---|---|---|
| `phantom verdicts ignore the flag` | insert after `payload=$(cat) \|\| exit 0` in `hooks/annotate.sh`: read `tool_input.dangerouslyDisableSandbox` and `exit 0` when it is `"true"` | 10 passed, 1 failed — `not ok 9 phantom verdicts ignore the flag`, on `flag true differs from absent: .../fire-masks-chardev-explicit.txt` |
| `every quiet fixture is silent` | `lib/matchers.sh`: `match_phantom_untracked`'s threshold `[ "$count" -ge 2 ]` → `[ "$count" -ge 0 ]` (always true, so the matcher fires unconditionally) | 6 passed, 5 failed — `not ok 10 every quiet fixture is silent` reds on its own assertion (`fired (post, absent): .../quiet-bats-fixture-grep.txt`); collateral reds in tests 1, 2, 6 and 11, which already assert other things this same over-firing matcher breaks |
| `the command is not read` | insert after the `case "$event" in … esac` block in `hooks/annotate.sh`: append `tool_input.command` to `text` | 10 passed, 1 failed — `not ok 11 the command is not read`, on `fired via tool_input.command (post)` |

Each restore was verified with `git diff --quiet hooks lib` before moving to
the next mutation, and once more at the end.

## Final green run

```
scripts/run-bats.sh tests/hook.bats tests/docs.bats
bats: 12 passed, 0 failed
```

`shellcheck tests/hook.bats tests/helpers/hook.bash hooks/annotate.sh
lib/matchers.sh lib/verdicts.sh`: clean.

`git status --porcelain -- tests/ hooks/ lib/`: only `tests/hook.bats`
modified.

## Done

RED only: `hooks/` and `lib/` untouched, nothing committed. Test edits and
this report are uncommitted, ready for the GREEN dispatch (which has nothing
to implement — slices 4-5 add no behaviour).
