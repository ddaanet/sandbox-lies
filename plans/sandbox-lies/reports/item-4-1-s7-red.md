# Item 4.1 slices 7-8 (+ carried) — RED

Batched dispatch: slice 7 (`every lock fixture yields its verdict`), slice 8
(`no probe without a verdict`), and the carried test from slice 4-6's code
review (`probe reads the result text on stdin`). All three tests added to
`tests/hook-locks.bats` (358 of 400 lines after the addition), reusing
`stub_probe`/`stub_lib` and the `failure_payload`/`post_payload` helpers from
`tests/helpers/hook.bash`. No implementation file carries any net change:
final `git status --porcelain` shows only `tests/hook-locks.bats` modified;
`hooks/annotate.sh` and `lib/verdicts.sh` show empty diffs after the
mutation-proof restores below.

## Tests written

- `every lock fixture yields its verdict` — sweeps every `fire-lock-*.txt` and
  `fire-configlock-*.txt` fixture (7 total: 5 lock, 2 configlock), building
  the payload shape from the fixture's own first line per Item 2.3's sweep
  rule (an `Exit code` line → `failure_payload`; anything else →
  `post_payload`), at flag absent and `true`. Both lock probes are stubbed to
  `mask`. Misses (non-zero exit, or a `systemMessage` not equal to the
  expected mask human line for that fixture's file) accumulate into one
  string across all 7 fixtures × 2 flags = 14 runs, asserted empty once at
  the end, so a red names every broken fixture rather than stopping at the
  first.
- `no probe without a verdict` — stubs `detect` itself (in the copied
  `matchers.sh`) to report a fake name `fake` with no matching `verdict_fake`,
  and stubs a `probe_fake` that would record its call to a file. Runs a
  lock-fixture failure payload through the hook: expects empty stdout and no
  call recorded, proving `annotate.sh`'s `declare -F "$fn"` gate on the
  verdict runs (and skips) before the probe is ever looked up.
- `probe reads the result text on stdin` (carried, item-4-1-s4-code-review.md
  Major 1) — stubs `probe_git_lock` to write its stdin to a file. For a
  `PostToolUse` payload with distinct non-empty `tool_response.stdout` and
  `tool_response.stderr`, asserts the file equals stdout, a newline, stderr
  (D-13's join, per `hooks/annotate.sh`'s header comment); for a
  `PostToolUseFailure` payload (`fire-lock-add-commit.txt`), asserts the file
  equals the `error` text. Both comparisons go through `$(cat ...)` on both
  sides so command substitution's trailing-newline stripping cancels out
  identically rather than needing to reason about the one newline
  `annotate.sh`'s `printf '%s\n' "$text" | "$probe_fn"` adds before piping in.

## Per-test output

All three pass on first run — the dispatch note anticipated this ("All three
behaviours likely exist already"), so each is proven by mutation below rather
than read as vacuous.

1. `every lock fixture yields its verdict`:
   ```
   1..1
   ok 1 every lock fixture yields its verdict
   ```
2. `no probe without a verdict`:
   ```
   1..1
   ok 1 no probe without a verdict
   ```
3. `probe reads the result text on stdin`:
   ```
   1..1
   ok 1 probe reads the result text on stdin
   ```

## Mutation proof

### `every lock fixture yields its verdict`

- File: `lib/verdicts.sh`, line 33 (unique in the file):
  `printf '%s\n' 'index.lock — sandbox mask, not a real lock'`
- Mutation: changed the human line to
  `'index.lock — MUTATED sandbox mask, not a real lock'`.
- Re-run (`direnv exec . bats -f 'every lock fixture yields its verdict'
  tests/hook-locks.bats`): reds on its own assertion —
  `` `[ -z "$misses" ] || { printf '%s' "$misses" >&2; return 1; }' failed ``,
  listing all 5 `fire-lock-*.txt` fixtures at both flag values (10 lines),
  each `got 'index.lock — MUTATED sandbox mask, not a real lock'` — the
  `fire-configlock-*` fixtures are absent from the list, confirming the sweep
  only flags the mutated detector's own fixtures.
- Restore: changed the human line back to
  `'index.lock — sandbox mask, not a real lock'`.
  `grep -n MUTATED lib/verdicts.sh` → no hit (exit 1);
  `direnv exec . bats -f 'every lock fixture yields its verdict'
  tests/hook-locks.bats` → `ok 1 every lock fixture yields its verdict`.

### `no probe without a verdict`

- File: `hooks/annotate.sh`, line 88 (unique in the file):
  `declare -F "$fn" >/dev/null || continue`
- Mutation: replaced the line with `:` (no-op), so the loop no longer skips a
  name whose verdict function is absent.
- Re-run (`direnv exec . bats -f 'no probe without a verdict'
  tests/hook-locks.bats`): reds on its own assertion —
  `` `[ -z "$output" ]' failed `` (with the gate removed, the hook reaches
  `probe_fake`, calls it — recording the call the test checks for next — then
  tries to invoke the non-existent `verdict_fake` as a command, whose "command
  not found" stderr `run` merges into `$output`, so the first violated
  assertion is non-empty output rather than the call-recorded check right
  after it; either way the mutation is caught).
- Restore: replaced `:` with `declare -F "$fn" >/dev/null || continue`.
  `grep -n '^  :$' hooks/annotate.sh` → no hit (exit 1); `git diff
  hooks/annotate.sh` → empty; `direnv exec . bats -f 'no probe without a
  verdict' tests/hook-locks.bats` → `ok 1 no probe without a verdict`.

### `probe reads the result text on stdin`

- File: `hooks/annotate.sh`, line 52 (unique in the file):
  `(.tool_response | objects | (.stdout | strings), (.stderr | strings))`
- Mutation: swapped the order to
  `(.tool_response | objects | (.stderr | strings), (.stdout | strings))`.
- Re-run (`direnv exec . bats -f 'probe reads the result text on stdin'
  tests/hook-locks.bats`): reds on its own assertion —
  `` `[ "$(cat "$recorded")" = "$(printf '%s\n%s' "$stdout" "$stderr")" ]'
  failed `` — the success-payload half of the test, which is the half this
  line governs; the failure-payload half (the `error` field, untouched by
  this line) is not reached because the case's first half already failed the
  test.
- Restore: swapped the order back to
  `(.stdout | strings), (.stderr | strings)`.
  `grep -n '(.stderr | strings), (.stdout | strings)' hooks/annotate.sh` → no
  hit (exit 1); `direnv exec . bats -f 'probe reads the result text on stdin'
  tests/hook-locks.bats` → `ok 1 probe reads the result text on stdin`.

## Full suite after restore

`direnv exec . bats tests/hook-locks.bats`:

```
1..13
ok 1 mask outcome through the hook
ok 2 mask paragraph is flag-neutral under flag true
ok 3 mask outcome through the hook under BSD stubs
ok 4 held interpolates the pid
ok 5 orphan and unknown interpolate size and age
ok 6 orphan with neither bytes nor age interpolates no empty value
ok 7 probe receives flag and cwd
ok 8 config-lock mask names config.lock and update-config
ok 9 piped lock failure on a success payload
ok 10 orphan with one of bytes and age interpolates that one alone
ok 11 every lock fixture yields its verdict
ok 12 no probe without a verdict
ok 13 probe reads the result text on stdin
```

All 13 pass — the 3 new cases plus the 10 already-green from earlier slices.
`git status --porcelain`: only `tests/hook-locks.bats` modified. `git diff
hooks/annotate.sh lib/verdicts.sh`: empty (both mutation round trips fully
restored). `wc -l tests/hook-locks.bats` → 358 lines, under the 400-line cap
(no need for the fallback `tests/hook-locks-sweep.bats`).

## Scope

No implementation file (`hooks/annotate.sh`, `lib/verdicts.sh`,
`lib/probes.sh`, `lib/matchers.sh`) carries any change beyond the three
mutate-then-restore round trips proven above. Slices 1-6 (already green from
prior dispatches) are untouched and still pass. Slice 9 (cap and `; ` joiner),
the memory retirement, `design.md` status flips, Items 4.2/4.3 and `docs/` are
untouched, per the dispatch's scope note.
