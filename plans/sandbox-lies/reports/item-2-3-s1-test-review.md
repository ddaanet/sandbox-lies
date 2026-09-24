# Item 2.3 slice 1 — test review

Mode: test review of the RED phase. Nothing committed. The stubs
(`hooks/annotate.sh`, `hooks/hooks.json`, `lib/verdicts.sh`) are
byte-identical to their RED versions, checked by sha256 after every probe and
again at the end. Only `tests/hook.bats`, `tests/verdicts.bats` and
`tests/helpers/hook.bash` changed.

## Verdict

The RED phase was sound on its face (five reds, each on an assertion), but the
probes found four implementations that should fail and passed, plus one wrong
implementation that stayed green in every test of `verdicts.bats`. I fixed all
of them. Five tests are still red on assertions against the stubs, and a
reference implementation passes all six.

## Findings and fixes

1. **Major: verdict stdin swallowed the row table** (`verdicts.bats`).
   `verdict_text` called the verdict inside `while read … done < <(rows)`
   without redirecting stdin. A verdict that reads its probe lines, which the
   Interfaces allow (stdin is the probe's `key=value` lines), consumed rows
   2–3. Probe V2 used 450-character paragraphs and a `remove` in rows 2–3, and
   all three tests passed. Fix: the verdict call gets `</dev/null`, which is
   the "empty when no probe" stdin.
2. **Major: the quiet negative was not paired** (`hook.bats`). The quiet
   case used `post_payload` while the gitadd case used `failure_payload`, so
   the two differed in both the event and the text. Probe P3, a hook that
   emits the gitadd verdict whenever the event is `PostToolUseFailure` and
   ignores the text, passed both tests. Fix: the quiet case also runs the same
   text as a failure payload, prefixed `Exit code 1` as D-13 shapes it. This
   uses the same helper, event and invocation as the gitadd case, so only the
   text differs. The `PostToolUse` half stays as the slice specifies.
3. **Major: `hooks.json` checks were too loose.** `endswith("hooks/annotate.sh\"")`
   accepted `"${CLAUDE_PLUGIN_ROOT}/hooks/annotate.sh"` with no `bash`. That
   form needs the exec bit, and the tests never exercise that invocation. It
   also accepted `bash "${CLAUDE_PROJECT_DIR}/…"`, which points at the wrong
   root. The check also allowed a `PreToolUse` registration (FR-1 forbids
   one), a missing `type`, and a hook registered twice. Fix: the command must
   equal Item 2.3's exact string `bash "${CLAUDE_PLUGIN_ROOT}/hooks/annotate.sh"`,
   passed with `--arg`. Also required: `.hooks | keys` exactly the two events,
   one entry per event, one hook per entry, and `type == "command"`.
4. **Major: a verdict function with no row escaped every check**
   (`verdicts.bats`). This was probe V6: `verdict_git_lock` with a
   450-character paragraph and a `delete`. Fix: `verdicts under 400 chars`
   first requires the set of `verdict_*` functions defined by
   `lib/verdicts.sh`, listed in a clean `bash -c` so the suite's own
   `verdict_text` does not count, to equal the set of row names. That makes
   "every row" mean every verdict. Outcome coverage per function cannot be
   derived this way; Items 4.1, 4.2 and 6.1 still owe one row per outcome.
5. **Minor: the two-line shape was not enforced.** A three-line verdict
   passed (probe V8), and so did an empty paragraph with only a human line
   (probe V10). Fix: the text must be exactly two lines, and line 1 must be
   non-empty.
6. **Minor: a failing row was dropped silently.** `all_verdict_text` runs
   inside `$(…)`, which errexit does not reach, so a missing verdict function
   was left out of the concatenation. The quiet and removal tests passed over
   the remaining rows (probe V9). Fix: `|| return 1` on each row's call. Now
   `all=$(all_verdict_text)` fails the test.
7. **Minor: the removal check could go red for the wrong reason.** `rm `
   matched inside `confirm ` and `form ` (probe V7 failed on "Confirm the
   tree"). Also, `[ "$status" -ne 0 ]` accepted grep's error status 2. Fix:
   the pattern is now `(^|[^[:alpha:]])rm `, which is portable ERE with no
   `\b`, and the check asserts `status -eq 1`.
8. **Minor: `stub_lib` guards** (helper). A misnamed file such as
   `verdict.sh` would be created fresh and never sourced, which leaves the stub
   silently inert and passes slice 9's negative. An unset `HOOK_COPY` would aim
   the append at `/lib`. Fix: `${HOOK_COPY:?…}` plus a check that the copied
   file exists, with a message on stderr.

## Checked and left as is

- **Hardcoded `hookEventName`** (probe P5) passes slice 1, as expected. Slice
  2 catches it (`hookEventName` is `PostToolUse` on a success payload).
- **`error` vs `tool_response.stdout` on failure.** `payload-failure.json`
  has no `tool_response` key, and `failure_payload` writes the text only to
  `.error`, which matches the recorded live shape. A hook that reads stdout on
  failure (P4) goes red, and so does one that feeds the raw payload JSON to
  `detect` (P7).
- **Helper against the Interfaces.** The argument order matches. For the
  flag: absent means the key is absent from `tool_input`, the same as both
  recorded fixtures; `false` and `true` set a JSON boolean. `post_payload o ""
  true` sets the flag with an empty stderr. Verified with jq.
- **Copied tree.** `setup` runs `hook_copy_tree` per test into
  `$BATS_TEST_TMPDIR/hook-copy`, and both hook runs invoke `bash
  "$HOOK_COPY/hooks/annotate.sh"`. A `stub_lib` probe changed only the copy;
  the sha256 of the repo's lib was unchanged.
- **`detect` from the repo's lib in `verdicts.bats`.** This is correct.
  `verdicts.bats` stubs nothing, and its subject is the shipped lib. The
  matchers are monotone (line-anchored, or "at least N"), so running detect
  over the concatenation is at least as strict as running it per row.
- **The stripped phrase.** Only the exact phrase `add, delete and report` is
  stripped, so any other `delete`, `remove` or `rm ` in the same text still
  fires. Residual: using that exact phrase as an instruction would be
  sanctioned. No realistic wording does that.
- **`run` merges stderr** into `$output`. This is stricter than stdout-only
  for both hook cases, and slice 6 asserts stderr separately.
- Not pinned: a hook that sources its lib through a `CLAUDE_PLUGIN_ROOT` set
  in the environment. That variable is unset in the test environment (checked),
  so such a hook fails slice 1. Slices 7 and 9 pin copy-sourcing through
  `stub_lib`.

## Probe table

Each probe swapped a throwaway implementation into the stubs, ran the suite
and restored the stubs. The restore was checked by sha256 against the RED
originals each time. "Before" and "after" refer to the test fixes. Ref is
annotate + hooks.json + verdicts built to spec: it passed 6/6 both before and
after.

| probe | wrong implementation | before | after |
|---|---|---|---|
| P2 | hook always emits the gitadd verdict | quiet red | quiet red |
| P3 | emits the gitadd verdict on any failure event | **all green** | quiet red |
| P4 | reads `tool_response.stdout` on failure | gitadd red | gitadd red |
| P5 | `hookEventName` hardcoded | green | green (slice 2) |
| P6 | extra top-level `continue` key | gitadd red | gitadd red |
| P7 | pipes raw payload JSON to `detect` | gitadd red | gitadd red |
| H2 | settings format, no `hooks` wrapper | red | red |
| H3 | matcher on the inner hook | red | red |
| H4 | command without `bash` | **green** | red |
| H5 | extra `PreToolUse` registration | **green** | red |
| H6 | `type` missing | **green** | red |
| H7 | `${CLAUDE_PROJECT_DIR}` root | **green** | red |
| H8 | `PostToolUse` registered twice | **green** | red |
| H9 | timeout as a string | red | red |
| V2 | verdicts read stdin; rows 2–3 bad | **all green** | 400 + removal red |
| V3 | "remove the mask" | removal red | removal red |
| V4 | verdict quotes the gitadd diagnostic | quiet red | quiet + 400 red |
| V5 | human line lacks ` — ` | 400 red | 400 red |
| V6 | unrowed `verdict_git_lock`, 450 chars | **all green** | 400 red |
| V7 | benign "Confirm the tree" | removal red (false) | green |
| V8 | three-line verdict | **all green** | 400 red |
| V9 | `verdict_phantom_untracked` missing | 400 red only | all three red |
| V10 | empty paragraph line | **all green** | 400 red |

## Final red run

`scripts/run-bats.sh tests/hook.bats tests/verdicts.bats`:

```
not ok 1 gitadd failure payload yields one verdict
#   `printf '%s' "$output" | jq -e . >/dev/null' failed with status 4
not ok 3 hooks.json names both events
#   `[ "$status" -eq 0 ]' failed
not ok 4 verdicts under 400 chars
#   `[ "$(printf '%s\n' "$text" | awk 'END { print NR }')" -eq 2 ]' failed
not ok 5 verdict text is quiet
#   `[ -n "$(printf '%s' "$all" | tr -d '[:space:]')" ]' failed
not ok 6 no removal instruction
#   `[ -n "$(printf '%s' "$all" | tr -d '[:space:]')" ]' failed
bats: 1 passed, 5 failed
```

Each of the five fails on an assertion. Test 4 now fails at the two-line check
because the stub returns empty text, and it passes the row-coverage check
first: 3 functions, 3 rows. Test 3 now fails on `.hooks | keys` of the stub's
empty object.

- `scripts/run-bats.sh tests/docs.bats`: 1 passed, 0 failed (self-quiet).
- `scripts/run-bats.sh tests/`: 66 passed, 5 failed, exactly the five above.
- `shellcheck` over the three test files and two stub scripts is clean.
  `bash -n tests/helpers/hook.bash` and `jq empty hooks/hooks.json` both pass.

## For the list revision

Slice 1 was widened by this review. `quiet fixture yields nothing` also runs
the text as an `Exit code 1`-prefixed failure payload. `hooks.json names both
events` now asserts the exact command `bash "${CLAUDE_PLUGIN_ROOT}/hooks/annotate.sh"`,
exactly the two events, one registration each, and `type` `command`.
`verdicts under 400 chars` asserts that the row table covers every
`verdict_*` function and that each text is exactly two non-empty lines.
`no removal instruction` matches `rm ` only as a word.
