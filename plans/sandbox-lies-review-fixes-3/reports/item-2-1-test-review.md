# Test review — Items 2.1 + 3.1

Mode: test review + fix on tests. Scope IN: `tests/probes-readonly-resolve.bats`,
the `tests/verdicts.bats` diff, the RED report. Nothing committed. `lib/` is
untouched (`git diff --stat -- lib` empty; no `MUT` text in
`lib/probes-readonly.sh` or `lib/verdicts.sh`).

Assessment: Ready. Six RED cases red on assertions, three regressions proven.

## Coherence of the two files

Both were read whole. Resolve file: 7 cases, no case repeats another. Cases 1
and 4 are the slice 1 unlink case and its `make_bsd_stubs` re-run, which
CLAUDE.md requires. Case 6 (partial-checkout line elsewhere in the text) is the
RED agent's addition and pins section B's "for that line alone", which neither
regression covers; it is not a contradiction. `verdicts.bats`: the whole-chardev
pin (existing test 3) and the new opening-sentence test 4 overlap on the
untracked opener on purpose; test 3 reds first at the chardev line and hides its
untracked assertions, so test 4 is the only one that reds on the untracked
paragraph alone. No other test in `tests/` mentions "project root". No fixture
was hand-cut: the cp case reads the cut `fire-readonly-path-cp-tmp`.
`load helpers/bsd-stubs` present; one case runs under `make_bsd_stubs grep sed`.
Self-quiet: `bash lib/matchers.sh` over the new file, `helpers/probes.bash` and
`probes-readonly-facts.bats` prints nothing; `tests/docs.bats` 2 passed;
`shellcheck -x` clean.

## Check 1: mechanical

Baseline against unchanged lib (also after my edits): resolve file 3 passed, 4
failed; `verdicts.bats` 9 passed, 2 failed.

| Test | Result | Failing assertion |
| --- | --- | --- |
| resolve 1 unlink-old from `sub` | FAILED | `path_line = path=$repo/d/f` |
| resolve 2 create-directory-at `d/n` | FAILED | `path_line = path=$repo/d/n` |
| resolve 3 linked worktree | FAILED | `path_line = path=$wt/d/f` |
| resolve 4 BSD grep+sed | FAILED | `path_line = path=$repo/d/f` |
| verdicts 3 chardev whole | FAILED | `line1 = chardev_para` |
| verdicts 4 untracked opener | FAILED | prefix comparison at the opener |
| resolve 5 cp keeps cwd join | green, mutation proof | |
| resolve 6 elsewhere-line | green, mutation proof | |
| resolve 7 no `.git` joins cwd | green, mutation proof | |

Every red case reaches `status 0` and empty stderr before the failing line, so
none erred.

## Mutation proof (my own, distinct from the RED report's)

Subject string, once in `lib/probes-readonly.sh`:
`path=$(_probe_readonly_resolve "$path" "$cwd")`. A script asserted exactly one
occurrence before replacing; restore swapped the strings. Each landing was shown
with `command grep`; each restore with `command grep -c` returning 0.

- Case 5 (cp keeps cwd): join onto the cwd's parent, `"${cwd%/*}"`.
  Run: 4 passed, 3 failed. Case 5 red at
  `path_line = path=$repo/sub/d/f` (line 116 then; 118 after my edit).
  Cases 6 and 7 also red; 2 and 3 also red after my deepening (below).
- Case 6 (matching line alone): gate the top-join on the LAST line of the text
  (`tail -n 1`) instead of the matching line. Run: 6 passed, 1 failed; only case
  6 red, at `path_line = path=$repo/sub/d/f`.
- Case 7 (no `.git` fallback): gate on the matching line, fall back to the
  cwd's parent. Run: 6 passed, 1 failed; only case 7 red at
  `path_line = path=$plain/sub/d/f`. Cases 1 to 4 green, so the tests are
  satisfiable.
- Satisfiability: a gated implementation falling back to `cwd` makes all 7
  green.
- Verdicts test 4, three mutations of the untracked opener in
  `lib/verdicts.sh` (old opener unique in the file). Each landed, each red
  alone with `bats -f 'phantom-untracked opens'`:
  - opener ending "repository. Mind the project root." red at the
    `*'project root'*` case line (89);
  - opener followed by `,` red at the space assertion (87);
  - "in this repository" red at the prefix comparison (86).
  Restored by swapping; residue 0; `git diff --stat -- lib` empty.

