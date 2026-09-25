# Review: Item 4.2 slices 1-2 — test review

**Scope**: the uncommitted test changes for rows `tmpdir-unset`, `resume-lost`
and `seccomp-init` — `tests/matchers.bats`, `tests/verdicts.bats`,
`tests/hook-candidates.bats` (new) — against the RED report
`item-4-2-s1-red.md`, runbook Item 4.2 and `docs/references/detectors.md`
`## Candidates`. The inert stubs in `lib/matchers.sh` and `lib/verdicts.sh` were
checked for completeness only. Out: implementation, memory, docs, Item 4.3,
`zellij-socket` (stays a candidate). **Date**: 2026-09-25 **Mode**: review + fix

## Summary

Every new or changed test reds on an assertion. None errors. The flag-policy
pairs are well formed: in each, one fixture runs twice with the same payload
shape and only the flag changes. Verdict transcriptions match `detectors.md`
exactly, and the BSD case does run the hook's `grep` through the stub. Three
gaps were fixed. First, slice 1's quiet half had no named cases and no pins for
the near-miss content. Second, the fires-with halves checked only a substring of
the context. Third, the slice 2 test names did not match the runbook. Temporary
mutations of the SUT, since restored, showed that every assertion that cannot
red today does red once a loose matcher or a missing policy is present.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

1. **Slice 1 quiet half: no named cases, and nothing pinned the near-miss**
   - Location: `tests/matchers.bats`, detector D section
   - Problem: slice 1 says each cut `quiet-<detector>-*` yields nothing. Its
     only check was the BSD sweep. No case pinned that a quiet fixture still
     carries its detector's phrase in the position the matcher rejects. If a
     fixture were hollowed out, its "quiet" result would be vacuous. Every other
     quiet fixture in the file has a named case with such a pin.
   - Fix: added three named cases, `tmpdir-unset stays quiet on a refusal
     naming a deeper path`, `resume-lost stays quiet on the index line quoting
     the refusal` and `seccomp-init stays quiet on a heading quoting the
     failure`. Each runs `assert_fixture` and then pins the phrase. The
     tmpdir-unset pin is a tool-prefixed missing-file line on a path with two
     or more components. The resume-lost and seccomp-init pins require the
     phrase to be present and not at a line start. Each pin quotes a fragment,
     never the full diagnostic (self-quiet).
   - **Status**: FIXED. The cases pass against the inert stubs as expected. A
     temporary loose matcher turned each of them red (see Check 1).

### Minor Issues

1. **Fires-with halves checked only a context substring**
   - Location: `tests/hook-candidates.bats`, all four cases
   - Problem: `additionalContext` containing the phrase does not prove the
     row's verdict was the one emitted, or that it was the only one.
   - Fix: each fires-with half now also requires `systemMessage` to equal the
     row's human line from `detectors.md`. This matches `hook-locks.bats`.
   - **Status**: FIXED

