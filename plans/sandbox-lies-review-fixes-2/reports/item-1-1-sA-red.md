# Item 1.1 Slice A — RED report

Files: `tests/probes-resume.bats` (new, loads `helpers/bsd-stubs`),
`tests/hook-candidates.bats`, `tests/verdicts.bats`,
`tests/helpers/verdicts.bash`, and the inert stub
`probe_resume_lost() { cat >/dev/null; }` in `lib/probes.sh`. Nothing
committed. `lib/verdicts.sh` and `hooks/annotate.sh` untouched.

Every fixture config dir and `HOME` lies under `$BATS_TEST_TMPDIR`. The
existing "resume-lost flag policy" case now exports `CLAUDE_CONFIG_DIR` at an
empty dir and is otherwise unchanged. `tests/hook-candidates.bats` gained a
file-level `shellcheck disable=SC2030,SC2031` for the per-case export.

Against the stub the probe prints nothing, so every `probe_resume_lost` case
fails on `[ "$output" = lost|found ]`. The hook then passes an empty outcome
to the unchanged verdict, which prints today's `lost` text.

## Per test

1. `hook-candidates.bats` "resume-lost through the hook: transcripts for both
   ids, no verdict" (case 1). RED: `assert_lacks "$output" 'never written''
   failed` (hook.bash:107).
   - World: both ids have `projects/-p/<id>.jsonl`, flag absent.
   - Else could produce it: a hook silent for another reason (gate, probe
     error). The paired case 2 pins that the same payload with an empty config
     dir does emit.
2. `hook-candidates.bats` "resume-lost through the hook: no transcript,
   today's verdict" (case 2). GREEN against the stub (behaviour exists); see
   Mutation proof. Asserts the exact paragraph and `systemMessage`.
   - World that fails it: verdict text changed, or hook silent with an empty
     config dir.
3. `probes-resume.bats` "one id without a transcript is lost" (case 3). RED:
   `[ "$output" = lost ]` (line 49). Only `$ID_1` has a transcript.
   - Else: a constant-`lost` probe; the found case pairs it.
4. "a transcript for an unrelated id does not count" (case 4). RED:
   `[ "$output" = lost ]` (line 59). Only an unrelated id has a `.jsonl`; a
   probe testing for any `.jsonl` prints `found`.
5. "a directory named <id>.jsonl is not a transcript" (case 5a). RED:
   `[ "$output" = lost ]` (line 69). `$ID_1` has a real file, `$ID_2` is a
   directory; a probe using `-e` prints `found`.
6. "a transcript under archived/ is not counted" (case 5b). RED:
   `[ "$output" = lost ]` (line 80). `$ID_1` real, `$ID_2` only under
   `projects/-p/archived/`; a recursive search prints `found`.
7. "both ids have a transcript, found" (case 6). RED: `[ "$output" = found ]`
   (line 39); also asserts exit 0, empty stderr. Positive partner: fails a
   constant-`lost` probe.
8. "CLAUDE_CONFIG_DIR unset falls back to HOME/.claude" (case 7). RED:
   `[ "$output" = found ]` (line 92). Transcripts only under
   `$HOME/.claude/projects/-p/`; a probe ignoring the fallback globs
   `/projects/*` and prints `lost`.
9. `hook-candidates.bats` "resume-lost no-transcript verdict survives BSD
   grep, sed, mktemp, stat and wc" (case 8). GREEN against the stub; see
   Mutation proof. Runs the hook plain, then with `make_bsd_stubs` ahead on
   `PATH`; asserts stdouts equal and non-empty, plus the `systemMessage`.
10. `verdicts.bats` "resume-lost verdict prints nothing for an outcome it has
    no text for" (case 9, `-`). RED: `[ -z "$output" ]` (line 107); the
    unchanged verdict ignores its argument and prints text. Status 0 is
    asserted first.
11. `verdicts.bats:90-94` and `tests/helpers/verdicts.bash:39` now pass
    `lost`; the "candidate verdict text matches detectors.md" case and the row
    table stay green.

Suite results: `verdicts` 8 passed 1 failed (the new case);
`hook-candidates` 15 passed 1 failed (case 1); `probes-resume` 0 passed 6
failed.

## Mutation proof

Each mutation: exact replacement of a once-occurring string, text confirmed
with `command grep`, test red, restored by the swapped replacement, then
`command grep -c` returned 0 and the test ran green.

- Test 2 (`lib/verdicts.sh`): `is read-only inside the sandbox.` to
  `is MUTATED inside the sandbox.` RED on the `[ "$ctx" = '…' ]` assertion
  (line 115). Restored: 0 hits, green.
- Test 9 (`lib/probes.sh`): `probe_resume_lost() { cat >/dev/null; }` to
  `probe_resume_lost() { cat >/dev/null; sed --version >/dev/null; }` (a
  GNU-only long option the BSD `sed` stub rejects). RED on
  `[ "$output" = "$plain" ]` (line 135), the plain run having passed.
  Restored: 0 hits, green.
