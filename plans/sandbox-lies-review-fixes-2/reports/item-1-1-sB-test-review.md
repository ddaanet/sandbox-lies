# Review: Item 1.1 Slice B — test review (after RED)

**Scope**: the uncommitted test changes (`tests/hook-resume.bats`,
`tests/hook-candidates.bats`, `tests/verdicts.bats`) and
`reports/item-1-1-sB-red.md`. `lib/` and `hooks/` are OUT and were left
unchanged. They were mutated in place for the proofs below and restored by
inverse replacement. No stub: the SUT is the unchanged code.

**Date**: 2026-10-07

**Mode**: review + fix (dispatch `item-1-1-sB-test-review`). Nothing committed.

## Summary

The RED set is sound in shape. Every flag-true case proves that its payload
carries the flag. The found text is compared whole and exactly, in the verdict
suite and through the hook. No surviving case asserts resume-lost silence under
flag true.

Four findings, all fixed in `tests/hook-resume.bats`:

- The mixed-id cases were not paired as the RED report claimed. A mutation that
  the original set survived proved it.
- The file would have failed `just precommit`'s shellcheck.
- A sibling test's name becomes false once GREEN lands.
- The header claimed a BSD re-run that does not exist.

**Overall Assessment**: Ready

## Mechanical check

Each suite was run once in the foreground, one at a time, against the unchanged
`lib/` and `hooks/`. The runs below are after the fixes.

- `tests/verdicts.bats`: 9 passed, 1 failed. The found case reds at
  `[ "$output" = "$expected" ]`, because `found` prints nothing today.
- `tests/hook-resume.bats`: 5 passed, 5 failed. Every red stops at
  `resume_verdict`'s assertion,
  `[ -n "$output" ] || { echo "no verdict emitted, flag …"; return 1; }`. None
  errors.
  - Red: "transcripts for both ids, the exists verdict" (flag `absent`).
  - Red: the four "flag true:" cases (no transcript, both ids, first id only,
    second id only), each with flag `true`.
  - Green by design, each proven by mutation below: "only the first id has a
    transcript" and "only the second id has a transcript" (flag absent).
- `tests/hook-candidates.bats`: 12 passed (one case deleted, none added).
- `tests/docs.bats`: 1 passed. No tracked file fires a detector. The RED report
  piped through `lib/matchers.sh` is quiet too (exit 1).
- Line counts: `hook-resume.bats` 163, `hook-candidates.bats` 355,
  `verdicts.bats` 185, all under 400. `scripts/check-line-limits.sh` exits 0.
- `shellcheck` over the three files exits 0 after Major 2.

## Issues Found

### Critical Issues

None.

### Major Issues

1. **The mixed-id cases were unpaired, and one probe defect went uncaught**
   - Location: `tests/hook-resume.bats`, the RED's tests 3 and 4c.
   - Problem: the flag-absent partial held only `ID_2`, and the flag-true
     partial held only `ID_1`. The RED report says 4c "pairs with test 3 …
     differing only in the flag". It differs in the id too. So nothing green
     today showed that the first-id-only partial reads `lost`, and 4c's red
     could not be attributed to the gate alone. Worse, under the flag absent, a
     probe that tests only the first id passes everything. Mutation M2 below
     shows it: the only flag-absent partial (`ID_2` only) stayed green. With
     GREEN landed, 4c alone would carry that check, and only under flag true.
   - Fix: both partials are now covered under both flag values. Each flag-true
     case has a flag-absent twin on the same config dir. A comment states why
     both orders exist.
   - **Status**: FIXED. "only the first id …" reds under M2. "only the second id
     …" reds under M1. Each stays green under the other mutation.

2. **The new helper made `just precommit`'s shellcheck fail**
   - Location: `resume_verdict`, defined after the "no config root" test.
   - Problem: shellcheck models each `@test` as a subshell. A helper defined
     after a test that ran `run` reads `$status` and `$output` as
     subshell-modified variables, and reports SC2030/SC2031. The precommit
     recipe runs `shellcheck` at default severity, so info-level findings fail
     it. The HEAD version of the file had none. The RED report called these
     findings "the same pattern as existing cases". No file under `tests/` has
     one.
   - Fix: moved `LOST_*`, `FOUND_*` and `resume_verdict` up beside `run_hook`
     and `resume_cfg`, above the first `@test`. That is where this file already
     defines its helpers. `shellcheck -x tests/hook-resume.bats` now exits 0.
   - **Status**: FIXED.

