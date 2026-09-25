# Review: Item 4.3 slice 1 — readonly-path matcher (code review)

**Scope**: `lib/matchers.sh` (`match_readonly_path`, the order in `detect`)
and the `tests/extract-fixtures.py` change in the HEAD commit ("Item 4.3/1 —
readonly-path matcher; 4.2 discriminator gaps pinned"). I also looked at
`tests/corpus-eval.py` for the green report's replay workaround. OUT: bats
tests, probe (slices 2-5), verdicts, memory, docs.
**Date**: 2026-09-26
**Mode**: review + fix

## Summary

The matcher is one `grep -qE` with two alternatives, both anchored at line
start. It follows the recorded discriminator in `detectors.md`'s
`### readonly-path` with one exception: the Python alternative required a
blank after the closing colon, which the recorded text ("the same message, a
colon") does not ask for. Fixed. Replayed over the corpus, the fix changes no
hits. The green report's multi-verdict parsing failure comes from
`tests/corpus-eval.py`: the replay loop in its own docstring writes records
that its `aggregate` parser cannot read. The loop in the report was copied
from that docstring. Fixed there.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

1. **corpus-eval.py's documented replay loop writes records its `aggregate`
   cannot parse**
   - Location: `tests/corpus-eval.py:22-26` (docstring Usage)
   - Problem: `detect` prints one verdict per line. The docstring loop does
     `v=$(bash lib/matchers.sh <"$f")` and then `printf '%s\t%s\n' … "$v"`.
     A survivor that fires two or more matchers therefore produces a
     continuation line with no tab, and `aggregate`'s
     `fname, vs = line.split("\t", 1)` raises on it. `aggregate` reads the
     verdicts with `vs.split()`, so the format it expects is one line per
     file with the verdicts separated by blanks. The writer is what breaks
     that format. The green report's ad-hoc loop is the docstring loop plus
     `|| true`, so it inherited the bug. It did not introduce it. The same
     workaround appears in the Item 4.2 green report.
   - Fix: the docstring loop now pipes through `tr '\n' ' '`, with a
     comment saying why. `aggregate` is unchanged.
   - Verified: I ran the corrected loop verbatim over the reused
     3,765-survivor extraction (in a scratch outdir symlinked to
     `/tmp/claude/sandbox-lies/eval/survivors`, in the foreground, taking
     3m10s) and then ran `aggregate` unmodified. The run gave 973 records,
     "survivor files with a verdict line: 973", and readonly-path 162 hits
     with 0 flagged. That matches the green report's figures without the
     scratch rejoin step.
   - **Status**: FIXED

### Minor Issues

1. **Python alternative is one character tighter than the recorded
   discriminator**
   - Location: `lib/matchers.sh` `match_readonly_path`, second alternative
   - Note: the regex ended `…busy): ` with a trailing blank. The recorded
     text ends at "a colon". Item 3.2's scratch arbiter had the blank too,
     but the shipped discriminator is the text. Python's `OSError` string
     always puts `: '<path>'` after the message, so this never mattered in
     practice. Over the 3,765 survivors both forms match the same 12 files,
     and the full replay above, run with the fix in place, still gives 162.
   - **Status**: FIXED — trailing blank removed.

2. **Comment misdescribes the Python form**
   - Location: `lib/matchers.sh` comment above `match_readonly_path`
   - Note: it said "the same errno (30 or 16) and message in brackets".
     Only the errno is in brackets, and the first alternative has no errno
     for "the same" to refer to. It also said the path "usually" follows,
     but Python's colon form always has one.
   - **Status**: FIXED — reworded to "`[Errno 30]` or `[Errno 16]`, the same
     message, then a colon".

3. **Report filename split across comment lines**
   - Location: `tests/extract-fixtures.py`, the `fire-tmpdir-unset-bash-bare`
     entry's comment
   - Note: `item-4-2-s1-code` / `-review.md` was hyphen-broken across two
     lines, so a grep for the filename misses it.
   - **Status**: FIXED — the filename is kept whole on one line.

## Fixes Applied

- `tests/corpus-eval.py` docstring — the replay loop now joins `detect`'s
  lines with `tr '\n' ' '`, plus a two-line comment on why.
- `lib/matchers.sh` `match_readonly_path` — removed the trailing blank after
  the Python alternative's colon, and reworded the comment's Python
  sentence.
- `tests/extract-fixtures.py` — the comment reflow above.

## Checks against the brief

- **Discriminator conformance.** I probed 19 inputs by hand. These fire:
  `cp` quoted refusal, trailing blanks, CRLF, `/bin/bash: line 3:`, git
  `fatal:` and `warning:` with EBUSY and EROFS, `mv: inter-device move
  failed … unable to remove target: Read-only file system`, `OSError` errno
  30, and errno 16. These stay quiet: indented, a list marker with
  backticks, a `grep -n` locator (`12:cp:`), trailing prose after the
  message, a pipe in the prefix, pytest's `E   OSError`, Python with no
  colon, errno 13, and `…systems`. Mid-line store quotations stay quiet
  because of the line anchor. `[A-Za-z]+Error` reads "an exception name
  ending in `Error`" as a name with a stem. It drops the scratch arbiter's
  `Exception` suffix and dotted names, as the recorded text does, and the
  corpus result is the same.
- **Text only.** The matcher reads stdin and nothing else: no path, no
  environment, no filesystem.
- **Portability.** POSIX ERE only: bracket classes, `\[`, grouped
  alternation, `^` inside alternation. No `-P`, `\s` or `\d`. The two
  single-quoted halves join into one word through a backslash-newline
  outside the quotes, which is valid in bash 3.2. The BSD-stub fixture
  sweep in `tests/matchers.bats` passes.
- **Performance (NFR-3).** One more process substitution and one `grep`,
  the same shape as every other matcher. There is no per-line loop. On a
  10 MB input with 60,000 near-miss lines plus a 280 KB line of repeated
  `: `, `match_readonly_path` alone took 0.068s. (The whole `detect` took
  4.5s on that input, but that cost was already there — `match_git_lock`'s
  `$(cat)` and nine `printf` copies — and is not this slice's.)
- **`detect` order.** `readonly-path` sits between `phantom-gitadd` and
  `tmpdir-unset`, matching the `###` order in `detectors.md`. The hook skips
  a name with no `verdict_*` function (`hooks/annotate.sh`, `declare -F …
  || continue`), so nothing is emitted and no probe runs until Item 6.1.
- **extract-fixtures.py.** I re-ran the extractor from a scratch copy for
  both new names. `fire-readonly-path-git-busy` and
  `fire-tmpdir-unset-bash-bare` came out byte-identical to the committed
  fixtures (`cmp`), so both SPEC entries are reproducible.

## Mutated-SUT run

One run, exact-string replace in `lib/matchers.sh`: I swapped the anchored
tool-prefix head `'^[^`|:[:space:]]+: .*: (Read-only` for the bare
`'(Read-only`, which is the unanchored match the slice exists to rule out.
I ran `tests/matchers.bats` and `tests/matchers-edges.bats` and then
reversed the replace; `git diff` shows the regex line holding only the
intended fix. Result: 1 of 49 redded. `readonly-path fires on a refusal at
line start, not quoted mid-line` fired on the `48:- \`just release\` … mv:
… Read-only file system` quotation. The other readonly tests stayed green,
as they should: their quiet fixtures do not end a line on the message, so
the anchor is not what keeps them quiet. The mutation did not touch the
Python alternative. The anchor is pinned by one test.

## Gate

`cd /Users/david/code/sandbox-lies && direnv exec . just precommit`, run in
the foreground: `bats: 173 passed, 0 failed`, `precommit passed: plugin.json,
hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests`. Nothing
committed.

## Positive Observations

- The shipped matcher and Item 3.2's scratch arbiter flag the identical 162
  survivor files. The green report diffed the filenames, not only the
  counts.
- One `grep` covers both alternatives, so stdin is read once and the matcher
  stays a single process like its neighbours.
- The trailing-blank tolerance `[[:space:]]*$` also takes CRLF output.
