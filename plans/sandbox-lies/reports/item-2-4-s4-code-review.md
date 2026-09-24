# Review: Item 2.4 / slice 4, the holder check (code review, d)

**Scope**: `lib/probes.sh` as changed by HEAD (`✨ Item 2.4/4 — a held lock
names its holder`). Tests are out of scope and were not edited.
**Date**: 2026-09-25
**Mode**: review + fix

## Summary

The slice added `_probe_holder_pid` and `_probe_fuser_pid` and a `held` branch
that runs before the size and age reads. The code gave the right outcome, but
it broke NFR-4 (`mktemp` in a function Item 4.1 runs inside the hook). Its
fuser comment also misdescribed fuser's stream layout. The lsof branch did not
meet the stderr standard, and the pid parse relied on unquoted expansion. I
reworked the holder check into one function, `_probe_holder_pids`. It keeps
stderr in a variable, sends stdout through fd 3 and has one expected-noise
rule. The first pid is now parsed with glob-free parameter expansion.
`tests/probes.bats` passes 8/8 and `just precommit` passes.

**Overall Assessment**: Ready (the four list-revision cases below are still
unpinned by tests)

## fuser's real stream layout on this box (psmisc 23.7)

Measured before choosing the fix, on a path with a quote and a space:

- Unheld: exit 1, stdout empty, **stderr empty**. The GREEN comment said
  fuser writes `<path>:` "on every call that resolves the path, whether or not
  a holder is found". That is false for psmisc. The same comment's first
  sentence said the opposite.
- Held (one holder): exit 0, stdout `     8`, space-padded with **no trailing
  newline**, stderr `<path>:\n`.
- Two holders: stdout `     8    15`, stderr still one `<path>:` line.
- Missing file: exit 1, stderr `Specified filename <path> does not exist.`
- Merged (`2>&1`), the layout is `<path>:      8\n`. That interleaving depends
  on fuser's own flushing, so stripping a prefix from the merged stream was
  rejected. The stderr capture with stdout on fd 3 keeps the two streams
  apart structurally.

## Issues Found

### Critical Issues

1. **`mktemp` in the probe breaks NFR-4 / A-8**
   - Location: `lib/probes.sh` `_probe_fuser_pid` (`err_file=$(mktemp)`)
   - Problem: the hook runs with `$TMPDIR` unset. Item 4.1 runs this probe
     there, so every held-lock probe would write under `/tmp`. When `/tmp` is
     full, `mktemp` fails and `$(cat "$err_file")` errors. The design says
     "The hook writes nothing". `tests/hook.bats` and `tests/matchers.bats`
     pin that for `detect` with a `mktemp` spy and a missing `TMPDIR`, but
     not yet for the probes.
   - Fix: `{ err=$(tool "$path" 2>&1 >&3 3>&-); } 3>&1`. The tool's stdout
     goes to the function's own stdout through fd 3, and its stderr goes into
     `err`. No file is written. fd 3 is re-bound only for the group and
     closed on the tool, so bats' fd 3 and the held tests' no-hang guarantee
     are unaffected. Scratch check (not shipped): with a real held lock,
     `PATH=<mktemp spy>:$PATH TMPDIR=<missing dir>`, the probe printed
     `held` / `pid=<holder>` and the spy log was never created.
   - **Status**: FIXED

### Major Issues

1. **lsof branch: stderr not handled, `head` closes the pipe**
   - Location: `_probe_holder_pid`, `lsof -t "$path" | head -n 1`
   - Problem: on hosts with FUSE or unreadable mounts, lsof prints `lsof:
     WARNING: can't stat() … file system …` plus an "Output information may
     be incomplete" line on every call. The hook would pass that noise to
     stderr each time. A vanished lock produces a status error for the path.
     Exit 1 means no holder, which the code handled only by accident.
     `head -n 1` could SIGPIPE lsof. That was harmless without `pipefail`,
     but it was a second parse path that differed from fuser's.
   - Fix: `lsof -w -t "$path"`. `-w` is lsof's own portable switch (Linux
     and macOS lsof 4.x) that turns off warnings only. An error about the
     named path is not a warning, so it still arrives and goes through the
     same capture-and-match as fuser. This is a named suppression of one
     documented message class, not a blanket `2>/dev/null`. The reason is in
     a comment next to the call. `head` is gone: both tools' raw pid lists go
     to one parse. Scratch check with an lsof stub on `PATH`: it was called
     as `-w -t <path>`, its extra stderr was passed through, and the output
     was `held` / `pid=42` from `42\n43\n`.
   - **Status**: FIXED

