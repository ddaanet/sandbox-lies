# Review: Item 2.4 / slice 1 — code review

**Scope**: `lib/probes.sh` as committed in the slice GREEN (HEAD, "Item 2.4/1 —
absent lock under the sandbox is mask"). Tests out of scope (not edited).
**Date**: 2026-09-25
**Mode**: review + fix (code review, TDD slice)

## Summary

The GREEN is minimal: an extractor plus one guarded `mask` branch. Nothing
beyond slice 1 is implemented. I found and fixed three problems. The
extractor cut a path off at a single quote inside it. It depended on the
locale for non-UTF-8 bytes. And the header carried slice-progress notes that
every later slice would have to rewrite. I checked the `set -u` claims and
they are true, but the wording was ambiguous, so I rewrote it. The empty-path
edge case goes to the list revision and is not guarded here.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

1. **A path containing a single quote was truncated**
   - Location: lib/probes.sh `_probe_lock_path` (was line 22)
   - Problem: git formats `Unable to create '%s.lock': %s` without escaping
     the path. The capture `'\([^']*\)'` stops at the first quote. Checked
     empirically: `/a/it's/r/.git/index.lock` came out as `path=/a/it`.
     The path is absent, so the probe returned `mask` for the wrong path. In
     later slices the stat and holder check would also run on that wrong
     path.
   - Fix: capture `\(.*\.lock\)': `. Greedy, it runs to the last `.lock': ` on
     the line, which is the same `'…\.lock'` shape `match_git_lock` gates on.
     It also works whatever the strerror tail says. Checked: the quoted path,
     a path with spaces, a rebase `\r`-prefixed line and the
     `fire-lock-add-commit.txt` fixture all extract whole.
   - Residual (documented in the comment): a path that itself contains the
     sequence `.lock': ` would be cut at its last occurrence. There is no clean
     fix, because git's output is ambiguous at that point.
   - **Status**: FIXED

### Minor Issues

1. **Extraction depended on the locale**
   - Location: lib/probes.sh `_probe_lock_path`
   - Note: under `C.UTF-8`, a path with an invalid UTF-8 byte (`\351`) gave
     `path=` empty on GNU sed, because `.` does not match the byte (checked).
     BSD sed under a UTF-8 locale exits with "illegal byte sequence" on
     stderr. That is stderr noise the probe must not make, and on macOS it
     would lose the path. The hook's text reaches the probe through jq, which
     emits valid UTF-8, so this is a hardening. But
     `lib/matchers.sh` already uses `LC_ALL=C` on its `tr` for the same BSD
     reason.
   - Fix: `LC_ALL=C sed …`. Byte-wise matching keeps the bytes, as checked.
   - **Status**: FIXED

2. **Header carried plan state that rots**
   - Location: lib/probes.sh header (was lines 8–12)
   - Note: the "Item 2.4 slice 1: … Later slices add … until slice 8"
     paragraph describes build progress, not the code. Each later GREEN would
     have to edit it, and nothing forces that. The one durable fact in it,
     that the leading U is case-insensitive as in `match_git_lock`, moved to
     the extractor's comment.
   - **Status**: FIXED

3. **`set -u` justification: claims true, wording ambiguous**
   - Location: lib/probes.sh header (was lines 14–16)
   - Verification: `hooks/annotate.sh:21` is `set -u`, before it sources
     `lib/matchers.sh` (line 26) and `lib/verdicts.sh` (line 28).
     `lib/matchers.sh:14` and `lib/verdicts.sh:7` each have their own
     top-level `set -u`. `tests/probes.bats` does not set `-u`. All the GREEN
     report's claims hold.
   - Problem: "sourced by hooks/annotate.sh" read as if it applied to
     `probes.sh`. The hook does not source `probes.sh` yet (Item 4.1 wires it).
   - Fix: reworded. `set -u` as in matchers/verdicts; the hook sets it before
     sourcing those; bats does not, so it is set here for direct sourcing. The
     code is unchanged.
   - **Status**: FIXED

## Checked, no finding

- **bash 3.2 / BSD:** `local`, `$(cat)`, `[ -e ]`/`[ -L ]` and `printf` are
  all 3.2-safe. The `sed -n` BRE uses only `\( \)`, `.*`, `\.`, `[Uu]` and a
  `p` flag, all POSIX. `head -n 1` is POSIX. No GNU-only flags.
- **Whitespace:** every expansion is quoted. A path with spaces extracts and
  prints whole (checked).
- **No stderr suppression:** there is no `2>` anywhere in `lib/probes.sh`.
  Absence is guarded with `[ ! -e ] && [ ! -L ]`. These are builtins with no
  tool call, so nothing needs silencing. `cat >/dev/null` in the config-lock
  stub discards stdin, not stderr.
- **Stdin fully consumed** (`text=$(cat)`) before extraction. The hook's
  writer can never get EPIPE from an early-exiting probe. Residual: if a text
  over the pipe buffer has two or more lock lines, `head` exits and a second
  write kills `sed` with SIGPIPE. That is silent. The inner `printf` could
  then see EPIPE on the unwritten tail. Not worth code.
- **Dangling symlink at the lock path:** `-L` is true, so it is not treated
  as absent and falls through. That is correct for slice 5's
  symlink-to-`/dev/null` fixture too (`-e` is true there).
- **Self-quiet (FR-11):** `bash lib/matchers.sh < lib/probes.sh` gives no
  output, rc 1. `tests/docs.bats` is green inside `just precommit`.

## Empty path (no lock line)

`[ -e "" ]` is false and `[ -L "" ]` is false. So on text with no lock line
and flag `false`, the probe prints `mask` and `path=` (empty), exit 0
(checked). That is a wrong claim: nothing was probed.

In production the hook only calls the probe after `match_git_lock` has fired
(Item 4.1). Its `'.*\.lock'` gate guarantees a non-empty capture under the
new regex. So the case is reachable only by calling the probe directly.
Guarding it here would add behaviour that no slice-1 test pins. I left it for
the list revision (below); this slice does not own it.

## Later slices stay red

With the SUT as it stands, each later slice's test fails:

- Slice 2 (flag `true`): no output.
- Slices 3, 4, 6 (present lock): no output.
- Slice 5 (symlink to `/dev/null`, `-e` true): no output.
- Slice 7 (relative `.git/index.lock`): tested against the process cwd, not
  `$2`, so it is `mask` or nothing, never `orphan`.
- Slice 8: the config-lock stub prints nothing.
- Slice 9: builds on slice 3's code, so its redness is that slice's concern.

Nothing beyond slice 1 is implemented.

## Mutated-SUT run

The mutation is the forbidden "path from `$2`, not the text":
`printf 'path=%s\n' "$path"` became `printf 'path=%s\n'
"$2/.git/index.lock"`. It was applied by in-place replacement and restored
by the inverse replacement (grep confirmed line 33 restored).

```
not ok 1 absent lock, sandboxed, is mask
#   `printf '%s\n' "$output" | grep -qxF "path=$lock"' failed
bats: 0 passed, 1 failed
```

The test went red on the `path=` assertion.

## Fixes Applied

- lib/probes.sh `_probe_lock_path`: capture `\(.*\.lock\)': ` (a quote
  inside the path survives), `LC_ALL=C` on `sed`, and a comment covering both
  and the residual.
