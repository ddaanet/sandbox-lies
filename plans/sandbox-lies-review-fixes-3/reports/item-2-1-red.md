# Item 2.1 + 3.1 RED report

Mode RED, one group: Item 2.1 (`probe_readonly_path` partial-checkout join)
and Item 3.1 (phantom wording). Nothing committed. No lib file touched:
`git diff --stat -- lib` is empty after the mutation proofs, and a grep for
every mutation text in `lib/probes-readonly.sh` and `lib/verdicts.sh` finds
nothing.

Takeover note: the tests were written by the stalled earlier agent (file
mtimes 18:43, before this dispatch). That agent (or a copy of it) woke during
this dispatch and wrote an earlier version of this report at 20:17:09, while
this run was mid-mutation. This report replaces it. Every mutation below was
applied and restored by this run alone, each guarded by an exact-once count
check, and the lib was clean at the start of every mutation. I changed no test
text: review found the two files sound.

Files: new `tests/probes-readonly-resolve.bats` (164 lines; loads
`helpers/bsd-stubs`, `helpers/git-env`, `helpers/probes`), edited
`tests/verdicts.bats` (208 lines). Refusal text is built from fragments
around `erofs_message` (`unlink_error`, `mkdir_error`), and the cp case reads
the cut fixture `fire-readonly-path-cp-tmp` through `readonly_path_text`.
`bash lib/matchers.sh` over both files prints nothing; `tests/docs.bats` is
green (2 passed). `shellcheck` reports only SC1091 (info) on
`source "$ROOT/lib/probes.sh"`, the same finding the existing
`tests/probes-readonly-facts.bats` has; `shellcheck -x` is clean. The repo
justfile has no `just lint` recipe; `just precommit` is the gate.

## Item 2.1 — `tests/probes-readonly-resolve.bats`

Against the unchanged lib: 4 fail on their path assertion, 3 pass. Each red
test reaches `[ "$status" -eq 0 ]` and `[ -z "$stderr" ]` first, so the probe
ran clean and the value is what differs.

Red:

```
not ok 1 partial-checkout path joins onto the worktree top, not the cwd
#   `[ "$(path_line)" = "path=$repo/d/f" ]' failed          (line 55)
not ok 2 partial-checkout directory path joins onto the worktree top
#   `[ "$(path_line)" = "path=$repo/d/n" ]' failed          (line 70)
not ok 3 partial-checkout path joins onto a linked worktree's top from a subdirectory
#   `[ "$(path_line)" = "path=$wt/d/f" ]' failed            (line 93)
not ok 4 partial-checkout path resolves through BSD grep and sed
#   `[ "$(path_line)" = "path=$repo/d/f" ]' failed          (line 109)
```

State of the world that fails each, and what else could produce the red:

1. `<repo>/.git` directory, cwd `<repo>/sub`, `<repo>/d/f` exists, text is the
   unlink-old line naming `d/f`. Probe prints `readonly` and
   `path=<repo>/sub/d/f` (observed by hand on the same state). Other cause: any
   join onto a place other than `<repo>`; the fixture makes the `.git` entry
   explicit and `d/f` exists only at the top, so only the join decides.
2. Create-directory-at line naming `d/n`; `<repo>/d` exists, `d/n` does not.
   Observed by hand: `readonly`, `path=<repo>/sub/d/n`. Same alternatives. The
   create shape also checks the parent rule: `writable` needs `<repo>/d`.
3. Real `git worktree add` at `main/wt` (`[ -f "$wt/.git" ]` asserted), cwd
   `wt/sub`, `d/f` present under both `wt` and `main`, so a join onto the
   outermost `.git` ancestor fails too. A git failure in setup would error
   before the assertion (git is not under `run`), not at it.
4. The slice 1 case with `make_bsd_stubs grep sed` first on `PATH`. Red on the
   same value; status 0 and empty stderr precede it, so a stub rejection
   (stderr, `nopath`) is excluded. Green must also pass through the stubs.

Green on the unchanged lib (behaviour present), mutation proof below:

5. `a cp refusal naming a relative path still joins onto the cwd`: cut cp
   fixture with `'d/f'`, cwd `<repo>/sub`, `d/f` present under both `sub` and
   the top; expects `path=<repo>/sub/d/f`.
6. `a partial-checkout line elsewhere in the text does not move a cp refusal's
   join`: an addition beyond the outline's two regressions, pinning section
   B's "for that line alone": the cp line is first, an unlink-old line for
   `d/g` follows.
7. `a partial-checkout path with no .git above the cwd joins onto the cwd`:
   `assert_no_git_above` as precondition; expects `path=<plain>/sub/d/f`.

## Item 3.1 — `tests/verdicts.bats`

Against the unchanged text, 9 pass and 2 fail:

```
not ok 3 verdict text matches detectors.md
#   `[ "$line1" = "$chardev_para" ]' failed                  (line 61)
not ok 4 phantom-untracked opens without naming a location
#   `[ "${line1:0:${#opening}}" = "$opening" ]' failed       (line 86)
```

- Test 3 (existing): `chardev_para` now holds the new whole paragraph
  ("...are sandbox masks, not files in the repository. Leave them out ... show
  the real tree."). The lib still says "masks over dotfiles in the project
  root". Other cause: any character difference in the paragraph; the expected
  string differs from the old only by the removed clause. Its untracked
  assertions further down are hidden behind this first red, which is why the
  separate test exists.
- Test 4 (new): line 1 of `phantom_untracked` starts with "The dotfile entries
  in this listing are sandbox masks, not files in the repository.", is
  followed by a space, and contains no "project root". Red at the prefix
  comparison. Other cause: any wording drift in the opener (the prefix is
  exact). The two later assertions are unreached in the red, so they get
  mutation proofs below.
- Length: the existing `verdicts under 400 chars` loop asserts
  `${#line1} -lt 400` for every row, both phantom paragraphs included (current
  288 and 374; the new text is shorter). It passes before and after, so no
  second length assertion was added.

