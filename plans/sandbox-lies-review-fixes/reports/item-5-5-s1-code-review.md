# Review: Item 5.5 slice 1 — code review (GREEN)

- **Scope**: commit 07627d4 ("Item 5.5/1 — lock probes leave out a
  newline-bearing path="). Reviewed: `lib/probes.sh` (`_probe_lock_at`, the
  header, the function comment), the Probe paragraph in
  `docs/references/lock-detectors.md`, and the `docs/changelog.md` sentence.
  `tests/probes-lock-newline.bats` was read as context only. `lib/verdicts.sh`
  and `hooks/annotate.sh` were read as consumers.
- **Date**: 2026-10-06
- **Mode**: review + fix

## Summary

The guard is correct. It is one `pathline` flag, set at the top of
`_probe_lock_at` from the resolved `$path`, and all six `path=` print sites read
it. For a newline-bearing path, every other key line and the outcome are
unchanged. The A-3 rule, its enforcer and its three consumers agree. Each
consumer's reading with `path=` absent is pinned at the verdict level. At the
hook level, nothing pins a lock probe that prints no `path=` line, and I propose
a pin for that below. I fixed one minor wording issue in the changelog.
`just precommit` exits 0.

**Overall Assessment**: Ready

## Checks

### 1. Correctness

- **The guard tests the resolved path, not the cwd.** The test is
  `[[ $path == *$'\n'* ]]` on `_probe_lock_at`'s `$2`. That is the path after
  `_probe_resolve_path`, and `_probe_lock_at` never receives the cwd. The idiom
  is the same as `lib/probes-readonly.sh:56`.
- **Every print site reads the guard.** `command grep -n 'path='` finds exactly
  six print sites: lines 69, 71, 84, 102 and 127 (`${pathline:+"path=$path"}`),
  and line 163 (inside `if [ -n "$pathline" ]`). There is no other `path=` print
  in the file.
- **Other output is unchanged.** `gone`, `mask`, `held` with `pid=`, and
  `orphan`/`unknown` with `bytes=` and `age=` all print as before. The guard
  changes nothing that is printed before or after the `path=` line. An empty
  path (the pathless config-lock case) still prints `path=` with an empty value,
  because `pathline` stays `1`.
- **bash 3.2 and `set -u`.** `pathline` is always set (`1` or empty), so
  `${pathline:+…}` never trips `set -u`. The outer expansion is unquoted and the
  inner word is quoted. So it gives one word, with no splitting or globbing,
  when `pathline` is set, and no word at all when it is empty. That holds in
  bash 3.2, and it avoids the empty-array expansion that 3.2 rejects under
  `set -u`.
- **`set -e` callers.** When the flag is empty, the final `if` with a false
  condition and no `else` returns 0, so the function still exits 0. I checked
  this by hand under `set -eu`, sourcing `lib/probes.sh` in `bash -c`. The run
  was the 5.4 review's `probe_config_lock` forging shape
  (`c⏎path=/h/.claude/settings.json.lock⏎y`). The output was `mask` and nothing
  else, and `verdict_config_lock mask false` on the remainder, fed as the hook
  feeds it (one empty line), printed *Re-run* with no `update-config`. The
  scratch tree under `$TMPDIR` was removed afterwards.
- **No new `2>/dev/null`.** The commit's added lines contain none. The one at
  line 121 predates the commit and is justified inline.

### 2. Contract across its surfaces

- **Rule**: the `lock-detectors.md` Probe paragraph and the `lib/probes.sh`
  header both say that `path=` is left out for a newline-bearing resolved path
  and that the outcome stands. The `_probe_lock_at` comment says the same.