### Minor Issues

1. **"transcripts for both ids, no verdict" names a state GREEN removes**
   - Location: `tests/hook-resume.bats`, the Slice A wiring case,
     `assert_lacks "$output" 'never written'`.
   - Problem: after GREEN the hook emits the exists verdict for this fixture, so
     the name "no verdict" is false. Its assertion is also subsumed. The exists
     case uses the same `resume_cfg "$RESUME_ID_1" "$RESUME_ID_2"` and the same
     text, and requires `additionalContext` and `systemMessage` to equal the
     found texts. No output can fail the negative while passing the positive.
   - Fix: deleted whole. A negative that restates its positive cannot fail on
     its own (test-discipline, non-vacuous negatives).
   - **Status**: FIXED.

2. **The header claimed a BSD re-run of both verdicts**
   - Location: `tests/hook-resume.bats:2-6`.
   - Problem: "their BSD re-run" covered the exists verdict too. Only the
     no-transcript verdict has a `make_bsd_stubs` case. That satisfies the
     CLAUDE.md rule, which asks for one case per suite.
   - Fix: the header now reads "the no-transcript verdict's BSD re-run".
   - **Status**: FIXED.

3. **Stray alignment spaces in `resume_verdict`**
   - Location: `[ -n "$output" ]     || {`.
   - **Status**: FIXED (single space).

## Wrong-reason hunt, per test

- **`verdicts.bats` "resume-lost found verdict prints the paragraph then the
  human line"**.
  - Fails when: the two lines are anything but the contract's bytes.
  - Else could pass: nothing. The whole output is compared with `=`.
  - Near-miss proof: mutation N1 dropped the paragraph's final period, and the
    test redded at `[ "$output" = "$expected" ]`. Mutation N2 turned the human
    line's em dash into a hyphen, and it redded at the same line. Both strings
    were also checked byte for byte against the dispatch contract (Python
    `str.count`, em dash as U+2014): one hit each in both files.
- **Hook "transcripts for both ids, the exists verdict"** (flag absent).
  - Fails when: the hook emits nothing (today) or other text.
  - Exactness: under N1 it redded at `[ "$ctx" = "$want_ctx" ]` (line 69). Under
    N2 it redded at `[ "$sys" = "$want_sys" ]` (line 70). So both lines' exact
    comparisons have each redded on a near-miss, not only on empty output.
  - Flag absence is asserted with
    `jq -e '… has("dangerouslyDisableSandbox") | not'`.
- **Flag-true cases** (no transcript, both ids, first only, second only).
  - Gate still in place: cannot pass. The gate's `continue` runs before the
    probe, so the output is empty and the case reds on "no verdict emitted".
  - Payload without the flag: cannot pass. The payload is checked first, and
    `.tool_input.dangerouslyDisableSandbox` must equal `true`. That path is the
    one the hook's jq reads.
  - Attribution proof: mutation G dropped `resume-lost:true | ` from the gate.
    The three lost cases went green. "both ids" stayed red, because `found` has
    no text yet. Each lost case's red is therefore the gate alone. Each also has
    a flag-absent twin that is green on the same config dir: "no transcript,
    today's verdict", "only the first id …" and "only the second id …".
  - "both ids" can be attributed only after GREEN, once its flag-absent twin is
    green. The RED report says the same.
- **Hook "only the first id …" and "only the second id …"** (flag absent).
  - Green today. Each is paired with a mutation it catches and the other
    survives (below), so neither is satisfied by the fixture alone.
- **Silence under flag true**: none survives. The old "resume-lost flag policy"
  case is deleted. `grep -rn resume tests/` finds no other flag-true resume-lost
  assertion. `hook.bats`'s quiet-fixture loop under flag true covers
  `quiet-resume-lost-index-line`, which never matches, so it is not a flag
  policy.
- **Isolation**: every hook case exports `CLAUDE_CONFIG_DIR` under
  `$BATS_TEST_TMPDIR` (`resume_cfg`). The "no config root" case unsets both
  `HOME` and `CLAUDE_CONFIG_DIR`. No case reads the host's `~/.claude`.
