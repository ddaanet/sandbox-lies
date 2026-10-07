# Item 1.1 Slice B — RED (outline slices 5 and 7)

Dispatch `item-1-1-sB-red`. Nothing committed. `lib/` and `hooks/` are
unchanged (`git status` shows only the three test files modified).

## Files

- `tests/verdicts.bats`: one new case (test 1).
- `tests/hook-resume.bats`: five new cases (tests 2, 3, 4a-c) and a helper
  `resume_verdict`; header comment updated.
- `tests/hook-candidates.bats`: the "resume-lost flag policy" case deleted
  (folded into 4a-c); the header comment no longer lists resume-lost as having
  a flag policy and points at `tests/hook-resume.bats`. Now 355 lines. Nothing
  there asserts silence for resume-lost under flag true.

The verdict texts are literals in the test files (`LOST_CTX`, `FOUND_CTX`, ...),
not read from `lib/verdicts.sh`.

## Runs against the unchanged code

- `tests/verdicts.bats`: 9 passed, 1 failed (test 1).
- `tests/hook-resume.bats`: 5 passed, 4 failed (tests 2, 4a, 4b, 4c). Test 3 is
  green, by design.
- `tests/hook-candidates.bats`: 12 passed.

## Per test

The hook cases fail on `resume_verdict`'s explicit assertion
`[ -n "$output" ] || { echo "no verdict emitted, flag ..."; return 1; }`, not
on a missing symbol: every function and file exists.

1. `verdicts.bats` "resume-lost found verdict prints the paragraph then the
   human line". Red at `[ "$output" = "$expected" ]` (line 109): `found` prints
   nothing today (`[ "${1-}" = lost ] || return 0`), status 0, output empty.
   - World that fails it: `verdict_resume_lost found` printing anything but the
     two exact lines (empty today; the lost text; a reworded found text).
   - Else could produce the observable: nothing for a pass, since the whole
     two-line output is compared with `=`. Exit 0 is asserted first, so a
     crash is a separate failure.

2. `hook-resume.bats` "transcripts for both ids, the exists verdict" (flag
   absent). Red: "no verdict emitted, flag 'absent'". Today the probe prints
   `found`, the verdict is empty and the hook emits nothing.
   - World that fails it: any hook output other than exactly the found
     `additionalContext` and `systemMessage`; today, silence.
   - Else could produce the observable (passing): nothing short of the exact
     texts, but the `found` outcome is only reached with a transcript for both
     ids. The sibling case "transcripts for both ids, no verdict" (existing,
     `assert_lacks 'never written'`) stays green and now shares its fixture
     with this case, which pins the positive side. If the config dir were
     unread (the probe printing `unknown`) the hook would also emit nothing
     and this case would stay red, which is right: it asserts the verdict.
   - Absent flag is proven: `resume_verdict ""` asserts the payload has no
     `dangerouslyDisableSandbox` key.

3. `hook-resume.bats` "one of two ids has a transcript, the lost verdict" (flag
   absent; only `ID_2` has one). Green today: existing behaviour.
   - Needs the mutation proof below.
   - World that fails it: a probe or verdict treating a partial as found (empty
     output, or the found text).
   - Else could produce its observable: only the `lost` outcome gives the exact
     `lost` texts. The transcript is `ID_2`'s, the second id, so a probe that
     tests only the first id reads `lost` anyway; the sibling flag-true case
     4c uses `ID_1` for the same partial, so the pair covers either id
     being the one missing.

4. Flag true, each with `dangerouslyDisableSandbox: true` and the same exact
   `additionalContext` and `systemMessage` as the flag-absent twin.
   - 4a "no transcript, the lost verdict as with the flag absent" (empty config
     dir). Red: "no verdict emitted, flag 'true'". World: the gate
     `resume-lost:true` in `hooks/annotate.sh:97` skips the name.
   - 4b "transcripts for both ids, the exists verdict ...". Red: same line.
     World: the gate silences, and `found` also prints nothing today.
   - 4c "one of two ids has a transcript, the lost verdict ...". Red: same
     line. World: the gate.
   - Else could produce silence, the observable the three reds share: (i) the
     payload never carried the flag, (ii) the probe printed `unknown`, (iii) no
     match. Excluded: (i) by `resume_verdict`, which asserts
     `jq -r '.tool_input.dangerouslyDisableSandbox'` of the very payload given
     to the hook equals `true` before running it (a failed payload would stop
     the case with a different failure line, `[ ... = "$flag" ]`, not the
     "no verdict emitted" one). Shown by hand below. (ii) and (iii) are
     excluded by the paired flag-absent twins: 4a pairs with the existing "no
     transcript, today's verdict" case, 4c with test 3, both green on the same
     config dirs and fixture text, differing only in the flag. 4b has test 2
     for a twin, red today for the found text, so its "gate dropped" reading
     is only provable after GREEN (once test 2 is green, 4b red means the
     gate). That is the one place the pair is not independently green today.

Payload proof: `post_payload "$text" "" true` runs `jq --argjson f true` and
sets `.tool_input.dangerouslyDisableSandbox = true`; `resume_verdict` asserts
this on every flag-true case (the assertion passes in all three, since the
failure is the later "no verdict emitted" line, not the payload line).

## Mutation proof

Test 3 ("one of two ids has a transcript, the lost verdict", flag absent).

- Mutation in `lib/probes.sh`, the string occurring once:
  `        [ -n "$hit" ] || verdict=lost` replaced by
  `        [ -n "$hit" ] || :`.
  A partial now reads `found`.
- Landed: `command grep -cF '        [ -n "$hit" ] || :' lib/probes.sh` returned 1.
- Red: `bats -f 'one of two ids has a transcript, the lost verdict'` showed the
  flag-absent case failing with `no verdict emitted, flag 'absent'` (found
  verdict is empty), on its own `resume_verdict` assertion.
- Restored by the inverse replacement (the same script with the strings
  swapped). `command grep -cF` of the mutation text returned 0, `verdict=lost`
  occurs once again, `git status` shows `lib/probes.sh` unmodified, and
  `bats -f 'through the hook: one of two ids'` gives `ok 1`.

## Notes

- shellcheck reports only info-level SC2030/SC2031 on `$output` in the new
  helper, the same pattern as existing cases in these files. The justfile has
  no `lint` recipe, so `just precommit` is the gate for GREEN.
- `tests/helpers/verdicts.bash` has a `resume_lost lost` row only. GREEN may
  want a `resume_lost found` row; the 400-character and two-line checks there
  would then cover the found text. Not changed here.
- `hooks/annotate.sh:93-96` comment still says resume-lost is silent under the
  flag; that is GREEN's.
