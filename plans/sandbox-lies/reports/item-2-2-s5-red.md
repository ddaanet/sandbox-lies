# Item 2.2 slice 5: RED

Scope: `tests/check-links.bats` only. `scripts/` untouched, byte-identical to
HEAD (verified below, and after every mutation probe). Not committed.

All eight behaviours this slice pins already exist in the SUT (they landed
as fixes in the slice 1, 3 and 4 code reviews), so the ordering supplies no
red: each test is proven by one exact-string mutation, restored by the
inverse replacement, with the restore proven per mutation and once more at
the end.

## Tests added

1. **`linking file with a space`** — `docs/a b.md` holding a broken link
   `[m](missing.md)`. Expects `broken-link: docs/a b.md -> missing.md`,
   status 1.
2. **`deleted tracked file is skipped`** — `docs/gone.md` added then removed
   from the work tree only (stays in the index). Expects status 0, empty
   stdout/stderr.
3. **`unreadable file exits 2`** — `chmod 000` on a tracked `docs/a.md`.
   Expects status 2, empty stdout. Guarded with `skip` when `id -u` is 0
   (root ignores the mode bit, so the fixture can't produce the failure).
4. **`extra argument exits 2`** — as Item 2.1's: a broken-link fixture,
   invoked with `"$dir" "$dir"` (a second, valid-root argument) so only the
   arity check can produce status 2; a check made after the walk would leak
   a `broken-link` line onto stdout instead.
5. **`any URI scheme is skipped`** — `ftp://h/x`, `HTTP://X` (case
   insensitive) and `x:y.md` (RFC 3986 §4.2: a URI with scheme `x`, not a
   path), each ahead of a `sentinel-missing.md` broken link. Expects only
   the sentinel's line, status 1.
6. **`CRLF fence closes`** — a CRLF file (`\r\n` throughout) with a closed
   ` ``` ` fence ahead of a `sentinel-missing.md` broken link. Expects only
   the sentinel's line, status 1.
7. **`code span at line start is not a fence`** — a line
   `` ```x``` text `` (a paragraph opening with a code span, not a fence:
   CommonMark disallows a backtick in a fence's info string), ahead of a
   `sentinel-missing.md` broken link. Expects only the sentinel's line,
   status 1.
8. **`name=value ROOT is a path`** — a fixture repo under
   `$BATS_TEST_TMPDIR/x=y`, invoked with the relative ROOT `"x=y"` and
   `</dev/null` on stdin (the suite's `setup` already `cd`s to
   `$BATS_TEST_TMPDIR`). Expects `broken-link: docs/a.md -> missing.md`,
   status 1.

## Run: full suite, unmodified SUT

`scripts/run-bats.sh tests/check-links.bats`: **17 passed, 0 failed** (up
from 9) — every new test green on the SUT as committed, since the behaviour
already exists.

## Mutation proofs

Each mutation was applied as an exact string replacement, the full suite run
once, the named test's own failed assertion recorded, then reverted by the
inverse replacement. Restore proven per mutation with a `grep`/`cmp` check
that the mutation text is gone; `scripts/` confirmed byte-identical to HEAD
at the end.

### 1. `linking file with a space`

- File: `scripts/lib/tracked.sh`. Mutation: `"$handler" "$file"` →
  `$handler $file` (drop the quotes, reintroducing word-splitting).
- Mechanism: `handle_file` then receives `$1=docs/a` (word-split at the
  space), which fails `markdown_in_scope` (not `*.md`) and is skipped
  entirely — the file is never checked.
- Red: `not ok 10 linking file with a space` — `[ "$status" -eq 1 ]` failed.
  16 passed, 1 failed.
- Restore: `grep -c '\$handler \$file' scripts/lib/tracked.sh` → `0`;
  `cmp scripts/lib/tracked.sh` against the pre-mutation copy → identical.

### 2. `deleted tracked file is skipped`

- File: `scripts/lib/tracked.sh`. Mutation:
  `if [ -L "$root/$file" ] || [ ! -f "$root/$file" ]; then` → `if false; then`
  (disables the symlink/non-file skip guard).
- Mechanism: the deleted-but-indexed file now reaches `handle_file`, which
  calls `check_links_in`, whose awk redirection against the missing path
  fails, printing `check-links: cannot read docs/gone.md` and exiting 2.
- Red: `not ok 11 deleted tracked file is skipped` — `[ "$status" -eq 0 ]`
  failed (actual 2). 16 passed, 1 failed.
- Restore: verified by `cmp` against the pre-mutation copy → identical.

### 3. `unreadable file exits 2`

- File: `scripts/check-links.sh`. Mutation:
  `if ! links=$(LC_ALL=C awk -f "$LIB_DIR/strip-code.awk" <"$ROOT/$file" |`
  → same with `set +o pipefail; ` prepended inside the substitution.
- Mechanism: this is the exact mutation the slice 4 code review used to
  demonstrate the finding — it drops the redirection's failure status and
  awk's, folding grep's benign 1 to 0, so an unreadable file reads as "no
  links" instead of failing the capture.
- Red: `not ok 12 unreadable file exits 2` — `[ "$status" -eq 2 ]` failed.
  16 passed, 1 failed. (Not running as root in this environment — `id -u`
  is 1000 — so the test itself ran rather than skipping.)
- Restore: verified by `cmp` against the pre-mutation copy → identical.

### 4. `extra argument exits 2`

- File: `scripts/lib/tracked.sh`. Mutation: `if [ "$#" -gt 2 ]; then` →
  `if [ "$#" -gt 2 ] && false; then` (arity guard never fires).
- Mechanism: with the guard defeated, `parse_root` falls through to
  `ROOT="${2:-.}"`, silently accepting the extra argument and walking the
  tree normally — which reports the fixture's broken link on stdout instead
  of refusing before the walk.
- Red: `not ok 13 extra argument exits 2` — `[ "$status" -eq 2 ]` failed.
  16 passed, 1 failed.
- Restore: verified by `cmp` against the pre-mutation copy → identical.

### 5. `any URI scheme is skipped`

- File: `scripts/check-links.sh`. Mutation: `[A-Za-z]*:*)` →
  `Z[A-Za-z]*:*)` (the scheme arm's pattern can no longer match anything,
  since no target starts with a literal `Z`).
- Mechanism: every scheme-shaped target — `ftp://h/x`, `HTTP://X`, `x:y.md`
  — now falls through to the file-existence check instead of being skipped,
  and none of the three exists as a path, so all three are reported ahead
  of the sentinel.
