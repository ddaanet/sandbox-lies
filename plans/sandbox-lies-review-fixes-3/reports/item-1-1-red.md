# Item 1.1 RED report — `path=` encoding, slices 1-4

Mode RED. `lib/` is unchanged (`git status` shows no `lib/` path). Nothing
committed; tests, the new helper and this report are left in the tree.

## What was written

- `tests/helpers/locale.bash` (new): `utf8_locale` moved verbatim out of
  `tests/hook-cap.bats`. Header names `hook-cap.bats`, `probes.bats` and
  `probes-lock-newline.bats` as the three sharing it. A helper, not a bats
  file, so the `bsd-stubs` rule does not apply.
- `tests/hook-cap.bats`: function deleted, `load helpers/locale` added.
- `tests/probes.bats`: `load helpers/locale`; three new cases (slices 1 and 4).
- `tests/probes-lock-newline.bats`: header rewritten, `load helpers/locale`,
  all five pinned print sites rewritten (slice 2), plus one added case (below).
- `tests/probes-readonly-members.bats`: the newline case renamed and rewritten
  (slice 3).

Not done, by scope: slice 5 and `_probe_path_line`. No `lib/` edit.

## Result against the unchanged SUT

Every new or changed test fails on an assertion (`not ok`, the failing line is
an assertion line, never a missing symbol or `127`). "Actual" below is the
unchanged probe run by hand on the same inputs (`<tmp>` = the test tmpdir).

### tests/probes.bats

1. `a relative lock path under a cwd holding a blank prints path= in %q form`
   - Failing line: 93, the `grep '^path=' ... = "path=$BATS_TEST_TMPDIR/r\\ b/..."`
     assertion. Before it, the case asserts `BATS_TEST_TMPDIR` holds no byte
     `%q` escapes (passes), status 0, empty stderr, line 1 `mask`.
   - Actual: `mask` / `path=<tmp>/r b/.git/index.lock`, expected
     `path=<tmp>/r\ b/.git/index.lock`.
   - State of the world that fails it: the blank in the resolved path is
     printed raw. Else could produce the red: a `BATS_TEST_TMPDIR` that `%q`
     escapes (ruled out by the opening assertion, which would fail the case
     before its subject line instead), or a wrong outcome token (asserted
     earlier). The expected literal is written out, not produced by `%q`.
2. `probe_config_lock with no config-lock line prints mask and no path=`
   - Failing line: 106, `[ "$output" = mask ]`.
   - Actual: `mask` / `path=` (a bare `path=` line).
   - State: an empty resolved path still prints a `path=` line. Else: nothing
     — the only other output shape is a different outcome, which the same
     whole-output equality also rejects, but the observed red is the bare line.
3. `a lock path holding e-acute prints the octal form under a UTF-8 locale`
   - Failing line: 125, the `grep '^path='` equality against
     `path=$'<tmp>/caf\303\251/.git/index.lock'`.
   - Actual: `path=<tmp>/café/.git/index.lock` (raw bytes).
   - State: the path is not encoded. The pin is not yet reachable here: the
     red is the missing encoder, as on any implementation. What the case
     guards later is stated in its comment: unpinned on bash 5.2 `%q` under
     UTF-8 prints `é` raw (confirmed by hand on 5.2.37:
     `LC_ALL=C.UTF-8 bash -c 'printf "%q\n" é'` prints `é`; with
     `LC_ALL=C` the same prints the `$'\303\251'` form), so a GREEN encoder
     without `LC_ALL=C` fails this case while one with it passes. `utf8_locale`
     fails the case outright when the box has no UTF-8 locale (it does here:
     `C.UTF-8`).

### tests/probes-lock-newline.bats

Each case failed first on its newline twin (`<b>`, run first), at
`assert_lines`' first check (line 57: exactly one `path=` line equal to the
literal). Actual for the newline twin is the outcome token alone, no `path=`
line (the `pathline` guard of `_probe_lock_at`). The blank twin `<g>` is run
after `<b>`, so its raw-blank red (`path=<tmp>/r age=99999 x/...` against
`r\ age=99999\ x`) is not what the case shows; it would fail next.

| Test | Failing line | Actual (unchanged SUT) |
| --- | --- | --- |
| `config-lock: ... gives mask and one encoded path= line` | 110 | `mask` only |
| `git-lock orphan: ... gives one encoded path= line` | 88 via 125 | `orphan`/`unknown`, `bytes=3`, `age=...`, no `path=` |
| `git-lock orphan under BSD sed, stat and wc: ...` | 88 via 133 | same, with BSD stubs |
| `git-lock held: ...` | 150 | `held`, `pid=...`, no `path=` |
| `git-lock character device: ...` | 174 | `mask` only |
| `git-lock gone: ... gives gone and one encoded path= line` | 192 | `gone` only |
| `git-lock gone: a newline and e-acute in one lock path ...` (added) | 217 | `gone` only |

