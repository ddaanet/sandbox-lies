# Item 2.1 slice 3 — RED

Three tests added to `tests/check-line-limits.bats`, names exactly as the
slice states them: `oversized skills node is reported`, `oversized root
markdown is reported`, `markdown elsewhere is out of scope`.

Each fixture is built to discriminate the boundary the runbook's slice-3
line names, not just to hit the literal numbers:

- **`oversized skills node is reported`**: `skills/x/references/n.md` at 401
  lines (over the 400 cap) sits beside a sibling `o.md` at 201 lines — over
  SKILL.md's 200 cap but under 400. `o.md` staying clean is the boundary
  that tells 400 from 200 for this node: a wrong implementation that caps
  all `skills/` markdown at 200 (slice 2's test-review named this as the
  plausible wrong shape) would flag `o.md` too and break the exact
  single-line `$output` assertion.
- **`oversized root markdown is reported`**: `README.md` at 401 lines sits
  beside `notes/deep.md`, the same 401 lines one directory down. `deep.md`
  staying clean is the root-only-vs-crossing-`/` boundary: an unanchored
  `*.md` arm, or one written to cross directories, would flag it too and
  break the same exact-output assertion.
- **`markdown elsewhere is out of scope`**: `lib/x.md` at 401 lines and
  `.claude/skills/y/SKILL.md` at 201 lines, both asserted clean (status 0,
  empty stdout/stderr) in one fixture — the two files the slice names
  verbatim.

## Red run

`scripts/run-bats.sh tests/check-line-limits.bats`:

```
1..6
ok 1 clean tree exits 0 silently
ok 2 oversized markdown is reported
ok 3 SKILL.md capped at 200
not ok 4 oversized skills node is reported
# (in test file tests/check-line-limits.bats, line 88)
#   `[ "$status" -eq 1 ]' failed
not ok 5 oversized root markdown is reported
# (in test file tests/check-line-limits.bats, line 105)
#   `[ "$status" -eq 1 ]' failed
ok 6 markdown elsewhere is out of scope

bats: 4 passed, 2 failed
```

Tests 4 and 5 fail on their first assertion (`[ "$status" -eq 1 ]`, actual
`0`): the current SUT's `case` has only `docs/*.md → 400` and
`skills/*/SKILL.md → 200`, so neither `skills/x/references/n.md` nor
`README.md` matches any arm and both fixtures read as clean — a real gap,
not a quiet-pass risk. Test 6 passes against the unchanged SUT as expected
(it caps neither `lib/` nor a non-root `skills/`), so its coverage is proven
by mutation below rather than by assertion failure.

## Mutation proof (`markdown elsewhere is out of scope`)

The test pins two behaviours, so two exact-string mutations, each shown red
on its assertion and then restored by the inverse edit.

**1. SKILL.md arm's `skills/` anchor.** Mutated line 74 from
`    skills/*/SKILL.md) check_cap "$file" 200 ;;` to
`    *SKILL.md) check_cap "$file" 200 ;;` (drops the anchor, so
`.claude/skills/y/SKILL.md` now matches). Ran
`scripts/run-bats.sh tests/check-line-limits.bats -f "markdown elsewhere is out of scope"`:

```
not ok 1 markdown elsewhere is out of scope
# (in test file tests/check-line-limits.bats, line 121)
#   `[ "$status" -eq 0 ]' failed
```

Restored by the inverse replacement. Proof:
`grep -c -F '*SKILL.md) check_cap' scripts/check-line-limits.sh` → `0`;
`grep -c -F 'skills/*/SKILL.md) check_cap' scripts/check-line-limits.sh` →
`1`; `git diff --quiet scripts/check-line-limits.sh` → byte-identical to
HEAD.

**2. `lib/x.md` out of scope.** Mutated line 73 from
`    docs/*.md) check_cap "$file" 400 ;;` to
`    *.md) check_cap "$file" 400 ;;` (widens the docs/ arm to any markdown,
so `lib/x.md` now matches). Ran the same filtered command:

```
not ok 1 markdown elsewhere is out of scope
# (in test file tests/check-line-limits.bats, line 121)
#   `[ "$status" -eq 0 ]' failed
```

Restored by the inverse replacement. Proof:
`grep -c -F '    *.md) check_cap' scripts/check-line-limits.sh` → `0`
(line-anchored on the leading indent, so it doesn't match the restored
`docs/*.md` line as a substring);
`grep -c -F '    docs/*.md) check_cap' scripts/check-line-limits.sh` → `1`;
`git diff --quiet scripts/check-line-limits.sh` → byte-identical to HEAD.

Both mutations transiently tripped shellcheck SC2221/SC2222 (shadowed/
shadowing `case` arms), expected of a deliberate order-breaking probe; clean
again after each restore.

## Final state

`scripts/run-bats.sh tests/check-line-limits.bats` (foreground, current
state): 4 passed, 2 failed (tests 4 and 5, as above — genuine red, no
mutation fallback needed for those two).

`shellcheck tests/check-line-limits.bats`: clean.

`git diff --quiet scripts/check-line-limits.sh`: byte-identical to HEAD —
the SUT was touched only for the two mutation probes above, each restored
immediately after its run.

`git status --porcelain -- scripts/ tests/`: only `tests/check-line-limits.bats`
modified. Nothing committed.

## Files changed

- `tests/check-line-limits.bats` (three new tests, uncommitted)
