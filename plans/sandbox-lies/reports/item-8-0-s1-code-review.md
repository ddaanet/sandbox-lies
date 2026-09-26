# Review: Item 8.0 slice 1 — lock verdicts word the re-run by the flag (code)

**Scope**: implementation changes in commit 0492468 — `lib/verdicts.sh`,
`hooks/annotate.sh`. Tests out of scope (not edited).
**Date**: 2026-09-26
**Mode**: review + fix

## Summary

The slice routes the payload flag into `verdict_git_lock` and
`verdict_config_lock` as `$2`. Two helpers, `_lock_rerun` and `_lock_retry`,
word *Re-run* and *Retry* from lock-detectors.md's flag table. config-lock
`mask` reads `path=` from stdin to swap in the update-config act. The hook
passes `"$flag"` as every probed verdict's second argument. The wording matches
the spec exactly in every variant, and the budget and portability hold. The
findings were comment narration, two shellcheck directives the change left
stale, and redundant defaults on internal helpers. All are fixed.

**Overall Assessment**: Ready

## Checks against the contract

- **Wording (lock-detectors.md).** Every variant was printed from the fixed
  code and compared with the spec by eye:
  - git-lock `mask`, `orphan` and `unknown` under both flags;
  - config-lock `mask` with a `.git/config.lock` path under both flags;
  - config-lock `mask` with a `.claude/settings.json.lock` path under both
    flags;
  - config-lock `orphan` and `unknown` under both flags.

  The *Re-run* sentence ends in a period, and *Retry* is finished by `;` in
  `orphan` and `.` in `unknown`. The settings act replaces *Re-run* under
  either flag. No variant contains "if it already ran". The old trailing
  "Run the `git config` or `git remote` write unsandboxed…" sentence is gone,
  as the spec requires. `gone` and `held` are unchanged.
- **Absent `$2` under `set -u`.** The public verdicts use `${2:-false}`. With
  `$2` absent, `verdict_git_lock mask` and `verdict_config_lock unknown`
  print the flag-false wording. A value other than `true` (such as `TRUE`)
  also reads as false. `$1` stays required, as it was before the slice.
- **bash 3.2 / BSD.** The code uses `${var#prefix}`, `local a="$1" b="${2:-…}"`,
  a nested `"$(fn "$flag")"` inside a double-quoted string, and escaped
  backticks. It adds no arrays, `[[ =~ ]]`, `${var,,}` or external tools. The
  `read -r … || [ -n "$line" ]` loop copies the existing
  `_verdict_lock_present` form.
- **FR-6 400-character budget.** Line 1 lengths with no probe lines:
  - git `mask`: 248 (flag false) / 246 (flag true);
  - config `mask`: 152 / 150, or 153 with the settings act;
  - `orphan`: 183 / 149;
  - `unknown`: 129 / 95.

  `orphan` with `bytes=0 age=0` is 201. The longest variant is 248.
- **Hook.** `"$fn" "$outcome" "$flag"` on the probed branch only. The flag
  reaches `verdict_readonly_path` too, which ignores `$2`. The unprobed branch
  still calls `"$fn" </dev/null`. The flag values the jq filter emits are
  exactly `true` and `false`.

## Issues Found

### Critical Issues

None.

### Major Issues

None.

### Minor Issues

1. **A narration clause in the helper comment**
   - Location: `lib/verdicts.sh`, `_lock_rerun`/`_lock_retry` comment
   - Note: "Neither wording carries the old flag-neutral "if it already ran"
     clause this replaces" retells the change's history. That belongs in the
     commit, not the code. The header also carried a clause arguing against an
     alternative ("rather than leaving a condition in the text for the agent
     to evaluate"). D-17 states that rule, and the comment already cites it.
   - **Status**: FIXED. Both clauses were cut, and the constraints were kept:
     any value but `true` reads false, and `_lock_rerun` returns a full
     sentence while `_lock_retry` returns a fragment.

2. **Two stale `SC2016` directives**
   - Location: `lib/verdicts.sh`, `verdict_git_lock` `mask` and
     `verdict_config_lock` `mask` printfs
   - Note: Both printfs are now double-quoted with escaped backticks, so the
     "backticks are literal prose" suppression no longer applies to them.
     shellcheck is clean without the directives.
   - **Status**: FIXED. Removed both.

3. **"flag absent reads false (D-17)" said five times**
   - Location: `lib/verdicts.sh` — the header, the helper comment, the
     `verdict_git_lock` and `verdict_config_lock` comments, and the
     `_verdict_lock_present` comment
   - Note: The same clause appears at five sites, which makes it a repeated
     phrase rather than a contract. Only the public boundary defaults the
     flag.
   - **Status**: FIXED. The clause now appears only in the file header, which
     documents the public contract. The per-function signature comments
     remain.

4. **Defaults on internal helpers that never fire**
   - Location: `_lock_rerun`, `_lock_retry` (`${1:-false}`), and
     `_verdict_lock_present` (`${3:-false}`)
   - Note: Every caller passes the already-defaulted `$flag`, so these
     defaults guard a state that cannot occur. The helpers' `*)` branch
     already maps any non-`true` value to false.
   - **Status**: FIXED. They now take `"$1"` and `"$3"`, and
     `_verdict_lock_present`'s signature comment reads `<flag>`, not `[flag]`.

5. **A parenthetical that recites the hook comment's own callers**
   - Location: `hooks/annotate.sh`, FR-4 comment
   - Note: "(D-17: verdict_git_lock and verdict_config_lock word their
     re-run/retry clause by it; a verdict that ignores a second argument, as
     the others do, is unaffected)" lists the current callers. A maintainer
     needs the contract instead: every probed verdict receives the flag and
     must tolerate it.
   - **Status**: FIXED. It now reads "…and the flag becomes its second
     argument (D-17), which a verdict not worded by the flag ignores."

