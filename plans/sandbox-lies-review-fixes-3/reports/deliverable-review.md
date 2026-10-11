# Deliverable Review: sandbox-lies-review-fixes-3

**Date:** 2026-10-11
**Methodology:** deliverable-review skill, references/axes.md
**Range reviewed:** `2309ae6..HEAD`, HEAD `2015b0f` on `main`
(`edify-review-range.sh` printed `RANGE:` for the outline, exit 0).
**Baseline:** `just precommit` on HEAD before any mutation: exit 0, 413 bats
cases passed, recap listing plugin.json, hooks.json, shellcheck, bash -n,
rumdl, line limits, links, python compile, tests.

## Inventory

About 1680 changed lines outside `plans/`, the skill's two-reviewer band. The
code and test partition was split in two because it also carried the
per-slice mutation runs; the reviewers ran one after the other, not in
parallel, because the box has 2 GB of RAM.

| Type | File | + | - |
| --- | --- | --- | --- |
| Code | `lib/verdicts.sh` | 79 | 13 |
| Code | `lib/probes-readonly.sh` | 41 | 23 |
| Code | `lib/probes-readonly-command.sh` | 22 | 13 |
| Code | `lib/probes.sh` | 17 | 17 |
| Code | `scripts/check-line-limits.sh` | 11 | 2 |
| Code | `tests/corpus-eval.py` | 21 | 9 |
| Code | `tests/extract-fixtures.py` | 23 | 24 |
| Test | `tests/verdicts-readonly-path.bats` (new) | 231 | 0 |
| Test | `tests/probes-readonly-resolve.bats` (new) | 176 | 0 |
| Test | `tests/probes-lock-newline.bats` | 123 | 51 |
| Test | `tests/corpus-eval.bats` (new) | 90 | 0 |
| Test | `tests/extract-fixtures.bats` (new) | 88 | 0 |
| Test | `tests/probes.bats` | 66 | 11 |
| Test | `tests/check-line-limits.bats` | 50 | 0 |
| Test | `tests/hook-writes.bats` | 47 | 0 |
| Test | `tests/verdicts-locks.bats` | 35 | 0 |
| Test | `tests/verdicts.bats` | 27 | 8 |
| Test | `tests/probes-readonly-members.bats` | 21 | 14 |
| Test | `tests/probes-readonly.bats` | 13 | 13 |
| Test | `tests/probes-config.bats` | 5 | 7 |
| Test | `tests/probes-readonly-facts.bats` | 3 | 28 |
| Test | `tests/hook-cap.bats` | 1 | 15 |
| Test | `tests/helpers/{corpus,locale,probes}.bash` | 82 | 0 |
| Docs | `docs/changelog.md` | 45 | 0 |
| Docs | `docs/references/readonly-path.md` | 33 | 9 |
| Docs | `docs/design.md` | 20 | 25 |
| Docs | `docs/references/detectors.md` | 9 | 9 |
| Docs | `docs/references/lock-detectors.md` | 2 | 2 |
| Docs | `docs/references/hook.md` | 1 | 1 |

