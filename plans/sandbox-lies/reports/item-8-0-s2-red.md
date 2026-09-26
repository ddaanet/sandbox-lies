# Item 8.0 slice 2 — RED report

`readonly-path states only the acts its facts select`
(`tests/verdicts-readonly.bats`, `tests/hook-candidates.bats`; the three
existing readonly-path transcription tests in `tests/verdicts.bats`)

## Scope

- New file `tests/verdicts-readonly.bats` (152 lines): `verdict_readonly_path`
  tail/merge-clause composition from synthetic stdin key lines (`path=`,
  `readfile=`, `merge=1`, `target=`, `match=`), per
  `docs/references/detectors.md` §readonly-path Verdicts.
- `tests/helpers/verdicts.bash`: `readonly_path_tail()` rewritten to the new
  no-facts tail (`Re-run the whole call with
  \`dangerouslyDisableSandbox: true\`.`), used by `tests/verdicts.bats`'s
  three existing readonly-path transcription tests — no direct edit to
  `tests/verdicts.bats` itself was needed since those tests already delegate
  to this helper.
- `tests/hook-candidates.bats`: one new test proving the hook passes
  `tool_input.command` byte-exact as the probe's third argument (newline,
  backslash, leading `-`; non-string/absent reads empty).
- No SUT file touched except the mutation proof below, restored before this
  report was written.

## Per-test red output

### tests/verdicts.bats

- `readonly-path writable verdict text matches detectors.md`
  ```
  not ok 5 readonly-path writable verdict text matches detectors.md
  # (in test file tests/verdicts.bats, line 114)
  #   `[ "$line1" = "\`$p\`$rest" ]' failed
  ```
- `readonly-path nopath verdict text matches detectors.md`
  ```
  not ok 7 readonly-path nopath verdict text matches detectors.md
  # (in test file tests/verdicts.bats, line 148)
  #   `[ "$line1" = "The sandbox's write allowlist most likely refused this write.$(readonly_path_tail)" ]' failed
  ```
- `readonly-path readonly verdict text matches detectors.md` — unaffected by
  the new tail (readonly carries no tail either before or after); still
  passes, as before this slice. Not part of the composition change.

### tests/verdicts-readonly.bats

- `readonly-path with no facts states the plain re-run act`
  ```
  not ok 1 readonly-path with no facts states the plain re-run act
  # (in test file tests/verdicts-readonly.bats, line 29)
  #   `[ "$w" = '`/r/x` is writable outside the sandbox, whose allowlist refused it. Re-run the whole call with `dangerouslyDisableSandbox: true`.' ]' failed
  ```
- `readonly-path readfile fact re-runs the writer, not the whole call`
  ```
  not ok 2 readonly-path readfile fact re-runs the writer, not the whole call
  # (in test file tests/verdicts-readonly.bats, line 44)
  #   `[ "$line1" = "$expected" ]' failed
  ```
- `readonly-path settings.json path composes the update-config act, readfile winning`
  ```
  not ok 3 readonly-path settings.json path composes the update-config act, readfile winning
  # (in test file tests/verdicts-readonly.bats, line 57)
  #   `[ "$line1" = '`/r/.claude/settings.json` is writable outside the sandbox, whose allowlist refused it. Write `.claude/settings.json` through the `update-config` skill.' ]' failed
  ```
- `readonly-path merge with target and match restores the named files then acts`
  ```
  not ok 4 readonly-path merge with target and match restores the named files then acts
  # (in test file tests/verdicts-readonly.bats, line 77)
  #   `[ "$line1" = '`/r/x` is writable outside the sandbox, whose allowlist refused it. The merge or checkout left files at the target with HEAD unmoved, blocking a re-run: restore `a`, `b` from HEAD — they match `main` —, then re-run the whole call with `dangerouslyDisableSandbox: true`.' ]' failed
  ```
- `readonly-path merge alone restores the written files then acts`
  ```
  not ok 5 readonly-path merge alone restores the written files then acts
  # (in test file tests/verdicts-readonly.bats, line 90)
  #   `[ "$line1" = '`/r/x` is writable outside the sandbox, whose allowlist refused it. The merge or checkout left the files it wrote with HEAD unmoved, blocking a re-run: restore them from HEAD, then re-run the whole call with `dangerouslyDisableSandbox: true`.' ]' failed
  ```
- `readonly-path merge with target and no match states the act alone`
  ```
  not ok 6 readonly-path merge with target and no match states the act alone
  # (from function `text_lacks' in file tests/helpers/verdicts.bash, line 88,
  #  in test file tests/verdicts-readonly.bats, line 104)
  #   `text_lacks "$line1" 'restore'' failed
  ```
  (Currently reds because the old fixed tail always contains "restore"; once
  the merge-clause omission is implemented this line will contain no
  "restore" and the baseline-equality assertion just above it will hold.)
- `readonly-path merge match list caps at five names then and N more`
  ```
  not ok 7 readonly-path merge match list caps at five names then and N more
  # (in test file tests/verdicts-readonly.bats, line 117)
  #   `printf '%s' "$line1" | grep -qF '`a`, `b`, `c`, `d`, `e`'' failed
  ```
- `readonly-path readonly ignores the probe's facts` — passed unmodified (see
  Mutation proof below).