6. **Stdin wording in the `verdict_config_lock` comment**
   - Location: `lib/verdicts.sh`, `verdict_config_lock` comment
   - Note: "(including no stdin at all)" suggests the function copes with a
     missing stdin, but it reads until EOF. The case it actually covers is no
     `path=` line.
   - **Status**: FIXED. It now reads "any other path, or none".

## Fixes Applied

- `lib/verdicts.sh` header — cut the "rather than leaving a condition…"
  clause and reflowed the lines.
- `lib/verdicts.sh` `_lock_rerun`/`_lock_retry` comment — cut the history
  clause and the redundant "(D-17)/absent" wording.
- `lib/verdicts.sh` `_lock_rerun`, `_lock_retry` — changed `case "${1:-false}"`
  to `case "$1"`.
- `lib/verdicts.sh` `verdict_git_lock` — changed the signature comment to the
  signature alone, and removed the stale `SC2016` directive above the `mask`
  printf.
- `lib/verdicts.sh` `verdict_config_lock` — merged the signature and
  stdin-contract comment and changed "no stdin at all" to "or none". Removed
  the stale `SC2016` directive above the `mask` printf.
- `lib/verdicts.sh` `_verdict_lock_present` — changed `flag="${3:-false}"` to
  `flag="$3"`, changed the signature to `<flag>`, cut the D-17/absent clause
  and reflowed the comment.
- `hooks/annotate.sh` FR-4 comment — replaced the parenthetical with the
  contract.

## Verification

- `shellcheck lib/verdicts.sh hooks/annotate.sh`: clean.
- The slice suites on the fixed code:
  - `tests/verdicts-locks.bats`: 4/4 passed;
  - `tests/verdicts.bats`: 8/8 passed;
  - `tests/hook-locks.bats`: 13/13 passed.
- Mutated-SUT run (once). The mutation makes both lock verdicts ignore the
  flag, which is the plausible-but-forbidden implementation this slice rules
  out. It was an exact-string replace in `lib/verdicts.sh`,
  `flag="${2:-false}"` → `flag=false`, at both occurrences. `grep -c` counted
  2 before the replacement, and the target string did not occur elsewhere.
  Results:
  - `tests/verdicts-locks.bats`: 4/4 red, all on assertions. Examples:
    line 108 expected "Retry the command once", and line 200 failed
    `grep -qF "$true_wording"`.
  - `tests/hook-locks.bats`: 2/13 red, both on assertions. "mask paragraph
    words the re-run by the flag" and "config-lock mask names config.lock and
    the settings act by path" (line 228, `grep -qF -- "$rerun"`) failed. The
    other 11 do not concern the flag wording.
  - `tests/verdicts.bats`: 8/8 green. This is expected: after the split, this
    file holds the length and quiet tests, which pass whatever the flag
    wording, and the flag-wording assertions live in `verdicts-locks.bats`.

  Restored by the inverse replace. `grep -c 'flag="${2:-false}"'` gives 2,
  and `cmp` against a pre-mutation copy matches.
- `just precommit`: exit 0 (its own status, captured on its own). The passing
  checks were plugin.json, hooks.json, shellcheck, bash -n, rumdl, line
  limits, links and tests (200 passed).
- Nothing committed. `hooks/annotate.sh` and `lib/verdicts.sh` are modified
  in the tree.

## Requirements Validation

| Requirement | Status | Evidence |
|---|---|---|
| D-17 (the script decides the condition) | Satisfied | `_lock_rerun`/`_lock_retry` pick the wording from the flag; no variant contains "if it already ran" |
| FR-4 (a probe feeds its verdict) | Satisfied | `hooks/annotate.sh` passes the outcome, the probe's remaining lines on stdin, and the flag as `$2` |
| FR-6 (under 400 characters, acts only) | Satisfied | The longest variant is 248 characters; the text consists of acts |
| D-7 (no removal, directive wording) | Satisfied | No variant instructs removing anything; `orphan` still reports state only |
| Slice: absent `$2` reads false | Satisfied | `${2:-false}` at both public verdicts; checked with `$2` absent |
| Slice: settings act by path, under either flag | Satisfied | The `*/.claude/settings.json.lock` case; a `.git/config.lock` path keeps *Re-run* |

**Gaps:** none.

## Positive Observations

- The *Re-run*/*Retry* table lives in one pair of helpers, which both lock
  detectors and `_verdict_lock_present` share, so the flag wording has a
  single source.
- config-lock `mask` reuses the `read -r … || [ -n "$line" ]` loop from
  `_verdict_lock_present`, so a final line with no trailing newline is still
  read.
- The hook change is a single argument, and verdicts that are not worded by
  the flag need no change.

## Recommendations

None. No refactoring was flagged (no `REFACTOR-NEEDED`).