- **Coverage asked for**:
  - Flag absent: `lost` ("no transcript, today's verdict"), `found`, and both
    mixed orders.
  - Flag true: `lost`, `found`, and both mixed orders.
  - All of them run `hooks/annotate.sh` (the `hook_copy_tree` copy) on a
    `post_payload` payload, with the real `probe_resume_lost`.
  - An explicit `"dangerouslyDisableSandbox": false` is not a separate case. The
    hook maps absent and every non-`true` value to `false` in its jq, so absent
    and explicit `false` reach the gate as the same token.

## Mutation proof

Each mutation was an exact replacement of a string that occurs once. It was
proven landed with `command grep -cF` returning 1. Each was restored by the
swapped replacement, and the restore was proven by `command grep -cF` returning
0. `git status` shows `lib/` and `hooks/` unmodified at the end.

- **M1** (for "only the second id has a transcript", flag absent). Differs from
  the RED's mutation, which turned `|| verdict=lost` into `|| :`.
  - Mutation, in `lib/probes.sh`: `        [ -n "$hit" ] || verdict=lost` became
    `        [ -n "$hit" ] && verdict=found || verdict=lost`. The last id now
    decides.
  - Red: "no verdict emitted, flag 'absent'". "only the first id" stayed green.
  - Restored: 0 hits, and both partial cases `ok`.
- **M2** (for "only the first id has a transcript", flag absent).
  - Mutation: `done < <(printf '%s\n' "$ids")` became
    `done < <(printf '%s\n' "$ids" | head -n 1)`. Only the first id is tested.
  - Red: "no verdict emitted, flag 'absent'". "only the second id" stayed green,
    which is the gap Major 1 closes.
  - Restored: 0 hits, and both cases `ok`.
- **G** (attribution of the flag-true reds; not a green test's proof).
  - Mutation, in `hooks/annotate.sh`:
    `tmpdir-unset:false | resume-lost:true | seccomp-init:true` became
    `tmpdir-unset:false | seccomp-init:true`.
  - Result: flag-true "no transcript", "first only" and "second only" went `ok`.
    "both ids" stayed red.
  - Restored: the gate string counts 1 again, and the mutation string 0.
- **N1 and N2** (exactness of the found text). Applied by one script, run once
  per variant.
  - Mutation, in `lib/verdicts.sh`: a line inserted ahead of
    `  [ "${1-}" = lost ] || return 0` that prints a near-miss found verdict and
    returns. The line is tagged `# MUTATION-SB`.
  - N1: the paragraph without its final period. N2: the human line with a hyphen
    for the em dash.
  - Reds: the `verdicts.bats` found case at its `=` line under both. The hook
    exists case at the ctx line under N1 and at the sys line under N2.
  - Restored: `MUTATION-SB` 0 hits, `transcript exists, not the sandbox` 0 hits
    in `lib/verdicts.sh`. The verdict case is back to its RED failure.

## Fixes Applied

- `tests/hook-resume.bats`:
  - The header's BSD clause is narrowed.
  - The "transcripts for both ids, no verdict" case is deleted.
  - The verdict constants and `resume_verdict` moved above the first `@test`.
  - The stray spaces are removed.
  - The flag-absent partial is split into "only the first id" and "only the
    second id". The flag-true partial is split the same way, with a comment
    stating why both orders exist.
- `tests/verdicts.bats` and `tests/hook-candidates.bats`: no change.

## Requirements Validation

| Requirement | Status | Evidence |
| --- | --- | --- |
| Q1: verdict under either flag | Tested | four flag-true hook cases, each with a flag-absent twin |
| Q2: found text, byte for byte | Tested | `verdicts.bats` whole-output `=`; hook ctx and sys `=`; N1 and N2 |
| `lost` keeps today's text | Tested | existing `verdicts.bats` transcription and "no transcript, today's verdict" |
| Other outcomes print nothing | Tested | `verdicts.bats` `-` case; hook "no config root" case (`unknown`) |

## Notes for GREEN

- `hooks/annotate.sh`'s gate comment says resume-lost is silent under the flag.
  It goes with the gate.
- `tests/helpers/verdicts.bash` has only a `resume_lost lost` row. A
  `resume_lost found` row would put the found text under its length and two-line
  checks. That is a test change, so it belongs in a later test pass, not in
  GREEN.
