# Item 2.2 slice 5: test review

Scope, Part A: the eight slice-5 tests and
`plans/sandbox-lies/reports/item-2-2-s5-red.md`. Part B: the suite split. I
mutated the SUT in place for probes only. Each mutation was an exact string
replacement, count-checked unique, and was inverted by the swapped
replacement in the same call. After every inversion `git diff --quiet
scripts/` passed. Nothing is committed.

## Part A: findings and fixes

1. **Major: `linking file with a space` pinned argument quoting only.** It
   has the same gap Item 2.1's review found in its twin. The single
   `docs/a b.md` fixture survived these mutations:
   - W3, a newline-delimited walk (`-z` and `-d ''` both dropped);
   - W4, an `IFS=`-less `read`;
   - Q2, an unquoted `[ ! -e $ROOT/$dir/$check_target ]`: the file sits in
     `docs/`, so `$dir` has no whitespace;
   - Q3, `dir=$(dirname $file)`: every link in the fixture is broken, so a
     wrong directory still reports it.

   **Fix:** renamed to `linking file with whitespace`, following the twin's
   `tab=$'\t'` idiom. The fixture now has four files:
   - ` lead.md`, which fails W4;
   - `docs/a<TAB>b.md`, which fails W3;
   - `docs/s p/a b.md`, which fails Q1 and Q2. Its first link, `[b](b.md)`,
     resolves to the tracked `docs/s p/b.md` beside it, so it also fails Q3.

   The test asserts the exact three-line output, in `ls-files` byte order.
   **Runbook drift:** slice 5 names the test `linking file with a space`,
   with the one file `docs/a b.md`. Update the slice text, or tell me to
   revert the name.
2. **Major: `deleted tracked file is skipped` was an unpaired negative.** A
   walk that yields nothing kept it green (D3: drop only `-z`, and the
   whole list is one unterminated record). So did `break` in place of the
   guard's `continue` (D2). Both give status 0 and empty output, which is
   exactly what the test asserted. **Fix:** a present `docs/sentinel.md`,
   which sorts after `gone.md`, holds the one broken link. The test now
   expects status 1 and exactly `broken-link: docs/sentinel.md ->
   missing.md`, with empty stderr. **Runbook drift:** the slice text says
   "yields status 0".
3. **Major: `extra argument exits 2`. Something other than the arity check
   could produce status 2 with empty stdout.** With the guard off and the
   arguments joined into one ROOT (`ROOT="${*:2}"`), `git ls-files` fails
   on `"$dir $dir"` and exits 2. The test stayed green (E2). **Fix:** it
   now also asserts `[ "$stderr" = "check-links: unexpected extra argument:
   $dir" ]`. The "last argument as ROOT" and "checked after the walk"
   readings were already closed: the second argument is a valid root, and
   the fixture has a broken link.
4. **No finding for the other five tests.**
   - `unreadable file exits 2` pairs mode 000 against a readable-content
     broken link, so a silent skip or a successful read leaks status 0 or
     1.
   - `any URI scheme is skipped` needs all three targets: each is pinned
     alone (S1 `HTTP`, S3 `x:y.md`, S4 `ftp`).
   - `CRLF fence closes` also pins the CRLF opener (C2), through the
     in-fence broken link.
   - `code span at line start is not a fence` is specific to the opener
     check.
   - `name=value ROOT is a path` reds when awk takes the path as an operand
     again, both as the RED's plain operand and as my `--` variant (N1). It
     depends on the shared `setup` `cd`; when I disabled that `cd`, this
     test went red.

## Mutation reproductions (final tests, final layout)

Each row ran `bats tests/check-links.bats tests/check-links-edges.bats`, 17
tests: 9 in `check-links.bats`, then the 8 edge tests numbered 10–17. Every
mutation differs from the RED report's. Unless noted, the result was 16
passed and 1 failed, and the red test was the one named for the behaviour,
failing on its own assertion.

