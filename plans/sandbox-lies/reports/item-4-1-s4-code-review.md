# Review: Item 4.1 slices 4-6 — code review

**Scope**: the implementation and doc changes of the commit "Item 4.1/4 —
probe arguments, config-lock mask, piped success payload (slices 4-6)":
`lib/verdicts.sh` (`verdict_config_lock` `mask` text),
`docs/references/lock-detectors.md` (config-lock `mask` paragraph), and the
probe-argument and PostToolUse paths of `hooks/annotate.sh` that slices 4 and
6 now pin. OUT: tests, slices 7-9, Items 4.2/4.3.
**Date**: 2026-09-25
**Mode**: review + fix

## Summary

The commit changes one phrase of the config-lock `mask` paragraph, from
`The lock in this error` to ``The `config.lock` in this error``, in the doc
and the verdict function. The two stay byte-identical, and the paragraph is
under the cap. The hook passes exactly the flag and cwd the interface
specifies, and does so whitespace-safely. A PostToolUse payload's text
reaches the probe on stdin intact. Two findings. One is a minor wording
inaccuracy whose fix needs a test-transcription edit, which this review may
not make. The other is a test gap: no hook case pins the probe's stdin.
Neither needs a code change to `hooks/annotate.sh`.

**Overall Assessment**: Needs Minor Changes

## Checks requested by the dispatch

- **Doc and code text identical.** I extracted the doc's config-lock `mask`
  bullet, unwrapped it, and compared it against `verdict_config_lock mask`
  lines 1 and 2 joined by `` · `…` ``: identical. `tests/verdicts.bats`
  `lock verdict text matches lock-detectors.md` is green on the same pair.
- **Doc diff is only the change plus reflow.** A `--word-diff=porcelain` of
  `docs/references/lock-detectors.md` shows exactly one word-level change:
  `-lock` / ``+`config.lock` ``. Every other changed line is rumdl's 80-column
  reflow of the same words.
- **Paragraph under 400 characters.** 361 characters (the paragraph line
  alone, as `verdicts under 400 chars` measures it).
- **Directive quality.** The changed sentence is the paragraph's one
  reassurance clause and sets up the acts that follow: re-run with the flag,
  re-run once nothing sandboxed is running, and run the config write
  unsandboxed or through `update-config`. It adds no mechanism or rationale.
  One accuracy problem remains (Minor 1).
- **Flag and cwd per the Interfaces block.** `hooks/annotate.sh:96` runs
  `"$probe_fn" "$flag" "$cwd"`, with both arguments quoted and nothing else
  passed. `$flag` is only ever `true` or `false`: jq emits the literal only
  when `dangerouslyDisableSandbox == true`, and "absent" becomes `false`. That
  matches "`$1` the flag (`true`/`false`, absent meaning `false`)". `$cwd`
  goes through jq, which doubles each backslash and writes each newline as
  `\n`, then through `printf -v cwd '%b'` (line 64). That round-trips `\c`,
  `\0nnn` and embedded newlines literally, since every backslash reaching
  `%b` is doubled. Whitespace runs survive because the value is never
  word-split. The case in `probe receives flag and cwd` (`/a  b\c`) and the
  test review's five mutations (dropped, extra, unquoted, swapped, undecoded)
  cover this.
- **Success-payload text reaches the probe intact.** I checked this by hand
  on a throwaway copy of `hooks/` and `lib/` under `$TMPDIR`. A stub
  `probe_git_lock` wrote its stdin to a file. The input was a PostToolUse
  payload with `fire-lock-piped-tail` in `tool_response.stdout`, `err \c line`
  in `stderr`, and cwd `/a  b`. The probe received stdout, a newline, the
  stderr text, then a trailing newline, with the backslash intact. The hook
  emitted the `index.lock` mask human line. Text never passes through `%b`:
  only the cwd does. The throwaway copy has been removed. This is a one-off
  check. The suite does not encode it (Major 1).

## Mutated-SUT run (once)

Mutation: in `hooks/annotate.sh:96`, an exact-string replace (matching
once) of
`probe_out=$(printf '%s\n' "$text" | "$probe_fn" "$flag" "$cwd")` with
`probe_out=$("$probe_fn" "$flag" "$cwd" </dev/null)`. This cuts the probe
off from the result text while keeping its arguments. I ran
`direnv exec . bats tests/hook-locks.bats tests/hook.bats` and then restored
the line with the inverse replace. A `grep` shows line 96 back to the
original, and `git status --short hooks/` is empty.

Result: **all 23 cases stayed green**, with no `not ok`. No hook case detects
a probe that receives the wrong stdin. See Major 1.

## Issues Found

### Critical Issues

None.

### Major Issues

