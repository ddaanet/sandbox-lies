# Review: Item 4.3 slice 2 — test review (between RED and GREEN)

**Scope**: slice 2's cases and helpers in `tests/check-jq.bats` (uncommitted),
the RED report `item-4-3-s2-red.md`; the stub `hooks/check-jq.sh` for stub
completion only.
**Date**: 2026-10-05
**Mode**: review + fix

## Summary

Three new cases and four helpers pin the jq-absent notice: one JSON object, the
style reset leading `systemMessage`, `SessionStart` event name, `jq` named in
both channels, status 0, stderr empty, and the same stdout under a missing
`TMPDIR` and under BSD stubs. The structure is sound and the RED is genuine.
Three gaps let a wrong script pass or a correct one fail for host reasons; all
are fixed, and the suite is still red on its assertions.

**Overall Assessment**: Ready

## Mechanical first check

Before and after the fixes, `bats tests/check-jq.bats`: case 1 (slice 1,
jq present) ok; cases 2, 3 and 4 not ok, each failing in `assert_notice` on the
`jq -e -s 'length == 1 …'` assertion (it prints `false` on the stub's empty
stdout). None passed, none errored, and the status and stderr assertions before
it pass. The stub needs no completion.

## Wrong-reason hunting

Checked against a scratch copy of `hooks/` and `tests/` under `$TMPDIR` with
candidate scripts in place of the stub. The tree's stub was not touched.

| Candidate script | Case 1 | Cases 2–4 | Pins |
| --- | --- | --- | --- |
| correct (`command -v jq` gate, `printf` of fixed JSON, `\u001b` escape) | ok | ok | the tests are satisfiable |
| always prints the notice | **not ok** | ok | slice 1 pins silence; the pair pins "notice iff jq absent" |
| gates on a fixed `/usr/bin/jq` path, not PATH | ok | **not ok** | the check must be PATH-based |
| notice plus a second `{}` object | ok | **not ok** | exactly one object |
| notice plus a trailing `done` line | ok | **not ok** | no non-JSON trailer |
| no style reset | ok | **not ok** | reset present |
| reset after a leading `x` | ok | **not ok** | `startswith` anchors it |
| raw ESC byte instead of `\u001b` | ok | **not ok** (after fix 2) | valid JSON whatever the jq |
| `mktemp` before printing | ok | 2 and 4 ok, **3 not ok** (after fix 3) | missing `TMPDIR` |

The other questions in the dispatch:

- **jq reachability.** The jq-less PATH is the `nojq-bin` directory alone, plus
  the BSD stub directory in case 4. Neither holds `jq`. The directories of the
  symlink targets are not on PATH. Each run is a fresh process, so no `hash`
  table carries over. `bash -c` reads no rc file, with two exceptions: it
  sources `BASH_ENV`, and some builds read `~/.bashrc` when `SSH_CLIENT` is
  set. Exported functions are inherited too. Every one of these came through
  the original `env` (finding 1).
- **Complete-stdout comparison.** `[ "$output" = "$plain" ]` compares all of
  stdout except trailing newlines, which `run` strips. For a hook's JSON stdout
  that difference is whitespace after the value, so it does not matter: Claude
  Code and `jq` parse both forms the same.
- **Tool-set portability (NFR-2).** `bash sed grep mktemp stat wc cat dirname`
  are all in the macOS and FreeBSD base systems, so no host the suite targets
  lacks one. A missing tool used to fail with no message; it now names itself
  (finding 4).

## Issues Found

### Critical Issues

None.

### Major Issues

