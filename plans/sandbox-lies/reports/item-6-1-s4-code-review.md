# Code review: Item 6.1 slice 4 — `silent unsandboxed`

**Scope**: the `hooks/annotate.sh` change in commit "Item 6.1/4 — readonly-path
silent unsandboxed" (the flag-policy `case` arm and its comment), plus any doc
sentence enumerating the candidate flag policies. Out of scope: `lib/*`,
`docs/design.md` status lines, `memory/`, the tests.
**Date**: 2026-09-26
**Mode**: review + fix (TDD code review)

## Summary

The change adds `readonly-path:true` to the flag-policy `case` and adds
`readonly-path` to the comment's "silent when it is" clause. It is correct,
minimal, and matches the file's style. I found no issues, so I changed no
files.

**Overall Assessment**: Ready

## Checks

- **Gate precedes the probe.** The `case` (lines 87-90) runs before the
  `declare -F "$fn"` verdict check (line 95) and before `probe_fn` is resolved
  and called (lines 101-103). A `readonly-path:true` name hits `continue`
  before any probe code runs. This matches `docs/references/hook.md`'s Flow:
  "A name its flag policy silences on this call … is skipped before any probe
  runs."
- **`\` continuation inside the pattern list.** The shell removes a
  backslash-newline pair while it reads input, before it splits tokens (POSIX
  XCU 2.2.1). Bash has done this in every version, 3.2 included. The joined
  line is the same `a | b | c | d)` pattern list. I checked it at runtime: the
  same `case` gave identical results under bash 5.2, `bash --posix` and dash.
  `readonly-path:true` and `seccomp-init:true` were skipped;
  `readonly-path:false` and an unrelated name fell through. Bash 3.2 is not
  installed on this box, so that claim rests on the lexer rule, not a run.
  `shellcheck` and `bash -n` pass in the gate.
- **Style.** The file's other continuation (the `jq -n` call, lines 145-146)
  also indents its second line by two columns. The wrapped arm stays within
  the file's width. The new arm sits with the other flag policies, in one
  `case`.
- **Comment accuracy.** "tmpdir-unset fires only when the flag is true;
  resume-lost, seccomp-init and readonly-path are silent when it is." I checked
  each detector against its `**Flag policy.**` line in
  `docs/references/detectors.md`:
  - `tmpdir-unset`: fires only when true.
  - `resume-lost`: fires only when false.
  - `seccomp-init`: silent if true.
  - `readonly-path`: silent when the flag is true.

  `readonly-path` is under `## Candidates` there, so "candidate flag policies"
  still describes the arm set.
- **Doc enumerations.** I grepped `docs/` for `seccomp-init` near "flag" or
  "polic", and for `flag polic` / `silent when`. No living doc lists the
  candidate flag policies together. `hook.md` states only the general
  skip-before-probe rule. `detectors.md` gives each policy in that detector's
  own entry, and the `readonly-path` entry already says "Silent when the flag
  is true". The one list hit, `docs/changelog.md:100`, is a dated history entry
  about which verdicts shipped, not a list of policies, so it stays. The
  `docs/design.md:5` status line is scope OUT.

## Mutated-SUT run (once)

I mutated `hooks/annotate.sh` in place to flip the arm's polarity. This is the
plausible wrong arm: exact-string replace `readonly-path:true) continue ;;` →
`readonly-path:false) continue ;;`, with grep count 1 confirming the change.
Then I ran `direnv exec . scripts/run-bats.sh tests/hook-candidates.bats`:

- `readonly-path flag policy` went red at its flag-absent half ("no verdict
  emitted, flag absent").
- `writable`/`readonly`/`nopath outcome through the hook` went red at
  `[ -f "$PROBE_CALLED" ]`.
- 4 passed, 4 failed.

I restored the file with the inverse replace. `grep -c 'readonly-path:true)
continue'` returned 1, and `git status --porcelain -- hooks lib tests docs`
was empty. Together with the test review's mutations A/B/C, this shows the
slice's test catches a wrong polarity, a policy that ignores the flag, and a
gate that runs after the probe.

## Issues Found

### Critical Issues

None.

### Major Issues

None.

### Minor Issues

None.

## Fixes Applied

None. No files changed by this review.

## Gate

```
$ cd /Users/david/code/sandbox-lies && direnv exec . just precommit > "$TMPDIR/pc.out" 2>&1; echo "exit=$?"; tail -3 "$TMPDIR/pc.out"
exit=0
bats: 196 passed, 0 failed
precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests
```

## Requirements Validation

| Requirement | Status | Evidence |
|---|---|---|
| Runbook slice 4: flag `true` gives empty stdout | Satisfied | `annotate.sh:87-90`; `readonly-path flag policy` green |
| Runbook slice 4: the stub probe records no call | Satisfied | the gate sits before `probe_fn` (line 101); `[ ! -f "$PROBE_CALLED" ]` green |
| FR-5 / detectors.md `readonly-path` flag policy | Satisfied | normalized `$flag` keyed in the one policy `case` |

## Positive Observations

- One arm added to the existing policy `case`, not a new special case, so
  every candidate's gating stays in one place, as the comment says.
- The comment was updated in the same change, so the policy list in the code
  and its prose agree.
