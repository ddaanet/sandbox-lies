# Review: Item 6.1 slice 1 — test review, path extraction widened

**Scope**: uncommitted changes to `tests/probes-readonly.bats` and
`tests/helpers/probes.bash`, plus the RED report `item-6-1-s1-red.md`. The
SUT (`lib/probes.sh`) was only touched for mutation proofs, and each one was
restored.
**Date**: 2026-09-26
**Mode**: review + fix (TDD test review)

No UNFIXABLE items.

## Summary

The RED tests pinned all six table rows with exact `path=` lines. Each one
failed on an assertion for the right reason: the probe returned `nopath`, or
for mv the source path. The runbook's forms were reproduced verbatim, and the
curly quotes are real U+2018/U+2019 bytes (`e2 80 98` / `e2 80 99`, checked
with `od -c`). There were four gaps. No path held a blank or a multibyte
character. The near-miss check tested one shape only. The near-miss check
never proved the matcher accepted its line. No BSD-stubs case covered the new
line kinds. All four are fixed. The file now has 371 lines, under the 400 cap.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

1. **The near-miss check pinned one shape, so a sloppy GREEN that
   generalises a fixed form still passed**
   - Location: `tests/probes-readonly.bats`, test `unquoted path after an
     unlisted prefix stays nopath`
   - Problem: the only near-miss line was `rm: cannot remove <p>`. Some
     GREENs that break the fixed-forms-only rule still passed every test. One
     makes bash's `line N:` locator optional, so it accepts a bare path
     straight after the prefix (BSD `touch: <p>: …`). Another keys dash's form
     on `cannot create` without its `sh: 1:` prefix.
   - Fix: the test now loops over three lines: `rm: cannot remove <p>`
     (words outside the forms), `touch: <p>` (path straight after the prefix)
     and `mkdir: cannot create directory <p>` (dash's words under another
     prefix). Each is proven separately by its own mutation (below).
   - **Status**: FIXED

2. **Near-miss `nopath` could come from the matcher rather than the
   extractor**
   - Location: same test
   - Problem: `probe_readonly_path` prints `nopath` both when no line matches
   and when a matching line gives no path. A near-miss line the matcher
   refused would pass for the wrong reason, which is the "right answer from
   the wrong guard" pattern.
   - Fix: `match_readonly_path <<<"$text"` is asserted for each line before
     the probe runs, so a refused line fails the test.
   - **Status**: FIXED

3. **No blank in any path, so a GREEN that stops the path at a blank
   passed**
   - Location: all six table tests and the touch/ln regression
   - Problem: every name was blank-free (`bash-target`, …). A GREEN whose
     unquoted capture is `[^ ]*`, or which takes "the last token before `: `"
     after a fixed prefix, passed. The design's only residual for an unquoted
     path is an embedded `: `, not a blank.
   - Fix: every name now holds a blank (`bash target`, `mv source`/`mv
     target`, `touch target`, …). The block comment says why.
   - **Status**: FIXED

4. **Curly-quoted path had no byte that could expose byte-wise quote
   handling**
   - Location: `curly-quoted mkdir path is extracted`
   - Problem: the runbook requires the curly quotes to be handled as UTF-8
     byte sequences under `LC_ALL=C`. Mirroring the straight-quote sed as
     `[^’]*` builds a byte class that excludes `e2`, `80` and `99` one by
     one, which cuts any path holding one of those bytes. With an ASCII-only
     path, that GREEN passed.
   - Fix: the name is now `curly — target`. The em dash is U+2014,
     `e2 80 94`, so it shares two bytes with each quote. Contrast run: that
     byte-class GREEN (`s/^[^‘]*‘\([^’]*\)’.*/\1/p`) stayed red with
     `nopath`. A sequence-aware GREEN (`s/^[^‘]*‘\(.*\)’: .*/\1/p`) went
     green. The SUT was restored after both runs.
   - **Status**: FIXED

5. **No BSD-stubs case covered the widened extraction**
   - Location: `tests/probes-readonly.bats` (end of file)
   - Problem: the extraction is sed- and grep-based, and GREEN will add new
     sed/grep code for the curly and unquoted forms. The existing BSD case
     only covers the old straight-quote path. The runbook's portability rule
     calls for a representative input under `make_bsd_stubs`.
   - Fix: added `curly and unquoted paths survive BSD grep and sed`. It runs
     the curly mkdir line and the bash `line N:` line through
     `make_bsd_stubs grep sed`, with an exact `path=` for each. It is red now
     on the outcome assertion (`nopath`), the same reason as its non-BSD
     twins. It will catch `-P`/`-z`, word boundaries, long options or `-i` if
     GREEN introduces any. The stubs do not emulate GNU BRE `\|`/`\+`.
   - **Status**: FIXED

### Minor Issues

1. **The near-miss comment misnamed the four fixed forms**
   - Location: the comment above the near-miss test
   - Note: it listed them as "(mkdir, /bin/bash, sh, git)". mkdir is the
     curly form, not one of the four unquoted ones. The four are bash's
     `line N:`, dash's `cannot create`, git's `could not lock config file`
     and git's `cannot mkdir`. Rewritten to name those.
   - **Status**: FIXED

2. **The RED report's line count and test list are now stale**
   - Location: `item-6-1-s1-red.md` ("334 lines", tests 1-8)
   - Note: it records the RED run as it happened, so it was left as is. This
     review records the current state: 371 lines, nine slice tests including
     the BSD case.
   - **Status**: OUT-OF-SCOPE — historical record of the RED run; the current
     state is recorded here

## Fixes Applied

