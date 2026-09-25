# Review: Item 4.2 slices 1-2 — code review

**Scope**: the implementation in the commit "Item 4.2/1 — tmpdir-unset,
resume-lost, seccomp-init ship (slices 1-2)". Files: `lib/matchers.sh`
(`match_tmpdir_unset`, `match_resume_lost`, `match_seccomp_init`, `detect`
order), `lib/verdicts.sh` (the three verdicts), `hooks/annotate.sh` (flag
policies), and the re-recorded `tmpdir-unset` `Corpus.` paragraph in
`docs/references/detectors.md`. Out: tests, memory, Item 4.3, `zellij-socket`.
**Date**: 2026-09-25 **Mode**: review + fix

## Summary

`resume-lost` and `seccomp-init` match their recorded discriminators exactly
(the same regexes as Item 3.2's arbiter). The verdicts equal `detectors.md`
word for word. The flag policies match the runbook's row table and live in the
hook. `match_tmpdir_unset` did not match its recorded discriminator. It missed
the most common bare shape, where the path comes right after the tool's prefix
(`cat: /x: …`, `bash: /x: …`; BSD tools print this form and macOS is the target
platform). It also fired on shapes the discriminator excludes: a bare path
after any words, a double-quoted path, and quoted words containing quotes. The
re-recorded `Corpus.` line blamed the resulting count change on the arbiter.
Both are fixed. The matcher now reproduces the Item 3.2 arbiter's match set
exactly: 195 matches, 13 flagged, all 13 true. So the `Corpus.` paragraph goes
back to its recorded text.

**Overall Assessment**: Ready. Three test gaps are deferred to the
orchestrator, because tests are out of scope here.

## Issues Found

### Critical Issues

1. **`match_tmpdir_unset` missed the canonical bare shape**
   - Location: `lib/matchers.sh` `match_tmpdir_unset`
   - Problem: the prefix class consumed `: `. The bare alternative then needed
     another blank before the root slash, so `tool: /x: <message>` never
     matched. It matched only after a `line N:` locator, and only through
     backtracking. Probe: `cat: /x.log: …` and `bash: /probe.sh: …` stayed
     quiet. In the corpus this lost a flagged true hit (devddaanet,
     `bash: /move-strays.sh`) and six unflagged matches (`cat:`, `cmp:`,
     `diff:`, `shasum:`, `bash:`).
   - Fix: implement the recorded discriminator. The bare path comes directly
     after the prefix or the optional locator. The quoted path is single
     straight or GNU curly quotes, after words that contain no straight quote.
     This is one ERE equal to the OR of the arbiter's two greps.
   - **Status**: FIXED

### Major Issues

1. **`match_tmpdir_unset` was looser than the recorded discriminator**
   - Location: same line
   - Problem: `.*[[:space:]]/x` accepted a bare path after arbitrary words.
     `"/x"` added double quotes, which neither the record nor the arbiter has.
     `.*` before a quoted path accepted words containing quotes. Probes: `cd`
     builtin refusals after the locator, `scrot: failed to save image: /x:`,
     `jq: error: Could not open file /x:`, prose of the form
     ``Error: `cp '/a' b` said cp: cannot stat '/a': …``, and `fish: "/x": …`
     all fired. Corpus: 14 matches beyond the record, 4 of them flagged.
   - Fix: as above. Probes of the fixed matcher: all five stay quiet; relative
     and deep paths stay quiet; `cat:`/`bash:`/`/bin/bash: line N:`/`cp`-quoted
     fire. One residual is inherent to the recorded shape and shared with
     `readonly-path`: a line whose prose starts with a word-colon, followed by
     an unquoted-word lead-in and then a quoted refusal, still fires.
   - **Status**: FIXED

2. **The re-recorded `Corpus.` line misattributed the move and dropped the
   pilot-traffic figure**
   - Location: `docs/references/detectors.md` `### tmpdir-unset` `**Corpus.**`
   - Problem: the line said the count moved because the arbiter's regex
     differed. In fact the shipped regex deviated from the recorded
     discriminator (issues above). The rewrite also dropped "no pilot
     traffic", which NFR-1 requires and which the neighbouring entries carry.
   - Fix: re-ran the fixed `lib/matchers.sh` (full `detect`, one call per
     file, in the foreground) over the reused 3,765 survivors in
     `/tmp/claude/sandbox-lies/eval`. The `tmpdir-unset` set is identical to
     `verdicts-item32-scratch-arbiter.tsv`: 195 matches, 13 flagged, 182
     silent. Flagged by project: devddaanet ×6, micro ×2, handoff ×2, gitlore,
     Emploi, pytest-md. That is Item 3.2's breakdown, and none of it is
     sandbox-lies traffic. The `resume-lost` and `seccomp-init` sets are
     unchanged. The paragraph was restored byte for byte:
     `git diff HEAD~1 -- docs/references/detectors.md` is empty.
   - **Status**: FIXED

### Minor Issues

1. **Plan-item labels in shipped comments**
   - Location: `hooks/annotate.sh` (policy comment), `lib/verdicts.sh`
     (candidate block comment)
   - Note: "Item 4.2" means nothing to a reader of the shipped plugin, and no
     other lib/hook comment uses plan-item labels. Reworded to "candidate flag
     policies" and "The shipped candidates".
   - **Status**: FIXED

2. **Test gaps the mutation run exposed** (tests are out of scope)
   - (a) No fixture pins the bare-after-prefix fire shape. Critical 1 passed
     every suite: with the committed regex restored in place, `matchers.bats`
     and `hook-candidates.bats` are all green. Suggested fixture: the flagged
     devddaanet corpus hit (`bash: /<name>.sh`, missing file).
   - (b) Nothing pins the quote-free-words rule (mutation M1c) or the root
     slash of the bare alternative (M1d, which accepts relative paths). Both
     stay green.
   - (c) The resume-lost and seccomp-init quiet fixtures are quieted by the
     tail anchor as well as the line-start anchor. The test review asked for
     "drop the line-start anchor must red"; that mutation stays green (M2,
     M3). Only a phrase-only loosening reds them (M2b, M3b). A quiet fixture
     quoting the whole diagnostic after a `grep -n` locator would pin the `^`.
   - **Status**: DEFERRED. Tests are Scope OUT; these are for the
     orchestrator's next test dispatch.

## Mutation proof

Each mutation was an exact-string replace in place, applied once and asserted.
The file's sha256 was compared before and after the inverse replace; every
restore matched. The driver was `$TMPDIR/mut.py`. Final hashes after all runs:
`lib/matchers.sh` 054be05bf891 and `hooks/annotate.sh` 017b217c1c10, taken
before the comment-only edits; `lib/verdicts.sh` e20dbc8c3616.

| # | mutation | expected red | result |
|---|---|---|---|
| M1 | quoted path allows `/` inside the quotes | `tmpdir-unset stays quiet on a refusal naming a deeper path` | red at `assert_fixture` |
| M1b | bare path at any depth (`.*/seg`) | same | red (plus BSD sweep) |
| M1c | quoted words may hold quotes (`.*`) | none written | green (gap 2b) |
| M1d | bare path need not start at root | none written | green (gap 2b) |
| M0 | committed regex restored | — | green (gap 2a) |
| M2 | resume-lost: drop `^` only | resume-lost quiet case | **green** (gap 2c) |
| M2b | resume-lost: phrase-only grep | resume-lost quiet case | red |
| M3 | seccomp-init: drop `^` only | seccomp-init quiet case | **green** (gap 2c) |
| M3b | seccomp-init: phrase-only grep | seccomp-init quiet case | red |
| M4a | drop `tmpdir-unset:false` clause | `tmpdir-unset flag policy` silent half | red at `[ -z "$output" ]`, others green |
| M4b | drop `resume-lost:true` clause | `resume-lost flag policy` silent half | red at `[ -z "$output" ]`, others green |
| M4c | drop `seccomp-init:true` clause | `seccomp-init flag policy` silent half | red at `[ -z "$output" ]`, others green |
| M5 | resume-lost human line made a firing line | `verdict text is quiet` | red at `[ "$status" -eq 1 ]` |

BSD spy (the test review's check 6): the hook ran with the fire fixture and the
flag true, under a logging wrapper around the BSD `grep` stub. It made 9 `grep`
calls through the stub, one of them `match_tmpdir_unset`'s pattern, and emitted
the `$TMPDIR` human line. The BSD case therefore exercises the new matcher.

## Other checks (no finding)

- Matchers read stdin only: no command, no exit status, no flag. No bash-4
  constructs. The fixed pattern drops the old multibyte `’` inside a bracket
  expression, which BSD grep under `LC_ALL=C` reads as three separate bytes.
- `detect` order follows catalogue order: after `phantom-gitadd`, and
  tmpdir-unset, resume-lost, seccomp-init as in `## Candidates`.
- Flag policies: `$flag` is always `true`/`false` (absent reads false), so
  `tmpdir-unset:false` gives "fires only when true". `resume-lost:true` and
  `seccomp-init:true` give "silent when true". This matches the row table.
  zellij-socket is untouched.
- FR-6: paragraphs are 198, 143 and 200 characters, all under 400. The human
  lines are single lowercase clauses. `verdicts.bats` "candidate verdict text
  matches detectors.md" passes.
- NFR-3: the hook on the firing tmpdir payload (verdict, no probe) averaged
  68 ms over 10 runs.

## Fixes Applied

- `lib/matchers.sh` `match_tmpdir_unset`: the regex is now the recorded
  discriminator (Critical 1, Major 1), and the comment is rewritten to
  describe it.
- `docs/references/detectors.md`: the `tmpdir-unset` `Corpus.` paragraph is
  restored to its recorded text, confirmed by re-measurement (Major 2).
- `hooks/annotate.sh` and `lib/verdicts.sh`: plan-item labels dropped from
  comments (Minor 1).

Gate: `direnv exec . just precommit` passed in the foreground, 160 bats tests,
0 failed. The checks that passed: plugin.json, hooks.json, shellcheck,
bash -n, rumdl, line limits, links, tests. Nothing committed.

## Requirements Validation

| Requirement | Status | Evidence |
|---|---|---|
| FR-5 flag policy in hook, not matcher | Satisfied | `hooks/annotate.sh` `case "$name:$flag"`; M4a-c |
| FR-6 verdict text, <400, catalogue order | Satisfied | lengths above; `detect` order |
| FR-7 matcher = recorded discriminator | Satisfied after fix | arbiter-identical corpus set |
| FR-10 translation wiring | Satisfied | three `verdict_*` present, hook-candidates green |
| NFR-1 precision with date and pilot traffic | Satisfied after fix | 13/13, 2026-09-25, no pilot traffic |

## Notes for the orchestrator

- The committed green report's NFR-1 table (16 hits / 186 silent) and its
  "arbiter differed" reasoning are superseded by Major 2. The shipped matcher
  now gives the recorded 13 / 182.
- Flagged true shapes that fall outside the recorded discriminator: bash
  builtin refusals after the locator (`cd: /x`: three flagged true hits), and
  a bare path after the tool's words (`scrot`). Widening the discriminator to
  cover them is a Candidates-record change that needs its own measurement. It
  is not a code fix.
- REFACTOR-NEEDED: none. `lib/matchers.sh` is well under the cap. The test
  review already noted that `tests/matchers.bats` is at 373/400.
