# Review: Item 4.2 slice 1 — test review (RED → GREEN)

**Scope**: The two new tests — `tests/probes-readonly-members.bats` "match=
names are absolute from a subdirectory cwd" and `tests/hook-writes.bats` "hook
restore clause names the match by absolute path" — and the RED report
`plans/sandbox-lies-review-fixes/reports/item-4-2-s1-red.md`. The SUT
(`lib/probes-readonly-facts.sh`) was changed only for the mutation runs below,
and each change was reverted by inverse replacement. The file matches its
original byte for byte and has no git diff.
**Date**: 2026-10-05
**Mode**: review + fix

## Summary

Both new tests fail on an assertion against the unchanged SUT. Neither passes
or errors. The hook test's needle is tight: it holds the whole restore list
between `restore` and `from HEAD`. The direct-call test needed two fixes. It
could pass on output that carried both the bare and the absolute lines, and its
refused path `<repo>/a` could not tell the repository root apart from the
refused path's directory. I fixed both. Five SUT mutations confirm the
discrimination.

**Overall Assessment**: Ready

## Mechanical first check

`bats tests/probes-readonly-members.bats tests/hook-writes.bats` was run in the
foreground. The results are the same before and after the fixes:

- `not ok 3 match= names are absolute from a subdirectory cwd`: fails on the
  `match=` comparison at line 81 (line 76 before the fix). This is an assertion
  failure, not a setup error.
- `not ok 13 hook restore clause names the match by absolute path`: fails on
  the restore-clause `grep -qF` at line 125. This is an assertion failure.
- The other 11 cases pass.

## Issues Found

### Critical Issues

None.

### Major Issues

1. **Output carrying both name forms passes the direct-call test**
   - Location: `tests/probes-readonly-members.bats`, the new case.
   - Problem: The test made three positive `grep -qxF "match=$repo/…"` checks
     and nothing else. An implementation that adds absolute lines but keeps the
     bare `match=a` lines would pass. So would one that adds absolute lines for
     the decoys `c` and `d`. The "both forms" mutation below demonstrates this
     shape.
   - Fix: Extract the `match=` lines and compare them whole, in index order,
     against `match=<repo>/a`, `match=<repo>/b`, `match=<repo>/e f`. This one
     assertion rejects bare lines, extra lines and missing lines. It is a
     positive check, so it cannot go vacuous the way a bare negative can.
   - **Status**: FIXED

2. **The repository root and the refused path's directory coincide**
   - Location: same case.
   - Problem: With refused path `<repo>/a`, `${path%/*}` is `<repo>`. An
     implementation that joins the name onto the refused path's directory
     instead of the resolved repository root would pass. The dispatch asked
     about cwd and `$PWD`, and both are ruled out (`<repo>/sub/a` and
     `$PWD/a`). The refused-path directory was not.
   - Fix: The case now loops over two refused paths. The first is `<repo>/a`,
     the runbook's case, kept unchanged. The second is `<repo>/sub/x`, whose
     directory is `<repo>/sub`. Both use cwd `<repo>/sub` and must give the
     same three absolute lines. I added a `writable` first-line check so the
     second iteration's `x`, which does not exist, cannot fall through to
     another outcome unnoticed.
   - **Status**: FIXED

### Minor Issues

1. **Comment sentence was garbled**
   - Location: same case, header comment.
   - Note: The comment read "the target= attempt is not the only path to
     match=", which says nothing true. I rewrote it to state the fact (merge is
     one of the three subcommands target= is attempted after). The comment now
     also names what the test rules out and why the comparison is whole.
   - **Status**: FIXED

## Wrong-reason hunting (dispatch check 2)

- **Is `<repo>` pinned as the repository root?** Yes, after fix 2. Joining onto
  cwd gives `<repo>/sub/a`, joining onto `$PWD` gives the bats run directory,
  and joining onto the refused path's directory gives `<repo>/sub/a` on the
  second iteration. All three are red (table below).
- **Are bare `match=a` lines asserted gone?** Yes, after fix 1, through the
  whole-list comparison.
- **Is the hook needle tight?** Yes. It is the full clause fragment ``restore
  `<repo>/a`, `<repo>/b`, `<repo>/e f` from HEAD``. A bare name before,
  between or after the listed names breaks the fixed string: it would show up
  as an extra backticked item before "from HEAD" or after "restore ". The
  refused-path subject (`` `<repo>/a` is writable…``) cannot satisfy it. The
  RED report's note about the vacuous bare `<repo>/a` needle is borne out.
- **Real probe, flag absent?** Yes. `setup` runs `hook_copy_tree` to copy the
  tracked tree, with nothing stubbed in this case. `readonly_payload_file`
  deletes `tool_input.dangerouslyDisableSandbox`, and the test only rewrites
  `.cwd`. The "correct" mutation turning the case green proves the real probe's
  output reaches the clause.
