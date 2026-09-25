# Review: Item 4.3 slices 2-5 — readonly-path probe (code review)

**Scope**: `lib/probes.sh` (`probe_readonly_path`, `_probe_readonly_resolve`,
`_probe_readonly_path_from_line`, the load-time source of `lib/matchers.sh`)
and `lib/matchers.sh` (`_readonly_path_line` extracted from
`match_readonly_path`), as committed in "Item 4.3/2 — readonly-path probe;
hook silent without a verdict (slices 2-5)". Tests, verdicts (Item 6.1),
memory and docs OUT.
**Date**: 2026-09-26
**Mode**: review + fix

## Summary

The probe meets the Interfaces block on the ordinary paths: line 1 is one of
`writable|readonly|nopath`, `path=` only once one was extracted, exit 0,
extraction of the matching line's first single-quoted segment, relative paths
joined plainly onto cwd (the test review's decision), empty cwd falling back
to `$PWD` as the lock probes do. Sharing `_readonly_path_line` with the
matcher removes the drift risk. The review found four defects, each confirmed
by running it: the probe aborted with no output under a `set -e` caller when
the text had no matching line; under a UTF-8 locale the matcher fired while
the probe read no path and printed grep's binary notice to stderr; an absent
path with a trailing slash tested the path itself instead of its parent; and
a dangling symlink always read `readonly`. All four are fixed and the gate
passes.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

1. **nopath aborts under a `set -e` caller**
   - Location: `lib/probes.sh` `probe_readonly_path`, the
     `line=$(printf … | _readonly_path_line)` assignment
   - Problem: `_readonly_path_line` is `grep -m1`, which exits 1 when no
     line matches. That status became the assignment's status, so a caller
     under `set -e` died silently with exit 1 and no output, where the
     interface requires `nopath` and exit 0. Reproduced:
     `bash -c 'set -e; . lib/probes.sh; printf "nothing\n" | probe_readonly_path false /; echo after'`
     printed nothing and exited 1. The same call to `probe_git_lock`
     survives (its extractor ends in `head -n 1`). The file already expects
     `set -e` callers: `_probe_lock_at` notes that its `||` status capture
     lets them survive. The hook sets no `-e`, so the hook itself was not
     affected.
   - Fix: one pipeline, `printf | _readonly_path_line | _probe_readonly_path_from_line`,
     whose status is sed's 0; the `line` variable goes.
   - **Status**: FIXED

2. **Matcher fires while the probe reads no path (UTF-8 locale, invalid byte)**
   - Location: `lib/matchers.sh` `_readonly_path_line`;
     `lib/probes.sh` `_probe_readonly_path_from_line`
   - Problem: under `C.UTF-8` (this box's default), GNU grep 3.11 treats a
     line holding a non-UTF-8 byte as binary. On the Python alternative,
     which anchors at the message and stops before the path,
     `match_readonly_path` exits 0 (fires), but `_readonly_path_line` prints
     no line and writes `grep: (standard input): binary file matches` to
     stderr. The probe therefore answered `nopath` and leaked a stray stderr
     line for a refusal whose path was right there. Reproduced with
     `/usr/bin/grep`, not the Bash tool's ugrep function. The sed extractor
     also lacked the `LC_ALL=C` that both lock extractors carry for the same
     byte-safety reason, and BSD sed exits with "illegal byte sequence" on
     such input.
   - Fix: `LC_ALL=C` on the shared grep and on the extractor's sed. Checked
     after the fix: both the Python and the `cp` shapes with an invalid byte
     fire and yield `writable` plus the path. Side effect on the matcher: the
     `cp`/prefix alternative with an invalid byte in the path now fires under
     a UTF-8 locale too (before, `.*` could not cross the byte). This makes
     the matcher byte-wise, which matches how the lock extractors and
     `detect`'s `tr` already treat input. The corpus figure does not move,
     because transcript text is valid UTF-8, and on valid UTF-8 the C and
     UTF-8 classes differ only on non-ASCII blanks.
   - **Status**: FIXED

3. **Absent path with a trailing slash tests itself, not its parent**
   - Location: `lib/probes.sh` `probe_readonly_path`, `target="${path%/*}"`
   - Problem: mkdir prints its operand as given, so a refusal can name
     `dir/new/`. `${path%/*}` of that is `dir/new`, which does not exist, so
     `-w` failed and a writable `dir` read `readonly`. That is the "not a
     sandbox effect" diagnosis, and here it was wrong. Reproduced: `rw/new/`
     under a writable `rw` gave `readonly`.
   - Fix: strip trailing slashes before taking the parent. `rw/new/` and
     `rw/new//` now give `writable`, `ro/new/` gives `readonly`, `/newtop/`
     falls to `/`, and `path=` still prints the path as extracted.
   - **Status**: FIXED

4. **Dangling symlink always reads `readonly`**
   - Location: `lib/probes.sh` `probe_readonly_path`,
     `[ ! -e "$path" ] && [ ! -L "$path" ]`
   - Problem: the `! -L` clause, carried over from the lock probes (where a
     dangling link is a present lock), sent a dangling symlink to `-w` on the
     link itself. `-w` follows the link and fails on the missing target, so
     every dangling link read `readonly`, whatever its directory allowed.
     Reproduced: a dangling link in a writable dir gave `readonly`.
   - Fix: parent fallback whenever `! -e`, so a dangling link is judged by
     the link's own directory. A code comment records the residual: a write
     through a dangling link lands in the target's directory, which may be a
     different one.
   - **Status**: FIXED

### Minor Issues

1. **Single-quote-in-path residual undocumented**
   - Location: `lib/probes.sh` `_probe_readonly_path_from_line`
   - Note: GNU coreutils prints a path holding `'` either double-quoted or
     as `'it'\''s'`. The extractor then yields `nopath` or the first quoted
     piece. The spec only says "the first quoted path", so this is
     acceptable, but the file states residuals and this one was missing.
   - **Status**: FIXED (residual added to the comment)

## Checked, no finding

- **Interface exactness.** Verified by running each input:
  - Empty stdin, `</dev/null`, no args, a no-match text, and an unbalanced
    single quote all give `nopath`, no `path=`, exit 0.
  - An existing directory, with or without a trailing slash, checks the
    directory.
  - A live symlink to a directory checks the target.
  - A path with a blank survives.
  - An unreadable parent makes `-e` fail, so the path is treated as absent;
    `-w` on that parent is then false and the result is `readonly`.
- **Extraction** reads only the `grep -m1` line, so a quoted path on another
  line cannot leak in. The `quoted path off the matching line is ignored`
  test pins this.
- **`-w` outside the sandbox.** access(2) with the real uid honours both
  mode bits and a read-only mount (EROFS), which is exactly the
  `writable`/`readonly` split. Running as root, `-w` is true except on a
  read-only mount; that falls under the spec's own residual.
- **bash 3.2 / BSD.** No bash-4 constructs are used. `grep -m` exists in BSD
  and macOS grep, and the BSD-stub case covers the grep and sed calls. There
  are no here-documents, no temp files and no `2>/dev/null`.
- **No pattern duplication.** The regex now lives only in
  `_readonly_path_line`. Sourcing `matchers.sh` from `probes.sh` follows
  `hooks/annotate.sh`'s dynamic-path pattern. Sourcing it twice from the hook
  only redefines the same functions (a `stub_lib` append to `matchers.sh`
  lands in the file that gets re-sourced, so no stub is lost).
- **Closed stdin (`<&-`) hangs** at `text=$(cat)`, because the substitution's
  pipe takes fd 0. `probe_git_lock` has the same `text=$(cat)` form, so this
  was not raised. The hook always pipes the probe's stdin
  (`printf | "$probe_fn"`), so the hook never hits it.

## Mutated-SUT run (once)

Mutation: `path=$(_probe_readonly_resolve "$path" "$cwd")` →
`path=$(_probe_resolve_path "$path" "$cwd")`, the lock probes' `.git` walk
that the test review ruled out. Applied as an exact-string replace (count
asserted 1), then `bats tests/probes-readonly.bats`, then the inverse
replace. `command grep -cF` confirmed the restore: original 1, mutant 0.
Result: only `relative path resolves against cwd` went red, on its outcome
assertion. The other 7 stayed green, as expected, since none of them uses a
relative path.

## Fixes Applied

- `lib/probes.sh` `probe_readonly_path`: the two assignments become one
  pipeline ending in sed, so exit 0 holds under `set -e` (Major 1).
- `lib/probes.sh` `probe_readonly_path`: parent fallback on `! -e` alone
  (Major 4), with trailing slashes stripped before `%/*` (Major 3), plus a
  comment giving the reason and the residual.
- `lib/probes.sh` `_probe_readonly_path_from_line`: `LC_ALL=C sed` (Major 2),
  plus the single-quote residual in the comment (Minor 1).
- `lib/matchers.sh` `_readonly_path_line`: `LC_ALL=C grep`, with a comment
  giving the reason (Major 2).

Gate: `direnv exec . just precommit` ran in the foreground and passed:
plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links,
tests (bats: 182 passed, 0 failed). Nothing committed.

## Requirements Validation

| Requirement | Status | Evidence |
|---|---|---|
| FR-4 (probe contract, A-3) | Satisfied | `probe_readonly_path` prints outcome then `path=` and exits 0 on every input tried, `set -e` caller included (after the fix) |
| FR-7 (readonly-path candidate) | Satisfied | matcher and probe share one discriminator; no verdict, so the hook never runs the probe (`declare -F` gate) |
| NFR-1 (corpus precision) | Satisfied | same regex; the move to byte-wise matching changes nothing on valid-UTF-8 transcript text |

## Recommendations

- No test pins the four fixed behaviours, and tests were OUT of this
  review. Worth adding in a follow-up test dispatch, each with a single
  observable:
  - a no-match text probed under `set -e` must still print `nopath`;
  - an absent `dir/new/` in a writable dir must read `writable`;
  - a dangling link in a writable dir must read `writable`;
  - a Python-shape refusal whose path holds a non-UTF-8 byte, run under
    `LC_ALL=C.UTF-8`, must give `writable` with an empty stderr.
