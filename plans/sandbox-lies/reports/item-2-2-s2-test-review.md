# Item 2.2 slice 2 — test review

Scope: the two new tests in `tests/check-links.bats` (`broken links in scope
are reported`, `markdown out of scope is ignored`) and `item-2-2-s2-red.md`.
The SUT was mutated in place only. Each mutation was an exact-string
replacement with its count asserted at 1, inverted in a `finally`, and
followed by `git diff --quiet scripts/`. Nothing is committed.

## Verdict

The RED fixtures did not pin the scope on their own. Six plausible wrong
implementations passed all four tests: one re-implemented table with a
narrowed skills arm, three with unanchored exclusions, one checking
non-markdown files, and one with a dot-directory skip in front of an
unanchored skills arm. Three mutations of `markdown_in_scope` itself also
survived. With the reference GREEN in place, this suite leaned on
`tests/check-line-limits.bats` for the skills arm's breadth and for the
exclusion anchors. After the fixture rebuild, every one of those
implementations and mutations goes red in this suite alone. The one
exception is the residual below. `broken links in scope are reported` is
still red on its exact-output assertion.

## Mechanical check (before fixes)

`scripts/run-bats.sh tests/check-links.bats`, foreground: 3 passed,
1 failed. `broken links in scope are reported` failed on its
`[ "$output" = … ]` assertion (line 92), so the failure is an assertion,
not an error. `markdown out of scope is ignored` passed, as the RED report
expects.

## Findings (all fixed in the tests)

Probe harness: `handle_file`'s `case` body was replaced by either the
reference GREEN (`if markdown_in_scope "$1"; then check_links_in "$1"; fi`)
or a re-implemented table. The whole file was then run.

1. **Major: a skills arm narrowed to skill directories passed**
   (`docs/*.md | skills/*/*.md`, and `markdown_in_scope`'s
   `skills/*.md` → `skills/*/*.md`). Both skills fixtures sit inside
   `skills/x/`. Item 2.1 scopes markdown directly under `skills/` as well
   (its slice 4, `markdown directly under skills/`). **Fix:** the positive
   test adds `skills/top.md`.
2. **Major: unanchored exclusions passed** (`*plans/* | *plugin-dev/*`,
   each half separately, and the same edit to `markdown_in_scope`). No
   positive fixture had a nested `plans/` or `plugin-dev/`. **Fix:** the
   positive test adds `docs/plans/a.md` and `skills/plugin-dev/SKILL.md`,
   one for each anchor. `docs/plans/a.md` also rules out a docs arm that
   stops at depth 1 (`docs/*/*) ;;` ahead of `docs/*.md`), which had passed
   too.
3. **Major: a scope over every file in docs/ and skills/ passed**
   (`docs/* | skills/*`, and `markdown_in_scope`'s catch-all
   `*) return 1` → `return 0`). Every fixture was `.md`. **Fix:** the
   negative test tracks `docs/x.txt` holding a broken link. It is not
   markdown, so it stays inside the test's name.
4. **Minor: the skills anchor was pinned only through a dot-directory.**
   `.claude/skills/y/SKILL.md` is the only non-root `skills/` path in the
   negative test. A `.*) ;;` skip followed by an unanchored `*skills/*.md`
   arm passed. Item 2.1's slice 3 review left this same residual. **Fix:**
   the negative test adds `lib/skills/y/SKILL.md`, which pins the anchor
   independently of dot-directory handling.

The positive test now expects seven lines, not the slice text's four. The
slice's four files and their order are unchanged. The three new files are
fixture discrimination, as in Item 2.1's slice 3 review (`p.md`). The sort
comment was reworded to cover the new lines.

## Wrong-implementation matrix

`ref-*` are correct layouts. `W*` are re-implemented tables. `M*` mutate
`markdown_in_scope` with the reference GREEN in place.