Not a deliverable: the `memory` submodule pointer moved in `5afa828` over two
memory commits (a tier-merge index update, and the reword of the opening of
`sandbox-effects.md` that the outline names as my human partner's step).

**Conformance summary.** Every outline item, 1.1 to 7.7, is implemented and
carried by a test or, for the docs, by text at HEAD. One deliberate deviation:
the review gate replaced §A's single `printf %b` over the `$'…'` body with a
per-escape loop, after its fuzz found the single call decoding a digit after
a control-byte escape wrongly. The loop is correct (see "Confirmed by me")
and is where most of the Phase 1 findings sit.

### Layer 1 reviewers

| Partition | Model | Report |
| --- | --- | --- |
| Prose (Items 7.1 to 7.7) | Opus (`claude-opus-5-5`) | `reports/deliverable-review-prose.md` |
| Code and tests, Phase 1 and Item 5.1 | Opus (`claude-opus-5-5`) | `reports/deliverable-review-code-tests-phase1.md` |
| Code and tests, Phases 2 to 6 | Opus (`claude-opus-5-5`) | `reports/deliverable-review-code-tests-phases2-6.md` |

## Critical Findings

None.

## Major Findings

Majors are numbered M1 to M3; Minor findings run from 2 to 30.

M1. **`tests/verdicts-readonly-path.bats`, case "_verdict_path_read decodes
   \\" and reads an escape %q never writes as no path, silently"** — vacuity
   (test). The redirection that should merge stderr follows the assignment
   `out=$(…)`, so bash applies it to nothing: stderr never reaches `out`, and
   the "silently" the case is named for is not asserted. The gate's own
   report lists stderr output as a state that fails this case. The code is
   silent today, so no behaviour is wrong; the pin is absent. Source:
   Phase 1 report, finding 1. **Confirmed:** I read the line (the redirect
   sits after the closing parenthesis), and the reviewer's mutant that prints
   to stderr before returning 1 left the file green.

M2. **`tests/probes-readonly*.bats` as Item 4.1's guard** — vacuity (test).
   The outline names these suites as the guard that the tokenizer's output is
   unchanged. No case reads the content of a word longer than 256
   characters, so a mutant that drops the pending run at the top-of-loop
   flush passes all seven files (101 cases): the one mechanism Item 4.1
   added is unpinned, and "output unchanged" rests on hand-run differentials
   (5186 inputs on bash 5.2, 4674 on 3.2.0, 0 differences in this review).
   Source: Phases 2 to 6 report, finding 2. **Confirmed** in part: my grep
   for a generated long word in the seven files found none (narrow
   patterns). Mutation not re-run by me.
M3. **`tests/check-line-limits.bats`, cases "plans/ is out of scope" and
   "plugin-dev/ is out of scope"** — coverage of an exclusion the outline
   specifies. Item 5.2 caps the four new types "outside `plans/`,
   `plugin-dev/` and `tests/fixtures/`"; only the fixtures exclusion is
   pinned for them. A mutant exempting script types only under those two
   roots passes all 21 cases and reports a 401-line TOML under `plans/`.
   Source: Phases 2 to 6 report, finding 3. **Confirmed** by grep: the
   `plans/` case names none of the four new types. Mutation not re-run.

## Minor Findings

**Coverage (surviving mutants, none equivalent)**

2. `lib/verdicts.sh`, `_verdict_path_read`, letter arm: `\a \b \f \r \v`,
   which `%q` writes for bytes 007, 010, 014, 015 and 013, are decoded by
   code no case runs; dropped from the list, such a path reads as no path.
   Phase 1 finding 2. **Confirmed** by grep: no case in the three suites
   holds one of those escapes. Mutation not re-run by me.
3. `lib/probes-readonly.sh`, `probe_readonly_path`: §A promises a
   newline-bearing path its real outcome, `writable` or `readonly`; only
   `writable` is pinned. Phase 1 finding 3. **Confirmed** by reading the one
   case; mutation not re-run by me.

**Robustness**

4. `lib/verdicts.sh`, `verdict_config_lock`: `_verdict_path_read` is called
   bare and returns 1 for a `mask` with no decodable `path=` line, the state
   the encoder now produces for an empty path. A caller under `set -e` gets
   status 1 and no text; before the build it got the paragraph. The hook
   sets no errexit and is unaffected; the probes pin errexit callers and no
   verdict case does. Layer 2 and Phase 1 finding 4, found independently.
   **Confirmed** on bash 5.2.37 and 3.2.0: a direct call under `set -e`
   prints nothing and exits 1.
5. `lib/verdicts.sh`, `_verdict_path_read`, `$'…'` loop: quadratic in the
   number of escapes. A 3873-byte path of CJK characters decodes in 4.2 s on
   bash 5.2.37. On 3.2.0 it takes 4.7 s under `LC_ALL=C` and 31.8 s under
   `C.UTF-8` (both my runs; the reviewer reports 4.2 s there). The hook runs
   under the session's locale, UTF-8 on a Mac, where bash 3.2 is the system
   shell. A
   243-byte one takes 0.05 s. The hook's timeout is 10 s and a timeout loses
   the annotation silently, the failure §D closed for the tokenizer. Phase 1
   finding 6. **Confirmed** by my own timing script.
6. `lib/probes-readonly-command.sh`, `_readonly_tokenize`: the `#` and `&`
   arms flush the pending run on every occurrence, so an unquoted word dense
   in `#`, or in `>&`, is copied whole each time. 16384 characters of that
   shape: 3.6 s and 5.0 s on bash 5.2.37, 35.4 s and 36.8 s on 3.2.0, against
   1.3 s and 3.1 s for a plain word. The header says "no copy grows with the
   word" and states no such residual. The Phases 2 to 6 reviewer found the
   same (its finding 1, rated Major there) and a worse shape: a word of `#`
   after one letter takes 68 s on 3.2.0, as before the build, and 6001 such
   characters take 11.1 s, past the hook's 10 s. Minor here: §D prescribes
   these joins, it is no regression, and only an unquoted `#` or `>&` takes
   these arms. Layer 2. **Confirmed** by timing.
7. `lib/verdicts.sh`, `_verdict_has_control`: on bash 3.2.0 the
   `local LC_ALL=C` is not undone on return, so the calling shell stays in
   the C locale. In the hook that shell is the verdict's own subshell.
   Phase 1 finding 5. **Confirmed:** the reviewer's one-liner prints `1 2` on
   3.2.0 and `1 1` on 5.2.37.
8. `lib/verdicts.sh`, `_verdict_path_read`: `$''` decodes to empty with
   status 0, so the paragraph opens with an empty code span instead of "The
   path"; a relative `$'…'` value is accepted; a `/` value ending in a lone
   backslash is accepted. The encoder prints none of them. Layer 2 and
   Phase 1 finding 8. **Confirmed** on both bash versions.
9. `tests/corpus-eval.py`, `cmd_aggregate`: a verdict line with no tab
   raises `ValueError` (the run summary's open item). Only a hand-edited TSV
   reaches it; outside the outline. **Confirmed** by reproduction under a
   scratch directory.

**Test quality**

10. `tests/verdicts-readonly-path.bats`, case "decodes the same with the BSD
    stubs first on PATH": `lib/verdicts.sh` forks no tool, so no stub runs
    and the case cannot fail for a BSD reason. Phase 1 finding 10.
    **Confirmed** by grep: the stubbed tool names occur in comments only.
11. Slice 1.1/5 rewrites: 16 encoded literals in `probes-readonly.bats`,
    `probes-config.bats` and `probes.bats` interpolate `BATS_TEST_TMPDIR`
    with no check that it holds no byte `%q` escapes; in `probes-config.bats`
    three whole-output equalities leave first-line and count assertions after
    them that can no longer fail. No assertion was weakened. Phase 1
    finding 11. Unconfirmed by me.
12. `tests/check-line-limits.bats` has exactly 400 lines, its cap: the next
    case needs a split, and a file parked at its cap no longer signals.
    Commit `4b80e0c` cut a three-line comment to one to stay there, which
    the shared rule on caps forbids. Layer 2 and Phases 2 to 6 finding 10.
    **Confirmed** by `wc -l`; the commit not re-read by me.

**Stale or inaccurate text**

13. `tests/hook-locks-pathless.bats`, header: still explains a pathless lock
    probe by a newline in the lock path; at HEAD such a path prints one
    `$'…'` line. Also `tests/hook-locks.bats` (`LOCK_PATH_LINE`) describes a
    raw value as what the probe prints, and `tests/helpers/locale.bash` says
    three cases use it where four do. Item 7.7 swept `lib/` only. Prose
    finding 1 (rated Major there, as a false statement about HEAD; Minor
    here, since it is a comment in a suite whose cases still hold) and
    Phase 1 finding 9. **Confirmed** for the first by reading the header;
    the other two unconfirmed by me.
14. `lib/verdicts.sh`, `_verdict_path_read`, comment above `local re=`: it
    explains the variables by a pattern substitution the gate fix removed;
    and the arm accepts `\"` and `\e`, which `%q` never writes, with no
    stated reason (excess). Prose finding 2, Phase 1 finding 7. **Confirmed**
    by reading the function.
15. "design section B" and "design section C" in `lib/probes-readonly.sh`,
    `tests/probes-readonly-resolve.bats` and `tests/verdicts.bats` mean the
    outline under `plans/`; `docs/design.md` has no such section. Prose
    finding 5. **Confirmed** by grep.
16. `lib/verdicts.sh`, comment above `verdict_readonly_path`: says the path
    passes through byte-exact and omits the display rule's exception. Prose
    finding 10. **Confirmed** by reading.

**Docs** (prose findings 3, 4, 6 to 9, 11; reviewer-verified, not re-checked
by me except where said)

17. `docs/design.md`, FR-10: marked `Done`, as the outline asked, against a
    legend that reserves `Done` for what a test or gate re-checks; its pin is
    the tier index and the translation map. **Confirmed** against the legend.
18. `docs/design.md`: FR-6's pin list omits
    `tests/verdicts-readonly-path.bats`; NFR-5 says "document and script"
    where the gate now also caps awk, TOML, JSON and a `justfile`; Status
    dates the dogfood before changes this build made.
19. `docs/references/hook.md`, Paths: covers the lock probes' resolution
    only; the partial-checkout walk is in `readonly-path.md` alone.
20. `docs/references/readonly-path.md` and `lock-detectors.md`: "the
    backslash form", "the `$'…'` form" and "the wire form" are used and
    never defined; the lock side does not say the suffix test runs on the
    decoded value.
21. `docs/changelog.md`, 2026-10-11 entry: nothing untrue; omits that an
    empty path now prints no `path=` line, the two new suites, the `pick()`
    branch removal and the docstring loop fix.
22. `docs/references/readonly-path.md`, five-shapes residual: places the
    fourth shape "in the home directory"; no source records a location.
    Unverified either way.
23. Three hard-to-parse phrasings in `readonly-path.md`, Probe.

**Phases 2 to 6** (that report's findings 4 to 9 and 11; reviewer-verified
by command, not re-run by me except where said)

24. `lib/probes-readonly.sh`, `probe_readonly_path`: the partial-checkout
    gate is a substring test on the matching line, so a non-git refusal whose
    path holds one of the three phrases joins onto the worktree top and can
    read `readonly` wrongly. A contrived name; anchoring on git's own
    prefixes would close it. Layer 2 noted the same from reading.
25. Same function: the command substitution around `_readonly_git_dir`
    strips a trailing newline from the top's name; an empty `cwd` is not
    walked (the join lands on `$PWD`) while a relative one is.
26. `tests/probes-readonly-resolve.bats`: no case puts the cwd at the top of
    a tree nested in another (a linked worktree inside the main checkout, a
    submodule's top); a mutant walking from the cwd's parent survives.
27. `tests/extract-fixtures.bats`, the null-timestamp and string-input
    cases: each asserts only that the cut lands, and the odd line never
    carries the matching call, so what it "reads as" is unobserved. Both
    slice mutants survive.
28. `tests/corpus-eval.bats`: the skipped count is pinned with one verdict
    per line, so a count of verdicts passes for a count of lines; the
    string-input case pins that shape only. Both mutants survive.
29. `tests/extract-fixtures.py` `iter_calls`, `tests/corpus-eval.py`
    `cmd_extract`: still fatal on an integer `text` or `timestamp`, a
    list-valued `id` or `tool_use_id`, and a subdirectory in `survivors/`.
    `extract` deletes any file in `<outdir>/survivors/`, as the outline says.
30. `justfile`, `precommit`: the comment above the Python compile step still
    says no suite runs the two tools. **Confirmed** by grep. Also the
    `check-line-limits.sh` header calls extensionless files out of scope
    while capping `justfile`.

## Mutations

Each: an exact one-site replacement, proved landed, one suite at a time,
restored by the swapped replacement, restore proved (`git diff --quiet`).

| Slice | Site | Change | Result |
| --- | --- | --- | --- |
| 1.1/1 | `_probe_path_line` | empty path prints a bare `path=` | killed |
| 1.1/2 | `_probe_lock_at`, vanish site | `path=` line dropped | killed |
| 1.1/3 | `probe_readonly_path` | no `path=` when `readonly` and a newline | **SURVIVED** (3) |
| 1.1/4 | `_probe_path_line` | `LC_ALL=C` to `LC_CTYPE=C` | killed |
| 1.2/1 | `_verdict_path_read`, `/` arm | unescape blanks only | killed |
| 1.2/1 | `hooks/annotate.sh` | probe lines through `%b` | killed |
| 1.2/2 | `_verdict_has_control` | `[:cntrl:]` to `![:print:]` | killed |
| 1.2/3 | `verdict_config_lock` | suffix on the shown value | killed |
| 1.2/3 | `verdict_readonly_path` | suffix on the shown value | killed |
| 1.2/4 | `_verdict_path_read` | `/*)` widened to `*/*)` | killed |
| gate fix | `_verdict_path_read` | stderr line before returning 1 | **SURVIVED** (M1) |
| gate fix | `_verdict_path_read` | `a b f r v` dropped | **SURVIVED** (2) |
| 5.1 | `_probe_lock_path` | `LC_ALL=C` dropped from `sed` | killed |
| 5.1 | `_probe_lock_at` | age 120 s too high | killed |

Phase 1 and Item 5.1: 14 mutations, 11 killed, 3 survived.

| Slice | Site | Change | Result |
| --- | --- | --- | --- |
| 2.1/1 | `probe_readonly_path` | walk from the cwd's parent | **SURVIVED** (26) |
| 2.1/2 | `_readonly_git_dir` | `-e` to `-d` on `.git` | killed |
| 2.1/3 | `probe_readonly_path` | fallback base `$PWD` | killed |
| 3.1 | `verdict_phantom_chardev` | names the working directory | killed |
| 4.1 | `_readonly_tokenize`, top flush | pending run dropped | **SURVIVED** (M2) |
| 5.2 | `handle_file`, first arm | exempts script types only | **SURVIVED** (M3) |
| 6.1/1 | `cmd_extract` | TSV unlinked under `survivors/` | killed |
| 6.1/2 | `cmd_aggregate` | counts verdicts, not lines | **SURVIVED** (28) |
| 6.1/3 | `cmd_extract` | guard tests for a string only | **SURVIVED** (28) |
| 6.2/1 | `iter_calls` | a null timestamp reads as a fixed day | **SURVIVED** (27) |
| 6.2/2 | `iter_calls` | a non-dict input passed through | **SURVIVED** (27) |

Phases 2 to 6: 11 mutations, 4 killed, 7 survived. Total: 25 mutations, 15
killed, 10 survived, none equivalent. Suites and the killing case for each
row are in the two sub-reports. Items 7.1 to 7.7 are prose: no mutation.

## Confirmed by me

- **Encoder and decoder round trip.** 5580 paths (every byte 1 to 255 before
  each of 16 following characters, then 1500 random byte strings) through
  `_probe_path_line` and `_verdict_path_read`: 0 mismatches on bash 5.2.37
  and 3.2.0, each under the default locale and `C.UTF-8`.
- **Display rule and hostile values**, both versions: `\177` and a newline
  show the wire form; UTF-8 shows decoded; a `$(…)` in the backslash form
  decodes inert (sentinel file absent); `\c`, `\x41`, `\8` and a truncated
  octal return 1 with both outputs empty.
- **Tokenizer target.** One 16384-character word: 1.25 s on 5.2.37, 3.12 s
  on 3.2.0 (target under 5 s).
- M1, M3, M2 in part, and Minor 2 to 10, 12 to 17 and 30 as stated on each (2,
3 and
  10 by grep or reading, their mutations not re-run). Minor 11, 18
  to 29 are the reviewers', verified by them by command and not re-checked
  by me.

## The four items the run summary left open

1. **`cmd_aggregate` raises on a tab-less verdict line.** Reproduced
   (finding 9). Minor, outside the outline: the documented loop always writes
   the tab.
2. **Audit recommendations 1 to 6.** Recommendation 1 (a permanent
   byte-by-following-character round trip) is not in the suite; my run of it
   passes on both versions, and findings 2 and 3 show the seam's pins are
   still thin, so it remains worth adding. Recommendation 4: the Phase 1
   reviewer compared the 15 rewritten cases with the base and found none
   weakened (finding 11 is what it did find). Recommendation 6's `|| base=`
   guard: the audit stands. `tests/probes-readonly-resolve.bats` has two
   cases under `set -e`, both for a text with no matching line, which never
   reaches that guard; its fallback value is pinned (a mutant falling back
   to `$PWD` was killed), its errexit role is not. The Phases 2 to 6
   reviewer's "each has a pin" holds for the value only. Recommendations 2,
   3 and 5 are process notes with nothing to check in the tree.
3. **`triage-feedback.sh` label mismatch.** Not re-run. It is edify tooling
   outside this repository and no defect of the build's deliverables.
4. **Bash 3.2.0 verified by report runs only; macOS unverified.** Stands,
   and cannot be closed here: bats-core fails to parse under the 3.2.0 build,
   so no suite can run on it. Hand runs on 3.2.0 in this review: the round
   trip and the tokenizer target hold; findings 5, 6 and 7 are 3.2-specific
   or worse there. Apple's 3.2.57 and BSD userland stay unverified.

## Gap Analysis

| Outline item | Status |
| --- | --- |
| A, Item 1.1: `path=` in `%q` form | covered; 3 |
| A, Item 1.2: decode and display | covered; M1, 2, 4, 5, 7, 8, 14 |
| B, Item 2.1: partial-checkout join | covered; 24, 25, 26 |
| C, Item 3.1: phantom wording | covered; none |
| D, Item 4.1: tokenizer | covered, target met; guard vacuous: M2; 6 |
| E, Item 5.1: suite on macOS | covered; unverified on a Mac, as stated |
| F, Item 5.2: line-cap coverage | covered; exclusions unpinned: M3; 12, 30 |
| G, Items 6.1, 6.2: Python tools | covered; 9, 27, 28, 29 |
| Items 7.1 to 7.6: docs | covered; 17 to 23 |
| Item 7.7: comments | covered for `lib/`; 13, 14, 16 |
| H, I: closed with reasons | recorded in the changelog and `readonly-path.md` |

No missing deliverable. Unspecified deliverables: the gate's per-escape
decoder (justified in its comment), `tests/verdicts-readonly-path.bats` in
place of `verdicts-readonly.bats` (its header gives the line cap as the
reason), the three Python guards the build's reviewer added (scalar and array
JSONL lines in both tools, a null `text` item), each named by its own test
case, and the pin cases added after each code review.

## Summary

Critical: 0. Major: 3 (M1 to M3). Minor: 29 (findings 2 to 30, several
merging two reviewers' reports).

All three Majors are test defects: an unasserted clause, a guard that does
not exercise the mechanism it guards, and two unpinned exclusions. No
finding shows wrong output from the shipped hook on bash 5.2.37 or 3.2.0 for
an input a probe can produce; the timing findings (5, 6) are the ones that
can cost an annotation, on bash 3.2 and on unusual input. Two findings were
downgraded from a Layer 1 rating of Major to Minor, with the reason stated
on each (6, 13).

## Sub-reports

All three under `plans/sandbox-lies-review-fixes-3/reports/`:

- `deliverable-review-prose.md`
- `deliverable-review-code-tests-phase1.md`
- `deliverable-review-code-tests-phases2-6.md`

## Final tree

`git status --short` after the last reviewer returned, sandbox-mask
dotfiles excluded:

```
M  .claude/handoff-task.md
M  .claude/handoff-todo.md
?? inbox/
?? plans/sandbox-lies-review-fixes-3/reports/deliverable-review-code-tests-phase1.md
?? plans/sandbox-lies-review-fixes-3/reports/deliverable-review-code-tests-phases2-6.md
?? plans/sandbox-lies-review-fixes-3/reports/deliverable-review-prose.md
?? plans/sandbox-lies-review-fixes-3/reports/deliverable-review.md
```

`git diff --stat` is empty and `grep -rn '# MUT' lib tests scripts hooks`
finds nothing: no mutation remains, and nothing but the four reports was
added. Nothing was committed.
