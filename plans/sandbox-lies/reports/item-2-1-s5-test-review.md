# Item 2.1 slice 5 — test review

Scope: the four new tests in `tests/check-line-limits.bats` and
`plans/sandbox-lies/reports/item-2-1-s5-red.md`. SUT
`scripts/check-line-limits.sh` was mutated in place for probes only, each
restored by the inverse exact replacement (count-checked unique), with
`git diff --quiet scripts/check-line-limits.sh` confirmed after every
restore and at the end. Nothing committed.

## Findings

1. **Major — the whitespace test pinned only argument quoting, not the
   walk.** The `docs/a b.md` fixture catches a word-splitting walk
   (`for file in $(…)`) and the RED report's unquoted-`$file` mutation, but
   **survived** two walk mutations: dropping both `-z` and `-d ''` (a
   newline-delimited walk), and dropping `IFS=`. A space is neither
   C-quoted by `git ls-files` nor trimmed by `read` when it sits inside the
   path. Dropping only `-z` or only `-d ''` does red it, but reds every
   positive test in the suite, because the walk yields nothing at all.
   Nothing in the suite was specific to the NUL walk the script's header
   names.
   - Fix: renamed `path with a space` → `path with whitespace`. The fixture
     now carries three files, each failing a different walk:
     `docs/a b.md` fails the word-splitting walk. `docs/a<TAB>b.md` fails
     the newline walk, because git C-quotes a tab without `-z` whatever
     `core.quotePath` says. ` lead.md` (root, leading space) fails the
     `IFS=`-less read. The exact output holds all three lines in
     `ls-files` byte order. **Runbook drift:** the slice names the test
     `path with a space`. Update the slice text, or tell me to revert the
     name.
2. **Major — `extra argument exits 2` could pass for the wrong reason.**
   - With `extra` as the second argument, a script that ignored the guard
     and took the *last* argument as ROOT exits 2 from `git ls-files`
     failing on `extra`. Probe E2 below stayed green.
   - With a clean 10-line tree, `[ -z "$output" ]` was vacuous: a script
     that checked the argument count only *after* the walk still printed
     nothing. Probe E3 stayed green.
   - Fix: the fixture is now a 401-line `docs/a.md`, and the second
     argument is `"$dir"` itself, a valid root. Now only the argument check
     can produce status 2, and a check made after the walk leaks an overage
     line onto stdout. Comments added for both.
3. **Minor — the BSD case's smoke-run status lived only in the RED report.**
   I verified the claim (see below). The name `oversized markdown survives
   BSD mktemp` follows the precedent in `tests/matchers.bats`
   (`the whole fixture sweep survives BSD grep, sed and mktemp`) and claims
   only that the script survives the stub. Fix: added a comment in the test
   saying that it is a smoke run and why no mutation reds it. The name
   stays.
4. **No finding — `unterminated last line counts`.** The fixture really
   does end without a newline (`tail -c 4 | od -c` → `\n 4 0 1`), and the
   red is specific: slice 1's newline-terminated 401-line test stays green
   under both count mutations.

## Mutation reproductions (final tests)

The suite is run whole under each mutation. "Red" names the failing test
and its first failed assertion.

| Id | Mutation | Result |
|---|---|---|
| W1 | `ls-files -z >` → `ls-files >` | 9 tests red on status (the walk yields nothing), incl. #13 |
| W2 | `read -r -d '' file` → `read -r file` | same 9, on status |
| W3 | W1 + W2 (newline walk) | **#13 only**, on output (tab line missing). Before the fix: survived |
| W4 | `while IFS= read` → `while read` | **#13 only**, on output (` lead.md` line missing). Before the fix: survived |
| W5 | `for file in $(tr '\0' '\n' <"$WALK_LIST")`, `done` without the redirect | **#13 only**, on status. Also red before the fix |
| Q | `check_cap "$file" 400` → `check_cap $file 400` (RED report's) | #13 only, on output |
| U1 | awk `NR` → `while IFS= read -r _` counting loop | **#14 only**, on status |
| U0 | awk `NR` → `wc -l` (RED report's) | #14 only, on status |
| E1 | guard → `if [ "$#" -gt 1 ] && false; then` | **#15 only**, on status |
| E0 | `-gt 1` → `-gt 2` (RED report's) | #15 only, on status |
| E2 | E1 + `ROOT="${2:-${1:-.}}"` (last argument as ROOT) | #15 on status. Before the fix: **survived** |
| E3 | E1 + `exit "$EXIT_CODE"` → `[ "$#" -le 1 ] \|\| exit 2; exit "$EXIT_CODE"` | #15 on `[ -z "$output" ]`. Before the fix: **survived** |

I confirmed the W3 and W4 mechanisms by running the mutated script
directly on the fixture:

- W3 prints the ` lead.md` and `docs/a b.md` lines. `git ls-files` without
  `-z` lists `"docs/a\tb.md"`, quotes included.
- W4 prints the two `docs/` lines.

## BSD case

- **The RED report's claim holds.** The script's only `mktemp` template
  ends in `X`, and the stub `exec`s the real tool for that. Probes:
  - B2, literal template `…XXXXXX.list`: green. The stub creates the
    literal file, and the trap removes it; no leftover in `$TMPDIR`.
  - B3, bare `mktemp`: green. The stub delegates an empty template.
  - A refusal needs the literal path to exist already. I reproduced that
    only with two mutations (literal template plus the trap removed) and
    two runs by hand: run 1 rc 0, run 2 rc 2 with
    `mkstemp failed … File exists`. No single mutation reaches it within
    one test run.
- **The stub is first on PATH and the script reaches it.** Probe B1 was a
  test-side edit, inverted afterwards and checked with a hash of the
  `git diff`. It swapped the stub for one that exits 1 only when its
  arguments contain `check-line-limits`, and #16 went red on
  `[ "$status" -eq 1 ]`.
- **A caveat for any future probe.** A stub that fails unconditionally
  reds #16 at the `run` line itself. Bats' `run --separate-stderr` calls
  `mktemp` under the same `PATH`, so such a probe measures bats, not the
  script.
- **Asserting the invocation in the suite: not done.** For this template
  the stub's observable output is byte-identical to the real tool's.
  Proving the script called it would need an instrumented or logging stub
  written by the test, which is exactly the contrived setup the dispatch
  excludes. `command -v mktemp` under the stubbed `PATH` is cheap, but it
  proves only resolution order, which B1 already showed. I did not add it.

## Final run

- `./scripts/run-bats.sh tests/check-line-limits.bats`: 16 passed, 0
  failed, rc 0.
- `shellcheck tests/check-line-limits.bats`: rc 0.
- `git diff --quiet scripts/check-line-limits.sh`: clean, so the SUT is
  byte-identical to HEAD.
- The test file is 319 lines, under its 400 cap.

Unrelated to this review: `/tmp/claude-1000/check-line-limits.sh.orig`, a
backup copy left by an earlier session, sits in `$TMPDIR`. Not touched.
