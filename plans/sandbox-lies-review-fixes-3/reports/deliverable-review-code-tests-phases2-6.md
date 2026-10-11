# Deliverable review: code and tests, Phases 2 to 6

Range `2309ae6..2015b0f`, Items 2.1, 3.1, 4.1, 5.2, 6.1, 6.2 (files as in the
dispatch). Reviewer: Opus 5.5 (`claude-opus-5-5`). Result: the code follows the
outline's design, and Item 4.1's 5 s target is unmet for one word shape; 0
Critical, 3 Major, 7 Minor. 11 mutations: 4 killed, 7 survived, none
equivalent. Scratch scripts named below sit in `/tmp/claude/dr-p2/`.

## Findings

1. **Major, robustness.** `lib/probes-readonly-command.sh`,
   `_readonly_tokenize`. A word dense in `#`, or in `&` after `>`, costs what
   the pre-build code cost: both arms join and re-read all of `word` at each
   such character, as section D prescribes. Item 4.1's "under 5 s on 3.2 for
   one 16384-character word" holds for a plain word only, and the header's "no
   copy grows with the word" is false. Not a regression, and unlikely (only an
   unquoted `#` or `>&` takes these arms).
   Verified: `/tmp/claude/bash32/bash time.sh <shape> new`, one 16384-character
   token: `a` then `#` repeated 68.2 s (pre-build 68.9 s), `a#` repeated
   35.7 s, `>&` repeated 37.8 s, plain `a` 2.45 s; bash 5.2: 6.1, 3.9, 4.2,
   1.08 s. A 6001-character all-`#` word: 11.1 s on 3.2.0, over the hook's 10.
2. **Major, vacuity.** `tests/probes-readonly*.bats` as Item 4.1's guard. No
   case reads the content of a word longer than 256 characters, so a mutant
   dropping the pending run at the top-of-loop flush passes all seven files:
   "output unchanged" rests on hand-run differentials only. Verified: Mutations
   row 4.1; the mutant cut the 305-character token of `cat <300 zeros>.log`.
3. **Major, coverage (an exclusion the outline specifies).**
   `tests/check-line-limits.bats`, `plans/ is out of scope` and `plugin-dev/
   is out of scope`. Both list every script type, by their own comment so that
   a narrowed exclusion is caught, and none of the four new types.
   Verified: Mutations row 5.2; under the mutant `scripts/check-line-limits.sh
   /tmp/claude/dr-p2/ll` reported `plans/c.toml`, `plans/x.json` and
   `plugin-dev/justfile`, exit 1; restored, exit 0.
4. **Minor, correctness.** `lib/probes-readonly.sh`, `probe_readonly_path`.
   The gate is a substring test on the whole matching line, so a non-git
   refusal whose path holds one of the three phrases joins onto the worktree
   top: the wrong `readonly` section B exists to remove, on a contrived name.
   Verified: `bash probe21.sh` case a (same on 3.2.0): from `<repo>/sub`, a
   `cp` refusal naming `unable to create file/x` printed `readonly` and
   `<repo>/unable\ to\ create\ file/x`; the parent under `sub` is writable.
5. **Minor, robustness.** Same function. (i) `base=$(_readonly_git_dir ...)`
   strips a trailing newline from the top's name, so the path loses it and
   reads `readonly`. (ii) An empty `cwd` is not walked: the join lands on
   `$PWD`, while a relative `cwd` walks from `$PWD/<cwd>`.
   Verified: `probe21.sh` cases g, b, b2.
