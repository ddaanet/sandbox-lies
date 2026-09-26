# Review: Item 8.0 slice 2 — test review

**Scope**: the uncommitted slice-2 test changes (`tests/verdicts-readonly.bats`
new, `tests/helpers/verdicts.bash`, `tests/hook-candidates.bats`) and the RED
report `plans/sandbox-lies/reports/item-8-0-s2-red.md`. This review also edited
`tests/hook-locks.bats` and `tests/verdicts.bats`, where tests outside the RED
changes contradict the new spec (findings 1 and 2).
**Date**: 2026-09-26
**Mode**: review + fix (test review, TDD slice)

## Summary

The RED set was mostly sound. Every listed test failed on an assertion, and
the one pass carries a mutation proof that I reproduced with a different
mutation. The hunt found two existing tests that the new spec contradicts. GREEN
could not have passed them without editing tests, which it may not do. It also
found one wrong-reason assertion in the hook test (the backslash case survived
without the escaping it claimed to check) and several gaps against the slice
text, all now covered. After the fixes, all 17 slice tests are red on their
assertions against unchanged `lib/` and `hooks/`. The rest of the suite (196
tests) is green. Checked against a throwaway spec implementation in `$TMPDIR`
(deleted afterwards), every test file passes, so the pinned strings do not
contradict each other.

**Overall Assessment**: Ready

## Mechanical first check

- `tests/verdicts-readonly.bats`: 8 of 9 original tests failed on an assertion,
  matching the RED report line for line. Test 6 (`merge with target and no
  match`) reds on `text_lacks … 'restore'` while its equality line passes for
  now: both sides carry the same old fixed tail. After GREEN the equality is
  pinned through test 1's baseline. Accepted.
- `readonly-path readonly ignores the probe's facts`: passes on unchanged
  code. The RED's mutation (`merge=*) path="${path}M"`) was not reused. I
  reproduced the proof with a different one: `readfile=*) path=${line#readfile=}
  ;;` inserted into `verdict_readonly_path`'s read loop. The test redded at
  `[ "$text" = "$baseline" ]`. I restored it by deleting that exact line. `command
  grep -n 'readfile=\*)' lib/verdicts.sh` exited 1, `git diff -- lib/ hooks/` was
  empty, and the test went green again.
- `tests/hook-candidates.bats` byte-exact test: failed on the first recorded-args
  assertion (two fields, not three), as reported.
- `tests/verdicts.bats` writable/nopath transcriptions: fail on the exact line
  through the rewritten `readonly_path_tail`. The readonly one passes and is
  unaffected, as reported.

## Issues Found

### Critical Issues

1. **Existing hook tests assert the old tail wording**
   - Location: `tests/hook-candidates.bats` "writable outcome through the hook",
     "nopath outcome through the hook"
   - Problem: both grepped `restore them from HEAD once they match the target`.
     The spec removes that phrase, so GREEN would turn both red and could not
     fix them without editing tests.
   - Fix: the writable case now stubs `path=/r/x` plus `merge=1` and asserts
     the merge clause through the hook: `restore them from HEAD, then re-run
     the whole call with \`dangerouslyDisableSandbox: true\`.` This also proves
     that the probe's fact lines reach the verdict's stdin. The nopath case now
     pins the whole additionalContext exactly to the no-facts paragraph.
   - **Status**: FIXED