1. **The jq-less run inherited the host environment that can restore `jq`**
   - Location: `tests/check-jq.bats` `run_nojq`
   - Problem: `env CLAUDE_PLUGIN_ROOT=… PATH=…` passes through `BASH_ENV`,
     exported `BASH_FUNC_*` functions and `SSH_CLIENT`. Both bashes (the
     `bash -c` and the registered command's inner `bash`) honour them, so a
     host setting any of them can put `jq` back in reach. A correct script then
     stays silent and the cases red for the wrong reason. Reproduced:
     with `BASH_ENV` pointing at a file that prepends `/usr/bin` to PATH, the
     correct candidate fails cases 2–4 under the original form and passes all
     four after the fix.
   - Fix: `env -i`, keeping only `CLAUDE_PLUGIN_ROOT`, `TMPDIR`, the caller's
     assignments and `PATH`. The shell runs as `"$NOJQ_BIN/bash"`, the
     symlinked bash.
   - **Status**: FIXED

2. **A raw ESC byte passed wherever the host's jq accepts it**
   - Location: `tests/check-jq.bats` `assert_notice`
   - Problem: `startswith($esc + "[0m")` holds whether the script writes the
     reset as the JSON escape `\u001b` or as a raw ESC byte. A raw control
     character is invalid JSON, and Claude Code's parser rejects it (Node's
     `JSON.parse` refuses it; checked). jq 1.7 also rejects it, so here the
     raw-ESC candidate fails only by luck of the host's jq version. A more
     lenient jq would pass it, and the notice would never display.
   - Fix: assert that stdout holds no raw ESC byte (`[[ "$output" != *"$esc"* ]]`)
     before the jq checks, which removes the dependence on the jq version.
   - **Status**: FIXED

### Minor Issues

3. **`env -i` would have dropped `TMPDIR` from the plain run**
   - Location: `tests/check-jq.bats` `run_nojq`
   - Problem: this issue came from fix 1. With no `TMPDIR`, the plain run fell
     back to `/tmp`, which the sandbox does not let a command write. The
     `mktemp` candidate then failed case 2 as well as case 3, so the
     missing-`TMPDIR` contrast was lost.
   - Fix: carry `TMPDIR="${TMPDIR:-/tmp}"` before the caller's assignments.
     env applies its assignments in order, so case 3's `TMPDIR` replaces it.
     The `mktemp` candidate now fails case 3 only.
   - **Status**: FIXED

4. **Tool lookup by `command -v`, with no message on a miss**
   - Location: `tests/check-jq.bats` `setup_nojq`
   - Problem: `command -v` returns a bare name for a function or alias, which
     would make a dangling relative symlink. A missing tool failed with no
     message.
   - Fix: `type -P` for `jq` and each tool. A miss prints
     `setup_nojq: no <tool> on PATH` and returns 1.
   - **Status**: FIXED

## Fixes Applied

- `tests/check-jq.bats` `setup_nojq`: `type -P` lookups, plus the named-miss
  message.
- `tests/check-jq.bats` `run_nojq`: `env -i`, `TMPDIR` carried over and
  overridable, `"$NOJQ_BIN/bash"` as the shell, and a comment giving the reason
  for each.
- `tests/check-jq.bats` `assert_notice`: an assertion that stdout holds no raw
  ESC byte.

After the fixes: `shellcheck -x tests/check-jq.bats` is clean, the file is 110
lines, and the suite gives case 1 ok and cases 2–4 not ok on the `length == 1`
assertion.

## Requirements Validation

| Requirement | Status | Evidence |
| --- | --- | --- |
| Slice 2: one JSON object | Satisfied | `jq -s 'length == 1 and … object'`; the two-object and trailer candidates red |
| `systemMessage` opens with the reset, contains `jq` | Satisfied | anchored `startswith`, plus the raw-ESC guard |
| `hookEventName` `SessionStart`; `additionalContext` contains `jq` | Satisfied | `assert_notice` |
| status 0, stderr empty | Satisfied | `assert_notice` |
| same stdout with `TMPDIR` missing | Satisfied | case 3; the `mktemp` candidate reds it |
| same stdout under `make_bsd_stubs sed grep mktemp stat wc` | Satisfied | case 4 |
| test's own `jq` by absolute path first | Satisfied | `JQ=$(type -P jq)` before PATH changes |
| NFR-2 (portable) | Satisfied | the tool set is all in the BSD base system; BSD re-run case |
| D-12 / FR-1 | Satisfied for this slice | together with slice 1, "notice iff jq absent" is pinned |

## Positive Observations

- `jq` is resolved before PATH changes, and every assertion runs through `$JQ`.
- Each variant run is compared with the plain run after both pass
  `assert_notice`, so equality cannot hold between two empty outputs.
- `[ ! -e "$NOJQ_BIN/jq" ]` makes the jq-less premise explicit.

## Recommendations

- GREEN: write the reset as the six characters `\u001b` inside the `printf`
  format (the format needs `\\u001b`), not as `\033`.
- GREEN may extend `NOJQ_TOOLS` if the script needs another tool. A tool missing
  from the set would show up as stderr on cases 2–4.