6. **Minor, coverage.** `tests/probes-readonly-resolve.bats`. No case puts the
   cwd at the top of a tree nested in another (a linked worktree's top inside
   the main checkout, a submodule's top). Verified: Mutations row 2.1/1; under
   the mutant, cwd `main/wt` printed `main/d/f` (restored: `main/wt/d/f`).
7. **Minor, specificity.** `tests/extract-fixtures.bats`, `a null timestamp
   reads as no day ...` and `a string tool_use input reads as no command ...`:
   each asserts only that the cut lands; the odd line never carries the
   matching call, so what it "reads as" is unobserved. `tests/corpus-eval.bats`,
   `aggregate skips ...`: each unmatched line holds one verdict, so a count of
   verdicts passes for a count of lines; `extract reads a string ...`: a mutant
   raising on a `null` or list `input` passes (`null` worked before the build).
   Verified: Mutations rows 6.1/2, 6.1/3, 6.2/1, 6.2/2; by hand each 6.2
   mutant cut a fixture (exit 0) from a call the real code rejects (exit 1).
8. **Minor, robustness.** `tests/extract-fixtures.py` `iter_calls`,
   `tests/corpus-eval.py` `cmd_extract`, `cmd_aggregate`. Still fatal: an
   integer `text` item or `timestamp` (cutter), a list-valued `id` or
   `tool_use_id` (both), a tab-less verdict line (deferred by the build), a
   subdirectory in `survivors/`. Verified: `python3 -I` on scratch copies under
   a scratch `HOME`, one corpus line per shape: a traceback and exit 1 each.
9. **Minor, excess.** `tests/check-line-limits.bats` sits at exactly 400
   lines: commit `4b80e0c` cut a three-line comment to one while adding a
   fixture (`item-5-2-pin-review.md`: "condensed so the file stays at 400").
   The shared rule forbids meeting a cap by shaving prose.
   Verified: `awk 'END{print NR}' tests/check-line-limits.bats` prints 400;
   `git show 4b80e0c -- tests/check-line-limits.bats`.
10. **Minor, clarity (outside the dispatch's file list).** `justfile`: the
    `precommit` comment says no suite runs the two Python tools; Items 6.1 and
    6.2 added two. Verified: `git diff --stat 2309ae6..HEAD -- justfile`: empty.

## Mutations

| Slice | Site | Change | Suite | Result |
| --- | --- | --- | --- | --- |
| 2.1/1 | `probe_readonly_path` | walk from `${cwd%/*}` | resolve | SURVIVED 9/9 |
| 2.1/2 | `_readonly_git_dir` | `-e` to `-d` on `.git` | resolve | killed by `... linked worktree's top from a subdirectory`, path assertion |
| 2.1/3 | `probe_readonly_path` | fallback `base="$PWD"` | resolve | killed by `... no .git above the cwd joins onto the cwd`, path assertion |
| 3.1 | `verdict_phantom_chardev` | "in the working directory" | verdicts | killed by `verdict text matches detectors.md`, `line1` |
| 4.1 | `_readonly_tokenize`, top flush | `{ run=''; }` | 7 readonly files | SURVIVED 101/101 |
| 5.2 | `handle_file`, first arm | exempt script types only | check-line-limits | SURVIVED 21/21 |
| 6.1/1 | `cmd_extract` | TSV unlinked under `survdir` | corpus-eval | killed by `extract drops survivors ...`, `! -e verdicts.tsv` |
| 6.1/2 | `cmd_aggregate` | `skipped += len(vs.split())` | corpus-eval | SURVIVED 4/4 |
| 6.1/3 | `cmd_extract` | `if not isinstance(inp, str)` | corpus-eval | SURVIVED 4/4 |
| 6.2/1 | `iter_calls` | `or "2026-08-13"` | extract-fixtures | SURVIVED 4/4 |
| 6.2/2 | `iter_calls` | `else inp` | extract-fixtures | SURVIVED 4/4 |

Each: one `Edit` of a once-occurring string, landed (`command grep`), restored
by the swapped `Edit`; then no mutation text, `git diff --quiet -- <file>`
exit 0, suite green. Each survivor changes behaviour: by hand above, or by
inspection (6.1/2: a two-verdict line counts 2; 6.1/3: a list `input` raises).

## Conformance

| Slice | Status | Carried by |
| --- | --- | --- |
| 2.1/1 | conforms | resolve cases 1, 2, BSD case; the pre-build lib prints `readonly`, `<repo>/sub/d/f` |
| 2.1/2 | conforms | resolve case 3, a real `git worktree add` |
| 2.1/3 | conforms | resolve cases 5 and 7; case 6 pins "that line alone" |
| 3.1 | conforms | `verdict text matches detectors.md`, `phantom-untracked opens ...`; 254 and 340 characters |
| 4.1 | section D as written; 5 s target unmet for `#`- or `>&`-dense words (findings 1, 2) | differential below; plain word 2.45 s on 3.2.0 |
| 5.2 | conforms; finding 3 | `oversized awk is reported` and two pins |
| 6.1/1 | conforms | `extract drops survivors and verdicts ...` |
| 6.1/2 | conforms; finding 7 | `aggregate skips verdict lines ...` |
| 6.1/3 | conforms; finding 7 | `extract reads a string tool_use input ...` |
| 6.2/1 | conforms; finding 7 | `a null timestamp reads as no day ...` |
| 6.2/2 | conforms; finding 7 | `a string tool_use input reads as no command ...` |

## Checked and clean

- Tokenizer, old against new (`diff.sh`): 5186 inputs on bash 5.2, 4674 on
  3.2.0, 0 differences, and the versions agree: random commands over every
  character the scan branches on, runs of 255 to 257, 512 and 513 under 8
  prefixes and 21 tails, and the cap (its one-word cases on 5.2 only).
- Section B's premise: git 2.47.3 run from `sub` names both shapes relative
  to the top (permission-denied variant, scratch repository).
- Item 2.1 resolves correctly with the cwd at the top, inside `.git/hooks`,
  below a `.git` file, or holding a blank and a mid-name newline. The two
  errexit guards serve a direct caller (the hook sets `-u` only); both pinned.
- The BSD stubs are reached through the `PATH=... run` prefix (scratch bats);
  every new bats file loads `helpers/bsd-stubs`. No new `2>/dev/null`.
- Item 5.2: the arm caps seven tracked files (largest 68 lines) and exempts
  two fixture JSON files; arm order and the header's scope sentence match.
- Python: scalar, array, `null` and truncated lines, a non-dict `message`, a
  string `content` and a `null` or list `input` exit 0 in both tools. All 34
  `SPEC` entries name a project, so `pick()` is unchanged. Both suites run
  under a scratch `HOME`. `extract` empties `<outdir>/survivors/`, as outlined.
- Excess: the three added Python guards and the pin cases each have a case
  and a stated reason. Accepted, but for findings 7 and 8.

## Tree

```text
M  .claude/handoff-task.md
M  .claude/handoff-todo.md
?? inbox/
?? plans/sandbox-lies-review-fixes-3/reports/deliverable-review-code-tests-phase1.md
?? plans/sandbox-lies-review-fixes-3/reports/deliverable-review-code-tests-phases2-6.md
?? plans/sandbox-lies-review-fixes-3/reports/deliverable-review-prose.md
?? plans/sandbox-lies-review-fixes-3/reports/deliverable-review.md
```

Above: `git status --short` less the mask dotfiles; `deliverable-review.md`
appeared during the run and is not mine. `git diff --stat`: empty.
`command grep -rn '# MUT' lib tests scripts hooks`: no output, exit 1.
