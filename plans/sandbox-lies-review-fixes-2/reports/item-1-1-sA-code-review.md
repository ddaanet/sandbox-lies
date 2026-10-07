# Review: Item 1.1 Slice A — code review (after GREEN)

**Scope**: `git show HEAD -- lib/probes.sh lib/verdicts.sh` (commit subject
`Item 1.1/A — resume-lost transcript probe`). Read against `hooks/annotate.sh`
(how it calls a probe and a verdict, FR-3) and the A-3 contract in the
`lib/probes.sh` header. Tests were out of scope except to run them and to add a
red test for each behaviour-changing fix.

**Date**: 2026-10-07

**Mode**: review + fix (dispatch `item-1-1-sA-code-review`). Nothing committed.

## Summary

The verdict guard is correct. The probe had four defects:

- It printed `found` when it had checked nothing.
- It died with a message on stderr under `set -u` when `HOME` was unset.
- It read an empty `CLAUDE_CONFIG_DIR` the way CC does not.
- It aborted under a caller's `failglob`.

Two of them reach the agent as a false claim. One is the `found`-for-nothing
case. The other is a BSD-only partial extraction that could also read `found`.
All four are fixed in `lib/probes.sh`, each after a test that reds on its
assertion against the slice commit.

The fix adds one outcome token, `unknown`, for "nothing could be checked". The
verdict has no text for it, so the hook stays silent for this name and still
emits the other names' verdicts.

**Overall Assessment**: Ready

## Files changed

- `lib/probes.sh`: `probe_resume_lost` and its comment.
- `tests/probes-resume.bats`: six new cases.
- `tests/hook-resume.bats`: one new case.

## Issues Found

### Critical Issues

None.

### Major Issues

1. **No id extracted printed `found`**
   - Location: `lib/probes.sh` `probe_resume_lost`, before the fix
     (`verdict=found` default, `sed` inside `< <(…)`).
   - Problem: `sed`'s status is lost behind the process substitution. A `sed`
     that fails, or extracts nothing, runs the loop zero times, and the `found`
     default goes out. Slice B gives `found` its own verdict, so the agent would
     be told a transcript exists when no path was tested.
   - A second route to the same lie is BSD-specific. BSD `sed` under a UTF-8
     locale exits on an invalid byte anywhere in its input (`_probe_lock_path`'s
     comment, which this repo already relies on). It prints the ids before that
     line and drops the rest. Only the ids before the byte are tested, so a lost
     id after it reads `found`. Reproduced with a stub: one transcript of two,
     an invalid byte first in the text, `found`.
   - Fix: the ids are captured with `ids=$(LC_ALL=C sed …) || ids=`, so a failed
     `sed` discards partial output. No ids, or no root (below), prints `unknown`
     and exits 0. `sed` runs under `LC_ALL=C`, as `_probe_lock_path` does.
     `sed`'s own stderr passes through, as the lock probes pass through what
     they cannot classify.
   - Fail-safe decision: `unknown`, not `lost`. `lost` is also a claim made on
     no evidence ("the sandbox lost it, run unsandboxed"). Silence is what FR-3
     gives any runtime failure. An exit 0 with an outcome the verdict has no
     text for keeps the A-3 contract (exit 0) and drops only this name's
     verdict. A non-zero exit would hit the hook's `|| exit 0` and drop every
     name's verdict.
   - **Status**: FIXED. Tests: "no id extracted is unknown, never found" and "an
     invalid byte under a UTF-8 locale still extracts the ids".

2. **`HOME` unset under `set -u` killed the probe with stderr output**
   - Location: `root=${CLAUDE_CONFIG_DIR:-$HOME/.claude}`.
   - Problem: with `CLAUDE_CONFIG_DIR` unset and `HOME` unset, bash aborts the
     probe's subshell on the unbound variable. The hook then exits 0 with no
     stdout, but `HOME: unbound variable` reaches stderr. That breaks the hook
     header's "with jq, the hook writes nothing to stderr". Reproduced by hand
     through `hooks/annotate.sh`.
   - Fix: `root=${HOME:+$HOME/.claude}` in the fallback branch, and an empty
     root prints `unknown`. CC's homedir falls back to a passwd lookup when
     `HOME` is unset or empty (libuv). The probe does not reproduce that lookup,
     so it says `unknown` rather than guess.
   - **Status**: FIXED. Tests: "HOME and CLAUDE_CONFIG_DIR both unset is
     unknown" (probe) and "no config root to search, silent" (hook, stdout and
     stderr merged, empty). Positive partner: "HOME unset, CLAUDE_CONFIG_DIR
     set, still found".