- `tests/probes-readonly.bats`, slice block comment: records that every name
  holds a blank, and why.
- `curly-quoted mkdir path is extracted`: path is now `curly — target`, with
  a comment on the shared bytes.
- `bash line-N`, `dash redirect`, `git config-lock`, `git mkdir`, `mv target`
  and `touch and ln` tests: each name now holds a blank.
- `unquoted path after an unlisted prefix stays nopath`: rewritten as a loop
  over three near-miss lines. Each iteration asserts the matcher accepts its
  line, then the probe returns `nopath` with no `path=`.
- New test `curly and unquoted paths survive BSD grep and sed`.
- `tests/helpers/probes.bash`: no change needed. `erofs_message` builds the
  message from two fragments, which matches the file's existing convention.

## Checks

**Mechanical run**: `direnv exec . bats tests/probes-readonly.bats`, run in
the foreground after the fixes (17 tests):

| # | test | result |
|---|---|---|
| 8 | curly-quoted mkdir path is extracted | RED — `[ "${output%%$'\n'*}" = writable ]` failed (nopath) |
| 9 | bash line-N path is extracted | RED — outcome assertion (nopath) |
| 10 | dash redirect path is extracted | RED — outcome assertion (nopath) |
| 11 | git config-lock path is extracted | RED — outcome assertion (nopath) |
| 12 | git mkdir path is extracted | RED — outcome assertion (nopath) |
| 13 | mv target path is extracted, not the source | RED — `grep -qxF "path=$p"` failed (source taken) |
| 14 | straight-quoted touch and ln keep their path | green; proven by mutation |
| 15 | unquoted path after an unlisted prefix stays nopath | green; proven by mutation |
| 17 | curly and unquoted paths survive BSD grep and sed | RED — outcome assertion (nopath) |

All eight existing tests (1-7, 16) stay green. Every red is an assertion
failure. None are ERROR.

**Mutation proofs**: each mutation differs from the RED's. Each was an
exact-string replace on `lib/probes.sh` line 116 (the `sed -n "s/^[^']*'…"`
extractor), applied with a replace that refuses a count other than 1. After
each run it was restored by the inverse replace. A grep for the mutated text
then returned count 0 (exit 1), and `git diff -- lib/probes.sh` was empty
after every restore and at the end (0 lines).

- Test 14, touch half. `sed -n "s/^[^']*'` → `sed -n "s/^cp: [^']*'` limits
  straight-quote extraction to cp, a plausible GREEN regression. Result: red
  at line 294, the touch half's outcome assertion.
- Test 14, ln half. `sed -n "s/^[^']*'` → `sed -n "s/^[^l']*'` refuses a
  prefix holding `l`, so touch passes and ln does not. Result: red at line
  304, the ln half's outcome assertion. The RED's own `\1Q` mutation only
  ever reached the touch half.
- Test 15, rm iteration (N1). A fallback `-e t -e 's/^[^:]*: \(.*\): [^:]*$/\1/p'`
  is the dispatch's sloppy GREEN, "take the text before the last `: `".
  Result: red at line 326 (`= nopath`). The probe printed `readonly`,
  `path=…/cannot remove …/near miss`.
- Test 15, touch iteration (N2). A fallback `'s/^[a-z]*: \(\/.*\): [^:]*$/\1/p'`
  accepts a bare path straight after the prefix. Result: red at line 326
  after the rm iteration passed. The probe printed `writable`,
  `path=…/near miss`.
- Test 15, mkdir iteration (N3). A fallback `'s/cannot create \(.*\): [^:]*$/\1/p'`
  is dash's words without its anchor. Result: red at line 326 after the rm
  and touch iterations passed. The probe printed `readonly`,
  `path=…mkdir: directory …/near miss`.

**Wrong-reason hunting**:

- Every table test pins the exact `path=` line with `grep -qxF`. The git
  config test's `path=$p` excludes a GREEN that reuses the config-lock
  helper and appends `.lock`.
- The mv test pins the target. A GREEN that takes the last quoted segment
  everywhere is already rejected by the existing `first quoted path on the
  line` test.
- Every table form matches the runbook's text verbatim, apart from the path
  and the message fragment.
- The outcome `writable` comes from an absent leaf whose parent is
  `$BATS_TEST_TMPDIR`. The distinguishing assertion is the path line, not
  the outcome.
- Host collision: none. Every path is under `$BATS_TEST_TMPDIR`. `/bin/bash`
  appears only as message prefix text and is never probed.

**Self-quiet**: `bash lib/matchers.sh < tests/probes-readonly.bats` and
`< tests/helpers/probes.bash` both exit 1 with no output.
`bats tests/docs.bats` passes.

**Lint**: `shellcheck -x tests/probes-readonly.bats tests/helpers/probes.bash
lib/probes.sh` is clean. That is the same file set the gate passes.

**Size**: `tests/probes-readonly.bats` has 371 lines (cap 400).

## Positive Observations

- `erofs_message` follows `git_lock_error`/`config_lock_error`: the phrase is
  built from fragments at run time, so no source line holds it whole.
- The mv test targets the one row where the old extractor gives a wrong path
  rather than no path, and its red shows exactly that.
- The regression row adds only touch and ln. The comment grounds why cp and
  Python are already pinned.

## Recommendations

- For GREEN: match the four unquoted forms anchored with their prefixes.
  Capture up to the final `: ` before the message (`\(.*\)`, not `[^ ]*`).
  Match the curly pair as byte sequences (`‘\(.*\)’: `), not as bracket
  classes. Keep the mv target rule specific to the `inter-device move
  failed` shape. The near-miss loop and the em-dash name will catch each
  shortcut.