## Mutation proof

Helper: a Python script that checks the old string occurs exactly once, then
replaces it; restore applies the same pair swapped. Each landing was shown by
`command grep`; each restore was proved by `command grep -c` returning 0 on
the mutation text and the suite returning to its baseline (resolve file: 3
passed, 4 failed; verdicts: 9 passed, 2 failed).

The once-occurring string in `lib/probes-readonly.sh` is
`path=$(_probe_readonly_resolve "$path" "$cwd")`. Replacements:

- Case 5, reds with the eager walk for every producer:
  `path=$(_probe_readonly_resolve "$path" "$(_readonly_git_dir "$cwd" || printf %s "$cwd")")`.
  Result: 5 passed, 2 failed. Case 5 red at
  `[ "$(path_line)" = "path=$repo/sub/d/f" ]` (line 127), case 6 red at the
  same assertion (line 145). Cases 1-4 and 7 green.
- Case 6, reds with the rule reading the whole text rather than the matching
  line: `path=$(_probe_readonly_resolve "$path" "$(if
  _readonly_partial_checkout_text "$text"; then _readonly_git_dir "$cwd" ||
  printf %s "$cwd"; else printf %s "$cwd"; fi)")` (one line in the file).
  Result: 6 passed, 1 failed; only case 6 red, line 145. Case 5 stays green
  (its text holds no partial-checkout line), which is why 5 and 6 need
  different mutations.
- Case 7, reds with a wrong fallback when no `.git` exists: the same as the
  case 6 replacement but gated on the matching line,
  `_readonly_partial_checkout_text "$(printf '%s\n' "$text" | _readonly_path_line)"`,
  and `|| printf %s /` as the fallback. Result: 6 passed, 1 failed; only case
  7 red at `[ "$(path_line)" = "path=$plain/sub/d/f" ]` (line 162). Under this
  mutation cases 1-4 turn green, so the tests are satisfiable by a correct
  implementation.
- Verdicts test 4, "project root" assertion, in `lib/verdicts.sh`: the
  untracked opener replaced by "The dotfile entries in this listing are
  sandbox masks, not files in the repository. They sit in the project root."
  (the old opener, unique in the file, is the replaced string). Test 4 red at
  `*'project root'*) return 1 ;;` (line 89), past the prefix assertion.
- Verdicts test 4, space-after-opener assertion: opener replaced by "The
  dotfile entries in this listing are sandbox masks, not files in the
  repository.Leave". Test 4 red at
  `[ "${line1:${#opening}:1}" = ' ' ]` (line 87).

## Notes for GREEN

- Case 3 builds a worktree inside the main checkout, so the walk meets the
  worktree's `.git` file before the main repository's `.git` directory.
- `docs/references/detectors.md` and `hook.md` still carry the old phantom
  wording; the docs side of section C is outside this dispatch. Test 3's name
  ("matches detectors.md") will name a doc that disagrees until that edit.
