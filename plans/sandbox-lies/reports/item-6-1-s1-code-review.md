# Review: Item 6.1 slice 1 — code review, path extraction widened

**Scope**: commit "Item 6.1/1 — readonly-path probe reads curly quotes, mv's
target and four unquoted forms". Reviewed: `_probe_readonly_path_from_line`
and its comment in `lib/probes.sh`, and the `readonly-path` **Probe.**
paragraph in `docs/references/detectors.md`. Tests were tightened only where
a fix needed a pinning case.
**Date**: 2026-09-26
**Mode**: review + fix (TDD code review)

No UNFIXABLE items.

## Summary

All four of the orchestrator's points were real and are fixed. The comment's
curly quote example was two straight quotes, and its "literal byte sequences
rather than a bracket class" claim was false for the prefix. The curly
capture ran to the last `’: ` rather than the first closing quote. The
unquoted residual was stated wrongly: a path holding `: ` was already read
correctly. The real defect was different. The unanchored `^.*` prefix picked
the last copy of a form's words, so a path holding those words was misread.
All four unquoted forms, the mv rule and the curly rule are now anchored or
matched exactly. Both the comment and the Probe paragraph state the residual
as it was measured. The gate passes.

**Overall Assessment**: Ready

## Files changed

- `lib/probes.sh` — `_probe_readonly_path_from_line` and its comment
- `tests/probes-readonly.bats` — five slice tests tightened, one comment
  block rewritten (now 385 lines)
- `docs/references/detectors.md` — `readonly-path` Probe paragraph (reflowed
  by `just format-docs`)
- `plans/sandbox-lies/reports/item-6-1-s1-code-review.md` — this report

## Evidence runs

These runs used a driver that sources `lib/probes.sh` and pipes each line
through `_readonly_path_line | _probe_readonly_path_from_line`, with the EROFS
message substituted. The message formats are real. Each tool (GNU coreutils,
bash, dash, git, under `LC_ALL=C.UTF-8`) was run against a chmod 555 scratch
directory, with names holding a blank, an em dash, `: ` and `’`. Only the
kernel message (Permission denied) was replaced. Some findings from those
runs:

- mkdir is the only tool that curly-quotes. cp, install, touch, ln, mkfifo,
  truncate and mv (both `cannot move` and `inter-device`) print straight
  quotes in a UTF-8 locale. No real message had two curly segments.
- GNU mkdir prints a `’` inside a name as `\’`
  (`‘…/it\’s’`).
- Committed code on unquoted lines:
  - `/t/co: lon` was read whole in all four forms.
  - `/bin/bash: line 4: /t/line 3: x: …` → `x`
  - `sh: 1: cannot create /t/a 2: cannot create b: …` → `b`
  - `error: could not lock config file /t/error: could not lock config file b:
    …` → `b`
- Committed code on curly lines:
  - `x—y: cannot create directory ‘/t/p’: …` → no path
  - `…‘/t/a’ ‘/t/b’: …` → `/t/a’ ‘/t/b`
  - `‘/t/it\’s’` → `/t/it\’s`

After the fix, each of those lines reads correctly, except the `\’` name,
which gives `/t/it\` and is now the stated residual. The driver output was
byte-identical under GNU `sed --posix`.

## Issues Found

### Critical Issues

None.

### Major Issues

1. **Unquoted forms read from the last copy of their anchor words**
   - Location: `lib/probes.sh`, `_probe_readonly_path_from_line`, the four
     `s/^.*<words> \(.*\): .*/` rules
   - Problem: the greedy `^.*` put the capture's start after the last copy of
     `line N: `, `N: cannot create `, `error: could not lock config file ` or
     `fatal: cannot mkdir `. A path holding those words gave its tail (runs
     above). A relative tail resolves against the cwd and names a file no
     error named.
   - Fix: each rule is anchored at the line start on the tool's colon-free
     prefix, which the matcher already requires:
     `^[^:]*: line [0-9][0-9]*: `, `^[^:]*: [0-9][0-9]*: cannot create `,
     `^error: could not lock config file `, `^fatal: cannot mkdir `. The same
     anchor was applied to mv's rule (`^[^:]*: inter-device move failed: `).
     Every real line is still accepted. This answers point 4: the extra
     precision is warranted because it removes a real misread. The
     end-of-line anchor on the matcher does not help with the start. No
     further tightening was added.
   - **Status**: FIXED

2. **Curly rule: bracket-class prefix, greedy close, false comment**
   - Location: same function, `s/^[^‘]*‘\(.*\)’: .*/`; the comment's second
     and third lines
   - Problem: under `LC_ALL=C`, `[^‘]*` is a class over bytes e2, 80 and 98.
     A prefix holding any of them never reaches the quote, which gives
     `nopath`. `\(.*\)’: ` ran to the last `’: `, not to the first closing
     quote as the Probe paragraph states. With two segments it named a
     nonexistent path whose missing parent reads `readonly`, and the verdict
     is then "not a sandbox effect". The comment claimed literal-sequence
     matching, and its "curly" example was ASCII `'...'` (`od -c`: bytes
     `' . . . '`).
   - Fix: the rule is now a `/‘.*’/{ … }` block. It replaces the first `‘`,
     then the first `’` after it, with a newline, the one byte a line cannot
     hold, and keeps what lies between. It uses only literal byte sequences,
     `\n` in an RE and a backslash-newline replacement (the newline comes from
     `local nl`). The comment was rewritten to describe this and no longer
     shows curly glyphs as ASCII.
   - **Status**: FIXED

3. **Stated residual was wrong in the comment and the Probe paragraph**
   - Location: comment's last line; `detectors.md` Probe paragraph
   - Problem: "an unquoted path containing `: ` is misread" is false. The
     capture is greedy to the last `: `, and the kernel message after it
     holds none, so `/t/co: lon` was read whole in every form. The real
     misread was issue 1, and after the fix no unquoted residual remains for
     a single-line path. The quoted residual was incomplete, since it did not
     cover the curly `\’`.
   - Fix: both texts now say that an unquoted path runs to the last `: ` and
     is read whole, `: ` and its form's own words included. The residual now
     reads: a quoted path holding its own closing quote (GNU prints it
     escaped: `'it'\''s'` or double-quoted when straight, `\’` when curly) is
     cut at that quote or yields `nopath`. The Probe paragraph also names the
     full words of each form (`N: cannot create`, `error: …`, `fatal: …`),
     each right after the tool's own prefix.
   - **Status**: FIXED

