# Item 8.0/5 code review — the no-target merge clause needs git's error

**Scope**: the implementation diff of the slice commit (`git show c46241e --
lib/`): `lib/probes-readonly-facts.sh`, `lib/verdicts.sh`,
`lib/probes-readonly.sh` (comments). The functions the change touches were
reviewed whole: `_readonly_print_facts`, `_readonly_partial_checkout_text`,
`_readonly_repo_facts`'s header, `verdict_readonly_path`. Tests, fixtures,
docs, the phantom and lock verdicts, the matchers and `hooks/annotate.sh`
were out of scope. `hooks/annotate.sh` was read only to confirm its
contract: it pipes every probe line after the outcome to the verdict
unfiltered, so the new `partial=1` line reaches it.
**Date**: 2026-09-27
**Mode**: review + fix

## Summary

The change matches the spec. The probe prints `partial=1` right after
`merge=1` exactly when the text holds one of git's three partial-checkout
errors, and only under `writable` and `nopath`: `_readonly_print_facts` is
called only from those two branches of `probe_readonly_path`. The verdict
writes the no-target restore clause only when `partial=1` is present. The
`match=` clause does not depend on `partial=1`, and `target=` with no
`match=` still gives no clause. There was one minor readability finding, now
fixed. No comment was left stale.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

None.

### Minor Issues

1. **Double-negated guard for setting the flag**
   - Location: `lib/probes-readonly-facts.sh:45` (in the commit).
   - Problem: the line was `! _readonly_partial_checkout_text "$text" ||
     partial=1`. It works, including under a caller's `set -e`: the negated
     command is exempt from errexit and the list ends in an assignment. But it
     makes the reader invert twice to see "set the flag when the text matches".
     The file's `[ … ] || act` idiom guards an action on a test's failure. This
     line bends that idiom around a predicate that has to be negated first.
   - Fix: replaced it with `if _readonly_partial_checkout_text "$text"; then
     partial=1; fi`, written over three lines. Behaviour is identical.
   - **Status**: FIXED

## Checks with no finding

- **Spec conformance.** See the table below.
- **bash 3.2 / `set -u`.** `partial` is declared with a value in both
  functions (`partial=0` in the probe, `partial=''` in the verdict). No new
  array, no case conversion, and no bash-4 construct.
- **Caller under `set -e`.** This was run by hand under `set -euo pipefail`
  (source `lib/probes.sh`, pipe text into `probe_readonly_path`):
  - the directory-creation needle with an empty command prints `nopath`,
    `merge=1`, `partial=1`, exit 0;
  - the same text under `git merge --ff-only <unresolvable>` prints the same
    three lines;
  - another tool's refusal under `git merge` prints `merge=1` and no
    `partial=1`;
  - another tool's refusal under a non-git command prints the outcome alone.

  Each run exits 0.
- **BSD tools.** The change adds no external command. Needle matching is
  `case` globbing inside bash.
- **Whitespace and multi-line text.** `case "$text" in *"$needle"*` matches
  the quoted needle literally, and `*` matches across embedded newlines. A
  needle that a hard wrap splits across two lines does not match. That is the
  intended reading, since git prints each needle on one line.
- **Self-quiet.** The third needle is built as `'cannot create'` plus
  `' directory at'`, like the other two, so no lib line holds it whole.
  `tests/docs.bats` passes inside `just precommit`.
- **Cost.** The text match now runs on every writable or nopath probe, not
  only on the no-subcommand path. It is three in-process glob matches with no
  new process, so NFR-3 is unaffected.
- **Comment accuracy.**
  - The header comments in all three files now list `partial=1`.
  - The `_readonly_partial_checkout_text` docstring names all three needles.
  - The NFR-3 remark in `_readonly_repo_facts` is accurate. Past 1000
    modified files the probe prints no `target=`, so the generic clause
    appears only under `partial=1`, and otherwise no clause appears.
  - The `target=` comment in `_readonly_print_facts` still holds: with
    `partial=1` and no merge-style subcommand, `sub` is empty and the case
    returns before any `target=` attempt.
  - `lib/probes-readonly-command.sh`'s header still describes only the facts
    that come from the command scan (`readfile=`, `merge=1`/`target=`), which
    is correct.

## Mutation run

This was one in-place mutation of the SUT, in `lib/verdicts.sh`
`verdict_readonly_path`. It is the forbidden implementation the slice exists
to rule out: the no-target restore clause for `merge=1` alone.

- Replaced `elif [ -n "$partial" ]; then` with `elif [ -n "$merge" ]; then`
  (exact-string Edit).
- Ran `tests/verdicts-readonly.bats`, `tests/hook-candidates.bats` and
  `tests/probes-readonly-facts.bats`. Two tests redded:
  - `readonly-path merge alone with no partial=1 states the act alone,
    capitalised` (verdicts-readonly, line 133);
  - `the no-target merge clause needs git's own partial-checkout error, not
    any refused write` (hook-candidates, line 204).

  The probe suite stayed green, as expected, because the mutation is on the
  verdict side.
- Restored by the inverse Edit. A `command grep -c` for the mutated line
  prints 0, the original line is back at `lib/verdicts.sh:198`, and
  `git diff -- lib/verdicts.sh` is empty. All three files ran green
  afterwards: 14, 10 and 15 passed.

## Fixes Applied

- `lib/probes-readonly-facts.sh:45-47`: the `! f || partial=1` guard became
  an `if f; then partial=1; fi` block, for readability (Minor 1).

## Requirements Validation

| Requirement | Status | Evidence |
|---|---|---|
| `partial=1` exactly when the text holds any of the three needles | Satisfied | `_readonly_partial_checkout_text` has three `case` needles; `_readonly_print_facts` prints `partial=1` iff it matched |
| `partial=1` only under `writable` and `nopath` | Satisfied | `_readonly_print_facts` is called only at `lib/probes-readonly.sh:53` (nopath) and `:78` (writable) |
| `partial=1` beside `merge=1`; the needle alone gives `merge=1` | Satisfied | the gate returns only when `sub` is empty and `partial` is 0; `merge=1` is printed, then `partial=1` |
| no-target restore clause needs `partial=1` | Satisfied | `lib/verdicts.sh:198` `elif [ -n "$partial" ]` |
| `match=` clause without `partial=1` | Satisfied | the `target=` branch does not read `partial` |
| `target=` with no `match=` gives no clause, `partial=1` or not | Satisfied | the `target=` branch leaves `rest=" $act"` when there are no matches |
| `merge=1` keeps its meaning | Satisfied | its print condition is unchanged: a merge-style segment, or `partial=1` |
| D-17: the script decides the condition | Satisfied | the verdict text holds no conditional; `partial=1` selects the clause |
| FR-4: the verdict never reads the tool text | Satisfied | the verdict reads only stdin facts; the hook pipes only the probe's lines after the outcome |
| FR-6: under 400 characters, quiet | Satisfied | the length and quiet tests pass in `just precommit` |

## Positive Observations

- Needle placement follows the brief's decision. The probe reads the text
  and the verdict reads a fact, so D-1 and FR-4 hold.
- The verdict change is a single guarded `elif`. It keeps the existing
  empty-versus-set style used for `merge` and `target`.
- The third needle is built from fragments, as the other two are.

## Gate

`just precommit`, run after the fix, exited 0. Recap line: `precommit passed:
plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links,
tests` (bats: 249 passed, 0 failed).
