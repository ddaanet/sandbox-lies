# Review: Item 2.4 / slice 9 — code review (d)

**Scope**: HEAD (`✨ Item 2.4/9 — the lock's mtime is read the BSD way
first`). In scope: `lib/probes.sh` (the mtime read) and
`tests/helpers/bsd-stubs.bash` (the `stat` and `wc` stubs). Tests were not
edited.
**Date**: 2026-09-25
**Mode**: review + fix

## Summary

The BSD-first read works. On this box it falls through to GNU by exit
status, and a vanish under BSD still reaches `gone`. The runbook asks for the
value to be checked as all digits before the arithmetic. The GNU fallback's
value skipped that check, and it is captured together with stderr (`2>&1`),
so a successful call that also wrote to stderr would have sent that text into
`$(( ))`. The BSD branch's digit check has a real use on GNU: with a file
named `%m` in the cwd, GNU `stat -f %m` exits 0 and prints filesystem
reports. The old comment said that call "exits 1", which was wrong. The
`stat` stub passed `stat <file>` with no `-f` straight to GNU, which
contradicted its own "not emulated → exit 2" rule. All of this is fixed. One
residual on BSD is recorded in a comment.

**Overall Assessment**: Ready

## Answers to the dispatch's questions

- **Is a GNU success digit-checked?** It was not. GNU `stat -c %Y` does not
  write to stderr when it succeeds, but a shim or wrapper `stat` on `PATH`
  could, and `2>&1` would put that text into `mtime`. `$(( ))` evaluates a
  variable's text as an expression. Fixed: both branches now go through
  `_probe_is_seconds`. When the GNU value is not seconds, it goes to stderr
  and the age line is dropped. That is the same path as a failure, including
  the `gone` check. I checked by hand with a stub `stat -c` printing
  `12 junk` and `warn` (exit 0): the output was `orphan`, `bytes=7`, no
  `age=`, and both lines on stderr.
- **A BSD `-f` failure that is not a vanish** gets hidden behind BSD's
  refusal of `-c`. I decided against a fix. Telling "unsupported form" from
  "failed on this file" means either matching the refusal text (fragile, and
  it depends on the locale) or capturing the `-f` stderr and choosing between
  two messages. In both cases the choice needs the dialect, and learning the
  dialect costs a probe. The case is also nearly unreachable. The presence
  test just stat'ed the path, and BSD `stat` without `-L` is an lstat, so
  even a dangling link succeeds. What is left is a race with a permission
  change, or EIO. The outcome is unaffected either way: `orphan`, no `age=`.
  The residual is now one sentence in the comment.
- **Vanish under BSD**: this reaches `gone`. The `-f` attempt fails, `-c` is
  refused (exit 1), and the `[ ! -e ] && [ ! -L ]` check does not depend on
  the error text. I checked by hand with a wrapper that removes its operand
  and then execs the BSD `stat` stub, under `make_bsd_stubs stat wc`: `gone`,
  `path=`, empty stderr, for both flags. The suite does not pin this (see the
  list revision).
- **bash 3.2**: `${var//pat/}`, `${1#-}` and `local` are all in bash 2+.
  `[ -n ]` is required, because `${x//[0-9]/}` of an empty string is also
  empty. `[0-9]` follows the file's existing pid parse, and stat prints ASCII
  digits.
- **Stubs vs other suites**: only `tests/probes.bats` loads the `stat`/`wc`
  stubs, and the other suites use `grep`, `sed` and `mktemp`. The full suite
  passed 115/115 before and after my edits.

## Issues Found

### Major Issues

1. **The GNU fallback's value reached `$(( ))` unchecked**
   - Location: `lib/probes.sh` `probe_git_lock`, the `elif ! mtime=$(stat
     -c %Y …)` line
   - Problem: the runbook requires a digit check before the arithmetic, but
     only the BSD branch had one. The value is captured with `2>&1`, so any
     stderr from a successful call (for example a wrapper `stat`) would be
     evaluated as an arithmetic expression.
   - Fix: added the helper `_probe_is_seconds`, used by both branches. The
     GNU branch now reads `elif ! mtime=$(stat -c %Y …) || !
     _probe_is_seconds "$mtime"`, so a non-seconds value goes to stderr with
     the age line dropped. It passes through the same vanish check first.
   - **Status**: FIXED

### Minor Issues

1. **A strict digit check would have regressed a pre-1970 mtime into
   noise**
   - Location: `lib/probes.sh`, the new check
   - Note: GNU `-c %Y` and BSD `-f %m` print a negative number for a
     pre-epoch mtime (checked: `-315622800`). HEAD's BSD branch rejected it.
     On BSD that fell through to the refusal of `-c`, which put noise on
     stderr and dropped the age. `_probe_is_seconds` accepts one leading
     minus. Checked by hand after the fix, with and without the BSD stubs:
     `age=2105956844`, empty stderr.
   - **Status**: FIXED

2. **The comment was inaccurate and long**
   - Location: `lib/probes.sh`, the mtime comment block
   - Note: it said GNU `-f` "exits 1", but with a file named `%m` in the cwd
     it exits 0 and prints two filesystem reports (checked). That case is why
     the BSD branch's digit check matters on GNU at all. The block has been
     rewritten at the same length. It covers both branches' contract (used
     only on exit 0 and when the value reads as seconds), the `%m` case,
     exception 1 of 2, the BSD residual, and a non-seconds value going to
     stderr.
   - **Status**: FIXED

