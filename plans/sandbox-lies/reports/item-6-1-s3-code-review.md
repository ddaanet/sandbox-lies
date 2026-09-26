# Review: Item 6.1 slice 3 — code review, readonly and nopath

**Scope**: `verdict_readonly_path` and `_verdict_readonly_path_tail` in
`lib/verdicts.sh`, and their comments, as the commit "Item 6.1/3 —
readonly-path readonly and nopath verdicts" changed them. Tests, the hook's
flag policy, `lib/probes*.sh` and `memory/` are out of scope.
**Date**: 2026-09-26
**Mode**: review + fix (TDD code review)

No UNFIXABLE items.

**Files changed by this review**: `lib/verdicts.sh` (only).

## Summary

The slice is correct. `readonly` and `nopath` print the detectors.md text
byte-exact. The path goes in through plain expansion and is never used as a
printf format. set -u is safe on every path the hook can take. Three minor
issues were fixed:

- two subshell forks per call
- a writable arm built differently from its readonly sibling
- two comments that repeated each other

After the fixes, the output is byte-identical to the commit's for every input
probed. The mutated-SUT run turned all four of the slice's cases red. The gate
passes.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

None.

### Minor Issues

1. **Two subshell forks to build constant text**
   - Location: `lib/verdicts.sh`, `verdict_readonly_path`
     (`subject=$(printf '`%s`' "$path")`, and
     `$(_verdict_readonly_path_tail)` in the writable and nopath arms)
   - Note: the subject and the shared tail were each built in a command
     substitution. That is one fork for the subject and a second for a
     function whose only job is to print a constant. The hook already runs
     each verdict inside `out=$(…)`, and `hooks/annotate.sh` goes out of its
     way to avoid a fork (its byte-length read: "bytes, with no fork"). A
     function that holds nothing but a constant is also a heavier form than
     the job needs.
   - Fix: the subject is now ``subject="\`$path\`"``, which is still plain
     expansion. The tail is a local `rerun` literal assigned once and used by
     both arms, so it is still one literal and cannot drift.
     `_verdict_readonly_path_tail` is removed. The SC2016 disable moves onto
     the `rerun` assignment, the one line that still carries literal
     backticks in single quotes.
   - **Status**: FIXED

2. **The writable arm split its paragraph across two printfs**
   - Location: `lib/verdicts.sh`, the `writable)` arm
   - Note: writable printed `$subject` with one `printf '%s'` and the rest
     with a second `printf '%s\n'`. The new readonly arm prints the
     subject inside one string. The two sibling arms built the same shape
     two different ways.
   - Fix: writable is now one `printf '%s\n' "$subject is writable …$rerun"`,
     the same form as readonly.
   - **Status**: FIXED

