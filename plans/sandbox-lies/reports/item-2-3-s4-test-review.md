# Item 2.3 slices 4-5 — test review

Scope: the three tests added to `tests/hook.bats` (`phantom verdicts ignore
the flag`, `every quiet fixture is silent`, `the command is not read`) and the
RED report `item-2-3-s4-red.md`. Two findings. Both are fixed in the tests, and
each fix is proven by a mutation that was green before the fix and red after.
`hooks/` and `lib/` are byte-identical to HEAD (`git diff --quiet hooks lib`
after every restore and at the end). Nothing committed.

## Findings

### F1 (major): quiet sweep's failure shape carried no exit-code line

`every quiet fixture is silent` built its failure payloads as
`failure_payload "$text"`, with the bare fixture text as `error`. No live
failure payload has that shape: `docs/references/detectors.md` Conventions
records `error` as the exit-code line followed by the merged output. No
`quiet-*` fixture starts with `Exit code`, so the item's sweep rule sends
every one to the success shape. The slice asks for "both shapes", so the
second shape has to be the real failure shape.

Demonstrated: the mutation `case "$text" in "Exit code 1"*) printf '{}\n';
exit 0 ;; esac` in `annotate.sh`'s failure branch fires on every exit-1
failure payload. The sweep stayed **green** under it. Only tests 1, 2 and 11
went red, and they build their failure payloads with the line.

Fix: the failure leg gets `Exit code 1` prepended, unless the fixture already
starts with `Exit code`. A comment explains why. Under the same mutation the
sweep now reds on its own assertion: `fired (failure, absent):
.../quiet-bats-fixture-grep.txt`.

### F2 (minor): command test's failure leg had no positive control

`the command is not read` had a positive control for the post shape only.
Its comment said it "cannot pass on a hook that has stopped firing
altogether". For the failure leg that claim was false.

Demonstrated: with `exit 0` inserted right after the `error` extraction (the
hook goes silent on every failure payload), the test reported **`ok 11`**.
The failure-leg negative passed vacuously. Tests 1 and 9 caught the
mutation, but this test did not.

Fix: a second positive control, `failure_payload "Exit code 1"$'\n'"$fire"`,
asserts non-empty output. The comment is reworded to "per shape", and the two
control messages are tagged `(post)` / `(failure)`. Under the same mutation
the test now reds with `positive control did not fire (failure)`.

## Wrong-reason checks that held

- **Flag test, differing verdict on `true`:** caught by byte-equality to the
  absent run (RED's mutation, and M1b below).
- **Flag test, fires only when the flag is false:** the absent run fires and
  the `true` run is silent, so equality fails. A hook firing only on a
  literal `false` fails the absent run's non-empty check.
- **Flag encoding:** the helper uses `--argjson`. The payload has `"dangerouslyDisableSandbox":false`,
  and `jq type` gives `"boolean"`. The base fixtures'
  `tool_input` has no such key, so "absent" is truly absent, which matches
  Conventions (absent when unset, `true` when set). `false` is an extra case
  with no recorded counterpart. It is harmless and the slice asks for it.
- **Flag test shapes:** the per-fixture `case` follows the sweep rule. Only
  `fire-masks-gitadd-refused` goes to the failure shape, and M1b proves that
  leg is live.
- **Count guards:** each test has a single loop, and its `count` covers it.
  By reading, not probed: an empty glob iterates once over the literal
  pattern, and `text=$(cat …)` fails the test under bats errexit before the
  count check runs. The check is redundant but harmless.
- **Command test positive control:** the same text goes through the same
  helper, and only the field differs. The negative also carries quiet text
  in the response field, which is needed to reach `detect` at all.
- **Hook reading `tool_input` only on failure payloads:** caught (M3).

Residual, not fixed: the fire sweep is a glob, so deleting a `fire-masks-*`
fixture shrinks it silently. Adding a fixture is the common change, and
deleting one is a reviewed change, so a floor pin is not worth its
maintenance.

## Mutation reproductions (each different from the RED's)

Each mutation was applied by exact-string edit and run with
`scripts/run-bats.sh tests/hook.bats`. Each was restored by the inverse edit,
then checked with `git diff --quiet hooks lib`.

| id | test | mutation | result |
|---|---|---|---|
| M1 | flag | `annotate.sh`, after `payload=$(cat)`: `exit 0` when `.tool_input.dangerouslyDisableSandbox` is `false` | 10/1. `not ok 9`, `flag false differs from absent: …chardev-explicit.txt` |
| M1b | flag | `annotate.sh` failure branch: clear `text` when the flag is `true` | 10/1. `not ok 9`, `flag true differs from absent: …gitadd-refused.txt` |
| M2 | quiet | `matchers.sh` `match_phantom_chardev`: mode class `c` → `[c-]` (regular files match) | 10/1. `not ok 10` alone, `fired (post, absent): …quiet-clean-ls.txt` |
| M2b | quiet | failure branch: `printf '{}'` on `Exit code 1*` (F1) | before fix: sweep green. After fix: `not ok 10`, `fired (failure, absent)` (plus 1, 2, 11 collateral) |
| M3 | command | failure branch: `jq -r '.error // empty, .tool_input.command // empty'` | 10/1. `not ok 11` alone, `fired via tool_input.command (failure)` |
| M3b | command | failure branch: `exit 0` after extraction (F2) | before fix: `ok 11`. After fix: `not ok 11`, `positive control did not fire (failure)` (plus 1, 9 collateral) |

The lead's suggested isolating mutation fires `phantom-gitadd` on an
`Exit code N` line through the matcher. It does not isolate the sweep's
failure leg: `quiet-clean-status.txt` holds an `Exit code 2` line at line 11,
so the sweep reds on its **post** leg first, alongside tests 2 and 11. M2
isolates the sweep and M2b proves the failure leg.

## Final run

```
scripts/run-bats.sh tests/hook.bats tests/docs.bats tests/verdicts.bats
bats: 16 passed, 0 failed
```

`shellcheck tests/hook.bats tests/helpers/hook.bash`: clean.
`git diff --quiet hooks lib`: identical to HEAD.
`git status --porcelain -- tests hooks lib`: only `tests/hook.bats` modified.
`tests/hook.bats`: 316 lines (cap 400).
