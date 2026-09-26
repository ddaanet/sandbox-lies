# Review: Item 6.1 slice 2 — test review, writable outcome through the hook

**Scope**: the uncommitted changes to `tests/hook-candidates.bats`,
`tests/helpers/hook.bash`, `tests/hook-locks.bats` and `tests/verdicts.bats`;
the RED report `item-6-1-s2-red.md`; and the SUT stub in `lib/verdicts.sh`,
for stub completion only.
**Date**: 2026-09-26
**Mode**: review + fix (TDD test review)

No UNFIXABLE items.

## Summary

The hook case pins the runbook's strings exactly. It uses the moved
`stub_probe_kv`, and the move left no copy behind. Two issues were found.
First, two row-driven cases in `tests/verdicts.bats` failed with `command not
found` instead of on an assertion. An inert stub now fixes that. Second, the
writable paragraph was pinned only by three substrings. A GREEN that dropped a
sentence from detectors.md's text would have passed. A transcription case now
closes that gap. After the fixes, every red is on an assertion and none is an
error. A temporary correct implementation turned every case green. It was
removed by an inverse edit.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

1. **Two row-driven cases errored instead of failing on an assertion**
   - Location: `tests/verdicts.bats`, `verdict text is quiet` and `no removal
     instruction`, and `lib/verdicts.sh`
   - Problem: with `verdict_readonly_path` undefined, `all_verdict_text` hit
     `command not found`. The test's `all=$(all_verdict_text)` then aborted
     before any assertion ran. The tests were correct; this was a stub gap.
   - Fix: an inert stub was added to `lib/verdicts.sh`. It is
     `verdict_readonly_path() { cat >/dev/null; }`: it drains stdin and prints
     nothing. Its effect on each case is listed under Per-test result below.
   - **Status**: FIXED