3. **The comments repeated each other and understated the byte-safety
   contract**
   - Location: `lib/verdicts.sh`, the comments above `verdict_readonly_path`
     and `_verdict_readonly_path_tail`
   - Note: the tail-sharing rationale appeared in both comments, and "so the
     two paragraphs cannot drift apart" defends the choice rather than
     stating a constraint. The byte-safety sentence named only the sed
     hazards (blanks, `&`, `\1`). It left out the printf-format hazards
     (`%`, a leading `-`) that a maintainer editing a `printf` line needs to
     know about. It also did not state the residual already recorded in the
     slice 2 review: a backtick in the path closes the code span early.
   - Fix: there is now one comment of 9 lines, down from 10 + 3. It states
     the subject rule, then the byte-safety contract ("never a printf format,
     sed or eval", listing blanks, `&`, `%`, `\1` and a leading `-`), then
     the backtick residual, then nopath's own opening, then why `rerun` is a
     single literal, then the unmatched-outcome rule.
   - **Status**: FIXED

## Fixes Applied

- `lib/verdicts.sh` `verdict_readonly_path`: the subject is built by plain
  expansion with no command substitution. The shared tail is a local `rerun`
  literal. The writable arm is a single `printf`.
- `lib/verdicts.sh`: `_verdict_readonly_path_tail` and its comment are
  removed.
- `lib/verdicts.sh`: the leading comment is rewritten as described in Minor
  3.
- File size: 164 → 155 lines.

Equivalence check: the committed `lib/verdicts.sh` (`git show HEAD:…`) and
the fixed one were each run under `set -u`, and their output compared with
`od -c`. Inputs were no path, `-n`, `%s%d%%`, ``a`b``, `/x\n\t\\`,
`  lead  `, `$(id)` and `/r/a b&c\1/x`, each crossed with the outcomes
`writable`, `readonly`, `nopath`, `bogus` and empty. Result: 0 differences.
Separately, a path holding the bytes `\377\316` came through untouched.

## Byte safety

The path reaches the output only as a `%s` argument (committed code) or by
double-quoted expansion (fixed code). Neither passes through a format string,
sed or eval. Each probed input came out byte-exact in both arms, including a
leading `-`, `%`, backslashes, a backtick, `$(…)`, blanks at either end and
invalid UTF-8. A path cannot hold a newline, because the probe emits it as
one `key=value` line.

Printf-format regressions are already pinned. The transcription fixture
`/r/a b&c\1/x` holds `\1`, which a path used as a format would turn into byte
001. Both the writable and readonly transcription cases would go red.

The residual, carried from slice 2 and now stated in the comment: a backtick
in the path closes the markdown span early. The agent reads raw text, so the
path is still there in full.

## set -u

Every variable is initialised before use. `outcome="$1"` is safe because
`hooks/annotate.sh` always passes an argument, which may be empty. `subject`
is assigned on both branches. An unknown or empty outcome drains stdin and
prints nothing (rc 0), which the hook skips.

## Conventions

- Entry points come before helpers. The committed code met this: the helper
  followed its user. The helper is now gone.
- Every literal-backtick single-quoted line carries a
  `# shellcheck disable=SC2016 # …` second comment, in the file's form.
  shellcheck is clean.
- Comment density is now one comment of contract statements, with no plan
  state and no narration.

## FR-6 lengths

These are base lengths as the `verdicts under 400 chars` case measures them:
empty stdin, `${#line1}`, all ASCII so characters equal bytes.

| outcome | base length | with `path=/r/x` | interpolated |
|---|---|---|---|
| `writable` | 392 (`The path` …) | 390 | 386 + path length |
| `readonly` | 82 (`The path` …) | 80 | 76 + path length |
| `nopath` | 377 | 377 | fixed; no path |

All three are under 400. The unbounded interpolated length of `writable` was
settled in the slice 2 review: the hook's 2 KB cap bounds it, and the FR-6
wording clause is left for whoever closes the FR-6 status line. `readonly`
stays under 400 for any path up to 323 characters. The human lines are
lowercase and use the em-dash separator.

## Mutated-SUT run (once)

Two exact-string mutants were applied together to the fixed SUT. Each one
breaks a different outcome, and the two outcomes' cases are disjoint:

- readonly arm: `"$subject is not writable outside` →
  `"The path is not writable outside`. This is the plausible-wrong readonly
  that drops the path.
- nopath arm: `refused this write.$rerun"` →
  `refused this write." # MUTANT`. This is the plausible-wrong nopath that
  leaves out the shared tail.

The run was `scripts/run-bats.sh tests/verdicts.bats tests/hook-candidates.bats`,
with the result `bats: 14 passed, 4 failed`:

- `readonly-path readonly verdict text matches detectors.md` — not ok
- `readonly-path nopath verdict text matches detectors.md` — not ok
- `readonly outcome through the hook` — not ok
- `nopath outcome through the hook` — not ok (on
  `compare modified files against the target`)

All four slice cases went red. The length case stayed green, as expected,
because it does not check content.

The SUT was restored by the inverse replace. `command grep -cF MUTANT` →
`0`. `command grep -nF` finds both original strings (lines 126 and 130).

## Directive wording (flagged, not reworded)

The text is transcribed from detectors.md and pinned verbatim, so each
concern below is for detectors.md's owner. Status: OUT-OF-SCOPE here, since
the text source is detectors.md.

1. **`readonly` carries no act.** "`<path>` is not writable outside the
   sandbox either; this is not a sandbox effect." is diagnosis only, and
   FR-6 asks for "a short paragraph of acts". The agent has to infer that it
   should handle this as an ordinary permission error and not escape the
   sandbox. Adding one act, such as choosing a writable destination or
   fixing the permission, would meet FR-6 literally. At 82 characters there
   is room for it.
2. **In the shared tail, the act order is inverted.** "Re-run the whole call
   … A merge or checkout that died here may be partial: compare modified
   files against the target first." The agent reads re-run first, and
   "first" arrives two sentences later. An agent that acts as it reads can
   re-run before it compares. Putting the merge/checkout clause before
   "Re-run" would match reading order to act order. This affects both
   `writable` and `nopath`.
3. **"the target" is undefined for a checkout.** For a merge, it is the
   merge target. For a checkout, the reader has to infer the branch being
   checked out. This is minor.
4. **`nopath`'s hedge is acceptable.** "most likely refused" followed by an
   imperative re-run is fine. The residual case is a path that is also
   read-only outside the sandbox. It costs one unsandboxed retry that then
   fails the same way, which is cheap and self-revealing.

The human lines (`read-only — real`, `read-only — sandbox allowlist`) are
curt, lowercase and give no instruction, as the user channel requires.

## Gate

```
exit=0
scripts/run-bats.sh tests/
bats: 195 passed, 0 failed — full log: /tmp/claude-1000/sandbox-lies-bats.JE48d8
precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests
```

## Requirements Validation

| Requirement | Status | Evidence |
|---|---|---|
| detectors.md `readonly` text | Satisfied | transcription case, both the path form and the `The path` form |
| detectors.md `nopath` text (opening sentence + writable from `Re-run`) | Satisfied | transcription case; a single `rerun` literal shared with writable |
| FR-4 (probe outcome → verdict) | Satisfied | hook cases for readonly and nopath, stubbed probe, `$PROBE_CALLED` |
| FR-6 (< 400, lowercase human line, quiet, no removal) | Satisfied for the text; wording concern 1 on "acts" | lengths above; `verdict text is quiet` passes |
| FR-5 / flag policy | Out of scope | slice 4 |

## Positive Observations

- The read loop keeps the `|| [ -n "$line" ]` guard, so a final line with no
  newline is not lost.
- An unknown outcome drains stdin and prints nothing, matching
  `_verdict_lock_present`, and the hook's `[ -n "$out" ]` skip relies on this.
- nopath ignores a stray `path=` line, as its contract says, and does not
  interpolate one.

## Recommendations

- detectors.md owner: consider wording concerns 1 and 2. Any change there
  means updating the transcription cases and `readonly_path_rerun_tail` in
  `tests/verdicts.bats` in the same commit.

No in-scope refactoring needed beyond what was applied.