3. **An empty `CLAUDE_CONFIG_DIR` fell back to `HOME/.claude`**
   - Location: the same `:-` expansion.
   - Problem: CC 2.1.292 resolves its config dir as
     `(process.env.CLAUDE_CONFIG_DIR ?? join(os.homedir(), ".claude")).normalize("NFC")`.
     This was read from the installed binary at
     `~/.local/share/claude/versions/2.1.292`, function `we`, with `o()`
     returning `process.env.CLAUDE_CONFIG_DIR`. `??` keeps an empty string, so
     CC's `projects/` is then relative to CC's cwd, not under `HOME`. The
     probe's `:-` searched `HOME/.claude` and could report `found` for a
     directory CC never reads.
   - Fix: `${CLAUDE_CONFIG_DIR+set}` selects the variable when it is set at all.
     An empty value gives an empty root, which prints `unknown`.
   - **Status**: FIXED. Test: "CLAUDE_CONFIG_DIR set but empty is unknown"
     (transcripts under the `HOME` fallback; the slice commit prints `found`).

### Minor Issues

1. **A caller's `failglob` aborted the probe**
   - Location: `for f in "$root"/projects/*/"$id".jsonl`.
   - Problem: under `failglob`, an id with no transcript is an expansion error.
     In a non-interactive shell that kills the shell running the probe, with
     `no match: …` on stderr. That shell is the `$(…)` subshell in the hook.
     `failglob` reaches the hook through an exported `BASHOPTS`, which bash
     applies at startup (checked:
     `env BASHOPTS=failglob bash -c 'shopt failglob'` reads `on`). It also
     reaches a bats file sourcing the library.
   - Fix: the function body is a subshell, `probe_resume_lost() ( … )`, with
     `shopt -u failglob`. `nullglob` needs nothing. Under it the loop does not
     run, and without it the unmatched literal fails `[ -f ]`. Both leave `hit`
     empty, so the outcome is `lost`, checked by hand against the slice commit.
     A `shopt -s nullglob` that was tried as well was removed: its mutation
     reddened nothing, so it was speculative.
   - **Status**: FIXED. Test: "a caller's failglob does not abort the glob".

2. **Stdin read twice over**
   - Location: `text=$(cat)` followed by `printf '%s\n' "$text" | sed`.
   - Note: `sed` now reads the probe's stdin directly. This is folded into the
     fix for Major 1, not a separate change.
   - **Status**: FIXED.

### Checked, no issue

- **Whitespace and glob characters in the config path**: `"$root"` is quoted
  inside the pattern, so a space, `*`, `[` or newline in it is literal. The ids
  are `[0-9a-fA-F-]+`: no glob character and no leading-dash operand, since the
  path starts with the root.
- **bash 3.2 and BSD**: no form newer than 3.2 is used: `local` in a
  subshell-bodied function, `shopt -u failglob` (bash 3.0+), `${v+set}`,
  `${v:+w}` (safe under `set -u`) and `< <(…)`. No here-string, which bash
  before 5.1 spools through a temp file (NFR-4). `sed -nE` and `[[:space:]]` are
  BSD-safe, and `LC_ALL=C` covers the locale divergence. The BSD-stub cases
  pass. No bash 3.2 binary is on this box, so this rests on reading the code,
  not a run.
- **Verdict gate** (`lib/verdicts.sh`): `[ "${1-}" = lost ] || return 0` matches
  the hook's contract that an outcome the verdict has no text for prints
  nothing, exit 0. `${1-}` is safe under `set -u` with no argument. `unknown`
  and `-` print nothing, and `tests/verdicts.bats`' `-` case pins the gate
  against an inverted (`!= found`) form.
- **No new `2>/dev/null`**.

## Fixes Applied

- `lib/probes.sh` `probe_resume_lost`:
  - The body is now a subshell, with `shopt -u failglob`.
  - The root is `CLAUDE_CONFIG_DIR` when set, even empty, else
    `${HOME:+$HOME/.claude}`.
  - The ids are captured as `ids=$(LC_ALL=C sed -nE …) || ids=`.
  - An empty root or empty ids prints `unknown` and returns 0.
  - The loop reads `< <(printf '%s\n' "$ids")`.
  - The comment states CC's resolution (2.1.292), the `unknown` cases, the
    `LC_ALL=C` reason and the `failglob` reason.
- `tests/probes-resume.bats`: six cases, listed below.
- `tests/hook-resume.bats`: one case, listed below.

## Evidence for each new test

Each was red on its assertion against the slice commit, and green after the fix.
Suite runs: `probes-resume` 11 passed, 5 failed before; 16 passed after.
`hook-resume` 3 passed, 1 failed before; 4 passed after.

1. "no id extracted is unknown, never found". A `sed` stub prints a message and
   exits 1, with an empty config dir.
   - Red: `[ "$output" = unknown ]`, because the slice commit prints `found`.
   - The world that fails it: a probe defaulting to an outcome on no ids.
   - Also asserts that `sed`'s stderr passes through verbatim.