2. **Fuser comment misstated the stream layout; the match was exact-only**
   - Location: `_probe_fuser_pid` header comment and the `!= "$path:"` test
   - Problem: see the layout above. The exact match also turned any
     access-code letters on the same line into "unexpected" stderr. psmisc
     prints `c`/`e`/`r`/`m` there, and other builds use their own letters.
   - Fix: stderr is expected when it is `<path>:` followed only by letters.
     The comment now says what each build prints and when. Anything else is
     passed through whole. Scratch checks: stub output `<path>:ce` gave empty
     stderr. Stub output `<path>:m` plus `fuser: something odd` passed both
     lines through, and the result was still `held` / `pid=77`.
   - **Status**: FIXED

3. **A lock that vanishes mid-check leaked the tool's complaint to stderr**
   - Location: holder check before the stat-based vanish check (item 5 of the
     dispatch)
   - Problem: I checked the GREEN's ordering claim. It is true for the
     outcome: the holder check finds no pid, then `stat` fails on the absent
     path and the probe prints `gone`. But fuser (and lsof) report the
     missing file on stderr first. So the vanish case the stat branch keeps
     quiet was noisy one step earlier.
   - Fix: the stat rule now applies to the holder tool too. Its stderr is
     dropped when the lock is absent afterwards. Scratch check with a fuser
     stub that removes the lock and prints the missing-file line: `gone`,
     `path=`, empty stderr.
   - The ordering comment was also rewritten. See the next issue for why
     "the holder exited, so the path is gone" is not the whole story.
   - **Status**: FIXED

### Minor Issues

1. **`for first in $out` split words and expanded globs**
   - Location: `_probe_fuser_pid`
   - Fix: parameter expansion only, `pids=${pids#"${pids%%[0-9]*}"};
     holder_pid=${pids%%[!0-9]*}`. It drops what precedes the first digit and
     keeps that digit run. No splitting, no globbing, and it works on both
     tools' layouts: fuser's space padding with no newline, and lsof's one
     pid per line. A build that appends access letters to stdout pids also
     parses. Bash 3.2 safe.
   - **Status**: FIXED

2. **Box-specific wording in a shipped comment**
   - Location: "lsof is absent on this box …"
   - Fix: the comment now states the residual without naming a host: "the
     lsof branch runs in the suite only on hosts that have lsof."
   - **Status**: FIXED

3. **`set -u` and portability**
   - `err`, `rest` and `pids` are always assigned before they are read.
     `${var//[[:alpha:]]/}`, `${var#"…"}` and `${var%%[!0-9]*}` all exist in
     bash 3.2. No new GNU-only flag was added. The path is absolute from git,
     and after slice 7 it is always absolute, so no `--` is needed and none
     is portable to psmisc fuser. No `2>/dev/null` was added.
   - **Status**: FIXED (no change needed beyond the rework; recorded)

