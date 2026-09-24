# Item 2.2 slice 6 — RED

Scope: `tests/check-links-edges.bats` only. `scripts/` is byte-identical to
HEAD (`git diff --quiet scripts/` after every mutation below). All behaviour
under test already exists (slices 2 and 4's code reviews fixed each of it);
this slice adds the tests slices 2 and 4 deferred, per their Test gaps
sections, plus the item's BSD case. Five tests added, all green against the
unmodified SUT.

Environment checked before writing the merge fixture
([[git-hook-env-leak]]): `GIT_CONFIG_KEY_0`/`_1` inject `safe.directory`
entries scoped to this repo's own path and glob, not the fixture's; no
`GIT_INDEX_FILE`, `GIT_DIR`, `GIT_WORK_TREE` or `GIT_COMMON_DIR` is set;
`commit.gpgsign` and `tag.gpgsign` are both unset. None of it reaches a
`git -C <fixture>` call in a way that matters.

## Tests added

- `tracked symlink is skipped`
- `bare-name invocation`
- `missing helper exits 2` (two sub-cases in one test: no `lib/` at all, and
  `lib/tracked.sh` present without `lib/strip-code.awk`)
- `unmerged path walked once`
- `broken link survives BSD grep and mktemp`

## Mutation proof

Each mutation below was applied with Edit, run against the named test (or
the whole suite where stated), confirmed red on the stated assertion, then
reverted with the inverse Edit. `git diff --quiet scripts/` confirmed clean
after every revert; the final one is reconfirmed in Checks run.

1. **`tracked symlink is skipped`** — `scripts/lib/tracked.sh`:
   `if [ -L "$root/$file" ] || [ ! -f "$root/$file" ]; then` →
   `if [ ! -f "$root/$file" ]; then`. Red: `[ "$output" =
   "broken-link: docs/sentinel.md -> missing.md" ]` fails (line 183) — the
   walk now follows the symlink and reports its target's broken link under
   `docs/l.md` too.

2. **`bare-name invocation`** — `scripts/check-links.sh`: the slash-aware
   `case "${BASH_SOURCE[0]}" in */*) … ;; *) LIB_DIR=lib ;; esac` →
   unconditional `LIB_DIR="${BASH_SOURCE[0]%/*}/lib"` (the pre-slice-2
   shape). Red: `[ "$status" -eq 1 ]` fails (line 197) — from `scripts/`,
   `${BASH_SOURCE[0]}` is the slash-less `check-links.sh`, `%/*` leaves it
   whole, and the script sources `check-links.sh/lib/tracked.sh` and exits 2.

3. **`missing helper exits 2`**, sub-case "no `lib/` at all` —
   `scripts/check-links.sh`: `source "$LIB_DIR/tracked.sh" || exit 2` →
   `source "$LIB_DIR/tracked.sh"`. Red: `[ "$status" -eq 2 ]` fails (line
   214) — a failed `source` returns 1, and without the `|| exit 2` guard
   `set -e` surfaces that 1 instead.

4. **`missing helper exits 2`**, sub-case "`lib/` without
   `strip-code.awk`" — `scripts/check-links.sh`:
   `if [ ! -r "$LIB_DIR/strip-code.awk" ]; then` →
   `if [ ! -r "$LIB_DIR/strip-code.awk" ] && false; then`. Red: `[ "$stderr"
   = "check-links: cannot read $copy/lib/strip-code.awk" ]` fails (line 227)
   — without the guard, `awk -f` on the missing file fails inside the piped
   capture, and the script's own diagnostic instead names the markdown file
   (`docs/a.md`) it was scanning, not the missing awk lib; status and empty
   stdout alone do not catch this, which is why the test also pins stderr.

5. **`unmerged path walked once`** — `scripts/lib/tracked.sh`:
   `if [ "$file" = "$prev" ]; then` → `if [ "$file" = "$prev" ] && false;
   then`. Red: `[ "$output" = "broken-link: docs/a.md -> missing.md" ]`
   fails (line 262) — three identical `broken-link: docs/a.md ->
   missing.md` lines instead of one, confirmed with `--verbose-run`; the
   merge itself still conflicts as built ("CONFLICT (content): Merge
   conflict in docs/a.md"), so the fixture reaches the real unmerged-stages
   case rather than failing before it.

6. **`broken link survives BSD grep and mktemp`** — `scripts/check-links.sh`:
   `grep -aoE -e '\]\([^)]*\)'` → `grep -aoP -e '\]\([^)]*\)'`. This is not
   a bare smoke run: `-P` behaves identically to `-E` under GNU grep for
   this pattern (verified: byte-identical extraction on a two-line probe),
   so the mutation is silent everywhere else — `scripts/run-bats.sh
   tests/check-links.bats tests/check-links-edges.bats` gave **21 passed, 1
   failed** with only this test red, on `[ "$status" -eq 1 ]` (line 280;
   `check-links: cannot read docs/a.md` on stderr, status 2). Only the BSD
   grep stub, which refuses any argument matching `-*P*` as a GNU-only
   flag, catches it. No mutation of the script's one `mktemp` call (the
   walk-list temp file, template ending in `XXXXXX`) reaches a stub refusal
   within a single run, per the `check-line-limits.bats` precedent
   (`item-2-1-s5-test-review.md`'s BSD case: a refusal needs the literal
   path to already exist, which one run's trap-cleaned `mktemp` never
   leaves behind) — re-confirmed by inspection rather than re-run, since
   the mechanism is identical and already established for this repo's sole
   `mktemp` call site (`scripts/lib/tracked.sh`, shared by both gate
   scripts).

## Checks run (foreground, final state)

- `scripts/run-bats.sh tests/check-links.bats tests/check-links-edges.bats`:
  `bats: 22 passed, 0 failed`.
- `scripts/run-bats.sh tests/`: `bats: 65 passed, 0 failed`.
- `shellcheck tests/check-links-edges.bats`: exit 0.
- `git diff --quiet scripts/`: clean — `scripts/` is byte-identical to HEAD.
- `git status --porcelain --untracked-files=all -- scripts/ tests/
  plans/sandbox-lies/reports/`: only `tests/check-links-edges.bats`
  modified.
- `wc -l tests/check-links-edges.bats`: 282 lines, under the 400 cap.

## Scope note

The item's `precommit` wiring (GREEN) and the implementation are out of
scope for this dispatch, per instructions; nothing here touches
`justfile` or the SUT.