- lib/probes.sh header: removed the slice-progress paragraph and reworded
  the `set -u` rationale.

## Gates

- `scripts/run-bats.sh tests/probes.bats`: `bats: 1 passed, 0 failed`
- `shellcheck lib/probes.sh`: clean
- `just precommit` final line: `precommit passed: plugin.json, hooks.json,
  shellcheck, bash -n, rumdl, line limits, links, tests` (96 passed)

## Requirements Validation

| Requirement | Status | Evidence |
|---|---|---|
| A-3: line 1 token, `path=` line, exit 0 (slice 1 reach) | Satisfied | test green; `mask`/`path=` printed, trailing `printf` returns 0 |
| Path from the error text | Satisfied | mutation run reds when path comes from `$2` |
| FR-4 / detectors.md `mask`: flag false, path absent | Satisfied | `[ ! -e ] && [ ! -L ] && flag = false` |
| NFR-2 portability | Satisfied | POSIX BRE, `head -n`, `LC_ALL=C` |
| No stderr suppression | Satisfied | no `2>` in file |

## For the list revision

1. **No lock line is not `mask`**: text without a lock line (e.g.
   `printf 'hello\n'`), flag `false`. Proposed expectation: line 1 `unknown`
   and no `path=` line, exit 0, empty stderr. Today it prints `mask` +
   `path=`. It fits after slice 6, where `unknown` exists.
2. **Quote and space in the lock path**: build the slice-3 fixture under a
   directory named with a space and a single quote (e.g.
   `$BATS_TEST_TMPDIR/it's here/r`), lock present, flag `false`. Expect
   `orphan` and `path=` equal to the full path. This pins the new capture and
   the quoting through `stat`/`wc`/`fuser`. The test review already
   recommended the space half.
3. (Optional) **Non-UTF-8 byte in the path**, under `LC_ALL=C.UTF-8`:
   absent lock, flag `false`. Expect `path=` to be byte-exact. This pins the
   `LC_ALL=C` hardening, which is otherwise untested.

## Positive Observations

- The absence guard is builtin-only, so the no-stderr rule holds with no
  suppression at all.
- `text=$(cat)` consumes stdin before extraction, so a writer piping into
  the probe never sees a broken pipe.
- The GREEN held scope: flag-`true` and present-lock paths fall through
  silently, which leaves slices 2–8 red.
