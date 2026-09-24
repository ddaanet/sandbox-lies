# Item 2.2 slice 4: code review

Scope: `git show HEAD -- scripts/check-links.sh scripts/lib/strip-code.awk`
(the slice 4 GREEN), read against the whole of both files and
`scripts/lib/tracked.sh`. I also read the recall artifact's memories
(`no-stderr-suppression` above all), `shell-gotchas` 0.4.0 and its
`portability.md`, the slice's RED, test-review and GREEN reports, and the
slice 1–3 code reviews. The fixes are not committed.

Every probe ran against real tools: this box's `awk` is mawk (`nawk` is a
symlink to it), bash 5.2, GNU grep.

## Findings

1. **Major (fixed): a ROOT shaped `name=value` passed silently.** The file
   went to awk as an operand. POSIX awk treats an operand like `x=y/docs/a.md`
   as a variable assignment and then reads stdin, and `--` does not stop
   that. `$ROOT/$file` always has a `/` before any `=` that comes from the
   file name, so a tracked `docs/k=v.md` was safe. A ROOT directory named
   `x=y` was not. Reproduced on the committed script: `x=y/docs/a.md`
   linking `missing.md` exited **0** with no output when stdin was
   `/dev/null`, and with a terminal on stdin the run hung. **Fix:** awk now
   reads the file by redirection, `<"$ROOT/$file"`, as
   `check-line-limits.sh` already does. That comment names the reason.

2. **Major (fixed): blanket `2>/dev/null` on awk.** It hid awk's own
   diagnostic for an unreadable file, a missing program file, or anything
   unanticipated. None of these is an error that is "normal and expected",
   so no justified redirect remains. **Fix:** the redirect is removed.
   Because awk now reads by redirection, an unreadable file fails in the
   shell's redirection, and bash's own `…/docs/a.md: Permission denied`
   reaches stderr before the script's line, the same as the sibling script.

3. **Minor (fixed): a temp file per scanned file.** The GREEN's reason for
   the temp file was also wrong. The mask went through `mktemp` and was
   removed by hand on each path, so there was one extra `mktemp` and one
   `rm` fork per file. Nothing on an `exit 2` path leaked, but no trap
   covered the window between `mktemp` and `rm`. The comment said a
   `mask=$(awk …)` capture "truncates at the first NUL". It does not: bash
   *drops* NUL bytes, with a warning from 4.4 on. A whole-file capture was
   the wrong choice anyway, but not for that reason. **Fix:** no temp file.
   awk pipes straight into grep inside the existing capture:
   `links=$(awk … <file | { grep … || [ "$?" -eq 1 ]; })`. grep's 1 (no
   match) folds to 0. Under the script's `pipefail`, any other failure fails
   the capture and exits 2: a failed redirection, awk's exit, or grep's 2.
   Both tools' statuses stay observable without `PIPESTATUS`. The capture
   holds only the `](target)` matches, as before. The `status` and `mask`
   locals are gone.

4. **Major (fixed): in a CRLF file, the first fence swallowed the rest of
   the file.** The closing regexes `^```+[ \t]*$` and `^~~~+[ \t]*$` never
   match `` ```\r ``, so every link after the first fence was skipped
   silently. Reproduced: `crlf-missing.md` after a closed fence was not
   reported. The repo already tracks one CRLF file
   (`tests/fixtures/fire-lock-rebase-inline.txt`), so CRLF is not
   hypothetical. **Fix:** `\r` is added to the trailing whitespace class of
   both closers. `\r` is a POSIX awk regex escape.

5. **Major (fixed): a line that starts with a code span opened a fence.**
   CommonMark does not allow a backtick in a backtick fence's info string,
   so ```` ```` ``` ```` … ```` is a paragraph that opens with a code span.
   The committed awk opened a fence on that line and dropped everything up
   to the next closing line, silently. This happens in tracked docs today.
   Run through the awk, `plans/sandbox-lies/reports/item-2-2-s4-test-review.md`
   (out of scope, but typical prose) came out as 39 of its 159 lines,
   because its line 32 swallowed 120 lines. A fixture with
   `after-span-line-missing.md` after such a line was not reported. **Fix:**
   the backtick opener is `^```+[^`]*$`. This does not apply to tilde
   fences, whose info string may contain backticks.

6. **Minor (fixed): the header comment was wrong about its residuals.** It
   said the residuals were "left for a later slice". No later slice covers
   them: they are residuals of the item. It said each one "fails loud". "An
   unclosed fence swallows the rest of the file" is silent, and at document
   level it is correct CommonMark, not a residual at all. The sentence "a
   span or a fence that a line break would close" was garbled, because a
   line break does not close a span. **Fix:** the residuals are now split
   into loud and silent groups. Loud: a closer shorter than the opener, a
   double-backtick span, a span crossing a line break, an indented code
   block. Silent: a fence inside a list item or block quote whose container
   ends first; a lone fence line inside an indented code block; a
   backslash-escaped backtick. The comment also says that an unclosed
   top-level fence runs to the end of the file, as in CommonMark.

7. **No change, residual now stated: fence openers at any indentation.**
   CommonMark allows 0–3 spaces at top level. The awk strips any leading
   whitespace, so a lone ```` ``` ```` line inside a 4-space indented code
   block opens a fence and swallows the rest of the file, silently. Capping
   the indent at 3 would move the error the other way. A fence in a nested
   list item sits 4 or more columns in (for example at column 4 under
   `  - sub`), and its links would then be reported. That is a loud false
   positive on real docs, which the test review's W3 already pinned for the
   2-column case. No in-scope tracked markdown has a fence at 4 or more
   columns today. I kept the current behaviour and stated the silent
   residual in the header.