3. **The `stat` stub passed no-`-f` forms to GNU stat**
   - Location: `tests/helpers/bsd-stubs.bash` `_bsd_stub_stat`
   - Note: `stat <file>` and `stat -L <file>` exec'd GNU stat. BSD's default
     output is not GNU's, so this broke the stub's own rule that anything not
     emulated exits 2 rather than reaching GNU with a different meaning. It
     now exits 2, and the five-line passthrough is gone. The not-emulated
     message used to read `got -f ` for a bare `stat f`. It now echoes the
     original arguments: `(got: stat <args>)`. The comment says no `-f` is
     not emulated. I rechecked every form: `f`, `-L f`, `-x f`, `-f %a f` →
     rc 2; `-c %Y f`, `-Lc %Y f`, `--format=%Y f`, bare `-f` → BSD refusal
     and usage line, rc 1; `-f %m f`, `-f%m f f`, `-L -f %m f`, `-f %m
     <dangling link>`, stdin → mtimes, rc 0; a missing file → rc 1.
   - **Status**: FIXED

## Mutated-SUT run

- Mutation: the BSD branch without its check, `if mtime=$(stat -f %m "$path"
  2>/dev/null) \ && _probe_is_seconds "$mtime"; then` → `if mtime=$(stat -f
  %m "$path" 2>/dev/null); then`. This is the plausible implementation that
  uses the `-f` stdout on exit 0 without checking it.
- `scripts/run-bats.sh tests/probes.bats tests/probes-edges.bats` → **20
  passed, 0 failed.** Every test stayed green. No fixture has the `-f`
  attempt exit 0 with non-seconds output, so the check is unpinned. A test
  for this is proposed below.
- Restore: inverse replacement. Grep count of the mutant line: 0. Grep count
  of `&& _probe_is_seconds "$mtime"; then`: 1.

## For the list revision

- **`a file named %m in the cwd`** (pins the BSD branch's check; proven by
  the mutation above): a 7-byte unheld lock, no stubs, the probe run from a
  cwd holding an empty file named `%m`, flag `false`. Expect `orphan`,
  `bytes=7`, an `age=` integer, empty stderr. Under the mutant, the
  filesystem report reaches `$(( ))`. Checked by hand on the fixed SUT:
  `orphan`, `bytes=7`, `age=0`, rc 0.
- **`non-seconds stat output is dropped`** (pins the GNU branch's check,
  Major 1): a stub `stat` that exits 1 for `-f`, and for `-c` prints `12
  junk` on stdout and a line on stderr, exit 0. Expect `orphan`, `bytes=7`,
  no `age=`, and both lines on stderr.
- **`pre-epoch mtime has an age`** (Minor 1): `touch -m -t 196001010000`,
  once plain and once under `make_bsd_stubs stat wc`. Expect an `age=`
  integer greater than now minus the Unix epoch, and empty stderr.
- **`vanished lock is gone under BSD stat`**: the existing vanish case, with
  its removing `stat` wrapper exec'ing the `make_bsd_stubs stat` stub
  instead of the real stat. Expect `gone`, `path=`, empty stderr, for both
  flags. Checked by hand: this passes.

Placement is `tests/probes-edges.bats`, next to the other stub cases. That
file stands at 358 lines, so four cases may need the orchestrator to weigh
the 400-line cap.

## Fixes Applied

- `lib/probes.sh` — new `_probe_is_seconds` (digits, one optional leading
  minus), placed with the other helpers above `probe_git_lock`. Both mtime
  branches now use it. The GNU branch also routes a non-seconds value to
  stderr and drops the age. The comment block is rewritten: accurate about
  the `%m` case, with the BSD residual and the non-seconds routing.
- `tests/helpers/bsd-stubs.bash` `_bsd_stub_stat` — no `-f` now exits 2 as
  not emulated (the GNU passthrough is removed), the message echoes the
  original arguments, and the comment is updated.

## Verification

- Full suite (inside `just precommit`): 115 passed, 0 failed.
- `just precommit`, final line: `precommit passed: plugin.json, hooks.json,
  shellcheck, bash -n, rumdl, line limits, links, tests`
- Nothing committed. `git diff --stat`: `lib/probes.sh`,
  `tests/helpers/bsd-stubs.bash`.

## Requirements Validation

| Requirement | Status | Evidence |
|-------------|--------|----------|
| Item text: mtime from BSD `stat -f %m` when it succeeds, else GNU `stat -c %Y` | Satisfied | `probe_git_lock` mtime `if`/`elif` |
| Item text: BSD attempt's output used only on exit 0, stderr exception commented | Satisfied | comment block, exception 1 of 2 |
| Slice 9: stderr kept out of the value, all digits checked before arithmetic | Satisfied after fix | `_probe_is_seconds` on both branches |
| Item text: `stat` stub refuses `-c` as BSD does, serves `-f %m` from real `stat -c %Y` | Satisfied | stub forms checked above |
| NFR-2 portability (bash 3.2, no new GNU-only flags) | Satisfied | expansions are bash 2+; no new flags |

## Positive Observations

- Selecting the dialect by exit status, with no second probe, keeps the
  common path at one `stat` on BSD and two on GNU, and needs no state.
- The vanish check keys on the filesystem, not the error text, so it is the
  same under both dialects.
- The `stat` stub's `getopts` parse refuses bundled and long GNU options the
  way BSD does.