4. **The holder check sees open descriptors only, so some live git locks read
   `orphan`**
   - Location: design of the `held`/`orphan` split (`detectors.md` git-lock
     table)
   - Evidence: `git commit -qam m` with a pre-commit hook that sleeps.
     During the hook, `.git/index.lock` exists (129 bytes) and
     `fuser -v .git/index.lock` exits 1 with no holder. A git lock whose
     holder is alive but has the file closed therefore reads `orphan`. The
     `orphan` verdict ("retry unsandboxed; a second identical failure means
     it predates this session") still leads somewhere sane, but the "no
     process holds it" wording is wrong for that case. The code comment now
     states this limit.
   - **Status**: OUT-OF-SCOPE. The verdict wording (Item 4.1) and `docs/`
     are scope OUT for this dispatch. This is for the orchestrator's
     phase-boundary corrector or design pass.

## Fixes Applied

- `lib/probes.sh`: `_probe_holder_pid` and `_probe_fuser_pid` are replaced
  by one `_probe_holder_pids <path>`. It picks lsof (`-w -t`) else fuser,
  sends stdout through fd 3 and holds stderr in a variable (no file). It
  drops expected stderr (`<path>:` plus letters, or anything once the lock is
  absent) and passes the rest on. The comment block states the measured
  layouts, the `-w` reason and the residual.
- `lib/probes.sh` `probe_git_lock`: the first pid is parsed by glob-free
  parameter expansion. The ordering comment is corrected: a lock removed
  mid-check reads `gone`, a closed-but-live lock reads unheld, and a holder
  exiting after the tool saw it reads `held`.

## Verification

- `scripts/run-bats.sh tests/probes.bats` (foreground): **8 passed, 0
  failed**.
- Mutated-SUT run, done once: the expected-shape test was replaced in place
  by `if false; then`, so every fuser stderr is passed through. Result:
  `held lock names the holder` and `held lock under a quoted, spaced path`
  both failed on `[ -z "$stderr" ]`, and 6 passed. The exact-string reverse
  replacement was applied afterwards, and a `grep` confirmed the original
  line was back. The held tests therefore do detect wrong stderr handling.
  They do not detect a temp-file write (see below).
- Slices 5–9 still go red against this code. Slice 5: `/dev/null` has many
  holders, so the result is `held`, not `mask`. Slice 5's GREEN must place
  the character-device test before the holder check. Slice 6: with no tool,
  the result is `orphan`, not `unknown`. Slice 7: the relative path tests
  absent against the process cwd. Slice 8: `probe_config_lock` is still a
  stub. Slice 9: the stat stub refuses `-c`, so no `age=` is printed and
  stderr is not empty.
- `cd /Users/david/code/sandbox-lies && just precommit` (foreground), final
  line: `precommit passed: plugin.json, hooks.json, shellcheck, bash -n,
  rumdl, line limits, links, tests` (103 passed, 0 failed).
- `pgrep -x sleep` was empty after the runs (rc 1). `pgrep -f 'sleep 30'`
  matches only the Bash tool's wrapper shell, whose command line contains
  that string.

## For the list revision

Proposed tests for `tests/probes.bats`. None are pinned today, and the old
`mktemp` code passed all 8 tests.

1. **Probe writes nothing** (mirrors `tests/hook.bats` "needs no temp dir"
   and `tests/matchers.bats` NFR-4): `hold_lock "$lock"`, then
   `make_spy "$spy" "$calls" mktemp`. Run with
   `run --separate-stderr env PATH="$spy:$PATH" TMPDIR="$BATS_TEST_TMPDIR/does-not-exist" bash -c 'source "$1"; probe_git_lock false /' _ "$ROOT/lib/probes.sh"`
   and the error text on stdin. Assert `held`, the exact `pid=`, empty
   stderr, and `[ ! -e "$calls" ]`. Add the same for an unheld present lock
   (`orphan`) and an absent one, so every branch is covered. This needs
   `load helpers/spy`.
2. **Lock vanishing during the holder check reads `gone`, quietly**: put a
   `fuser` stub first on `PATH` (and no `lsof`, via a tools-only `PATH`
   dir as in slice 6). It removes `$1`, prints fuser's missing-file line on
   stderr and exits 1. Assert `gone`, `path=` and empty stderr, for both
   flags. Red today if the absence rule is removed.
3. **Unexpected holder-tool stderr is passed through**: a `fuser` stub that
   prints `<path>:` and a foreign line on stderr and a pid on stdout. Assert
   `held`, that pid, and the foreign line in `$stderr`. Also a stub printing
   `<path>:ce` gives empty stderr, which pins the access-letter tolerance.
4. **lsof decides when present**: an `lsof` stub printing `42\n43\n` next
   to a `fuser` stub that would answer differently. Assert `pid=42`, one
   `pid=` line, and that the stub was called with `-w -t <path>`. This
   exercises the lsof branch on hosts that lack lsof, which closes the
   residual in the code comment. It also settles the several-holders
   question (first pid, one line) that the test review left open, if the
   list adopts first-pid.
