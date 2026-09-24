# Item 2.1 slice 3: test review

Scope: the three new tests in `tests/check-line-limits.bats`
(`oversized skills node is reported`, `oversized root markdown is
reported`, `markdown elsewhere is out of scope`) and the RED report. I
probed the committed SUT in place and restored it after every probe.
Nothing is committed.

## Mechanical check (before fixes)

`scripts/run-bats.sh tests/check-line-limits.bats`, foreground, exit 1:
4 passed, 2 failed. Test 4 failed on `[ "$status" -eq 1 ]` (line 88) and
test 5 failed on `[ "$status" -eq 1 ]` (line 105). Both are assertion
failures, not errors. Test 6 passed, as the RED report expects.

### Mutation reproductions for test 6

I used different mutations from the RED report's `*SKILL.md` and `*.md`.
Each one is an exact replacement of the two-arm `case` body, tagged
`# PROBE-MUTANT`. The same `python3` call inverted it after the run. It
also asserted a count of 1 for each direction, then checked that
`PROBE-MUTANT` had 0 hits and that `git diff --quiet
scripts/check-line-limits.sh` returned 0.

| behaviour | mutation | test 6 |
|---|---|---|
| SKILL.md arm's `skills/` anchor | `skills/*/SKILL.md` → `*skills/*/SKILL.md` | red, `[ "$status" -eq 0 ]` (line 121) |
| `lib/x.md` stays out | `docs/*.md` → `*/*.md` | red, `[ "$status" -eq 0 ]` (line 121) |

In the first mutation, `.claude/skills/y/SKILL.md` is the only fixture file
the mutated arm reaches. In the second, `.claude/skills/y/SKILL.md` gets 400
and stays clean at 201, so `lib/x.md` is the only file flagged. Both
behaviours are proven, and each red is caused only by the behaviour it
targets. I reran both after the fixes and both are still red on the same
assertion (now at line 130).

## Wrong-reason hunt

Reference implementation used to check the fixtures (it passes 6/6 before
and after the fixes): `docs/*.md` 400, `skills/*/SKILL.md` 200,
`skills/*.md` 400, `*/*)` skip, `*.md` 400. Each wrong implementation below
replaced the arms in the same way and was run against the whole file.

| wrong implementation | before fixes | after fixes |
|---|---|---|
| A. `skills/*.md` 400 above SKILL.md (shadowing) | red: test 3 (status) | red: test 3 |
| B. skills arm unanchored, `*skills/*.md` 400 | **6/6 pass** | red: test 6 |
| C. root arm leaks into dot-dirs, `[!.]*/*)` skip, then `*.md` 400 | **6/6 pass** | red: test 6 |
| D. skills arm narrowed, `skills/*/references/*.md` 400 | **6/6 pass** | red: test 4 (output) |
| E. 200 cap on all `skills/*.md` | red: tests 3, 4 | red: tests 3, 4 |
| F. root arm crosses `/` (no `*/*)` skip) | red: tests 5, 6 | red: tests 5, 6 |

### Findings

1. **An unanchored skills-node arm passed the suite (major).** Test 6's only
   non-root `skills/` file is a 201-line SKILL.md, which is under any
   node's 400 cap. So `*skills/*.md` → 400 (B) left it clean. In the real
   tree that arm would cap vendored `plugin-dev/…/skills/` markdown and
   `.claude/skills/` markdown. **Fix:** test 6 now also tracks a 401-line
   `.claude/skills/y/references/n.md`, which is test 4's positive node
   moved under a dot-directory. The existing status-0 and empty-output
   assertions require it to stay clean.
2. **A root arm that leaks into dot-directories passed the suite (major).**
   Test 5's `notes/deep.md` rules out a root arm that crosses `/` in
   general. It does not rule out one that skips only non-dot
   subdirectories (C), which would flag `.claude/*.md`, and the real tree
   tracks `.claude/handoff-*.md`. **Fix:** the same new
   `.claude/skills/y/references/n.md` also catches C. I reworded test 5's
   comment, which claimed it pinned "files with no `/`". It now says it
   rules out crossing `/`, and points to test 6 for dot-directories.
3. **Test 4's 201-line sibling `o.md` was not load-bearing, and its comment
   overstated it (minor).** The comment said `o.md` "pins the node's cap at
   400, not 200". But n.md's own exact line already does that: under E it
   prints `> 200` and fails on its own (the E row above still goes red
   after `o.md` was removed). The pattern came from slice 2's test 3, where
   the sibling *is* load-bearing because SKILL.md's line says `> 200`. The
   fixture also left D, a node arm narrowed to `references/`, uncaught,
   although scope is "tracked markdown under `skills/`" (rumdl:
   `skills/**/*.md`). **Fix:** I replaced `o.md` with a 401-line
   `skills/x/p.md` at the skill root. Test 4 now expects two exact lines,
   `p.md` first because `git ls-files` sorts bytewise (`p` < `r`). The `>
   400` on n.md's line pins the cap, and p.md's line pins the breadth.

### Checked and sound

- Arm order shadowing SKILL.md (A) is already caught by slice 2's
  `SKILL.md capped at 200`. A slice-3 test does not need to duplicate it.
- A root arm that crosses `/` (F) is caught by test 5 (`notes/deep.md`) and
  by test 6 (`lib/x.md`).
- All three tests use `run --separate-stderr` and exact `$output`
  equality. Their names are unique and match the slice verbatim. Every
  fixture file is `git add`ed into its own `git init` root.

### Residual (not fixed)

- A skills arm that is unanchored *and* sits behind an explicit
  dot-directory skip (`.*) ;;` first, then `*skills/*.md`) would pass test 6
  and still cap `plugin-dev/…/skills/` markdown. That needs two
  coordinated wrongs, so I judged a second fixture not worth adding.
  `plugin-dev/` exclusion belongs to slice 4's scope in any case.

## Final red run (unchanged SUT, fixed tests)

`scripts/run-bats.sh tests/check-line-limits.bats`, foreground, exit 1:

```
not ok 4 oversized skills node is reported
# (in test file tests/check-line-limits.bats, line 88)
#   `[ "$status" -eq 1 ]' failed
not ok 5 oversized root markdown is reported
# (in test file tests/check-line-limits.bats, line 108)
#   `[ "$status" -eq 1 ]' failed

bats: 4 passed, 2 failed
```

`shellcheck tests/check-line-limits.bats`: clean.
`git diff --quiet scripts/check-line-limits.sh`: exit 0, and
`grep -c PROBE-MUTANT` finds 0 hits, so the SUT is byte-identical to HEAD.
`git status -- scripts tests`: only `tests/check-line-limits.bats` is
modified.

## Files changed

- `tests/check-line-limits.bats` (tests 4, 5, 6: fixtures and comments)