2. **Test names did not match slice 2's name**
   - Location: `tests/hook-candidates.bats`
   - Problem: the runbook names the cases `<detector> flag policy`, and
     `hook-locks.bats` uses its slice names verbatim. The RED names ("fires
     only when the flag is true", …) did not match.
   - Fix: renamed the cases to `tmpdir-unset flag policy`, `resume-lost flag
     policy` and `seccomp-init flag policy`, each with its policy as a
     one-line comment. Added a comment above the three cases saying why the
     silent half can only be the policy. The BSD case keeps its name.
   - **Status**: FIXED

3. **Comment described a state that GREEN will change**
   - Location: `tests/matchers.bats` `expected_for`, candidate block comment
   - Problem: "the matcher stays inert … until the slice's GREEN" would be
     false from the GREEN commit on.
   - Fix: the comment now reads "Candidates recorded `ships` …, built by Item
     4.2 (zellij-socket stays a candidate and has no fixture)."
   - **Status**: FIXED

## Check 1 — mechanical

Run in the foreground, after the fixes:
`direnv exec . bats tests/matchers.bats tests/verdicts.bats
tests/hook-candidates.bats`.

| Test | Result | Fails on |
|---|---|---|
| matchers 17-20 (four fire cases) | not ok | `expected [<detector>] got []` |
| matchers 21-23 (three new quiet cases) | ok | cannot red against inert stubs; see below |
| matchers 33, BSD sweep (existing) | not ok | `fire-resume-lost-two-turn: expected [resume-lost] got []` |
| verdicts 37, `verdicts under 400 chars` (existing, now has rows) | not ok | the two-line count |
| verdicts 38, `verdict text is quiet` | ok | cannot red: the stub verdicts print nothing |
| verdicts 40, candidate transcription | not ok | line-1 string equality |
| hook-candidates 45-48 | not ok | explicit `[ -n "$output" ]` with a message |

No case errors, and every red is an assertion. The stubs are complete: all six
`match_*`/`verdict_*` symbols are defined, and `rows()` calls real functions.

**Quiet expectations and silent halves.** These cannot red against inert
stubs. Each becomes evidence once the matcher exists. To confirm this now, I
applied temporary mutations and restored them by deleting the inserted
`# MUTANT` lines. `grep -rn MUTANT lib hooks` was then empty, `hooks/` was
clean, and `git diff --stat HEAD -- lib` was back to 15 and 14 insertions:

- `lib/matchers.sh` `detect` was wired to three loose matchers:
  - tmpdir-unset accepted any absolute path.
  - resume-lost and seccomp-init were unanchored phrase greps.

  All four fire cases went green, and all three quiet cases went red. They
  reported `got [tmpdir-unset]`, `got [resume-lost,seccomp-init]` and
  `got [seccomp-init]`.
- Stand-in verdicts were added to `lib/verdicts.sh` while the hook had no
  policy. The fires-with half of all three flag-policy cases passed, and each
  case then went red at `[ -z "$output" ]` on its silent half.
- A policy was added to `hooks/annotate.sh`: `case "$name:$flag"` skipping
  `tmpdir-unset:false|resume-lost:true|seccomp-init:true`. All four cases
  went green. Inverting only the tmpdir-unset clause to `tmpdir-unset:true`
  turned cases 45 and 48 red on their fires-with assertion, while 46 and 47
  stayed green.

**Mutation checks the code review must run after GREEN**, against the real
implementation:

1. Loosen `match_tmpdir_unset` to accept a multi-component path.
   `tmpdir-unset stays quiet on a refusal naming a deeper path` must red.
2. Drop the line-start anchor from `match_resume_lost`.
   `resume-lost stays quiet on the index line quoting the refusal` must red.
3. Drop the line-start anchor from `match_seccomp_init`.
   `seccomp-init stays quiet on a heading quoting the failure` must red.
4. Delete each row's flag-policy clause in the hook. That row's
   `<detector> flag policy` case must red at `[ -z "$output" ]`.
5. Make one candidate verdict's paragraph fire its own matcher.
   `verdict text is quiet` must red. This checks that it now covers the
   candidate rows.
6. Run a spy `grep`/`sed` in the BSD case and confirm that
   `match_tmpdir_unset`'s own tool calls pass through the stub. If the matcher
   uses `[[ =~ ]]` and no external tool, the BSD case proves nothing about it,
   and the report should say so.

## Check 2 — wrong-reason hunting

- **Payload shape (Item 2.3 sweep rule).** `fire-tmpdir-unset-redirect` and
  `fire-seccomp-init-sed` begin with an `Exit code` line and go in
  `failure_payload`. `fire-resume-lost-two-turn` does not, and goes in
  `post_payload`. The rule is followed. `payload-failure.json` and
  `payload-post.json` carry no `dangerouslyDisableSandbox`, so "absent" really
  is absent.
- **The silent half is the policy, not a failure to match.** Each case feeds
  the same text through the same payload builder twice, and only the flag
  changes. `detect` reads text only, so the matcher result cannot depend on
  the flag. The fires-with half therefore proves the matcher and verdict fire
  on exactly the text the silent half suppresses. `run_hook` merges stderr, so
  a hook crash would also make `[ -z "$output" ]` red. The mutation run above
  confirmed that each silent half reds only when the policy is missing.
- **Verdict transcriptions.** All three were checked by script against
  `detectors.md`. For each detector, the `**Verdict.**` paragraph was
  whitespace-joined and split on ` · `, and both the paragraph and the human
  line appear verbatim in `tests/verdicts.bats`: 3/3 exact.
- **The BSD case runs under the stubs.** A scratch bats file (since deleted)
  wrapped the BSD `grep` stub with a logger. Under
  `PATH="$bsd:$PATH" run_hook`, the hook's matchers made six `grep` calls
  through the stub, so the temporary `PATH` reaches the `bash -c` child. The
  candidate matchers do not call anything yet, so check 6 above is the
  remaining gap.
- **Fire fixtures.** `assert_fixture` compares the full verdict set, so a fire
  case also fails if another detector joins.

## Check 3 — self-quiet

`bash lib/matchers.sh` exits 1 on each of the three test sources. No test
source contains a candidate diagnostic whole. The hook cases read fixtures
from disk. The quiet pins quote fragments (`No conversation found`,
`unshare(CLONE_NEWUSER)`, a partial `ls:` regex), and none of them sits at a
line start where the documented matchers anchor. The verdict transcriptions
are verdict prose, not diagnostics. `tests/docs.bats` still has to run over
these files after GREEN, with the real matchers. Precommit runs it.

## Fixes Applied

- `tests/matchers.bats` `expected_for`: the candidate-block comment was
  rewritten so it no longer describes a state GREEN will change.
- `tests/matchers.bats` detector D: added three named quiet cases with
  near-miss pins, plus a two-line comment on why the pins exist.
- `tests/hook-candidates.bats`: renamed the three cases to
  `<detector> flag policy`, added a comment above them on why the silent half
  can only be the policy, and added `systemMessage` equality to every
  fires-with half, the BSD case included.
- Stubs: no change needed.

## Requirements Validation

| Requirement | Status | Evidence |
|---|---|---|
| Slice 1: fire fixtures yield exactly the detector | Satisfied (red) | matchers 17-20 |
| Slice 1: quiet fixtures yield nothing | Satisfied | matchers 21-23 and the BSD sweep; loose-matcher mutation turns them red |
| Slice 2: flag policy per row | Satisfied (red) | hook-candidates 45-47; policy mutation run |
| Verdict text from detectors.md, `verdicts.bats` row | Satisfied (red) | verdicts 37, 40; transcription script |
| Portability: one BSD case in the new file | Satisfied (red) | hook-candidates 48; stub reach confirmed |
| Self-quiet | Satisfied | matchers exit 1 on all three sources |

## Positive Observations

- The explicit `[ -n "$output" ] || { echo …; return 1; }` guard ahead of `jq`
  makes the red a named assertion rather than a `jq` parse error.
- Leaving the stub matchers out of `detect` keeps the red on the expectation
  flip, and the stub verdicts keep `rows()` from calling an undefined function.

## Recommendations

- `tests/matchers.bats` is at 373 of 400 lines. Item 4.3 slice 1 adds
  readonly-path fire and quiet cases there, which will bring it close to the
  cap.
