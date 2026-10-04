# Review: Phase 2 — pin hook, matcher and probe behaviour

**Scope**: `git diff c3427a9 HEAD` (Items 2.1–2.5):
`tests/hook-candidates.bats`, `tests/hook-malformed.bats`,
`tests/hook-writes.bats` (new), `tests/matchers-edges.bats`,
`tests/probes-edges.bats`, `tests/probes-readonly-members.bats` (new), and
`plans/sandbox-lies-review-fixes/reports/item-2-{1,2,3,4,5}.md`.

**Date**: 2026-10-04

**Mode**: review + fix (phase-boundary checkpoint)

## Summary

The six test files match their item text: every fixture, stub, payload shape and
assertion the runbook names is present, the two new bats files load
`helpers/bsd-stubs` and keep a `make_bsd_stubs` case, and every file is under
400 lines. The item reports' fault records cover every negative assertion that
carries the item's point, but not every new assertion. This review ran faults
for the rest, and each assertion now has a recorded fault that turns it red
(table below). Three minor fixes were applied: one non-emptiness guard, one
quoting fix in a stub and one inaccurate comment.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

1. **D5 fault record incomplete in four item reports**
   - Location: `reports/item-2-1.md`, `item-2-2.md`, `item-2-3.md`,
     `item-2-4.md`
   - Problem: the runbook's Phase 2 header says a new assertion no fault turns
     red is not done. The reports record faults only for the faults the item
     names. These assertions had none: Item 2.1's paired `check_fires` positives
     and `check_reached` markers; Item 2.2's unspied `systemMessage` pins, the
     spied-equals-unspied comparison, the BSD case's equality, and in
     `probes-edges.bats` the `writable`/`merge=1` lines, the before/after
     listing and the empty-stderr check; Item 2.3's two near-miss negatives (the
     deeper curly-quoted path, the one-name status block); Item 2.4's plain-form
     `readfile=` positives, `target=feat`, `match=a`, the BSD case and the
     empty-stderr checks; Item 2.5's flagged tmpdir-unset and unflagged
     readonly-path firing halves.
   - Fix: faults applied one at a time to a scratch copy at
     `/tmp/claude-1000/sl/scratch-p2/` (`hooks/ lib/ scripts/ tests/` copied,
     the bats file run from the copy, the copy deleted after each run). The
     table under "Fault record" lists each fault and what it turned red. The
     item reports are left as written; this table supplements them.
   - **Status**: FIXED

### Minor Issues