2. "an invalid byte under a UTF-8 locale still extracts the ids". A stub exits
   with BSD's illegal-byte message whenever `LC_ALL` is not `C` and the input
   holds `\377`. Only `ID_1` has a transcript.
   - Red: `[ "$output" = lost ]`, because the slice commit prints `found` (shown
     by hand).
   - Discriminates: a probe that only maps a failure to `unknown` still fails
     it. Only extracting under `C` reads `lost`.
3. "HOME and CLAUDE_CONFIG_DIR both unset is unknown". Transcripts sit under the
   would-be fallback.
   - Red: `[ "$status" -eq 0 ]`, because the probe died on the unbound variable.
4. "HOME unset, CLAUDE_CONFIG_DIR set, still found". Green on both sides, since
   the behaviour exists. This is the positive partner of 3: it fails a fix
   returning `unknown` whenever `HOME` is unset. See the mutation proof.
5. "CLAUDE_CONFIG_DIR set but empty is unknown". Transcripts sit under
   `HOME/.claude`.
   - Red: `[ "$output" = unknown ]`, because the slice commit prints `found`.
6. "a caller's failglob does not abort the glob". Only `ID_1` has a transcript.
   - Red: `[ "$status" -eq 0 ]`, because of the `failglob` expansion error.
7. `hook-resume.bats` "no config root to search, silent". The hook runs under
   `env -u HOME -u CLAUDE_CONFIG_DIR`, with stderr merged.
   - Red: `[ -z "$output" ]`, because `HOME: unbound variable` was in the
     output.
   - Paired with "no transcript, today's verdict", which emits for the same text
     once a root exists.

## Mutation proof

Each mutation was an exact replacement of a once-occurring string. Its landing
was shown by `command grep -cF` returning 1, then the case ran red. The
replacement was then applied with the strings swapped, `command grep -cF`
returned 0, and the case ran green.

- Case 4: `if [ "${CLAUDE_CONFIG_DIR+set}" = set ]; then` became
  `if [ -n "${HOME-}" ] && [ "${CLAUDE_CONFIG_DIR+set}" = set ]; then`. Red on
  `[ "$output" = found ]`. Restored: 0 hits, green.
- Case 2: `ids=$(LC_ALL=C sed -nE` became `ids=$(sed -nE`. Red on
  `[ "$output" = lost ]`. Restored: 0 hits, green.
- Case 6: `    shopt -u failglob` became `    : shopt -u failglob`. Red on
  `[ "$status" -eq 0 ]`. Restored: 0 hits, green.
- `    shopt -s nullglob` became `    : shopt -s nullglob`. The case stayed
  green, so the line was removed (Minor 1).
- The optional mutated-SUT run used a plausible but forbidden probe:
  `[ -f "$f" ]` became `[ -e "$f" ]`. "a directory named <id>.jsonl is not a
  transcript" redded on `[ "$output" = lost ]`. Restored: 0 hits, green.

## Gate

`just precommit` ran unsandboxed in the foreground and exited 0. 330 bats passed
and 0 failed (323 before, plus 7). The checks that passed were plugin.json,
hooks.json, shellcheck, bash -n, rumdl, line limits, links and tests.

## Requirements Validation

| Requirement | Status | Evidence |
| --- | --- | --- |
| D-a probe | Satisfied, widened | `lost` and `found` as specified; adds `unknown` (Major 1-3) |
| D-b verdict (`lost` part) | Satisfied | `lib/verdicts.sh` guard; `found` text is Slice B |
| FR-3 silence on failure | Satisfied | hook case 7; no stderr from the probe on HOME, failglob |
| NFR-4 writes nothing | Satisfied | no here-string or temp file in the probe |

## Hand-offs

These items are out of this dispatch's scope:

- **Interface**: the outline's Item 1.1 interface reads "stdout is `lost` or
  `found`". It is now `lost`, `found` or `unknown`. Item 4.1 (`lib/probes.sh`
  header outcome list) and Item 5.2 (`detectors.md` Probe paragraph) should name
  `unknown` and its causes. Slice B's `found` verdict must keep printing nothing
  for `unknown`. Its contract already says so: "any other outcome prints
  nothing".
- **Residuals for Item 5.2**:
  - A relative non-empty `CLAUDE_CONFIG_DIR` is resolved against the hook's cwd,
    where CC resolves it against its own.
  - The hook reads its own environment's `CLAUDE_CONFIG_DIR`, not one the
    command set inline for its `claude` (the E5 shape).
  - CC's NFC normalisation of the config path is not reproduced.
  - An exported `GLOBIGNORE` would filter the glob.
- **Possible stub extension**: `make_bsd_stubs`' `sed` has no illegal-byte rule.
  Case 2 carries a local one. A shared rule would also exercise the other
  suites' `sed` calls, which is a wider change than this slice.

No REFACTOR-NEEDED items.
