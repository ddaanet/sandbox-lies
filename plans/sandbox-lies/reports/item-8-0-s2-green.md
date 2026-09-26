# Item 8.0 slice 2 — GREEN report

`readonly-path states only the acts its facts select`
(`hooks/annotate.sh`, `lib/verdicts.sh`)

## Scope

- `hooks/annotate.sh`: the jq parse gains a fourth field, `tool_input.command`
  — a non-string, absent, or non-object `tool_input` reads empty — escaped the
  same way `cwd` is (backslash doubled, newline written `\n`, undone by
  `printf %b`); the bash-side split reads event/flag/cwd/command as the first
  four lines; every probe call now passes `"$flag" "$cwd" "$command"`. Header
  comment updated to describe the fourth field and the new split point.
- `lib/verdicts.sh`: `verdict_readonly_path` now composes the writable/nopath
  tail from the probe's stdin facts (`readfile=`, `path=`, `merge=1`,
  `target=`, `match=`) per `docs/references/detectors.md` §readonly-path
  Verdicts — the act (readfile re-run, update-config, or the plain whole-call
  re-run, in that precedence, update-config gated to `writable`), then an
  optional merge clause (named restore, capped at five names then "and N
  more"; "restore them" with no `target=`; no clause at all with a `target=`
  and no `match=`) leading lowercase into the act, or the act standing alone
  capitalised with no `merge=1`. `readonly` is unaffected — it still ignores
  every fact but `path=`. New helper `_readonly_match_list` builds the capped,
  comma-joined name list. Doc comment above the function rewritten to describe
  the composition instead of the old fixed tail.
- No test file touched.

## Tests made green, in order

Implementation grew in two edits (the hook's argument-threading, then the
verdict's composition), each verified against its own dependent tests before
moving to the next; the composition itself is one function because the facts
interact (`readfile=` outranks a `path=` settings match regardless of stdin
line order; the merge clause wraps whichever act the facts selected), so no
test in this group could be made to pass by a smaller increment than the
whole function.

1. Hook argument threading (`hooks/annotate.sh`) — verified against:
   - `tests/hook-locks.bats`: `probe receives flag, cwd and command`
   - `tests/hook-candidates.bats`: `every probe receives tool_input.command
     byte-exact`
2. `verdict_readonly_path` composition (`lib/verdicts.sh`) — verified against
   `tests/verdicts-readonly.bats` in full (all 12 new/changed tests):
   `readonly-path with no facts states the plain re-run act`; `readonly-path
   readfile fact re-runs the writer, not the whole call`; `readonly-path
   settings.json path composes the update-config act, readfile winning`;
   `readonly-path update-config act is writable-only and needs a
   .claude/settings.json`; `readonly-path merge with target and match restores
   the named files then acts`; `readonly-path merge alone restores the
   written files then acts`; `readonly-path merge clause leads lowercase into
   whichever act the facts select`; `readonly-path merge with target and no
   match states the act alone`; `readonly-path merge match list caps at five
   names then and N more`; `readonly-path longest composition stays under 400
   with one-character values`; `readonly-path readonly ignores the probe's
   facts`; `readonly-path compositions drop the old tail wording and remove
   nothing`.
3. Dependents that the same composition change also turns green, confirmed
   next: `tests/verdicts.bats` — `readonly-path writable verdict text matches
   detectors.md`, `readonly-path nopath verdict text matches detectors.md`;
   `tests/hook-candidates.bats` — `writable outcome through the hook`,
   `nopath outcome through the hook`.
4. Full slice-2 file group re-run together
   (`tests/verdicts-readonly.bats tests/verdicts.bats
   tests/hook-candidates.bats tests/hook-locks.bats`): 42 passed, 0 failed —
   every one of the above plus every previously-green test in these four
   files stayed green.
5. Full suite (`scripts/run-bats.sh tests/`): 213 passed, 0 failed (196
   baseline + 17 slice tests, matching the RED/test-review count).

No test required a second implementation attempt.

## `just precommit`

`direnv exec . just precommit` exit 0:

```
scripts/run-bats.sh tests/
bats: 213 passed, 0 failed — full log: /tmp/claude-1000/sandbox-lies-bats.E0aLpB
precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests
```

No warnings from any check (shellcheck, `bash -n`, rumdl, line limits, links)
against the changed files. No `just lint` recipe exists in this repository;
`just precommit`'s own checks (shellcheck, `bash -n`, rumdl `fmt --check`,
line limits, link check, tests) are the gate named in the runbook.

## Line counts

All under the 400-line cap: `hooks/annotate.sh` 156, `lib/verdicts.sh` 265,
`tests/verdicts-readonly.bats` 237, `tests/hook-candidates.bats` 237,
`tests/hook-locks.bats` 398, `tests/verdicts.bats` 166,
`tests/helpers/verdicts.bash` 100.

## Out of scope, untouched

`lib/probes-readonly.sh` (the real probe's facts, slice 3) and the lock
verdicts (`verdict_git_lock`, `verdict_config_lock`, `_verdict_lock_present`)
are unchanged; `probe_git_lock`/`probe_config_lock` in `lib/probes.sh` ignore
the new third argument the hook now passes them (they read only `$1` and
`${2-}`), so no change was needed there for the git-lock probe-argument test
to pass.