8. **Minor (fixed): a missing `strip-code.awk` blamed a markdown file.**
   `check-links: cannot read docs/a.md` was printed, even though that file
   was fine. **Fix:** after the `source`, a `-r` guard exits 2 with
   `check-links: cannot read <lib>/strip-code.awk`.

9. **Unverified: NUL bytes under BSD awk.** mawk passes a NUL through
   unchanged (the GREEN checked this, and I re-probed: `nul-missing.md`
   after `x\0y` on the same line is reported). The one-true-awk stores
   records as C strings, so on macOS the rest of a line after a NUL may be
   lost. That would silently drop a link placed after a NUL on the same
   line. I could not verify this because no BWK awk is installed here. It is
   a question for slice 7's BSD test or for a macOS dogfood run, and it does
   not justify a code change on a reading alone.

### Checked and sound

- Every awk construct is POSIX: `sub`, `gsub`, `~`, a `BEGIN` block,
  `next`, and regexes using `+`, `[ \t\r]` and `[^`]`. There is no
  `gensub`, no 3-argument `match` and no `\s`.
- The span regex on a line with an odd number of backticks pairs the
  backticks left to right, and the unpaired last backtick stays literal.
  CommonMark reads it the same way, and a link after it is reported.
- The script's `set -e` is off inside the command substitution in
  non-POSIX bash, but `pipefail` is inherited. That is what makes the fold
  work, and the comment names it.

## Probes (fixed script)

The scratch repo sits under a ROOT named `x=y`, with stdin from
`/dev/null`. The run exits 1 and reports `missing.md`, `crlf-missing.md`
(but not the in-fence `in-fence.md`), `missing-eq.md` from `docs/k=v.md`,
`nul-missing.md` and `after-span-line-missing.md`. With one file set to
`chmod 000`, the shell prints `…: Permission denied` and the script prints
`check-links: cannot read docs/unread.md`, exit 2. With the awk lib
deleted from a copy, the script prints
`check-links: cannot read …/lib/strip-code.awk`, exit 2.

## Mutation run (one, in place)

`if ! links=$(LC_ALL=C awk` was changed to
`if ! links=$(set +o pipefail; LC_ALL=C awk`. That drops awk's status and
the redirection's: an unreadable file reads as empty, grep's 1 is folded
to 0, and the file passes. `scripts/run-bats.sh tests/check-links.bats`
gave **9 passed, 0 failed**, so the tests did not red. The inverse
replacement restored the file. `git diff --quiet scripts/` cannot prove the
restore, because the review fixes are a diff under `scripts/`, so I used
`cmp` against a copy of the fixed script taken before the mutation, which
reported the files identical.

## Gates (foreground)

- `scripts/run-bats.sh tests/`: 52 passed, 0 failed.
- `just precommit`: `precommit passed: plugin.json, shellcheck, bash -n,
  rumdl, line limits, tests`.
- `scripts/check-links.sh`: exit 0.

## Test gaps

- **The unreadable-file exit 2 is unpinned** (see the mutation above).
  Slice 5's `unreadable file exits 2` covers it, now through the awk
  redirection rather than grep.
- **CRLF (finding 4) and the code-span line opener (finding 5)** are both
  unpinned. Reverting either fix leaves the suite green. Proposed: add
  them to the slice 4 fixture or to slice 5's edge inputs. That means a
  CRLF `docs/c.md` with a closed fence ahead of a broken sentinel, and a
  line starting with ```` ```` ``` ```` ```` ahead of a broken sentinel.
  Both yield the sentinel's line.
- **A ROOT shaped `name=value` (finding 1)** is unpinned. Proposed for
  slice 5: a fixture repo created under a directory named `x=y`, invoked
  with that relative ROOT and `</dev/null`, yielding its `broken-link`
  line and status 1.
- **The missing-lib guard (finding 8)** fits slice 6's `missing helper
  exits 2`, which copies the script without `lib/`. As written, that test
  cannot tell which helper is missing. A copy holding `lib/tracked.sh` but
  not `strip-code.awk` would pin the new guard.

## Refactor flag

None needed.

## Files changed

- `scripts/check-links.sh`:
  - The awk-then-grep step is a single piped capture that reads the file by
    redirection, with no temp file and no `2>/dev/null`.
  - The `mask` and `status` locals are removed.
  - The comments are rewritten.
  - A `-r` guard for `lib/strip-code.awk` follows the `source`.
- `scripts/lib/strip-code.awk`:
  - `\r` is allowed on both closers.
  - The backtick opener rejects a backtick in the info string.
  - The header states both new rules and splits the residuals into loud
    and silent groups.