| Id | File | Mutation | Red |
|---|---|---|---|
| W3 | tracked.sh | `ls-files -z >` → `ls-files >` plus `read -r -d '' file` → `read -r file` | #10 whitespace, output. Before the fix: survived |
| W4 | tracked.sh | `while IFS= read` → `while read` | #10, output. Before the fix: survived |
| Q2 | check-links.sh | `[ ! -e "$ROOT/$dir/$check_target" ]` unquoted | #10, output. Before the fix: survived |
| Q3 | check-links.sh | `dir="${file%/*}"` → `dir=$(dirname $file)` | #10, output. Before the fix: survived |
| D1 | tracked.sh | guard → `if [ -L "$root/$file" ]; then` (the `-f` arm dropped) | #11 deleted, status |
| D2 | tracked.sh | the guard's `continue` → `break` | #11, status. Before the fix: survived |
| D3 | tracked.sh | `ls-files -z >` → `ls-files >` only | #11 and 13 others (walk empty). Before the fix: #11 survived |
| U1 | check-links.sh | `{ awk … <"$ROOT/$file" \|\| :; } \|`, which swallows the read failure | #12 unreadable, status |
| E1 | tracked.sh | `-gt 2` → `-gt 3` | #13 extra argument, status |
| E2 | tracked.sh | guard `if false`, plus `ROOT="${*:2}"` | #13, stderr. Before the fix: survived |
| E3 | tracked.sh | guard `if false`, plus ROOT = the last argument | #13, status |
| S1 | check-links.sh | `[A-Za-z]*:*)` → `[a-z]*:*)` | #14 scheme, output |
| S2 | check-links.sh | whole scheme arm → `http://*\|https://*\|mailto:*) continue ;;` | #14, output |
| S3 | check-links.sh | `[A-Za-z]*:*)` → `[A-Za-z]*://*\|mailto:*)` | #14, output |
| S4 | check-links.sh | `[Ff][Tt][Pp]) ;;` arm added ahead of `*) continue ;;` | #14, output |
| C1 | strip-code.awk | backtick closer `/^```+[ \t\r]*$/` → `/^```+$/` | #15 CRLF, status |
| C2 | strip-code.awk | opener `[^`]*$` → `[^`\r]*$` | #15, output |
| O1 | strip-code.awk | opener `/^```+[^`]*$/` → `/^```+[^`]*/` (unanchored) | #16 span, status |
| N1 | check-links.sh | `<"$ROOT/$file"` → `-- "$ROOT/$file"` | #17 name=value, status |

I did not rerun the RED report's own eight mutations. Rows D1, U1, E1,
S1–S4, C1, O1 and N1 also went red, each on its own test, in the pre-split
file before the fixes.

## Part B: the split

| File | Lines | Tests |
|---|---|---|
| `tests/helpers/fixture-root.bash` (new) | 32 | none |
| `tests/check-links.bats` | 249 (from 409) | 9, slices 1–4 |
| `tests/check-links-edges.bats` (new) | 163 | 8, slice 5 |
| `tests/check-line-limits.bats` | 301 (from 319) | 16 |

- **What the helper holds:**
  - `bats_require_minimum_version 1.5.0`;
  - `ROOT` (SC2034 disabled, with the reason given inline);
  - the `setup` that `cd`s into `$BATS_TEST_TMPDIR`;
  - `make_fixture_root`;
  - the shared rationale comments.

  Each suite keeps `SCRIPT="$ROOT/scripts/<name>"` after
  `load helpers/fixture-root` and `load helpers/bsd-stubs`. `SCRIPT`
  differs per suite, so it stays in the suite.
- **The helper lines are load-bearing.** I neutered each one by exact
  replacement and inverted it the same way.
  - With the version line gone, the edges suite printed `BW02: Using flags
    on run requires at least BATS_VERSION=1.5.0`.
  - With the `cd` gone, `name=value ROOT is a path` went red.
- **Behaviour change in `check-line-limits.bats`:** it now inherits the
  `setup` `cd`, which the brief asked for. Every one of its invocations
  passes an absolute `"$dir"`, and its 16 tests stay green.
- **Suite count unchanged:** 60 before the split, 60 after, with 33
  across the three check suites. Part A changed assertions, not the number
  of tests.

## Follow-ups, not fixed

The Item 2.1 twins in `tests/check-line-limits.bats` have the same two
holes. The brief kept that file's logic unchanged in the move, so I left
them. Both probes were run and inverted, with `scripts/` equal to HEAD
afterwards:

- **`deleted tracked file is skipped`** stays green when the walk yields
  nothing (`ls-files -z` → `ls-files`). It needs the same present sentinel
  fix as check-links. Its comment also names "`check_cap`'s `[ ! -f … ]`
  guard", which now lives in `walk_tracked_files`.
- **`extra argument exits 2`** stays green with the guard off and
  `ROOT="${*:2}"`. It needs the same exact-stderr assertion.

## Final runs (foreground)

- `scripts/run-bats.sh tests/`: `bats: 60 passed, 0 failed`, rc 0.
- `just precommit`: `precommit passed: plugin.json, shellcheck, bash -n,
  rumdl, line limits, tests`, rc 0.
- **Caveat on that gate:** it walks tracked files only. The two new files
  are untracked, so its shellcheck and line-limit steps have not seen them
  yet. Run directly, `shellcheck` is clean on all four test files, and the
  new files are 163 and 32 lines.
- `git diff --quiet scripts/`: clean, so `scripts/` is byte-identical to
  HEAD.
- Working tree:
  - modified: `tests/check-links.bats`, `tests/check-line-limits.bats`;
  - untracked: `tests/check-links-edges.bats`,
    `tests/helpers/fixture-root.bash`, the RED report and this report.