- **Is `$repo` safe as a fixed string?** Yes. It is `$BATS_TEST_TMPDIR/repo`:
  the needle is matched with `-F`, so regex metacharacters do not apply. Bats
  temp paths hold no backtick, newline or quote. The whitespace case is covered
  by `e f` in the list, and the direct-call test uses `scratch repo`.
- **Does the needle match what GREEN's verdict will print?** Yes. The
  `_readonly_match_list` format is backticked names, comma-joined, followed by
  `from HEAD`. The correct-implementation mutation turns the case green.

## Mutation runs

`/tmp/claude-1000/sl/r42_mutate.py` swaps the merge-pass line
`out="${out}match=${files[$i]}"$'\n'` in place. It runs `bats -f absolute` over
both files and then restores the line by inverse replacement. The script
asserts that the SUT's text equals the pristine copy, and `git status --short
lib` is clean.

| Mutant | direct-call | hook |
| --- | --- | --- |
| correct: `${repo}/${files[$i]}` | green | green |
| cwd join: `${cwd}/…` | red | red |
| `$PWD` join | red | red |
| refused-path dirname: `${path%/*}/…` | red | green |
| both forms (bare + absolute) | red | red |

The hook case staying green under the dirname mutant is expected. Its payload
is fixed by `readonly_payload_file` at refused path `<repo>/a`, and the
direct-call case carries that discrimination. The hook case's job is the
end-to-end wiring from probe to clause.

## Fixes Applied

- `tests/probes-readonly-members.bats`, the new case (now lines 61–83): the
  rewritten header comment, the loop over refused paths `<repo>/a` and
  `<repo>/sub/x`, the `writable` first-line check, and the whole-list
  `match=` comparison against `$expected`. The file is 194 lines (cap 400).
- `tests/hook-writes.bats`: unchanged (126 lines).
- `shellcheck -x` is clean on both files. After the fix, both new tests are
  still red on their assertions and the other 11 cases still pass.

## Migration list for GREEN

Every existing probe-output `match=` assertion has to move to `<repo>/<name>`
in the GREEN commit. Use double quotes so `$repo` expands, since every repo
path here holds a space or is a tmpdir path. A negative left bare can never
fail once the names are absolute, so it must move as well.

`tests/probes-readonly-facts.bats` (`repo="$BATS_TEST_TMPDIR/scratch repo"`):

- l.273–275: `match=a`, `match=b`, `match=e f` become `"match=$repo/a"`,
  `"match=$repo/b"`, `"match=$repo/e f"`.
- l.276–277, negatives: `run ! grep -qxF 'match=c'` and `'match=d'` become
  `"match=$repo/c"` and `"match=$repo/d"`.
- l.314 (path's repository, not the cwd's): `"match=$repo/a"`. Here
  `$repo` is the path's repository, not `$cwd`, so this assertion also pins
  which root is joined on.
- l.329 (nopath, cwd fallback): `"match=$repo/a"`.
- l.348–349 (BSD stubs): `"match=$repo/a"`, `"match=$repo/e f"`.

`tests/probes-readonly-members.bats` (Item 2.4's `match=a`):

- l.58 (switch case): `"match=$repo/a"`. The test title on l.46, "…gives
  target=feat and match=a", names the old form and should be reworded. The
  section banner on l.42 can stay.
- l.182 (BSD-tools case): `"match=$repo/a"`.

`tests/probes-readonly-pins.bats`:

- l.81: `"match=$repo/a"`. In the l.60 comment, "match=a" is prose about the
  fact and can stay or be reworded.
- l.83, negative: `run ! grep -qxF 'match=d'` becomes `"match=$repo/d"`.
- l.201 (1000-file bound, nopath, cwd `$repo`): `"match=$repo/f1000"`.
- l.238 and l.264 (merge-pass cases, `repo="$BATS_TEST_TMPDIR/passrepo"`):
  `"match=$repo/z"`.

These stay as they are:

- `tests/verdicts-readonly.bats`, every `match=` (l.92, 144, 173, 182, 216,
  226, 237, 247, 266, 269). These are verdict input, and the verdict prints
  whatever name it receives.
- The `tests/hook-candidates.bats` restore assertions (l.132, l.188). They pin
  the partial-checkout `restore them from HEAD` clause, which names no file.
  No hook stub or helper in `tests/helpers/` carries a `match=` line.
- `tests/probes-edges.bats` "readonly-path probe writes nothing" makes no
  `match=` assertion.
- Prose mentions (facts.bats l.3, members.bats l.8/l.42) describe the fact
  kind, not its value.

## Positive Observations

- The RED report records the vacuous first draft of the hook needle and why it
  was vacuous. That is what made the tight needle reviewable.
- The hook case is placed beside the file's existing real-probe payload
  builder, and its cwd is rewritten with `jq` rather than forking the helper.
- The direct-call test uses a repo path with a space, and the list includes
  `e f`, so whitespace in both the root and the name is exercised.

## Recommendations

- In GREEN, the l.314 facts case (path's repository versus a cwd that is
  another repository) becomes a second root-pinning test once its assertion is
  `"match=$repo/a"`. Keep `$repo` there and not `$cwd`.