- Red: `not ok 14 any URI scheme is skipped` — `[ "$output" = … ]` failed
  (extra lines ahead of the sentinel's). This mutation also reds the
  existing `urls and anchors ignored` test (both exercise the same
  scheme-skip arm) — 15 passed, 2 failed, with test 14 red on its own
  assertion as required.
- Restore: verified by `cmp` against the pre-mutation copy → identical.

### 6. `CRLF fence closes`

- File: `scripts/lib/strip-code.awk`. Mutation: the backtick closer's
  `trimmed ~ /^```+[ \t\r]*$/` → `trimmed ~ /^```+[ \t]*$/` (drops `\r`
  from the trailing-whitespace class; the tilde closer's copy of the same
  class is left untouched, so the mutation is scoped to the fixture's
  backtick fence).
- Mechanism: the closing ` ```\r ` line no longer matches the closer, so the
  fence never closes and swallows the sentinel line along with it.
- Red: `not ok 15 CRLF fence closes` — `[ "$status" -eq 1 ]` failed (actual
  0, output empty — the whole rest of the file was swallowed as fence
  content). 16 passed, 1 failed.
- Restore: verified by `cmp` against the pre-mutation copy → identical.

### 7. `code span at line start is not a fence`

- File: `scripts/lib/strip-code.awk`. Mutation:
  `if (trimmed ~ /^```+[^`]*$/) {` → `if (trimmed ~ /^```+/) {` (drops the
  "no backtick after the opener" check).
- Mechanism: `` ```x``` text `` now opens a fence (previously excluded,
  since CommonMark disallows a backtick in the info string and the line has
  one), and the fence runs to the end of the file with no closer, swallowing
  the sentinel.
- Red: `not ok 16 code span at line start is not a fence` —
  `[ "$status" -eq 1 ]` failed (actual 0, empty output). 16 passed, 1 failed.
- Restore: verified by `cmp` against the pre-mutation copy → identical.

### 8. `name=value ROOT is a path`

- File: `scripts/check-links.sh`. Mutation:
  `awk -f "$LIB_DIR/strip-code.awk" <"$ROOT/$file" |` →
  `awk -f "$LIB_DIR/strip-code.awk" "$ROOT/$file" |` (file passed as an
  operand instead of by redirection).
- Mechanism: this reintroduces exactly the slice 4 code-review finding.
  POSIX awk reads an operand shaped `name=value` as a variable assignment;
  `x=y/docs/a.md` splits at its first `=` into a valid identifier (`x`) and
  a value, so awk treats the whole path as an assignment, takes no file
  operand, and reads stdin (`/dev/null`) instead — silently checking no
  links in `docs/a.md`.
- Red: `not ok 17 name=value ROOT is a path` — `[ "$status" -eq 1 ]` failed
  (actual 0, empty output — the broken link went unchecked). 16 passed, 1
  failed.
- Restore: verified by `cmp` against the pre-mutation copy → identical.

## Final state

- `scripts/run-bats.sh tests/check-links.bats` (current state, after every
  restore): **17 passed, 0 failed**.
- `shellcheck tests/check-links.bats`: clean. Two `printf` lines carrying
  literal backticks in CRLF/code-span fixtures needed
  `# shellcheck disable=SC2016`, justified inline as fixture data, following
  the precedent already in this file for the slice 4 fixture.
- `bash -n scripts/check-links.sh`: clean (unchanged from HEAD).
- `git diff --quiet scripts/ && echo "scripts/ byte-identical to HEAD"` →
  printed.
- `git status --porcelain --untracked-files=no` → ` M tests/check-links.bats`
  only.

## Flag: test file now over the 400-line cap

`tests/check-links.bats` is now 409 lines. `scripts/check-line-limits.sh`
(Item 2.1, already wired into `just precommit`) caps any tracked `.bats`
file at 400 and is already wired into `precommit`; run directly against the
repo as it now stands it reports
`oversized-file: tests/check-links.bats: 409 lines > 400` and exits 1. This
dispatch was scoped to adding slice 5's tests only, and slices 6–7 add more
tests to the same file, so the overage will not shrink on its own. Not
fixed here — deciding how to bring the file back under cap (trim comments,
split into more than one `.bats` file, or something else) is outside this
RED dispatch's scope and changes the suite's shape in a way the runbook does
not currently spell out. Flagging for the team lead's call before slice 6.

## Files changed

- `tests/check-links.bats` (eight new tests, uncommitted). `scripts/`
  unchanged.
