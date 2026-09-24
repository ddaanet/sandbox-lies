# Item 2.1 slice 2: test review

Scope: the new test `SKILL.md capped at 200` in
`tests/check-line-limits.bats` and the RED report. The SUT is committed and
was probed in place (see below), then restored. Nothing committed.

## Mechanical check (before fixes)

`scripts/run-bats.sh tests/check-line-limits.bats`, foreground: 2 passed,
1 failed. The new test failed on `[ "$status" -eq 1 ]` (actual 0, since the
SUT scopes only `docs/*.md`). That is an assertion failure, not an error.
Slice 1's two tests passed.

## Wrong-reason hunt

State of the world the test is meant to fail in: a tracked 201-line
`skills/<name>/SKILL.md` that is not reported with cap 200.

I probed by adding `case` arms to the SUT's walk loop, each tagged
`# PROBE-MUTANT`, and ran the suite after each one.

| probe | arms added after `docs/*.md` | original test | fixed test |
|---|---|---|---|
| B: 200 cap on all of skills/ markdown | `skills/*.md` → 200 | **pass** | red (output) |
| A: intended shape | `skills/*/SKILL.md` → 200, then `skills/*.md` → 400 | pass | pass |
| C: arms swapped | `skills/*.md` → 400 first, so it shadows SKILL.md | red (status) | red (status) |

### Findings

1. **The test did not pin the cap to SKILL.md specifically (major).** The
   fixture held only `skills/x/SKILL.md`, so a 200 cap applied to every
   markdown file under `skills/` produced exactly the expected line and
   passed (probe B). The item caps SKILL.md at 200 and other `skills/`
   markdown at 400, so B is the plausible wrong implementation.
   **Fix:** the same fixture now also tracks a 201-line
   `skills/x/references/n.md`. The existing exact single-line `$output`
   assertion now requires that file to stay clean, so B prints a second
   line and fails. I used 201 lines rather than 400 so that the node differs
   from SKILL.md only in its path, which is the trigger input. The node's own
   400 boundary belongs to whichever test owns non-SKILL `skills/` markdown
   (see below).
2. **The comment misdescribed the 201-cap case (minor).** It said a 199 or
   201 cap "would still flag the file but print the wrong number". A 201 cap
   does not flag a 201-line file, because 201 > 201 is false: that case fails
   on status, not on the number. **Fix:** the comment is reworded.

### Checked and sound

- **One exact-output assertion is enough, once the fixture has a sibling.**
  Exact `$output` equality under `--separate-stderr` pins the cap value (199
  prints `> 199`; 201 and 400 leave the file clean), the stream, the path
  form, and after fix 1 the absence of a second line.
- **Comparison operator:** `-gt` versus `-ge` is shared through `check_cap`,
  and slice 1's 400-line clean test already pins it. A separate SKILL.md
  comparison would escape that. I did not add a 200-line clean SKILL.md,
  because the slice states only the overage case.
- **Tracking:** both files are `git add`ed into their own `git init` root.
  The test name is unique in the file.

### Observations outside this slice (not fixed)

- **Non-SKILL `skills/` markdown at 400 has no test in slices 1–6.** Slice 3
  covers scripts, `plans/`, untracked and deleted files. The scope sentence
  names `skills/` markdown, but no slice asserts that a 401-line references
  node is reported. An implementation with only a `skills/*/SKILL.md` arm
  passes the whole planned suite. Root `/*.md` is likewise untested. A test
  like `oversized skills node is reported` (401-line
  `skills/x/references/n.md` → `> 400`) would close the first gap.
- **Depth of the SKILL.md pattern:** `skills/*/SKILL.md` in a bash `case`
  also matches `skills/a/b/SKILL.md`, because `*` crosses `/`. That is
  harmless unless nested SKILL.md files are meant to be capped at 400.

## SUT restore

Each probe was an exact-string edit, and I restored the SUT by applying the
inverse edit. Proof: `grep -c PROBE-MUTANT scripts/check-line-limits.sh` →
`0`, and `git diff --quiet scripts/check-line-limits.sh` succeeded, so the
file is byte-identical to HEAD. During probe C, shellcheck's SC2221/SC2222
warnings were about the deliberately shadowed probe arm. They cleared on
restore.

## Final red run

`scripts/run-bats.sh tests/check-line-limits.bats`, foreground, exit 1:

```
not ok 3 SKILL.md capped at 200
# (in test file tests/check-line-limits.bats, line 70)
#   `[ "$status" -eq 1 ]' failed

bats: 2 passed, 1 failed
```

`shellcheck tests/check-line-limits.bats` is clean.
