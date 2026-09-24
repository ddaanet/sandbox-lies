# Item 2.1 slice 4: RED

Scope: add the six slice-4 tests to `tests/check-line-limits.bats` — no SUT
change except the mutation proofs below, each applied and reverted. Test names
exactly as the runbook/dispatch quote them.

## Tests added

1. `oversized script is reported` — a 401-line `lib/x.bash`, `lib/x.bats`,
   `lib/x.py` and `lib/x.sh`, asserting all four `oversized-file:` lines in
   `git ls-files` bytewise order (`.bash` < `.bats` < `.py` < `.sh`).
2. `plans/ is out of scope` — 401-line `plans/x.md` and `plans/x.sh`, status 0.
3. `plugin-dev/ is out of scope` — 401-line `plugin-dev/x.sh`, status 0.
4. `markdown directly under skills/` — 401-line `skills/top.md`, status 1,
   `oversized-file: skills/top.md: 401 lines > 400`.
5. `untracked file is out of scope` — 401-line `docs/u.md`, never `git add`ed,
   status 0.
6. `deleted tracked file is skipped` — 401-line `docs/gone.md` added then
   `rm`ed from the work tree only (stays in the index), status 0.

## Evidence

### Genuine red

`scripts/run-bats.sh tests/check-line-limits.bats`:

```
not ok 7 oversized script is reported
# (in test file tests/check-line-limits.bats, line 148)
#   `[ "$status" -eq 1 ]' failed

bats: 11 passed, 1 failed
```

No script arm exists in the SUT yet, so `oversized script is reported` fails
for real: status is 0 (all four files fall through the `case` uncounted)
against the asserted 1. The other five pass now — vacuously (no script arm
exists to violate the `plans/`/`plugin-dev/` exclusions; the `skills/*.md`,
`git ls-files`-only walk, and `check_cap`'s `[ ! -f … ]` guard already do the
right thing per slice 3's review). Each of those five is proven load-bearing
by mutation below, per dispatch.

### Mutation proof

Each mutation is an exact-string `Edit` on `scripts/check-line-limits.sh`,
run with `scripts/run-bats.sh tests/check-line-limits.bats -f "<name>"`, then
reverted by the inverse edit. Restore proof after each: `grep -c -F` for the
mutation text (0 hits) and `git diff --quiet scripts/check-line-limits.sh`
(clean). A `cmp` against a pre-mutation copy of the file, taken before any
mutation, also matched at the end of the run.

**1. `plans/ is out of scope` and `plugin-dev/ is out of scope`** — inserted
`    *.sh) check_cap "$file" 400 ;;` as the case's first arm (before
`docs/*.md`):

```
not ok 1 plans/ is out of scope
#   `[ "$status" -eq 0 ]' failed
not ok 1 plugin-dev/ is out of scope
#   `[ "$status" -eq 0 ]' failed
```

Both red under the unexcluded `*.sh` arm. Reverted; `grep -c -F '*.sh) check_cap "$file" 400 ;;'` → 0; `git diff --quiet` clean.

**2. `markdown directly under skills/`** — narrowed
`skills/*.md) check_cap "$file" 400 ;;` to `skills/*/*.md) check_cap "$file" 400 ;;`:

```
not ok 1 markdown directly under skills/
#   `[ "$status" -eq 1 ]' failed
```

Red: `skills/top.md` no longer matches a pattern requiring a subdirectory.
Reverted; `grep -c -F 'skills/*/*.md) check_cap'` → 0; `git diff --quiet`
clean.

**3. `untracked file is out of scope`** — changed
`git -C "$ROOT" ls-files -z` to `git -C "$ROOT" ls-files -z --others`:

```
not ok 1 untracked file is out of scope
#   `[ "$status" -eq 0 ]' failed
```

Red: the untracked `docs/u.md` now enters the walk. Reverted; `grep -c -F
'ls-files -z --others'` → 0; `git diff --quiet` clean.

**4. `deleted tracked file is skipped`** — removed the regular-file half of
the skip guard, `if [ -L "$ROOT/$file" ] || [ ! -f "$ROOT/$file" ]; then`
narrowed to `if [ -L "$ROOT/$file" ]; then`:

```
not ok 1 deleted tracked file is skipped
#   `[ "$status" -eq 0 ]' failed
```

Red: without the `! -f` guard, `check_cap` runs `awk` against the missing
`docs/gone.md` and the run no longer exits 0. Reverted; `git diff --quiet`
clean; final `cmp` against the pre-mutation copy of the file matched
(identical).

## Verification

- `scripts/run-bats.sh tests/check-line-limits.bats` (foreground, final
  state): `bats: 11 passed, 1 failed` — the one failure is
  `oversized script is reported`, the intended red.
- `git status --porcelain scripts/check-line-limits.sh` → empty (byte-identical
  to HEAD).
- `git diff --stat` → `tests/check-line-limits.bats | 90 ++++...`, no other
  file touched.

## Files changed

- `tests/check-line-limits.bats` (six tests added). Uncommitted, as required
  for RED.

## Done

RED complete. SUT untouched from HEAD. Nothing committed.