2. **Lock probe-args test pins exactly two arguments**
   - Location: `tests/hook-locks.bats` "probe receives flag and cwd"
   - Problem: it asserted `[true][/x]`, `[false][/x]` and `[false][/a  b\c]`. The
     slice has the hook pass the command as *every* probe's third argument, so
     GREEN would record a third field (the fixture's command) and fail this
     test. Found by running the whole suite against the throwaway
     implementation.
   - Fix: each payload now sets `.tool_input.command = "c"`, and each
     expectation gains `[c]`. Renamed to "probe receives flag, cwd and
     command", with the comment's "two" changed to "three". The file stays at
     398 lines, because each change replaced a line in place.
   - **Status**: FIXED

### Major Issues

1. **Backslash case did not exercise the escaping (wrong-reason)**
   - Location: `tests/hook-candidates.bats` byte-exact test, `cmd=$'-x \\y\nz'`
   - Problem: `printf %b` leaves an unknown escape like `\y` as it is. A hook
     that turns newlines into `\n` but never doubles backslashes passes this
     command unchanged, so the backslash half of "escaped as the cwd is"
     proved nothing. Verified: `printf -v o '%b' '-x \y\nz'` equals
     `$'-x \\y\nz'`.
   - Fix: `cmd=$'-n a\\nb \\\\ c\nz'`. It holds a literal `\n` and `\\`, which
     `%b` rewrites unless each backslash is doubled, plus a real newline and a
     leading `-n`. With the throwaway implementation's doubling removed, the
     test reds.
   - **Status**: FIXED

2. **"Every probe" covered only readonly-path**
   - Location: same test
   - Problem: the slice says the command goes to every probe. A GREEN that
     passes it only to `probe_readonly_path` would pass.
   - Fix: the test (renamed "every probe receives tool_input.command
     byte-exact") also stubs a recording `probe_git_lock` over
     `fire-lock-add-commit.txt` and asserts the same byte-exact third argument.
   - **Status**: FIXED

3. **Merge clause tested only into the whole-call act**
   - Location: `tests/verdicts-readonly.bats`
   - Problem: "a merge clause leads into the act, lowercase" was pinned only
     for the whole-call act. A GREEN that hardcoded `then re-run the whole
     call…` inside the clause would pass. The merge clause under `nopath` was
     only checked negatively.
   - Fix: new test "merge clause leads lowercase into whichever act the facts
     select". It pins three lines exactly, each with length and quiet checks:
     merge alone + `readfile=` → `…, then re-run the command that wrote
     \`/w/b.log\`.`; settings path + merge/target/one match → `restore \`a\`
     from HEAD — they match \`t\` —, then write \`.claude/settings.json\`
     through the \`update-config\` skill.`; `nopath` + merge/target/match →
     `…, then re-run the whole call with \`dangerouslyDisableSandbox: true\`.`
   - **Status**: FIXED

4. **Update-config act: writable-only and path matching untested**
   - Location: `tests/verdicts-readonly.bats` settings test
   - Problem: the spec's "(`writable` only)" had no test, and nothing ruled out
     a loose `*settings.json` match.
   - Fix: new test "update-config act is writable-only and needs a
     .claude/settings.json". `nopath` with `path=/r/.claude/settings.json` →
     the plain whole-call act. `writable` with `path=/r/settings.json` → the
     plain act. Each case pairs a `text_lacks 'update-config'` negative with an
     exact positive. The existing writable settings test is the positive over
     the same stdin.
   - **Status**: FIXED

5. **readfile precedence pinned only in probe line order**
   - Location: settings test
   - Problem: with `path=` before `readfile=`, a "last fact line wins" rule
     also passes.
   - Fix: the read act is also asserted with `readfile=` before `path=`.
   - **Status**: FIXED

6. **Seven-match cap checked by substrings only; five-name boundary untested**
   - Location: "merge match list caps at five names then and N more"
   - Problem: substring greps allowed `and 2 more` anywhere, and a stray
     `and 0 more` at exactly five matches went undetected.
   - Fix: the seven-match line is pinned whole. detectors.md leaves one point
     open: whether a comma comes before `and N more`. Both joins (`\`e\` and 2
     more from HEAD…` and `\`e\`, and 2 more from HEAD…`) are accepted, and
     the comment in the test says so. A new five-match case pins the exact line
     with no `more`.
   - **Status**: FIXED

### Minor Issues

1. **Longest composition had no length check with one-character values**
   - Location: `tests/verdicts-readonly.bats`
   - Note: the slice asks for a length check "each composition, one-character
     values". The largest one (update-config act behind a capped seven-match
     clause) was never measured. Added "longest composition stays under 400
     with one-character values" (`path=/.claude/settings.json`, `target=t`,
     `match=a…g`). It first greps that the clause and act are both present, so
     a short broken line cannot pass.
   - **Status**: FIXED

2. **Old-phrase negatives had no paired positives; settings and nopath-merge
   compositions missing; no D-7 check on the merge clauses**
   - Location: "composition drops the old tail wording"
   - Note: an empty or failed composition would have passed all three
     negatives. Each negative is now paired with its replacement phrase over
     the same combined text (`The merge or checkout left`, `— they match
     \`main\` —`, `Re-run the command that wrote`). The settings and
     nopath-merge compositions are added. The global "no removal instruction"
     check (`tests/verdicts.bats`) sees only no-facts text, so the D-7
     `rm |remove|delete` check now also runs over the merge compositions,
     paired with `restore them from HEAD`. Renamed "compositions drop the old
     tail wording and remove nothing".
   - **Status**: FIXED

3. **readonly-ignores test depended on another file for its baseline**
   - Location: "readonly-path readonly ignores the probe's facts"
   - Note: `text = baseline` holds even if both are wrong the same way. Added
     an exact pin of the readonly line.
   - **Status**: FIXED