2. **The writable paragraph was pinned by substrings only**
   - Location: `tests/hook-candidates.bats`, `writable outcome through the
     hook`, and `tests/verdicts.bats`
   - Problem: the hook case checks `/r/x`, `is writable outside the sandbox`
     and `compare modified files against the target`. The rest of
     detectors.md's writable paragraph was unpinned: the `Re-run the whole
     call` sentence, the command-output-read clause and the `update-config`
     sentence. A mutation proved this. A paragraph with the `update-config`
     sentence removed kept the hook case green. Item 2.3 slice 3 had the same
     gap, which its code review found and closed with a transcription case.
   - Fix: a new case, `readonly-path writable verdict text matches
     detectors.md`, transcribes line 1 and line 2 from detectors.md's
     Verdicts list. `<path>` is replaced by the `path=` stdin line, the same
     way the lock tests substitute `N`. The path is `/r/a b&c\1/x`: it holds a
     blank plus `&` and `\1`, which a sed- or eval-based substitution would
     mangle. The doc writes the placeholder in backticks, and markdown needs
     those backticks for `<path>` in any case. So the case accepts the path
     bare or backticked and pins everything after it verbatim. The case does
     not decide the rendering; GREEN does. The same mutation (sentence
     removed) turns this case red.
   - **Status**: FIXED

### Minor Issues

1. **Stale file header**
   - Location: `tests/hook-candidates.bats` header
   - Note: the header still described "readonly-path's silence while it has
     no verdict". It now reads "readonly-path's probed verdicts (Item 6.1)".
   - **Status**: FIXED

2. **Helper comments did not name the new sharing**
   - Location: `tests/helpers/hook.bash`, the header and the `stub_probe_kv`
     comment
   - Note: the header now says `stub_probe` and `stub_probe_kv` are shared by
     both hook suites. The key list in the `stub_probe_kv` comment now
     includes `path=`.
   - **Status**: FIXED

## Checks

- **Runbook strings.** The hook case uses `stub_probe_kv readonly_path
  writable 'path=/r/x'`, so the path line is exactly `path=/r/x`. The fixture
  path is `/tmp/checkpoint.py.orig`, so `/r/x` can only come from the probe's
  line. The substrings match the runbook: `is writable outside the sandbox`
  and `compare modified files against the target`. The `systemMessage`
  equality is `read-only — sandbox allowlist, writable outside`. That equality
  also pins that readonly-path is the only verdict contributing, which was the
  retired case's `detect` names readonly-path alone check. The payload has no
  flag, so slice 4's policy does not interfere.
- **`stub_probe_kv` move.** `grep -rn stub_probe_kv tests/` finds one
  definition, in `tests/helpers/hook.bash`, and seven call sites: six in
  `hook-locks.bats` and one in `hook-candidates.bats`. `hook-locks.bats` has
  13 passing cases and 0 failures. The stub is appended to the copied
  `probes.sh`, after that file sources `probes-readonly.sh` at line 21, so it
  does override `probe_readonly_path`.
- **Retirement.** `no probe without a verdict` in `tests/hook-locks.bats`
  stubs `detect` to name `fake`. It asserts empty output and that the probe
  was not called. It then defines `verdict_fake` as a positive twin and
  asserts the probe was reached. That covers the `declare -F` gate
  (annotate.sh:94) for any name, independent of any shipped detector.
- **Self-quiet.** `bash lib/matchers.sh < <file>` exits 1 with no output for
  each of the four test files and for `lib/verdicts.sh`.
- **Line counts.** `hook-candidates.bats` 125, `hook-locks.bats` 358,
  `verdicts.bats` 271, `helpers/hook.bash` 100, `lib/verdicts.sh` 122. All
  are under 400.
- **Lint.** `shellcheck` reports nothing on all five files.

## Per-test result (after fixes, stub in place, foreground)

`tests/hook-candidates.bats` has 4 passing cases and 1 failure:

- `writable outcome through the hook` fails at line 103,
  ``printf '%s' "$ctx" | grep -qF '/r/x'``. The verdict is now defined, so
  the hook runs the stub probe and `[ -f "$PROBE_CALLED" ]` passes. The stub
  verdict prints nothing, so the hook stays silent and `ctx` is empty. The
  first context assertion fails.

`tests/hook-locks.bats` has 13 passing cases and 0 failures.

`tests/verdicts.bats` has 7 passing cases and 2 failures:

- `verdicts under 400 chars` fails at line 78, on the exactly-two-lines
  assertion. `defined = rowed` now passes. Every earlier row passes, and the
  `readonly_path writable` row yields one empty line.
- `readonly-path writable verdict text matches detectors.md` (new) fails at
  line 165, on the line 1 equality, because the stub prints nothing.
- `verdict text is quiet` and `no removal instruction` pass, and they pass for
  the right reason. Both check the whole verdict set. A row with no text
  cannot quote a diagnostic or tell the agent to remove anything, so these
  cases have no red state in RED. For this row, their guard applies after
  GREEN. It stays non-vacuous because `verdicts under 400 chars` requires the
  row to yield two non-empty lines. Both stayed green under the temporary
  correct implementation, so the transcribed text is quiet and contains no
  removal word.
- `candidate verdict text matches detectors.md` and the other four cases pass
  unchanged. None of them reads the `readonly_path` row.

**Feasibility and mutation.** `verdict_readonly_path` was replaced in place
by a correct implementation, first with a bare path and then with a
backticked one. `hook-candidates.bats` had 5 passing cases and 0 failures.
`verdicts.bats` had 9 passing cases and 0 failures, for both renderings. Next,
the `update-config` sentence was removed from the paragraph.
`hook-candidates.bats` stayed at 5 passing cases, which shows issue 2's gap.
`verdicts.bats` failed only the new transcription case. The body was then
restored by an inverse edit back to `cat >/dev/null`.
`grep -c 'writable outside' lib/verdicts.sh` returns 0, and
`git diff -- lib/` shows only the 6-line stub.

## Fixes Applied

- `lib/verdicts.sh` (end of file): added an inert `verdict_readonly_path`
  stub with a one-line RED-stub comment, which GREEN replaces.
- `tests/verdicts.bats`: added the `readonly-path writable verdict text
  matches detectors.md` case after `candidate verdict text matches
  detectors.md`.
- `tests/hook-candidates.bats`: updated the header comment.
- `tests/helpers/hook.bash`: updated the header comment and the
  `stub_probe_kv` key list.

## Requirements Validation

| Requirement | Status | Evidence |
|---|---|---|
| FR-4 (probe outcome and key=value lines reach the verdict) | Satisfied (test) | the hook case asserts the probe ran and that `/r/x` from `path=` reaches the context |
| FR-5 (flag policy) | Out of slice | slice 4 |
| FR-6 (text from detectors.md, under 400 characters) | Satisfied (test) | the transcription case and the `verdicts under 400 chars` row |

## Positive Observations

- The RED report diagnosed the `all=$(all_verdict_text)` abort correctly and
  reported it rather than widening scope.
- Choosing `/r/x` distinct from the fixture's own path makes the path
  assertion discriminating.
- The retirement check was made before deleting the case.

## Recommendations

- The shared dispatch context file (`.git/phase6-dispatch.md`, standing
  rules) still says `stub_probe_kv` is "defined in tests/hook-locks.bats only
  (375 lines)". That line is now stale. The file is outside the repo tree and
  outside this review's scope.