- `readonly-path composition drops the old tail wording`
  ```
  not ok 9 readonly-path composition drops the old tail wording
  # (from function `text_lacks' in file tests/helpers/verdicts.bash, line 88,
  #  in test file tests/verdicts-readonly.bats, line 149)
  #   `text_lacks "$combined" 'If a merge'' failed
  ```

### tests/hook-candidates.bats

- `readonly-path probe receives tool_input.command byte-exact`
  ```
  not ok 8 readonly-path probe receives tool_input.command byte-exact
  # (in test file tests/hook-candidates.bats, line 181)
  #   `[ "$(cat "$recorded")" = "[false][/tmp/scratch][$cmd]" ]' failed
  ```
  Reds on the first sub-case (byte-exact command): the current hook calls
  `"$probe_fn" "$flag" "$cwd"` with no third argument, so the stub's recorded
  `$@` has only two bracketed fields, not three. The test's later sub-cases
  (non-string / absent `tool_input.command` reading empty) are not reached
  until this one is fixed — expected, since bats stops a test at its first
  failing assertion.

## Mutation proof

`readonly-path readonly ignores the probe's facts` passed unmodified: the
current `verdict_readonly_path` only ever parses a `path=` line from stdin
(every other key, including `merge=`, is read and silently discarded), so its
`readonly` branch already ignores every fact regardless of composition —
exactly the behaviour this test names, already present per the slice text's
own "`readonly` ignores the facts" clause.

Mutation, in `lib/verdicts.sh`'s `verdict_readonly_path` read loop:

- Before: `      path=*) path=${line#path=} ;;`
- After: `      path=*) path=${line#path=} ;;\n      merge=*) path="${path}M" ;;`

This makes a `merge=1` stdin line perturb `$path` (present in the test's
`text` call, absent in its `baseline` call), which the readonly branch
interpolates into its subject — breaking the equality the test asserts.

Re-run after the mutation (`tests/verdicts-readonly.bats`):
```
not ok 8 readonly-path readonly ignores the probe's facts
# (in test file tests/verdicts-readonly.bats, line 134)
#   `[ "$text" = "$baseline" ]' failed
```
9 failed / 0 passed for that file (the test named itself vacuous no longer —
it now reds on its own assertion under the mutation).

Restore: replaced the mutated line back with
`      path=*) path=${line#path=} ;;` (removing the appended `merge=*)`
arm), exactly inverting the swap.

Verified the restore:
```
$ grep -n 'merge=\*) path=' lib/verdicts.sh; echo "grep exit: $?"
grep exit: 1
```
followed by a full re-run of `tests/verdicts-readonly.bats`, confirming the
suite is back to `1 passed, 8 failed` — the one pass being this same test,
now legitimately green on unmodified code, and the other 8 the still-pending
compositions above.

## State at end of dispatch

`lib/verdicts.sh` and `hooks/annotate.sh` are byte-identical to before this
dispatch (`git status` shows no change to either). Only test files changed:
`tests/verdicts-readonly.bats` (new), `tests/helpers/verdicts.bash`,
`tests/hook-candidates.bats`. Nothing committed.
