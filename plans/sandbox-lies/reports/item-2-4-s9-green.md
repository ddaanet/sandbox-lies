# GREEN: Item 2.4 / slice 9 — BSD stat

**Scope**: `lib/probes.sh` `probe_git_lock`'s mtime read only. No other file
touched in this dispatch beyond what RED already staged
(`tests/helpers/bsd-stubs.bash`, `tests/probes.bats`,
`tests/probes-edges.bats`, `tests/helpers/probes.bash`), and no test file
edited.

## Implementation

Replaced the single `stat -c %Y "$path"` call with a BSD-first try/fallback,
in place, in one edit (the whole batch was already red on one test, `BSD
stat`, so there was only one failing test to grow against):

```
if mtime=$(stat -f %m "$path" 2>/dev/null) && [ -n "$mtime" ] \
    && [ -z "${mtime//[0-9]/}" ]; then
    :
elif ! mtime=$(stat -c %Y "$path" 2>&1); then
    if [ ! -e "$path" ] && [ ! -L "$path" ]; then
        printf '%s\n' gone "path=$path"
        return 0
    fi
    printf '%s\n' "$mtime" >&2
    mtime=''
fi
```

- `stat -f %m "$path" 2>/dev/null`: BSD's mtime field, tried first. On this
  box (GNU coreutils), `-f` means filesystem mode and `%m` a file operand, so
  the call exits 1 but still prints a filesystem report on stdout — the
  environment fact the brief measured. `2>/dev/null` here is the item text's
  first named no-stderr-suppression exception (comment in the code marks it):
  provoking this refusal on GNU is the selection mechanism, so its stderr is
  discarded rather than surfaced.
- The value from that attempt is used only when the command exits 0, is
  non-empty, and matches `[ -z "${mtime//[0-9]/}" ]` (all digits) — the
  digits guard the runbook's slice 9 text asks for, ahead of the `age=$((now
  - mtime))` arithmetic. On this box the guard is never reached with a
  digit-only value (GNU's `-f` always fails), matching the test review's
  "not reachable from these fixtures" note; it exists for a real BSD/macOS
  host, where `-f %m` succeeds and stdout is exactly digits.
- On any other outcome, falls through to the existing GNU `stat -c %Y
  "$path" 2>&1` capture, unchanged: same vanished-lock check, same
  stderr-passthrough-and-drop-age behaviour.

## Tests run, in order

1. `scripts/run-bats.sh tests/probes.bats -f "BSD stat"` → 1 passed. First
   and only implementation step; the batch had one failing test.
2. `scripts/run-bats.sh tests/probes.bats tests/probes-edges.bats` → 20
   passed, 0 failed (the full failing batch, now green).
3. `scripts/run-bats.sh tests/` → 115 passed, 0 failed (full suite, no
   regression).

No second implementation attempt was needed for `BSD stat`; it passed on the
first run of the edit above.

## Deferred mutation (from RED), run now

The RED report deferred the `wc` left-pad strip's mutation because `BSD
stat` was still red on the `stat` refusal at the time, so removing `tr -d
'[:space:]'` could not demonstrate a *new* red. With `BSD stat` green after
the implementation above, re-ran it:

- Confirmed the target string occurs exactly once:
  `command grep -cF "bytes=\$(wc -c <\"\$path\" | tr -d '[:space:]')"
  lib/probes.sh` → `1`.
- Mutation: `bytes=$(wc -c <"$path" | tr -d '[:space:]')` →
  `bytes=$(wc -c <"$path")`.
- Red observed: `scripts/run-bats.sh tests/probes.bats -f "BSD stat"` →
  `not ok 1 BSD stat`, failing at line 318, `` `printf '%s\n' "$output" |
  grep -qxF "bytes=7"' failed`` — the stub's left-padded `wc -c` output
  (`       7`) no longer matches the exact-line `bytes=7` grep once the
  strip is gone. Reds on its own assertion, not on a missing symbol.
- Restore: inverse replacement, `bytes=$(wc -c <"$path")` back to
  `bytes=$(wc -c <"$path" | tr -d '[:space:]')`.
- Restore proved: `command grep -cF 'bytes=$(wc -c <"$path")' lib/probes.sh`
  → `0` (grep exit 1) — the mutated text is gone. `git diff --stat
  lib/probes.sh` after restore shows only the intended BSD-first-mtime
  change (17 insertions, 5 deletions), no mutation residue.
- Rerun green: `scripts/run-bats.sh tests/probes.bats tests/probes-edges.bats`
  → 20 passed, 0 failed, confirming the restore.

This closes the RED report's "Deferred mutation" section: the `wc` padding
strip is now shown pinned by `BSD stat` on a BSD-path-implementing SUT, the
way slice 3's code review found it unpinned on plain GNU `wc`.

## Full suite, lint, precommit

- `scripts/run-bats.sh tests/` → 115 passed, 0 failed.
- This repo's `justfile` has no `lint` recipe (`just --list`: `check-version`,
  `format-docs`, `precommit`, `prerelease`, `release`, `resume-release`,
  `test`, `update-plugin-dev`) — `precommit` is the gate.
- `just precommit` → `scripts/run-bats.sh tests/` (115 passed) then
  `precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl,
  line limits, links, tests`. No warnings emitted.

## Files changed by this dispatch

- `lib/probes.sh` — the BSD-first mtime read described above (17 insertions,
  5 deletions against HEAD). No other function touched.

Everything else in `git status` under this scope (`tests/helpers/bsd-stubs.bash`,
`tests/helpers/probes.bash`, `tests/probes.bats`, `tests/probes-edges.bats`)
was already staged content from the RED dispatch, unmodified here. No test
file was edited in this dispatch.

## Not done (out of scope for this slice)

`probe_config_lock` and the shared-helper lift (slice 8, deferred behind an
open design question), the relative-path base and missing `$2` question, the
errored-holder `unknown` (slice 10) — none touched.
