# Review: Item 4.3 slice 1 tests, batched with Item 4.2's deferred test gaps

**Scope**: the uncommitted RED change: `tests/matchers.bats`,
`tests/extract-fixtures.py`, `tests/fixtures/fire-tmpdir-unset-bash-bare.txt`,
and the inert `match_readonly_path` stub in `lib/matchers.sh` (checked for stub
completion only). Checked against the RED report `item-4-3-s1-red.md`, the
`### readonly-path` entry in `docs/references/detectors.md`, and
`item-4-2-s1-code-review.md` ("Test gaps the mutation run exposed" a/b/c).
Out of scope: the implementation, the probe (slices 2-5), verdicts, memory and
docs.
**Date**: 2026-09-26
**Mode**: review + fix (test review)

## Summary

The red is genuine: every flipped `readonly-path` row fails on its assertion
against the inert stub, and every 4.2 gap test reds under a second mutation of
my own, one different from the RED's, on its named rule only. The fixture is a
verbatim corpus cut and the `extract-fixtures.py` change is one data row. Four
defects, all fixed. The RED took `tests/matchers.bats` from 373 to 451 lines,
over its 400 cap, so the gate would fail at GREEN. The quiet `readonly-path`
fixture would stay quiet even with the line-start anchor dropped. The
busy-device (EBUSY) half and the errno-16 half of the discriminator had no test.
The 4.2 gap tests were bare negatives.

**Overall Assessment**: Ready (post-fix)

## Issues Found

### Critical Issues

1. **`tests/matchers.bats` over the 400-line cap**
   - Location: `tests/matchers.bats` (451 lines; HEAD had 373)
   - Problem: `scripts/check-line-limits.sh .` printed `oversized-file:
     tests/matchers.bats: 451 lines > 400`. `just precommit` runs this check,
     so the GREEN commit would be blocked. The RED report does not mention it.
   - Fix: split by kind of input. `tests/matchers.bats` keeps the recorded
     fixtures, as its header already says it does. A new
     `tests/matchers-edges.bats` (named on the `probes-edges.bats` precedent)
     takes the input built at run time: the four fragment-built 4.2 gap cases
     and the two moved `detect` plumbing cases, `detect sees past a NUL` and
     `detect on closed stdin`, byte-identical. `detect needs no temp dir` stays
     in `matchers.bats`, because `docs/design.md` NFR-4 and a `tests/hook.bats`
     comment cite it there. The comment in `tests/helpers/probes.bash` that
     named the NUL test's file now names the new one. Result: 371 and 165
     lines, and `check-line-limits.sh` passes.
   - **Status**: FIXED

### Major Issues