## Check 2: wrong-reason hunting

State that fails each test, and what else could produce its observable:

1. Unlink-old from `<repo>/sub`, `<repo>/.git` directory, `d/f` only at the top.
   Fails when the join is anything but the top. The path line is a literal, and
   `d/f` exists only at the top, so only the join decides it.
2. Create-directory-at `d/n`, `d` exists at the top, `d/n` does not. Fails if the
   mkdir shape is not covered by the rule. FINDING: with `sub` as cwd, "join
   onto the cwd's parent" passed cases 1 to 4 (the top is `sub`'s parent in
   every fixture). Fixed, see below.
3. Linked worktree, `.git` a file (`[ -f "$wt/.git" ]`), nested in the main
   repository, `d/f` at both tops. A join onto the outermost `.git` names
   `main/d/f`; a join onto the cwd names `wt/sub/.../d/f`. Same parent-of-cwd
   weakness, fixed.
4. As 1 under stubs. Status 0 and empty stderr precede the path line, so a stub
   rejection is excluded. Only proves the stubbed tools work with the new code.
5. cp refusal, `d/f` at both `sub` and the top. Fails only when the cp line joins
   onto the top; the path differs between the two while the outcome does not.
6. cp line first, unlink line for `d/g` after. Fails when the rule reads the
   whole text or the last line.
7. `assert_no_git_above` as precondition, so a `.git` supplied by the box cannot
   change it. Fails when the no-ancestor fallback is anything but the cwd.

Verdicts 3 and 4: red states named above; the untracked opener pin is exact and
followed by a space check, and the "project root" absence check catches the old
clause moved anywhere in the line.

Outline coverage: Item 2.1 slices 1 (unlink and mkdir shapes, both built from
fragments), 2 (linked worktree from a subdirectory), 3 (cp regression, no-`.git`
regression) all present. Item 3.1 slice 1: chardev paragraph pinned whole,
untracked opener pinned. The 400-character bound is held by the existing
`verdicts under 400 chars` loop over every row (phantom_chardev and
phantom_untracked included); it is green before and after, so no duplicate
assertion was added.

## Check 3: findings and fixes

1. Major: the cwd was one level below the top in cases 1 to 3, so a join onto the
   cwd's parent satisfied them. Status: FIXED. Cases 2 and 3 now run from
   `sub/deep`; case 1 stays at `sub` as the outline words it. Re-proved: the
   parent-of-cwd mutation now reds cases 2, 3, 5, 6 and 7; the gated correct
   implementation turns all seven green.
2. Minor: `partial_checkout_unlink_error` and `partial_checkout_mkdir_error` were
   duplicated as `unlink_error` and `mkdir_error` in the new file.
   Status: FIXED. The three builders moved to `tests/helpers/probes.bash`; both
   files use them, and the local copies and header comments in
   `probes-readonly-facts.bats` and the new file were updated. Facts suite
   15 passed (15 before), `probes-readonly.bats` 17 passed, `docs.bats` 2
   passed.
3. Minor: the new file compared literal `path=$repo/...` lines against `%q`
   output without the precondition the Item 1.1 cases carry (a `BATS_TEST_TMPDIR`
   holding an escaped byte would red cases 5 to 7 forever). Status: FIXED. The
   `setup()` asserts `printf %q` of `BATS_TEST_TMPDIR` is unchanged.

## Fixes applied

- `tests/helpers/probes.bash` — added `partial_checkout_unlink_error`,
  `partial_checkout_create_error`, `partial_checkout_mkdir_error`.
- `tests/probes-readonly-facts.bats` — removed its local copies, comment points
  to the helper.
- `tests/probes-readonly-resolve.bats` — uses the shared builders; `setup()`
  guard; cases 2 and 3 run from `sub/deep`, with comments.

## Final state

`tests/probes-readonly-resolve.bats` against the unchanged lib: 3 passed, 4
failed on assertions (lines 44, 60, 84, 100). `tests/verdicts.bats`: 9 passed, 2
failed (lines 61 and 86). No `# MUT` edit remains. Deferred: docs still carry
the old phantom wording until Item 7.4; test 3's title names `detectors.md`
until then.