4. **Stale comment in the nopath transcription test**
   - Location: `tests/verdicts.bats` "readonly-path nopath verdict text
     matches detectors.md"
   - Note: it still said nopath's rest is "the writable paragraph from `If a
     merge` on". Reworded to the tail with no facts, the whole-call re-run.
   - **Status**: FIXED

5. **Non-object `tool_input` not covered**
   - Location: hook byte-exact test
   - Note: `.tool_input.command` read without an `objects` guard is a fatal jq
     error on a string `tool_input`, which would silence the hook on that
     payload. No existing test covers it. Added a sub-case: `.tool_input =
     "cp a /tmp/x"` must still emit output and hand the probe an empty third
     argument.
   - **Status**: FIXED

## Fixes Applied

- `tests/verdicts-readonly.bats` — the settings test now asserts readfile
  winning in both line orders. New tests: writable-only/near-miss path for
  update-config, merge clause into each act (writable readfile, writable
  settings, nopath), longest composition at one-character values. The cap test
  pins the whole line (either comma join) and adds the exact five-match
  boundary. The readonly test gains an exact line pin. The old-phrase test
  gains paired positives, the settings and nopath-merge compositions, and a D-7
  check. 152 → 237 lines.
- `tests/hook-candidates.bats` — the writable/nopath "outcome through the hook"
  tests now assert the new wording (writable through a `merge=1` fact line,
  nopath exact). The byte-exact test is renamed "every probe receives
  tool_input.command byte-exact", with a `%b`-sensitive command, a non-object
  `tool_input` sub-case and a `probe_git_lock` recorder. 212 → 237 lines.
- `tests/hook-locks.bats` — "probe receives flag, cwd and command": each
  payload sets the command and each expectation takes the third field. 398
  lines, unchanged.
- `tests/verdicts.bats` — nopath transcription comment reworded.
- `lib/verdicts.sh` — mutation applied and reverted for the reproduction only.
  No net change (`git status` clean for `lib/` and `hooks/`).

## Verification

- `scripts/run-bats.sh tests/` against unchanged `lib/` and `hooks/`: 196
  passed, 17 failed, and every failure is a slice assertion. That is 11 in
  `tests/verdicts-readonly.bats` (the readonly-ignores test is green, backed
  by its mutation proof), 3 in `tests/hook-candidates.bats`, 1 in
  `tests/hook-locks.bats` and 2 in `tests/verdicts.bats`. None ERRORed.
- A throwaway spec implementation in a `$TMPDIR` copy of `lib/`, `hooks/` and
  `tests/` passes every suite (excluding `docs.bats`, which needs `plans/`,
  not copied). The pinned strings are therefore satisfiable together.
- `shellcheck -x` is clean on the changed files. `lib/matchers.sh` fires on
  none of them (they are untracked, so FR-11's `docs.bats` sweep does not yet
  read them).

## Requirements Validation

| Requirement (slice 2) | Status | Evidence |
|---|---|---|
| hook passes `tool_input.command` as every probe's 3rd arg, byte-exact (newline, backslash, leading `-`); non-string → empty | Covered | hook-candidates "every probe receives…"; hook-locks "probe receives flag, cwd and command" |
| no facts → the act alone | Covered | verdicts-readonly test 1; verdicts.bats transcriptions |
| `readfile=` → re-run the writer, no `dangerouslyDisableSandbox` | Covered | test 2; precedence over settings in both orders |
| settings.json → update-config act, writable only, readfile wins | Covered | tests 3, 4 |
| merge + target + match → named restore then act | Covered | test 5; into each act, test 7 |
| merge alone → restore them then act | Covered | tests 6, 7 |
| merge + target, no match → no clause | Covered | test 8 |
| seven matches → five names then `and 2 more` | Covered | test 9, plus the five boundary; comma join left open per spec |
| old phrases absent in every composition | Covered | test 12, positives paired |
| readonly ignores facts | Covered | test 11, mutation-proven |
| length < 400 and quiet over the compositions | Covered | per-test checks; test 10 longest at one-character values |

**Gaps:** none.

## Positive Observations

- The RED report records its mutation and its grep-verified restore exactly,
  so the proof was checkable.
- `readonly_path_text` feeds synthetic stdin in one subshell per composition,
  and the quiet checks run the real matcher over each composed text.
- The byte-exact hook test brackets every argument, so a dropped or split
  argument shows up in the recorded value.

## Recommendations

- detectors.md does not say whether a comma comes before `and N more`. When
  GREEN picks a join, a one-word doc edit and a single exact string in the cap
  test would close it.