1. **The quiet `readonly-path` fixture does not pin the line-start rule**
   - Location: `tests/matchers.bats`, `readonly-path stays quiet on the memory
     index line naming the message`
   - Problem: `quiet-readonly-path-index-line` is quieted three ways at once. A
     slash, not a colon and space, sits before the message. Prose follows the
     message. The line opens with a `grep -n` locator and a list marker, not a
     tool prefix. This is the same shape as 4.2 gap (c). To test it, I put the
     entry's discriminator in place of the stub (the run is recorded below) and
     dropped the tool alternative's `^`. The quiet case stayed green (K1). No
     test pinned the store's mid-line quotation: a refusal quoted whole at the
     end of a prose line.
   - Fix: new pair `readonly-path fires on a refusal at line start, not quoted
     mid-line` in `matchers-edges.bats`. For each alternative (tool prefix and
     Python), the whole refusal fires alone on its line and stays quiet behind
     `48:- ` and prose. The two texts differ only in that lead-in. Built from
     fragments. It reds under K1 and K2 (each alternative's `^` dropped) and
     under nothing else. The existing quiet case now also asserts that the
     fixture carries the message, not just the store's phrase.
   - **Status**: FIXED

2. **EBUSY and errno 16 had no test**
   - Location: the `readonly-path` rows in `tests/matchers.bats`
   - Problem: the entry's matcher accepts the read-only-filesystem (EROFS) or
     busy-device (EBUSY) message, and errno 30 or 16. All three fire fixtures
     carry EROFS and errno 30. A GREEN matching EROFS alone (K3) or errno 30
     alone (K4) would have passed the whole suite.
   - Fix: a new corpus cut, `fire-readonly-path-git-busy` (gitlore,
     2026-07-23, git's `error` prefix refusing a worktree delete with the
     busy-device message). Its cut-list entry sits beside the other
     `readonly-path` rows in `extract-fixtures.py`, it has an `expected_for`
     row, and a test, `readonly-path fires on git's busy-device refusal`. The
     corpus has no errno-16 line (the Item 3.2 hit dump in
     `/tmp/claude/sandbox-lies/ro.txt` has none). So `readonly-path fires on
     Python's busy-device form, errno 16` derives one from the cut errno-30
     fixture with `sed`. It first asserts that the substitution applied and
     that no `Errno 30` survives, so the test cannot pass on the original line.
     K3 reds the fixture case only and K4 the derived case only.
   - **Status**: FIXED

3. **The 4.2 gap tests were bare negatives**
   - Location: the four fragment-built gap (b) and (c) cases
   - Problem: each asserted quiet only. That passes before the matcher exists
     and after it is deleted. Mutation proves each guard today, but the proof
     is not part of the artifact.
   - Fix: each case, moved to `matchers-edges.bats`, is now a pair through a
     shared `assert_verdict <want> <text>`. A positive over the same text,
     differing only in the rule's trigger, fires first. That is the quote
     inside the words for (b) quote-free-words, the root slash for (b) relative
     path, and the `42:`/`7:` locator for (c). Mutations A1 to C2 below were
     re-run on the moved form, with results listed under Checks.
   - **Status**: FIXED

### Minor Issues

1. **Portability case for the new file**
   - Location: `tests/matchers-edges.bats`
   - Note: the runbook's Portability rule gives every new bats file a case
     re-run under `make_bsd_stubs`. Added: `a near-miss pair survives BSD grep
     and sed`, which re-runs the tmpdir-unset quoted-words pair, positive and
     negative, under the BSD `grep` and `sed` stubs. With a positive in it, a
     stub that refused the pattern would red rather than read as quiet.
   - **Status**: FIXED

## Checks

### 1. Mechanical

`direnv exec . bats tests/matchers.bats` in the foreground, as received: 1..45
with 4 failing (29-31, and 42, the BSD fixture sweep). Each fails on the
`assert_fixture` assertion (`expected [readonly-path] got []`). None errored and
none passed. The repo has no test of `extract-fixtures.py` itself.

After the fixes, run in the foreground,
`direnv exec . bats tests/matchers.bats tests/matchers-edges.bats`: 1..49 with
7 failing, all on assertions against the inert stub:

| test | fails at |
|---|---|
| `readonly-path fires on a quoted cp refusal under /tmp` | `assert_fixture`, got [] |
| `readonly-path fires on a background task's output file read` | `assert_fixture`, got [] |
| `readonly-path fires on a Python OSError errno 30 refusal` | `assert_fixture`, got [] |
| `readonly-path fires on git's busy-device refusal` (new) | `assert_fixture`, got [] |
| `the whole fixture sweep survives BSD grep, sed and mktemp` | `assert_fixture`, got [] (side effect, as in the RED) |
| `readonly-path fires on a refusal at line start, not quoted mid-line` (new) | first `assert_verdict`, the positive: got [] |
| `readonly-path fires on Python's busy-device form, errno 16` (new) | `assert_verdict`, got [] (both substitution guards passed first) |

The 4.2 gap tests and every other case pass. `direnv exec . just precommit`
fails only at `test`, with 166 passed and the same 7 failures. The
`check-line-limits.sh .` check passes, and shellcheck is clean on both bats
files.

**Stub completion.** `match_readonly_path` reads its stdin and returns 1, and
it is wired into `detect()` in catalogue order. No test errored, so the stub is
complete. Nothing was changed in it.

**Fixture provenance.** I copied `fire-tmpdir-unset-bash-bare.txt` aside, re-ran
`python3 tests/extract-fixtures.py fire-tmpdir-unset-bash-bare`, and `cmp`
reported the copy and the fresh cut identical (62 B, devddaanet 2026-09-13). A
sha256 of every fixture before and after showed no other fixture changed. So it
is a verbatim cut, not hand-written. The `extract-fixtures.py` change is one
`SPEC` row using the existing tuple shape, with no logic change, which keeps
fixtures cut from the corpus (FR-8). The new `fire-readonly-path-git-busy` was
cut the same way: the sha256 diff shows one added file and no other change.

**4.2 gap mutations, my own.** Each is an exact-string replace applied once in
`lib/matchers.sh`, then a run of the whole file, then the inverse replace. After
every restore, `sha256sum -c` against the hash recorded before the first
mutation (`b23c6745…`) returned OK. The stub-state reds (29-31, 42) are the
baseline and are left out of the table.

| # | rule (test) | mutation, different from the RED's | red beyond baseline |
|---|---|---|---|
| A1 | gap (a), bare shape (`…bare shape directly after the tool prefix`) | bare path component may not hold a hyphen: `)?/[^/:[:space:]]+\|` → `)?/[^/:[:space:]-]+\|` | 19 only. The fixture reaches the bare alternative and nothing else |
| A2 | gap (a) complement | drop the optional locator: `((line [0-9]+: )?/` → `(/` | 17 only (the redirect fixture's `line 8:`). 19 stays green, so the two fixtures pin distinct sub-shapes |
| B1 | gap (b), quote-free words | words exclude the curly quote instead: `[^']*('\|‘)/` → `[^‘]*('\|‘)/` | 23 only |
| B2 | gap (b), root slash | any number of root slashes: `)?/[^/:…]+\|` → `)?/*[^/:…]+\|` | 24 only |
| C1 | gap (c), resume-lost anchor | accept a `grep -n` locator: `'^No conversation found` → `'^([0-9]+:)?No conversation found` | 26 only (25, the truncated-id fixture, stays green) |
| C2 | gap (c), seccomp-init anchor | same: `'^apply-seccomp:` → `'^([0-9]+:)?apply-seccomp:` | 28 only (27 stays green) |

The test numbers in this table are from the as-received `matchers.bats`. I
re-ran the same six mutations after the fixes. B2, C1 and C2 each red their own
pair only, and A2 reds the redirect fixture only. A1 also reds the
relative-path pair, whose positive, `bash: /move-strays.sh`, has the same
hyphenated shape as the gap (a) fixture. B1 also reds the BSD case, which
re-runs the quoted-words pair. Both extra reds are the positives doing their
job. Every restore was verified by hash.

### 2. Wrong-reason hunting

**Against the entry's discriminator.** I put the discriminator from the
`### readonly-path` entry in place of the stub for the duration of the runs,
then restored the stub by the inverse replace. `sha256sum -c` confirmed the
restore, and `git diff --stat lib/matchers.sh` still shows only the RED's
10-line addition. The discriminator is the tool-prefix line ending in the
EROFS or EBUSY message with trailing blanks allowed, or the Python line
`<Name>Error: [Errno 30|16] <message>: `, both anchored at line start. With it
in place, both suites were fully green, which means no fire fixture
cross-fires another detector and the quiet fixture stays quiet. Its mutants:

| # | mutant | red |
|---|---|---|
| K1 | tool alternative: drop `^` | only the new line-start pair. The quiet index-line case stayed green, which is Major 1 |
| K2 | Python alternative: drop `^` | only the new line-start pair |
| K3 | EROFS only | only `…git's busy-device refusal` (plus the BSD sweep) |
| K4 | errno 30 only | only `…busy-device form, errno 16` |
| K5 | Python alternative removed | the errno-30 fixture case, the pair, the errno-16 case, the BSD sweep |

Answers to the dispatch's questions:

- Once the matcher exists, the quiet fixture stays quiet, but not because of
  the line-start prefix rule alone: it is quiet three ways, and K1 shows it
  survives losing the anchor. The new pair pins the anchor instead, and pins
  the store's mid-line quotation of a whole refusal at line end, for both
  alternatives.
- The 4.2 gap tests red on the named rule only (A1 to C2). Wrong-reason shapes
  checked: the gap (a) fixture's extra `grep` checks the shape at birth, so a
  re-cut picking the `line N:` form would red. In gap (b), the negative's text
  has no bare-path route to firing, since a backtick follows the prefix. In
  gap (c), the id is all hex and untruncated, so the tail anchor cannot be
  what quiets it.

### 3. Self-quiet

With the entry's discriminator in place, `lib/matchers.sh` read each of these
and fired nothing: `tests/matchers.bats`, `tests/matchers-edges.bats`,
`tests/extract-fixtures.py`, `tests/helpers/probes.bash`,
`plans/sandbox-lies/reports/item-4-3-s1-red.md`, `lib/matchers.sh` and this
report. `tests/docs.bats` also passed with it in place. That is a preview for
GREEN: no tracked file fires the future matcher. Each diagnostic in the new
tests is assembled from fragments, and each source line naming a message is
indented, which the tool-prefix rule rejects.

## Fixes Applied

- `tests/matchers.bats`: the four fragment-built gap cases and the slice-9
  `detect` plumbing moved out. Added the `fire-readonly-path-git-busy`
  `expected_for` row and its test. The quiet `readonly-path` case asserts the
  message is present. The section comment points at the anchor pair.
- `tests/matchers-edges.bats` (new): the `assert_verdict` helper; the four
  4.2 gap cases rebuilt as positive/negative pairs; the `readonly-path`
  line-start pair; the derived errno-16 case; a BSD case; `detect sees past a
  NUL` and `detect on closed stdin`, moved verbatim.
- `tests/extract-fixtures.py`: the `fire-readonly-path-git-busy` cut-list row.
- `tests/fixtures/fire-readonly-path-git-busy.txt` (new): a verbatim cut.
- `tests/helpers/probes.bash`: the comment citing the NUL test names its new
  file.

Nothing committed. `lib/matchers.sh` is byte-identical to how it was received.

## Recommendations

- GREEN's commit carries the new files by name:
  `tests/matchers-edges.bats` and
  `tests/fixtures/fire-readonly-path-git-busy.txt`, as well as the RED's
  fixture and the reports.
- GREEN's NFR-1 re-run of `tests/corpus-eval.py` is unaffected by the new
  fixture. Its `Corpus.` line counts corpus hits, not fixtures.