4. **Tests could not see issues 1 and 2**
   - Location: `tests/probes-readonly.bats`, slice tests 8–12
   - Problem: the unquoted names held only a blank, and the curly test had an
     ASCII prefix and a single segment. The committed code passed all of
     them.
   - Fix: each unquoted name now holds `: ` and its own form's words
     (`bash line 3: target`, `dash 2: cannot create target`,
     `error: could not lock config file target`, `fatal: cannot mkdir target`).
     The curly test gained a second half: a tool invoked by a path holding an
     em dash (`/opt/tools—2/mkdir`), with two curly segments, expecting the
     first. The slice block comment now says why.
   - **Status**: FIXED

### Minor Issues

None beyond the above.

## Mutated-SUT runs

Each run was an exact-string replace in `lib/probes.sh` that refused any
match count other than 1. After the run, the inverse replace restored the
file, and `git hash-object` matched the pre-mutation hash every time. A final
grep for the mutated forms found 0 hits.

| mutation | result |
|---|---|
| curly block → committed `s/^[^‘]*‘\(.*\)’: .*/` rule | test 8 red (second half, outcome) |
| curly close at the last `’` | test 8 red (line 226, second half) |
| bash `^[^:]*: line ` → `^.*line ` | test 9 red (`path=`) |
| dash `^[^:]*: [0-9]…` → `^.*[0-9]…` | test 10 red (`path=`) |
| `^error: could…` → `^.*error: could…` | test 11 red (`path=`) |
| `^fatal: cannot mkdir` → `^.*fatal: cannot mkdir` | test 12 red (`path=`) |
| mv rule disabled | test 13 red (`path=`) |

One inserted mutation had no effect: `s/^[^‘]*‘/‘/` added inside the block
does not substitute when the prefix holds an em dash, so the block goes on
correctly. The first row covers the bracket-class prefix instead.

## BSD portability (point 3)

- **Labels.** `t end` and `:end` each sit alone in their own `-e`
  argument. BSD sed joins `-e` arguments with newlines and ends a label at
  the newline. The known BSD failure is a label followed by `;` in the same
  argument (`:a;N;ba`), and it does not occur here. The block's `{` ends one
  argument and `}` is alone in another, which BSD accepts.
- **UTF-8 bytes.** Under `LC_ALL=C`, BSD sed treats each byte as a
  character, so the literal three-byte sequences match byte for byte.
  `LC_ALL=C` also avoids macOS sed's "illegal byte sequence" on invalid
  UTF-8. With the curly class gone, no bracket class over those bytes
  remains.
- **The new block.** It uses only POSIX sed: `\n` in an RE, a
  backslash-newline in a replacement (BSD's native form, where GNU's `\n`
  replacement is the non-portable one) and address braces. Its behaviour does
  not depend on whether `.` matches a newline, because neither `.*` it uses
  spans one.
- **Checks.** `sed --posix` gave byte-identical results. The suite's BSD
  case (`make_bsd_stubs`) only checks options and cannot show BSD semantics,
  so this section is reasoning, not a BSD run.

## Gate

`direnv exec . just precommit`, run in the foreground: `exit=0`,
`bats: 190 passed, 0 failed`,
`precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line
limits, links, tests`. `tests/probes-readonly.bats` gave 17/17 ok.

## Refactoring signals

- REFACTOR-NEEDED: `lib/probes.sh` (392 lines against the 400 cap) — the
  readonly-path probe and its two helpers (`probe_readonly_path`,
  `_probe_readonly_resolve`, `_probe_readonly_path_from_line`, about 110
  lines) are a separable unit. The next growth of any probe will need that
  split. I did not apply it: it is a module split, outside this slice.

## Positive Observations

- The mv rule is keyed on mv's own words, not on any `'X' to 'Y'`, so the
  existing "first quoted path on the line" test keeps its meaning.
- The dash rule's digit locator already rejected cp's and mkdir's own
  `cannot create` wording once their quotes are stripped. The near-miss loop
  pins that.
- The em-dash name in the test review caught the byte-class close in the
  capture. This review extends the same idea to the prefix.