1. **No hook case pins the probe's stdin**
   - Location: `tests/hook-locks.bats`, stubs `stub_probe`, `stub_probe_kv`
     and the slice 4 recorder (all run `cat >/dev/null`);
     `hooks/annotate.sh:96`.
   - Problem: the interface says the hook "runs the probe with the text on
     stdin", and slice 6 exists to show a success payload's text is what gets
     probed. Under the mutation above, which gives the probe `/dev/null` as
     stdin, all 23 hook cases stayed green. The real `probe_git_lock` and
     `probe_config_lock` read the lock path from that text. A hook that fed
     them nothing, or the wrong field, would ship silently. The code is
     correct today (checked by hand, see above).
   - Suggestion: have slice 6's stub, or slice 4's recorder, write its stdin
     to a file under `$BATS_TEST_TMPDIR`. Assert that the file equals the
     fixture text plus the newline join. In slice 6, give the stderr a value
     that is distinct and non-empty, so both parts and their order are
     pinned.
   - **Status**: DEFERRED — the fix is a test edit, and tests are Scope OUT
     for this code review. The orchestrator should route it to the next test
     dispatch for this item: slice 7's sweep, or a test-review fix-up of
     slice 4/6. The code is correct.

### Minor Issues

1. **The config-lock `mask` paragraph points at a string the error does not
   contain**
   - Location: `lib/verdicts.sh:48`; `docs/references/lock-detectors.md:110`.
   - Note: git's config-lock error names the config file (`.git/config`),
     never `config.lock`. Both `fire-configlock-*` fixtures confirm this.
     ``The `config.lock` in this error`` invites the reader to look for that
     string in the error, find nothing, and narrate the discrepancy. That is
     the verify-and-narrate reaction a directive is meant to avoid. The
     git-lock paragraph has no such problem, because git's index-lock error
     does name `index.lock`. Fix: ``The `config.lock` behind this error``.
     This keeps slice 5's `config.lock` assertion satisfied and measures 365
     characters.
   - **Status**: UNFIXABLE (U-REQ)
   - **Investigation:**
     1. Scope OUT: tests are OUT. The fix must change the verbatim
        transcription at `tests/verdicts.bats:143` in the same edit, or
        `lock verdict text matches lock-detectors.md` goes red and precommit
        fails.
     2. Design deferral: not deferred. The runbook takes the text from
        `lock-detectors.md` and does not fix the wording.
     3. Codebase pattern: the three copies are pinned byte-for-byte on
        purpose (the green report's point 2), so no code-and-doc-only fix
        exists.
     4. Conclusion: "apply all fixes" conflicts with the code-review rule
        "never edit the tests here". This is a minor wording issue, so the
        orchestrator decides. To apply it, replace `The `config.lock` in this
        error` with `The `config.lock` behind this error` in all three files
        in one edit, then run rumdl reflow via `just precommit`.

## Fixes Applied

None. The only code-and-doc fix (Minor 1) needs a test-file edit this review
may not make. Major 1 is a test addition.

## Requirements Validation

| Requirement | Status | Evidence |
|-------------|--------|----------|
| Interfaces: probe `$1` flag `true`/`false`, absent → `false` | Satisfied | `annotate.sh:44-45,96`; slice 4 cases `[true][/x]`, `[false][/x]` |
| Interfaces: probe `$2` payload cwd | Satisfied | `annotate.sh:47-48,64,96`; slice 4 `/a  b\c` case |
| Interfaces: probe gets the text on stdin | Satisfied, unpinned | `annotate.sh:96`; hand check; not detected by the suite (Major 1) |
| Slice 5: config-lock mask context names `config.lock`, `update-config` | Satisfied | `verdicts.sh:48`; slice 5 green |
| Slice 6: PostToolUse stdout lock failure → `GIT_INDEX_FILE` (D-4) | Satisfied | `annotate.sh:51-53`; slice 6 green |
| FR-6: paragraph ≤ 400 chars | Satisfied | 361 characters |
| Doc = code | Satisfied | direct comparison identical |

## Gate

`cd /Users/david/code/sandbox-lies && direnv exec . just precommit`, run in
the foreground:

```text
scripts/run-bats.sh tests/
bats: 144 passed, 0 failed
precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests
```

The working tree is unchanged by this review, apart from this report.

## Positive Observations

- The GREEN change is minimal: one phrase, in the paragraph slice 5 needed
  and nowhere else. Config-lock's other outcomes and git-lock's paragraph
  are untouched.
- The cwd escape-and-decode path doubles backslashes before `%b`, so no
  escape sequence in a real path is interpreted. Only the cwd goes through
  `%b`. The text does not.
- The test review's mutation table already covers each argument-shape
  failure of line 96.

## Recommendations

- Close Major 1 in the next test-writing dispatch for Item 4.1. A stdin
  recorder in slice 6's case is the smallest change.
