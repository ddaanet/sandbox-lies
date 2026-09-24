# Item 2.3 slice 2 — test review

Scope: the three new cases in `tests/hook.bats` (`porcelain on stdout fires
untracked`, `listing on stderr fires`, `rebuild inserts a newline between
stdout and stderr`) and `reports/item-2-3-s2-red.md`. Nothing committed.
`hooks/` and `lib/` byte-identical to HEAD (`git diff --quiet hooks lib`
exits 0 after every probe and at the end).

## Verdict

The three tests are sound. Every plausible wrong rebuild probed is caught,
each by the test named for the behaviour it breaks. No wrong-reason red. Two
minor fixes were applied (one to the test, one to the RED report); no
major or critical findings.

## Findings

1. **Minor, fixed: test 3's stderr literal carried a trailing newline**
   (`stderr=$'?? .gitconfig\n'`). The recorded payloads carry no trailing
   newline on either field (`payload-post.json`: `"probe-out-1\nprobe-err-1"`),
   and the newline is not part of what the test discriminates. Now
   `stderr='?? .gitconfig'`. The comment now says both fields are shaped as
   recorded and names the second failure mode the fixture catches: a rebuild
   reading only one field sees one name, which is under the threshold.
   Probe results for test 3 are identical before and after the edit.
2. **Minor, fixed: RED report miscount.** It said the porcelain fixture holds
   "24 status lines' worth of distinct masked names". `match_phantom_untracked`'s
   own pipeline over `fire-masks-porcelain.txt` counts **19**. The conclusion
   (well over the threshold of 2) still holds. Updated the report, and its
   description of test 3's stderr literal to match finding 1.
3. **Note, no fix: stdout/stderr order is unobservable (probe E).** Every
   current matcher is a function of the set of lines in the text:
   `git-lock` is two whole-line `grep`s anywhere in the text, and the other
   four are line-anchored. With a newline separator, the line set is the
   same in either order, so no test on the hook's output can pin "stdout
   then stderr". The item text and FR-3 fix the order, and D-13 records
   `stderr` arriving empty live, so this is acceptable. The order could
   first become observable in Item 4.1, whose probes read the same text on
   stdin. That is out of scope here.
4. **Note, no fix: text drawn from outside `tool_response`.** A rebuild like
   `jq -r '.. | strings'` would also pass all three tests. It pulls in
   `tool_input.command`, `cwd` and the other string fields as well. No
   slice claims "the command is never read" at the hook level (that is a
   matcher convention in `detectors.md`), and this is not a plausible
   implementation of "stdout, newline, stderr", so adding a test was not
   justified. Residual: a later slice or code review can add a quiet case
   with firing text in `tool_input.command` if the hook ever reads more of
   the payload.

Checked and clean:

- **The context phrase is unique to its verdict.** `reading the sandbox,
  not the tree` appears only in `verdict_phantom_untracked`
  (`lib/verdicts.sh:17`). The chardev paragraph ends differently, and the
  chardev matcher cannot fire on the porcelain fixture anyway.
- **The fixture really needs the newline.** This was run through the real
  matcher, using `command grep`. `?? .bashrc` alone is quiet,
  `?? .gitconfig` alone is quiet, the merged `?? .bashrc?? .gitconfig` is
  quiet, and the two lines separated by a newline fire. The RED report's
  threshold reasoning holds.
- **The pairing is exact.** Tests 1 and 2 share the helper, the event and
  the text. Only the field differs, and `post_payload ""` passes an empty
  stdout (the helper uses `$1`, and `${2:-}` for stderr, so no default
  replaces the empty string).
- **Test names match the slice verbatim.** `shellcheck tests/hook.bats`
  is clean.

## Probe table

Each probe inserted a `PostToolUse)` arm before `esac` in
`hooks/annotate.sh` by exact replacement. Probes H and I also replaced
`--arg event "$event"` with a literal. The driver ran `bats tests/hook.bats`
and inverted both replacements in the same process. It asserted that the
file was byte-identical to its pre-probe content, and `git diff --quiet
hooks lib` was checked afterwards. Driver: `/tmp/claude/s2-review/probe.py`.

T1–T3 are the three new tests; S1 is slice 1's gitadd case.

| # | Rebuild (jq over payload) | T1 stdout | T2 stderr | T3 newline | S1 | Expected |
|---|---|---|---|---|---|---|
| A | `.stdout + "\n" + .stderr` (correct) | ok | ok | ok | ok | all green |
| B | `.stdout` only | ok | **red** | **red** | ok | caught |
| C | `.stderr` only | **red** | ok | **red** | ok | caught |
| D | `.stdout + .stderr` (no separator) | ok | ok | **red** | ok | caught by T3 alone |
| E | `.stderr + "\n" + .stdout` | ok | ok | ok | ok | unobservable (finding 3) |
| F | `.tool_response \| tojson` | **red** | **red** | **red** | ok | caught (escaped `\n` breaks line anchors) |
| G | stderr if stdout empty, else stdout | ok | ok | **red** | ok | caught by T3 alone |
| H | A + `hookEventName` = `PostToolUseFailure` | **red** | **red** | ok | ok | caught |
| I | A + `hookEventName` = `PostToolUse` | ok | ok | ok | **red** | caught by slice 1 |
| J | `.stdout, .stderr` (jq -r emits each on its own line) | ok | ok | ok | ok | correct variant |
| K | A without `-r` (JSON-quoted) | **red** | **red** | **red** | ok | caught |

H and I together show that the echo of `hookEventName` is pinned jointly by
slice 1's failure case and this slice's success cases. T3 was re-probed
after the edit: B, C, D, F and G are still red, and E, H, I and J are still
green.

## Final red run

`scripts/run-bats.sh tests/hook.bats`: 3 passed, 3 failed, exit 1. Each
failure is on its own assertion:

```
not ok 3 porcelain on stdout fires untracked
#   `[ "$(printf '%s' "$output" | jq -r '.hookSpecificOutput.hookEventName')" \' failed
not ok 4 listing on stderr fires
#   `[ "$(printf '%s' "$output" | jq -r '.hookSpecificOutput.hookEventName')" \' failed
not ok 5 rebuild inserts a newline between stdout and stderr
#   `| grep -qF 'reading the sandbox, not the tree'' failed
```

`scripts/run-bats.sh tests/docs.bats`: 1 passed, 0 failed, so the edited
`tests/hook.bats` stays quiet under the detector.
