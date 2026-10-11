# Review: review-fixes-3 code group (Items 1.1 to 6.2)

**Scope**: lib/ and scripts/ changes plus the tests listed in the dispatch,
`d6d0043..HEAD`, against `outline.md` Design A to D and Items 1.1 to 6.2.
**Date**: 2026-10-11
**Mode**: review + fix. Requirements context: FR-4, FR-6, FR-8, D-7, NFR-1 to
NFR-5. Execution context provided; Scope OUT (docs/, plans/, memory/, Items
7.x, closed items H and I) not reviewed.

## Summary

The implementation matches the design: one `_probe_path_line` encoder with
`LC_ALL=C` and no line for an empty path, both newline guards gone, the
two-form decoder with the control-byte display rule, partial-checkout joining
onto the worktree top from the matching line alone, phantom wording without a
location, the bounded-run tokenizer, the line-cap arm, and both Python tools.
One real defect fell between Items 1.1 and 1.2: the decoder mis-read the
octal escape `%q` writes for a control byte when a digit followed it. Fixed
with a red test first. Everything else is clean.

**Overall Assessment**: Ready

## Issues Found

### Major Issues

1. **Decoder mis-reads a digit after a control-byte escape**
   - Location: `lib/verdicts.sh` `_verdict_path_read`, `$'...'` branch.
   - Problem: `printf %b` reads `\0` plus up to three more octal digits, and
     `%q` writes `\001`-`\037` as `\0NN`. A path holding a control byte
     followed by a digit decoded wrongly: wire `$'/x/a\0046/f'` (byte 0x04,
     then `6`) decoded to `/x/a&/f`. The wrong decode held no control byte, so
     the display rule showed the wrong path decoded, to the agent, as fact. A
     fuzz of 600 random `%q` outputs against the decoder found 27 such
     mismatches, all with a digit after a `\0NN` escape, identical on bash
     5.2 and 3.2.0. The same fault could flip the `.claude/settings.json`
     suffix match. Neither Item 1.2 slice nor its code review used a digit
     after a control-byte escape, and the wire form was only ever produced by
     the encoder in Item 1.1, so no one test saw both sides.
   - Fix: replaced the single `%b` call with a loop that copies literal runs
     and decodes one escape at a time: `\NNN` is read as `%b` of `\0NNN`
     (exactly three digits), `\'` becomes `'`, any other pair goes through
     `%b` as an argument. The pattern sits in a variable (3.2 regex rule).
     `\` + `'` no longer needs the `bq`/`q` substitution, which is removed.
   - **Status**: FIXED. Verified: fuzz bad=0 on bash 5.2 and 3.2.0.

## Fixes Applied

- `lib/verdicts.sh` (`_verdict_path_read`) — per-escape decode loop as above;
  comment states why `%b` alone is wrong.
- `tests/verdicts-readonly-path.bats` — new case "_verdict_path_read keeps the
  octal digit that follows a control-byte escape": paths `\004`+`6`,
  `\001`+`7`, `\037`+`0`, e-acute+`1`, and e-acute plus a literal backslash
  and `0046`, each compared byte-exact to the original; plus the paragraph for
  the first shows the wire form. Evidence: red before the fix on its own
  assertion (`wire $'/x/a\0046/f' decoded to /x/a&/f`), green after.

## Evidence run

- `just precommit` before changes: pass (411 tests). After the fix: pass (412
  tests), exit 0, all ten checks listed.
- Tokenizer equivalence: 400 seeded random commands (runs of 254-258 and
  511-513 characters ending in a space, `&`, `#`, quotes, backslash, `>&`)
  through the pre-change `_readonly_tokenize` (from `d6d0043`) and the
  current one: token lists and `_readonly_tokens_cut` identical, 0 differences.
- Decoder fuzz (above), 600 random byte strings, bash 5.2 and the 3.2.0
  build: 0 mismatches after the fix; 27 before.
- No `# MUT` marker added; no mutation of lib files beyond the fix itself.

## Requirements Validation

| Requirement | Status | Evidence |
|-------------|--------|----------|
| FR-4 (path= `%q`, resolution) | Satisfied | `lib/probes-readonly.sh` `_probe_path_line`, `probe_readonly_path`; `probes*.bats`, `probes-readonly-resolve.bats` |
| FR-6 (verdict decode, phantom wording) | Satisfied after fix | `lib/verdicts.sh`; `verdicts-readonly-path.bats`, `verdicts.bats` |
| FR-8 (cutter) | Satisfied | `tests/extract-fixtures.py`, `tests/extract-fixtures.bats` |
| D-7 (decoder grammar, display rule) | Satisfied after fix | as FR-6 |
| NFR-1 (replay harness) | Satisfied | `tests/corpus-eval.py`, `tests/corpus-eval.bats` |
| NFR-2 (BSD/3.2 portability) | Satisfied | new bats files load `helpers/bsd-stubs`; BSD-stub cases in resolve, hook-writes, verdicts-readonly-path, lock-newline suites; decoder run on 3.2.0 |
| NFR-3 (tokenizer bound) | Satisfied | bounded run, output unchanged (fuzz) |
| NFR-4 (no file, no eval) | Satisfied | decoder uses a process substitution and `%b` of arguments only |
| NFR-5 (line caps) | Satisfied | `scripts/check-line-limits.sh` arm, three cases in `check-line-limits.bats` |

Scope IN mapping: every item 1.1 to 6.2 has a deliverable and a test or the
stated "no case" rationale (Items 4.1, 5.1 report-only; Item 6.1/6.2 no-case
notes honoured: docstring loop uses one `>`, prefilter comment corrected,
`pick()` all-projects branch removed).

## Checks with no finding

- Test evidence: the newline-twin, locale-pin, resolve (worktree top, linked
  worktree two levels deep, no `.git` ancestor, cp regression with decoy
  partial line) and Python cases each name a state that fails them; the
  preconditions asserting `BATS_TEST_TMPDIR` holds no `%q`-escaped byte are
  present where literals interpolate it.
- Cross-item: `_probe_path_line` is the only `path=` producer; `verdict_config_lock`
  and `verdict_readonly_path` are the only consumers and both use
  `_verdict_path_read`; `utf8_locale` is loaded by the three suites its
  header names; `partial_checkout_*_error` helpers are shared by two suites
  as their header says.
- CLAUDE.md rules: no live file fires a detector (docs.bats green); no hand
  fixtures; every new bats file loads `helpers/bsd-stubs`.

## Deferred Items

None raised. Items H and I, docs, and the Item 7.x comments were not reviewed
(Scope OUT).

## Positive Observations

- The `evidence.md` figures are met and the tokenizer comment states measured
  numbers.
- Python guards (`isinstance` on JSONL lines and `input`, `or ""` on
  timestamps) are minimal and each has a case.
- Tests pin literal wire forms rather than reusing the encoder, except where
  a precondition guards the tautology.
