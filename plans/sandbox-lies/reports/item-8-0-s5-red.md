# Item 8.0/5 RED report — the no-target merge clause needs git's error

Slice: `runbook.md` Item 8.0 entry 5. Scope: `tests/probes-readonly-facts.bats`,
`tests/verdicts-readonly.bats`, `tests/hook-candidates.bats`. No `lib/` or
`hooks/` change survives this dispatch except the restored mutation proof
below.

## New tests written

### tests/probes-readonly-facts.bats

- Added builder `partial_checkout_mkdir_error` (git's third partial-checkout
  needle, `fatal: cannot create directory at '<dir>': <erofs message>`, built
  from two fragments around `erofs_message` like the two existing builders —
  no source line holds the phrase whole).
- New test `partial=1 fires with merge=1 for each of git's three
  partial-checkout errors, not for another tool's refusal`: three positive
  cases (unlink/create/mkdir needles under a non-merge command, `just sync`,
  asserting both `merge=1` and `partial=1`), then a negative control (a
  merge-style command, `git merge feat`, whose text holds only another
  tool's refusal — `merge=1` fires from the command shape, `partial=1` does
  not).
  - Failing output against unchanged code: fails at the first `partial=1`
    assertion (the unlink-needle case) —
    `` printf '%s\n' "$output" | grep -qxF 'partial=1' `` failed. The
    unchanged probe never prints `partial=1` at all, so every positive case
    fails there; the mkdir-needle case would also fail its `merge=1`
    assertion, since unchanged code's partial-checkout recognizer has only
    two needles.

### tests/verdicts-readonly.bats

- New test `readonly-path merge alone with no partial=1 states the act
  alone, capitalised`: positive control (`merge=1 partial=1` → the
  restore-them clause, already true on unchanged code) first, then the
  negative (`merge=1` alone, no `partial=1` → identical to the no-facts
  baseline, `restore` absent).
  - Failing output against unchanged code: fails at
    `` [ "$line1" = "$baseline1" ] `` (line 133) — unchanged code still
    composes the restore-them clause for `merge=1` alone, so `line1` differs
    from the no-facts baseline.
- New test `readonly-path merge with target, partial=1 and no match still
  states the act alone`: `merge=1 partial=1 target=main`, no `match=` → no
  clause. This already holds on unchanged code (the target branch decides
  the no-clause case regardless of `partial=1`); see Mutation proof below.

### tests/hook-candidates.bats

- New test `the no-target merge clause needs git's own partial-checkout
  error, not any refused write`: through the hook with the **real probe**
  (not stubbed), positive control first — the cut
  `fire-readonly-path-git-mkdir` fixture under its recorded command
  (`git -C /tmp/sl8c-wt checkout feat2 2>&1`, cwd overridden to
  `$BATS_TEST_TMPDIR` so the fixture's relative quoted path reads writable)
  — carries `restore them from HEAD`; then the negative — the cut
  `fire-readonly-path-git-config-busy` fixture under its recorded command (a
  checkout, then a refused config write, cwd likewise overridden) — carries
  no `restore`.
  - Failing output against unchanged code: fails at
    `` run ! grep -qF 'restore' <<<"$ctx" `` (line 198), "expected nonzero
    exit code" — unchanged code composes the restore-them clause for the
    config-busy case too (its recorded command's `checkout` segment gives
    `merge=1` with no target, and unchanged code restores unconditionally in
    that shape).

## Existing tests edited (kept green under unchanged code)

Each feeds `merge=1` with no `target=` and expected the restore clause under
the old spec; the new spec needs `partial=1` alongside it, so each gets that
fact added — all still pass against unchanged code, since it ignores
`partial=1` entirely and restores on `merge=1` alone regardless.

- `tests/verdicts-readonly.bats`: `readonly-path merge alone restores the
  written files then acts` — `partial=1` added to its stdin facts.
- `tests/verdicts-readonly.bats`: `readonly-path merge clause leads
  lowercase into whichever act the facts select` — `partial=1` added to its
  first sub-case (`merge=1 readfile=...`, no target); its other sub-cases
  (`target=`+`match=`) are unaffected, per "match= lines keep their clause
  without partial=1".
- `tests/verdicts-readonly.bats`: `readonly-path compositions drop the old
  tail wording and remove nothing` — `partial=1` added to the merge-alone
  composition in its combined text, since without it the "restore them from
  HEAD" grep this test relies on would no longer be produced by any
  composition once GREEN lands.
- `tests/hook-candidates.bats`: `writable outcome through the hook` —
  `partial=1` added to the stubbed probe's fact lines alongside `merge=1`.

Already-covered item, no new test added: "`match=` lines keep their clause
without `partial=1`" is covered by the existing
`readonly-path merge with target and match restores the named files then
acts` test (unchanged, still feeds `merge=1 target=main match=a match=b`
with no `partial=1` and expects the match-list clause).

## Mutation proof

- Test: `readonly-path merge with target, partial=1 and no match still
  states the act alone` (`tests/verdicts-readonly.bats`).
- Mutation: `lib/verdicts.sh`, the target-branch guard in
  `verdict_readonly_path` — `if [ -n "$target" ]; then` → `if [ -z "$target"
  ]; then` (unique string in the file, occurs once).
- Reran `tests/verdicts-readonly.bats` filtered to that test: reds on its
  own assertion — `` [ "$line1" = "$baseline1" ] `` failed — since the
  mutated branch now takes the unconditional restore-them path for a
  `target=`-bearing composition.
- Restored by swapping the two strings back (`if [ -z "$target" ]; then` →
  `if [ -n "$target" ]; then`).
- Verified: `grep -n 'if \[ -z "\$target" \]; then' lib/verdicts.sh` — no
  hit (exit 1). Then reran `tests/verdicts-readonly.bats`,
  `tests/hook-candidates.bats`, `tests/probes-readonly-facts.bats`,
  `tests/verdicts.bats`, `tests/verdicts-locks.bats`,
  `tests/probes-readonly.bats`, `tests/probes-readonly-pins.bats`,
  `tests/hook-locks.bats` together: 90 passed, 3 failed — exactly the three
  new-behaviour tests above (this slice's own reds), everything else green,
  confirming the restore and that no other test was disturbed.

## Verification

- `scripts/run-bats.sh tests/probes-readonly-facts.bats` — 14 passed, 1
  failed (the new partial=1 test).
- `scripts/run-bats.sh tests/verdicts-readonly.bats` — 13 passed initially
  (before the guard test's mutation proof), 14 passed / 1 failed after
  adding the negative test (the new negative-behaviour test), the guard test
  passing green as expected.
- `scripts/run-bats.sh tests/hook-candidates.bats` — 9 passed, 1 failed (the
  new hook test).
- Combined run of all eight readonly/lock-adjacent suites named above: 90
  passed, 3 failed (the three new-behaviour tests only).
- `git status --short` / `git diff --stat`: only the three test files
  changed; `lib/verdicts.sh` shows no diff, confirming the mutation was
  fully restored.

No commit made. Tests and this report are left uncommitted for the slice's
GREEN dispatch to carry.
