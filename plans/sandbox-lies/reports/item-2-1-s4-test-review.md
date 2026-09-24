# Item 2.1 slice 4: test review

Scope: the six slice-4 tests in `tests/check-line-limits.bats` (uncommitted
diff) and `item-2-1-s4-red.md`. The SUT was mutated in place only, and each
mutation was reverted by the inverse exact-string replacement. Nothing is
committed.

## Verdict

Four plausible wrong implementations passed the RED fixtures. Fixture
rebuilds now pin all four. `oversized script is reported` is still red on an
assertion, and the other five are each red under a mutation different from
the RED report's.

## Findings (all fixed)

1. **Major: an unanchored exclusion passed.** With
   `*plans/* | *plugin-dev/*) ;;` plus a correct script arm, all 12 tests
   were green. That exclusion drops every script under a nested `plans/` or
   `plugin-dev/` directory. I judged pinning the anchor to be inside the
   slice. The Item's scope and the script's header both use root-relative
   paths, and slice 3 pinned the `skills/` anchor the same way (with
   `.claude/skills/…`). The fix is two positives, `tools/plans/x.sh` and
   `tools/plugin-dev/x.sh`, added to `oversized script is reported`. I put
   them there and not in the exclusion tests so that those tests keep the
   slice's stated observable (status 0).
2. **Major: a directory-list script arm passed.** The port source walks
   `for dir in src tests`, so an arm like `lib/*.sh | … | scripts/*.sh |
   tests/*.bats | hooks/*.sh` is a plausible port. It passed because every
   positive fixture sat under `lib/`. The fix places the new positives under
   `tools/`, which the real tree lacks. It also adds a root-level `x.sh`.
3. **Major: a subdirectory-only arm passed.** `*/*.sh | */*.bash | …` copies
   the shape of the `*/*.md` skip and never counts a root-level script. The
   fixed fixture's root-level `x.sh` pins it.
4. **Major: a narrowed exclusion passed.** With
   `plans/*.sh | plans/*.md | plugin-dev/*.sh) ;;`, `plans/ is out of scope`
   and `plugin-dev/ is out of scope` stayed green, because `.sh` was the only
   script type either fixture held. Both fixtures now hold all four types
   (`x.bash`, `x.bats`, `x.py`, `x.sh`). `plans/` keeps its `x.md`. The
   comment in `oversized script is reported` now covers the new files.

## Confirmed harmless or already pinned

- The exclusion covers `plans/` only, or `plugin-dev/` only: the other
  directory's test goes red on `[ "$status" -eq 0 ]`. This held before and
  after the fixes.
- The exclusion is placed after the script arm: both exclusion tests go red.
- The script arm is placed below the `*/*.md) ;;` skip, or even below the
  root `*.md)` arm: 12/12 green, both as one arm (V0) and split across two
  positions (`.sh/.bash` first, `.bats/.py` last, V9). This is harmless as
  the lead expected, because the skip only matches `.md`. Putting the arm
  first (V5) is also green.

## Mutation reproductions

Each run applied the mutation, ran the full file, then inverted the
replacements in reverse order. Each run ended with `git diff --quiet
scripts/check-line-limits.sh` exiting 0. The runner refuses to start on a
dirty SUT. V0 is the reference implementation: `plans/* | plugin-dev/*) ;;`
first, and `*.sh | *.bash | *.bats | *.py) check_cap "$file" 400 ;;` last.

These are the mutations for the five non-red tests. Each is different from
the one the RED report used:

| Test | My mutation | Result |
|---|---|---|
| `plans/ is out of scope` | V2: exclusion lists only `plugin-dev/*` | red, `[ "$status" -eq 0 ]` |
| `plugin-dev/ is out of scope` | V1: exclusion lists only `plans/*` | red, `[ "$status" -eq 0 ]` |
| `markdown directly under skills/` | the `skills/*.md` arm deleted | red, `[ "$status" -eq 1 ]` (plus `oversized skills node is reported`, which shares the arm) |
| `untracked file is out of scope` | `ls-files -z` → `ls-files -z --cached --others` | red, `[ "$status" -eq 0 ]` |
| `deleted tracked file is skipped` | `[ ! -f "$ROOT/$file" ]` → `[ -d "$ROOT/$file" ]` (skips gitlinks only) | red, `[ "$status" -eq 0 ]` |

In every one of these runs, `oversized script is reported` was also red,
because none of those mutations adds a script arm.

The wrong implementations against the fixed fixtures:

| Variant | Before fix | After fix |
|---|---|---|
| V3 unanchored exclusion | 12/12 green | red, test 7 exact-output assertion |
| V6 exclusion narrowed to `.sh`/`.md` | 12/12 green | red, tests 8 and 9 on status |
| V10 exclusion missing `.py` | (not run) | red, tests 8 and 9 on status |
| V7 directory-list arm | 12/12 green | red, test 7 exact-output assertion |
| V8 `*/*.sh` arm | 12/12 green | red, test 7 exact-output assertion |
| V4 exclusion after the arm | red 8, 9 | red 8, 9 |
| V0, V5, V9 (correct layouts) | 12/12 green | 12/12 green |

**Process incident.** The first batch included a deletion mutation (the
skills arm replaced by an empty string). My runner's inverse cannot
re-anchor an empty string, so it aborted with the line still deleted. Every
later variant in that batch then ran against a SUT missing `skills/*.md`.
The first restore check was not clean (`restore: … exit 1`), and a
`git diff` showed the lone missing line. I restored it with the inverse
`Edit` (reinserting the line after the `skills/*/SKILL.md` arm), and
`git diff --quiet` then exited 0. I discarded that whole batch, rewrote the
deletion as an anchored replacement, added the clean-SUT precheck, and
reran everything. Only the reruns are reported above.

## Final red run

`scripts/run-bats.sh tests/check-line-limits.bats`, run in the foreground:

```
not ok 7 oversized script is reported
# (in test file tests/check-line-limits.bats, line 157)
#   `[ "$status" -eq 1 ]' failed

bats: 11 passed, 1 failed
```

- `shellcheck tests/check-line-limits.bats`: clean.
- `git diff --quiet scripts/check-line-limits.sh`: exit 0, so the SUT is
  byte-identical to HEAD.
- `git diff --stat`: only `tests/check-line-limits.bats` (247 lines, under
  its own 400 cap once GREEN scopes `.bats` in).

## Residuals, not pinned

- **Nested exclusion fixtures** (`plans/job/x.sh`): every glob form of the
  exclusion crosses `/`. Only a dirname-equality test would miss a nested
  file, and I judged that implausible.
- **A slashless `plans*` exclusion**, which would also drop `plans.sh` or a
  `plansx/` directory: a typo-class variant, outside the slice's stated
  fixtures.

## Files changed

- `tests/check-line-limits.bats`: the fixtures for `oversized script is
  reported`, `plans/ is out of scope` and `plugin-dev/ is out of scope`
  were extended, with comments.
- The mutation runner was a scratch tool outside the repo, at
  `/tmp/claude-1000/s4-review/mutate.py`.
