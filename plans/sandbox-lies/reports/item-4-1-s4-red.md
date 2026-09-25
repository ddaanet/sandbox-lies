# Item 4.1 slices 4-6 — RED

Batched dispatch: slice 4 (`probe receives flag and cwd`), slice 5
(`config-lock mask names config.lock and update-config`), slice 6 (`piped
lock failure on a success payload`). All three tests added to
`tests/hook-locks.bats`, reusing `stub_probe`/`stub_lib` and the
`failure_payload`/`post_payload` helpers from `tests/helpers/hook.bash`. No
implementation file touched (final diff: only `tests/hook-locks.bats`
modified — `hooks/annotate.sh` shows no diff after the mutation-proof
restores below).

## Tests written

- `probe receives flag and cwd` — a dedicated stub (`stub_lib probes.sh`)
  overriding `probe_git_lock` to record `"$1 $2"` to a file under
  `$BATS_TEST_TMPDIR`, drain stdin and print `mask`. Runs `failure_payload`
  against `fire-lock-add-commit.txt` with `.cwd` set to `/x` via `jq` on the
  built payload (per the dispatch note), once with the flag `true` and once
  with it absent.
- `config-lock mask names config.lock and update-config` — `stub_probe
  config_lock mask` against `fire-configlock-remote-add.txt`, checking
  `hookSpecificOutput.additionalContext` for both literal strings.
- `piped lock failure on a success payload` — `stub_probe git_lock mask`
  against `fire-lock-piped-tail.txt` fed through `post_payload` (event
  `PostToolUse`, text in `tool_response.stdout`, exit-0-shaped fixture per
  D-4), checking `additionalContext` contains `GIT_INDEX_FILE`.

## Per-test output

1. `probe receives flag and cwd` — passes on first run:
   ```
   1..1
   ok 1 probe receives flag and cwd
   ```
   The hook already forwards `"$flag" "$cwd"` to the probe (Item 4.1 slice
   1's GREEN), so this is the already-existing-behaviour case; proven by
   mutation below.

2. `config-lock mask names config.lock and update-config` — fails on its own
   assertion:
   ```
   1..1
   not ok 1 config-lock mask names config.lock and update-config
   # (in test file tests/hook-locks.bats, line 211)
   #   `printf '%s' "$ctx" | grep -qF 'config.lock'' failed
   ```
   Genuine red, no mutation needed: `verdict_config_lock`'s `mask` case
   (`lib/verdicts.sh`) names `config.lock` only in its human line
   (`config.lock — sandbox mask, not a real lock`), never in the
   `additionalContext` paragraph — `docs/references/lock-detectors.md`'s
   config-lock `mask` paragraph itself has no `config.lock` occurrence ahead
   of its `·` separator. `update-config` alone is already present in the
   paragraph (untested independently, since the test's first `grep` aborts
   the case).

3. `piped lock failure on a success payload` — passes on first run:
   ```
   1..1
   ok 1 piped lock failure on a success payload
   ```
   The `PostToolUse` text-extraction branch and `verdict_git_lock`'s `mask`
   paragraph (carrying `GIT_INDEX_FILE`) already exist; proven by mutation
   below.

## Mutation proof

### `probe receives flag and cwd`

- File: `hooks/annotate.sh`, line 96 (unique in the file):
  `probe_out=$(printf '%s\n' "$text" | "$probe_fn" "$flag" "$cwd") || exit 0`
- Mutation: swapped the call's argument order to
  `"$probe_fn" "$cwd" "$flag"`.
- Re-run (`direnv exec . bats -f 'probe receives flag and cwd'
  tests/hook-locks.bats`): reds on its own assertion —
  `` `[ "$(cat "$recorded")" = 'true /x' ]' failed ``.
- Restore: swapped the arguments back to `"$flag" "$cwd"`.
  `grep -c '"\$probe_fn" "\$cwd" "\$flag"' hooks/annotate.sh` → `0` (no hit);
  `direnv exec . bats -f 'probe receives flag and cwd' tests/hook-locks.bats`
  → `ok 1 probe receives flag and cwd`.

### `piped lock failure on a success payload`

- File: `hooks/annotate.sh`, line 50 (unique in the file):
  `elif $event == "PostToolUse" then`
- Mutation: changed the compared literal to `"PostToolUseX"`.
- Re-run (`direnv exec . bats -f 'piped lock failure on a success payload'
  tests/hook-locks.bats`): reds on its own assertion — `` `[ -f
  "$PROBE_CALLED" ]' failed `` (the jq filter no longer matches the event
  name, so text extraction yields nothing and the hook exits before any
  probe runs, upstream of the `additionalContext` check).
- Restore: changed the literal back to `"PostToolUse"`.
  `grep -n 'PostToolUseX' hooks/annotate.sh` → no hit;
  full-file re-run (`direnv exec . bats tests/hook-locks.bats`) below.

## Full suite after restore

`direnv exec . bats tests/hook-locks.bats`:

```
1..10
ok 1 mask outcome through the hook
ok 2 mask paragraph is flag-neutral under flag true
ok 3 mask outcome through the hook under BSD stubs
ok 4 held interpolates the pid
ok 5 orphan and unknown interpolate size and age
ok 6 orphan with neither bytes nor age interpolates no empty value
ok 7 probe receives flag and cwd
not ok 8 config-lock mask names config.lock and update-config
# (in test file tests/hook-locks.bats, line 211)
#   `printf '%s' "$ctx" | grep -qF 'config.lock'' failed
ok 9 piped lock failure on a success payload
ok 10 orphan with one of bytes and age interpolates that one alone
```

9 of 10 pass; the one red (`config-lock mask names config.lock and
update-config`) is this dispatch's genuine, unmutated red for slice 5 — the
designed end state for RED.

`git status --porcelain`: only `tests/hook-locks.bats` modified;
`git diff --stat hooks/annotate.sh` is empty (mutation fully restored).
`wc -l tests/hook-locks.bats` → 262 lines, under the 400-line cap.

## Scope

No implementation file (`hooks/annotate.sh`, `lib/verdicts.sh`,
`lib/probes.sh`, `lib/matchers.sh`) carries any change beyond the two
mutate-then-restore round trips proven above. Slices 1-3 (already green from
prior dispatches) are untouched and still pass. Slices 7-9, Items 4.2/4.3,
`docs/`, the memory retirement and `design.md` status flips are untouched,
per the dispatch's scope note.