- **Enforcer**: `_probe_lock_at` does what the rule says (check 1).
- **Consumers**:
  - `verdict_config_lock` mask: an absent `path=` leaves `path=''`, so the act
    is *Re-run*. This is pinned by `tests/verdicts-locks.bats` (the
    `config_lock mask false|true` transcription, with empty stdin through
    `verdict_text`'s `</dev/null`). The cost is that a newline-bearing
    `.claude/settings.json.lock` path loses the update-config act and falls back
    to *Re-run*. That is the degradation option 1 accepted, and
    lock-detectors.md's "when the probe's `path=` is a
    `.claude/settings.json.lock`" wording is consistent with it.
  - `_verdict_lock_present` (held, orphan and unknown, for both lock detectors):
    it never reads `path=`, so an absent line reads the same as a present one.
    This is pinned by the `tests/helpers/verdicts.bash` row table, which runs
    every held, orphan and unknown row with empty stdin.
  - `verdict_git_lock` mask and gone: neither reads stdin at all. This is pinned
    by the same rows.
  - `hooks/annotate.sh`: it splits only the first line. A probe output with no
    newline takes the `*)` branch (`probe_rest=""`). That branch is pinned
    generically by `tests/hook-candidates.bats:154`
    (`stub_probe_kv readonly_path nopath`), but not for a lock probe. See Major
    1.
- `docs/design.md` FR-4, `docs/references/detectors.md` and
  `docs/references/hook.md` say only "`key=value` lines". None of them claims
  `path=` is always printed, so none contradicts the code. `docs/design.md`
  needs no edit.

### 3. Docs

The lock-detectors.md Probe paragraph matches the runbook's A-3 text. Lines 83,
87 and 157 are records of live reproductions and still hold. `skills/` does not
describe lock-probe `path=` anywhere. The changelog sentence was ambiguous
(Minor 1).

### 4. Mutated-SUT run (in place, once)

- **Mutation**: in `lib/probes.sh`, the guard pattern `*$'\n'*` was replaced
  with `*[[:space:]]*`. This is a guard that also drops paths holding blanks.
- **Landing**: `command grep -c` found 1 occurrence of the mutated pattern.
- **Result**: `bats tests/probes-lock-newline.bats` failed all six cases (1–6).
- **Restore**: the replacement was inverted. `command grep -c` then found 0
  occurrences of the mutated pattern and 1 of the original, and
  `git diff --stat lib/probes.sh` was empty.

## Issues Found

### Critical Issues

None.

### Major Issues

1. **No hook-level pin for a lock probe that prints no `path=` line**
   - Location: `tests/hook-locks.bats`. Every lock case there goes through
     `stub_probe`, which always prints `path=stub`, or through `stub_probe_kv`
     with a `path=` line.
   - Problem: the outcome-only probe output that this slice now produces for
     `mask` and `gone` reaches the verdict through the hook's no-newline branch
     as one empty stdin line. No lock case exercises that. The verdict-level
     pins use `</dev/null` (zero lines) instead, and the hook branch is pinned
     only through readonly-path's `nopath`. The reading is correct today (my run
     under check 1 shows it), so this is a coverage gap, not a defect.
   - Proposed pin, not written because tests are read-only in this review. In
     `tests/hook-locks.bats`, for each flag in `false` and `true`, run
     `stub_probe_kv config_lock mask` with no extra lines on
     `fire-configlock-remote-add.txt`. Assert exit 0, the probe marker present,
     `systemMessage` equal to `config.lock — sandbox mask, not a real lock`, the
     context carrying the flag's *Re-run* wording, and
     `assert_lacks "$ctx" update-config`. Then run
     `stub_probe_kv git_lock held 'pid=4242'` with no `path=` line, and assert
     the systemMessage `index.lock — held by pid 4242`. A sharper, unstubbed
     variant would run the real probe with a payload `cwd` of
     `<T>/c⏎path=<T>/h/.claude/settings.json.lock⏎y`, encoded as the hook
     decodes it (`%b`), and assert no `update-config` in the context. That is
     the 5.4 review's exploit, end to end.
   - **Status**: DEFERRED — tests are out of scope for this code review (the
     dispatch makes them read-only context). The pin is left for the
     orchestrator to dispatch.

### Minor Issues

1. **Changelog sentence's referent**
   - Location: `docs/changelog.md`, in the 2026-10-05 entry.
   - Note: "the lock probes leave out `path=` for such a path" pointed back to
     "a refused path that resolves to a newline-bearing one". That phrase is
     readonly-path's refusal, and it is not the lock probe's resolved lock path.
   - **Status**: FIXED. The sentence now reads: "a lock probe whose resolved
     path holds a newline keeps its outcome and leaves out `path=`".

### Informational

- **Test file location.** The runbook placed the tests in
  `tests/probes-config.bats`, but they landed in a new
  `tests/probes-lock-newline.bats`. That file is 313 lines, plus the new 174,
  which is over the 400-line cap, so the split is warranted. Design FR-4's
  "`tests/probes*.bats`" glob covers the new file. No action.

## Fixes Applied

- `docs/changelog.md` (2026-10-05 entry): the lock-probe clause now names its
  own subject and says that the outcome is kept. `just format-docs` reflowed the
  paragraph.

## Gate

`just precommit` ran in the foreground and exited 0, with bats at 305 passed and
0 failed. These checks passed: `plugin.json`, `hooks.json`, shellcheck,
`bash -n`, rumdl, line limits, links and tests.

## Requirements Validation

| Requirement | Status | Evidence |
| ----------- | ------ | -------- |
| FR-4 (A-3: outcome stands, `path=` left out for a newline-bearing resolved lock path) | Satisfied | `lib/probes.sh:61-63` guard read by all six sites (69, 71, 84, 102, 127, 163); the mutant run; the end-to-end check under `set -eu` |
| Docs bullet (lock-detectors.md, header, function comment, changelog) | Satisfied | `docs/references/lock-detectors.md:29-31`; `lib/probes.sh:7-8`, `:52-54`; changelog (after Minor 1) |
| Out of scope: `path=` encoding | Respected | No encoding introduced |

## Positive Observations

- There is one guard at the shared function, and the sites read it rather than
  each re-testing the path. This matches the 5.4 review's placement advice.
- The idiom matches readonly-path's existing newline check, so both probes read
  the same way.
- The bash-3.2-safe `${var:+"word"}` form avoids an empty array under `set -u`.