State of the world that fails each: a lock path holding a newline (relative
lock joined onto a cwd `<tmp>/r\nage=99999\nx`), reaching the named print
site. Else that could produce the red: any probe that prints no `path=` line
for another reason; the expected literal (`path=$'<tmp>/r\nage=99999\nx/.git/...'`,
written out by `bad_wire`, not by `%q`) rules out a differently shaped line,
and `assert_lines`' second check (all other lines equal to the literal list)
rules out a forged `age=99999` line from a split path.

How "whole-output equality" became the new assertion, as the slice says: each
twin is asserted by `assert_lines <path-line> <non-path lines...>`: exactly
one `path=` line equal to its literal, and every other line equal to the given
outcome line and key lines. The outcome and non-path lines are the same
literals for both twins (`mask`, `gone`); for `held` and `orphan` the pid and
age are per-twin values read from each run (a holder per twin has its own pid,
and the age lies within a minute of the lock's real age as before), so
"identical" there means identical in shape, with the twin's own pid or age.

The extra case (not in the slice list): a path holding a newline and `é`, run
under `utf8_locale`. It exists because the dispatch has
`probes-lock-newline.bats` load `helpers/locale`, and a loaded helper no case
uses would leave the helper's header naming a suite that does not share it.
Drop the case and the `load` together if the review disagrees.

`setup` in this suite also asserts `BATS_TEST_TMPDIR` holds no byte `%q`
escapes.

### tests/probes-readonly-members.bats

`a resolved refused path holding a newline gives writable and one encoded path= line`
(renamed from `... gives nopath, not path=`)

- Failing line: 158, the first output comparison (the newline twin, run first).
- Actual: `nopath` / `readfile=build.out`; expected `writable` /
  `path=$'<tmp>/r\nreadfile=x/a'` / `readfile=build.out`.
- State: the relative refused path resolves to a path holding a newline, and
  the newline arm of `probe_readonly_path` prints `nopath`. Else: a wrong
  `readfile=` or a non-writable cwd — the directory is created writable by the
  test, and the `readfile=build.out` line is part of the same equality, so only
  the outcome and the path line differ.
- Also rewritten in this test, as it is slice 3 by line number: the blank twin's
  `path=` is now `path=<tmp>/r\ readfile=x/a` (unencoded before). The sibling
  and absolute-path runs follow the newline run. Slice 5 should not count this
  test again.

## Helper move: green on the unchanged SUT, mutation proof

`tests/hook-cap.bats` after the move: 7 passed, 0 failed. The move is
behaviour-preserving, so it is the one place a test is green before any change.
The moved function's only user is `the 2 KB cap counts bytes, not characters`.

### Mutation proof

- Test: `the 2 KB cap counts bytes, not characters` (`tests/hook-cap.bats`).
- Mutation, in `tests/helpers/locale.bash` (string occurring once):
  `      printf '%s\n' "$loc"` replaced by `      printf '%s\n' C`.
- Landed: `command grep` found `printf '%s\n' C` at line 14.
- Result: `not ok 1 the 2 KB cap counts bytes, not characters`, failing at
  hook-cap.bats line 182: `| LC_ALL="$loc" wc -m)))" -le 2048 ]` (under `C`
  the character count equals the byte count, 2770 > 2048, so the fixture no
  longer straddles the cap).
- Restore: the replacement applied with the two strings swapped. `command grep`
  for `printf '%s\n' C` exits 1 (no hit); `tests/hook-cap.bats` green again
  (7 passed, 0 failed).

## Other runs

- `tests/probes.bats` in full: the three new cases are the only failures; the
  twelve existing cases pass.
- `tests/docs.bats`: 2 passed (the new `$'...'` literals fire no detector).
- `shellcheck tests/helpers/locale.bash`: clean.

## For slice 5 (observed, not touched)

Existing assertions still green on the unchanged SUT that the encoder will
break: `tests/probes.bats` `non-UTF-8 byte in the path` and `quote and space in
the lock path` (grep for `path=$lock` with a raw byte, an apostrophe and a
blank); `tests/probes-config.bats` `pathless text never names the base`
(asserts a bare `path=` line from `probe_git_lock`, which the empty-path rule
removes); and the blank-named trees in `tests/probes-readonly*.bats` and
`tests/hook-*.bats` the slice names. The full suite was not run, per the
dispatch, so that list is the slice's expectation plus what reading showed.

## Dispatch deviations to note

- Bad-twin-first ordering in the slice 2 and 3 cases: the advisor suggested
  last, but bats stops at the first failing assertion, so first is what makes
  the report's red the newline behaviour rather than the blank escaping.