| variant | before fixes | after fixes |
|---|---|---|
| ref-call (`markdown_in_scope`), ref-table | 4/4 green | 4/4 green |
| W1 `skills/*/*.md` | **green** | red: test 3, output |
| W2 `*skills/*.md` | red: test 4, status | red: test 4 |
| W3 root arm crosses `/` (no `*/*` skip) | red: test 4 | red: test 4 |
| W4 root arm takes dot-dirs (`[!.]*/*) ;;`) | red: test 4 | red: test 4 |
| W5 `*plans/* \| *plugin-dev/*` | **green** | red: test 3, output |
| W5b only `*plans/*` unanchored | **green** | red: test 3, output |
| W5c only `*plugin-dev/*` unanchored | **green** | red: test 3, output |
| W6 `docs/* \| skills/*` (non-md) | **green** | red: test 4, status |
| W8 `.*) ;;` then `*skills/*.md` | **green** | red: test 4, status |
| W9 docs depth 1 only | **green** | red: test 3, output |
| W10 `markdown_in_scope && check_links_in` (errexit) | red: test 4 | red: test 4 |
| M1 `skills/*.md` → `skills/*/*.md` | **green** | red: test 3, output |
| M2 `*/*.md) return 1` deleted | red: test 4 | red: test 4 |
| M3 exclusion unanchored | **green** | red: test 3, output |
| M4 docs arm deleted | red: tests 2, 3 | red: tests 2, 3 |
| M5 root arm deleted | red: test 3 | red: test 3 |
| M6 `skills/*.md` → `*skills/*.md` | red: test 4 | red: test 4 |
| M7 catch-all `return 0` | **green** | red: test 4, status |
| W7 root arm hardcoded to `README.md` | green | green (residual) |

W10 is worth knowing about for GREEN. A handler ending in `a && b` returns
1 on an out-of-scope file, and `walk_tracked_files` runs under errexit, so
the run exits 1. The negative test catches this.

## Mutation reproductions (different from the RED report's)

| behaviour | RED report's mutation | mine | test 4 |
|---|---|---|---|
| scope limited | `docs/*.md)` → `*.md)` | `docs/*.md)` → `*/*.md)` | red, `[ "$status" -eq 0 ]` |
| untracked excluded | `ls-files -z --cached --others --exclude-standard` | `ls-files -z --others` | red, `[ "$status" -eq 0 ]` |

Under the second mutation, `docs/u.md` is the only file in test 4's
fixture that `--others` lists. That makes it the sole cause of the red.
Tests 2 and 3 go red too, because their tracked files drop out of the
walk. Both mutations were inverted and `git diff --quiet scripts/` exited
0 after each. Before the reproductions, two drafts of these mutations
carried a `# PROBE-MUTANT` marker that broke shell syntax: every test went
red for the wrong reason. I discarded those runs and reran without the
marker. Only the reruns are reported.

## Observation outside this slice (SUT, not a test issue)

M8: I deleted `markdown_in_scope`'s `plans/* | plugin-dev/*) return 1` arm
with the reference GREEN in place, and all four tests stayed green. The arm
is dead for markdown: the anchored `docs/` and `skills/` arms and the
`*/*.md) return 1` skip already send `plans/x.md` to false. Its comment,
"an unanchored `*.md` would otherwise match `plans/x.md`", overlooks that
the skip comes before `*.md`. `check-line-limits.sh` excludes both
directories on its own (lines 48–58). No test can pin the arm, so the code
reading applies: delete it with its comment, or keep it as a stated
defensive guard. That is the refactor's or code review's call, not this
slice's.

## Residual (not pinned)

- **W7, a root arm hardcoded to `README.md`.** This is implausible. Neither
  the shared predicate nor the port's rumdl scope (`/*.md`) names files.
  Pinning it would take a second root file, which pushes the slice's
  fixture further from its text.

## Final red run (unchanged SUT, fixed tests)

`scripts/run-bats.sh tests/check-links.bats`, foreground, exit 1:

```
not ok 3 broken links in scope are reported
# (in test file tests/check-links.bats, line 103)
#   `[ "$output" = "broken-link: README.md -> missing.md' failed

bats: 3 passed, 1 failed
```

- `shellcheck tests/check-links.bats`: clean.
- `git diff --quiet scripts/`: exit 0, and `PROBE-MUTANT` has 0 hits under
  `scripts/`. The SUT is byte-identical to HEAD.
- `git status -- scripts tests plans`: `tests/check-links.bats` modified,
  plus the two slice reports. `tests/check-links.bats` is 140 lines.

## Files changed

- `tests/check-links.bats`: fixtures and comments for both slice-2 tests.
- The mutation runner was a scratch tool outside the repo, at
  `$TMPDIR/s2rev/mutate.py`.
