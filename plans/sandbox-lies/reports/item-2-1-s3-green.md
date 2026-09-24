# Item 2.1 slice 3 — GREEN

Made the two red tests pass and confirmed the third (`markdown elsewhere is
out of scope`) stayed green, one test at a time.

## Implementation

Extended `scripts/check-line-limits.sh`'s `case` with three arms, in the
order the test review's reference implementation used:

```sh
case "$file" in
docs/*.md) check_cap "$file" 400 ;;
skills/*/SKILL.md) check_cap "$file" 200 ;;
skills/*.md) check_cap "$file" 400 ;;
*/*) ;;
*.md) check_cap "$file" 400 ;;
esac
```

- `skills/*/SKILL.md` (200) stays ahead of `skills/*.md` (400): `case` takes
  the first match, and a SKILL.md also matches the broader `skills/*.md`
  pattern — this is the arity fix the runbook called out ("the existing
  `skills/*/SKILL.md` → 200 arm must keep precedence").
- `skills/*.md` covers any other markdown under root-level `skills/` at any
  depth: `case` pattern matching is string matching, not filesystem globbing,
  so `*` crosses `/` and reaches `skills/x/references/n.md` as well as
  `skills/x/p.md`.
- `*/*) ;;` is a no-op catch for anything else carrying a `/` — markdown
  under any other directory, dotted or not (`.claude/skills/`, `lib/`,
  `notes/`) — so it falls through without reaching the root-only arm.
- `*.md` last catches what's left: a root-level file, since everything with
  a `/` was already consumed by an arm above.

Updated the header's Scope comment to name all four arms (docs/, SKILL.md,
other skills/ markdown, root markdown).

## Test-by-test

1. `oversized skills node is reported` — passed once the `skills/*.md` arm
   landed.
2. `oversized root markdown is reported` — passed once the `*/*` skip +
   `*.md` pair landed.
3. `markdown elsewhere is out of scope` — stayed green throughout; the
   `.claude/skills/…` fixtures never match `skills/*/SKILL.md` or
   `skills/*.md` (both anchored to a root-level `skills/`), and fall into the
   `*/*` skip arm.

## Verification

- `scripts/run-bats.sh tests/check-line-limits.bats`: 6 passed, 0 failed.
- `scripts/run-bats.sh tests/`: 33 passed, 0 failed.
- `scripts/check-line-limits.sh .` against the real tree: exit 0, no output.
- `just precommit` (foreground): `precommit passed: plugin.json, shellcheck,
  bash -n, rumdl, tests`.

## Files changed

- `scripts/check-line-limits.sh` (case arms + header Scope comment)
- `tests/check-line-limits.bats` (slice-3 tests, carried from RED/test-review)