1. **`assert_no_readfile` passes on an empty probe answer**
   - Location: `tests/probes-readonly-members.bats`, `assert_no_readfile`
   - Note: the helper checked status 0, empty stderr and no `readfile=` line. A
     probe that answered something other than `writable` would still pass it.
     Under fault L1 (the probe's `outcome=writable` assignment misspelled) the
     plain-form `readfile=` positives stay green, so without a guard the four
     exclusion cases pass. Added a first-line `writable` check, and all four now
     go red on `assert_no_readfile` under L1. The recorded arm-removal faults
     still turn them red (F1 re-run after the edit).
   - **Status**: FIXED

2. **Inline probe stub quotes its marker path with bare single quotes**
   - Location: `tests/hook-malformed.bats`, "probe dying after output stays
     quiet"
   - Note: the stub body embedded the marker path as `'$called'`. A path holding
     a single quote would break the stub. `stub_probe` in `helpers/hook.bash`
     uses `printf '%q'` for the same job. The case now builds
     `q=$(printf '%q' "$called")` and writes `: >$q`. Fault F3 still turns the
     case red after the edit.
   - **Status**: FIXED

3. **Comment misstates what the curly-quote fault leaves**
   - Location: `tests/matchers-edges.bats`, "tmpdir-unset fires on a GNU refusal
     with the path in curly quotes"
   - Note: the comment said dropping the curly quotes "leaves only the bare
     alternative". The straight-quoted alternative remains too, and neither of
     the two matches the curly-quoted line. Reworded.
   - **Status**: FIXED

## Fixes Applied

- `tests/probes-readonly-members.bats` `assert_no_readfile`: added
  `[ "${output%%$'\n'*}" = writable ]` and updated the helper's comment.
- `tests/hook-malformed.bats` "probe dying after output stays quiet": the marker
  path is `%q`-quoted into both stub bodies.
- `tests/matchers-edges.bats`: reworded the curly-quote fault comment.

After the fixes, `just precommit` exits 0 and its sign-off lists every check:
plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests
(271 passed, 0 failed).

## Fault record

Each fault was applied alone to a fresh scratch copy, landing exactly once
(checked by occurrence count before the edit). Re-applied recorded faults are
marked "spot-check".

| Id | Fault | Bats file | Red |
| --- | --- | --- | --- |
| F1 | spot-check, Item 2.4: `sort:-o*` arm removed | members | 4, 8 |
| F2 | spot-check, Item 2.5: jq `== true` removed | candidates | 13 only |
| F3 | spot-check, Item 2.1: probe's `\|\| exit 0` to `\|\| true` | malformed | 5 only |
| F4 | `[^/']+` to `[^']+` in the quoted alternative | matchers-edges | 7 |
| F5 | phantom-untracked threshold `-ge 2` to `-ge 1` | matchers-edges | 8 |
| F6 | `: >"$PWD/stray"` atop `_readonly_print_facts` | probes-edges | new case |
| F7 | probe branch condition replaced by `false` | malformed | 5, 6 |
| F8 | `*.log` dropped from the readfile name case | members | 4–7 |
| F9a | tmpdir-unset policy arm keyed on `true` | candidates | 1, 10, 11, 13 |
| F9b | readonly-path policy arm keyed on `false` | candidates | 4–9, 12 |
| F10 | `merge` dropped from the merge subcommand case | probes-edges | new case |
| G1 | GNU `\b` grep atop `_readonly_print_facts` | hook-writes | 3 only |
| G2 | `mktemp … \|\| exit 0` in the hook's probe branch | hook-writes | 1–3 |
| G3 | writable human line reworded in `verdicts.sh` | hook-writes | 1 only |
| H1 | `echo stray >&2` atop `_readonly_print_facts` | probes-edges | new case |
| H2 | the same | members | 1–8 |
| J1 | `switch` dropped from the target= subcommands | members | 2, 8 |
| J2 | ls-tree `blob` record test never matching | members | 2, 8 |
| K1 | every verdict's output dropped (`continue`) | malformed | 1–7 |
| L1 | probe outcome `writable` misspelled | members | 4–7 |

File names are abbreviated: "members" is `probes-readonly-members.bats`,
"candidates" `hook-candidates.bats`, "malformed" `hook-malformed.bats`.

What each fault proves:

- F4 and F5: the near-miss negatives. The paired positive still matches under
  the widened pattern and the lowered threshold, so the red is the negative.
- F6, H1 and F10: `probes-edges.bats`'s listing, empty-stderr and `merge=1`
  assertions.
- F7: Item 2.1's `check_reached` markers. They go red together with the paired
  `check_fires`, since no fault on one hook can skip the probe in only one of
  the two runs. K1: all three paired `check_fires` positives. Under K1
  `check_quiet` cannot go red, so the red is the positive.
- G1: the BSD case's equality. G2: the spied-equals-unspied comparison, red on
  the equality line ahead of the spy log. G3: the `systemMessage` pin.
- J1: `target=feat`. J2: `match=a`, confirmed at that line, with `target=feat`
  still printed.
- F8: the plain-form `readfile=` positives in cases 4–7. H2: the empty-stderr
  checks. G1, run against the members file, turns its BSD case (8) alone red.
- F9a and F9b: the flagged tmpdir-unset and unflagged readonly-path firing
  halves of the two sweeps. Item 2.5's fault 1 covers the other halves.

## Other checks

- **Item text vs tests**: each item's fixtures, stubs, payload fields and
  assertions are present as named. Two departures are recorded in the item
  reports, and both are sound. Item 2.1 uses an inline `stub_lib` probe, because
  `stub_probe` cannot return 1. Item 2.2's git-lock text appends the follow-on
  sentence `match_git_lock` requires, built from fragments. The BSD re-run of
  Item 2.2's readonly case is a separate case, not a re-run inside the first
  one. It compares against a fresh unspied run, which holds the same contract.
- **Vacuous negatives**: every `run !`, `[ -z "$output" ]`, `[ ! -e … ]` and
  `[ ! -f "$PROBE_CALLED" ]` sits beside a positive over the same fixture. The
  readonly sweep clears `PROBE_CALLED` before each run, so the flagged run's
  "probe not reached" check is live (Item 2.5 fault 1 turned it red).
- **Zero-match sweep globs**: with every `fire-tmpdir-unset-*` and
  `fire-readonly-path-*` fixture deleted from a scratch copy, both sweeps go red
  on `text=$(cat "$f")`, because the unmatched glob stays literal. The
  `[ "$count" -gt 0 ]` line itself is unreachable as the failing line. It
  follows `hook-locks.bats`'s shape and the item asks for it. No change.
- **BSD stubs**: `hook-writes.bats` and `probes-readonly-members.bats` load
  `helpers/bsd-stubs` and each keeps one `make_bsd_stubs grep sed stat wc` case.
  G1 shows that each of those cases detects a GNU-ism on its probe path.
- **Whitespace**: new expansions are quoted. The members file's scratch repo
  path holds a space. `run_spied` joins `PATH` with `:` from
  `$BATS_TEST_TMPDIR`, which holds no colon. Residual, already documented in
  `readonly_path_text`: a path holding `#`, `&` or a backslash.
- **Stderr suppression**: no `2>/dev/null` added. The new `>/dev/null` redirects
  are stdout-only (`cat >/dev/null` draining stdin in stubs, and `jq -e .`,
  whose status is the assertion).
- **Self-quiet**: `tests/docs.bats` passes in the gate. New error text is built
  from fragments (`enoent`, `follow`) or from the cut fixtures through
  `helpers/probes.bash`.
- **Shellcheck RCA (Item 2.2)**: all six files are tracked and lint clean when
  run directly. The only output is SC1091 info on
  `source "$ROOT/lib/probes.sh"`, which the existing `probes-edges.bats` shares.
  No untracked test file remains. See Recommendations for the gate gap itself.
- **Line counts**: `hook-candidates.bats` 374, `probes-edges.bats` 341,
  `hook-malformed.bats` 217, `matchers-edges.bats` 199,
  `probes-readonly-members.bats` 178, `hook-writes.bats` 108.

## Requirements Validation

| Requirement | Status | Evidence |
| --- | --- | --- |
| FR-3 (Item 2.1) | Satisfied | three `hook-malformed.bats` cases; F3, F7, K1 |
| NFR-4 (Item 2.2) | Satisfied | `hook-writes.bats`, `probes-edges.bats`; G1–G3, F6, H1 |
| FR-7 (Item 2.3) | Satisfied | two `matchers-edges.bats` cases; F4, F5 |
| FR-4 (Item 2.4) | Satisfied | `probes-readonly-members.bats`; F1, F8, J1, J2, L1 |
| FR-5 (Item 2.5) | Satisfied | three `hook-candidates.bats` cases; F2, F9a, F9b |

**Gaps:** none.

## Positive Observations

- Every negative in the phase is paired in its own case with a positive over the
  same fixture, and the sweeps collect misses so one red names every broken
  fixture.
- `hook-writes.bats` computes the unspied output in the same case rather than
  pinning a literal, so the spied comparison is exact. The readonly case's
  `systemMessage` pin keeps that comparison from being two empty outputs.
- The members file runs its `target=`/`match=` case in a repo path holding a
  space.

## Recommendations

- **`hook-candidates.bats` before Item 4.2** (no split now): at 374 lines it has
  26 lines of room. Item 4.2's hook case (scratch repo with `sub`, payload, real
  probe, `additionalContext` check) is likely 20–25 lines, which fits, but
  barely. If the drafted case runs past about 24 lines, put it in
  `tests/hook-writes.bats` (108 lines). That file already builds a real-probe
  readonly payload on a `make_scratch_repo` tree (`readonly_payload_file`).
  Splitting now would move tests ahead of a decision that Item 4.2's actual size
  settles.
- **Precommit lints only tracked files** (OUT-OF-SCOPE: `justfile`, not in this
  phase's diff): `tracked()` lists files with `git ls-files`, so a new,
  untracked `.bats` or `.sh` skips shellcheck and `bash -n`. `just test` still
  runs it, which is how Item 2.2's lint failure got through. Adding
  `--others --exclude-standard` to that `git ls-files` call would close the gap.
  Until then, executors should `git add` new files before running the gate.
