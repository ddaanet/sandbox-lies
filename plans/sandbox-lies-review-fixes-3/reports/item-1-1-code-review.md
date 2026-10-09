# Review: Item 1.1 code review with mutation testing

**Scope**: commit 5bfd2e2 — `lib/probes.sh`, `lib/probes-readonly.sh`, and the
commit's tests (slice-5 rewrites included). Out: `lib/verdicts.sh`, Item 1.2,
the old-contract comments (Item 7.7), the readfile=/match=/target= newline
skips.
**Date**: 2026-10-09
**Mode**: review + fix (code review of the GREEN commit; one test added)

## Summary

`_probe_path_line` is correct: one print path for every `path=` line, empty
path prints nothing, `LC_ALL=C` pin on the builtin, `%q` form. All seven print
sites (six in `_probe_lock_at`, one in `probe_readonly_path`) go through the
helper, and `command grep` finds `'path=` printed only inside the helper. Both
newline guards are gone. Of eleven mutations, ten went red on their own
assertion; one survived (the vanish-mid-probe `gone` site) and is now pinned
by a new test.

**Overall Assessment**: Ready

## Mutation proof

Method for each row: exact string replacement (string occurring once, checked
by the script, which refuses otherwise), `command grep`-equivalent count of
the new text = 1 after applying, run only the listed bats files in the
foreground, restore by swapping the strings, count of the mutation text = 0
after (for rows 2 and 3 the "new" text is a substring of the original, so the
restore was proved by reading line 92: `LC_ALL=C printf -v quoted %q "$1"`).
`git diff -- lib` is empty at the end.

| # | Behaviour | Mutation | Result |
|---|-----------|----------|--------|
| 1 | Empty-path rule | helper `if [ -n "$1" ]` to `if true` | red: `probes.bats` 5 (`mask and no path=`, line 107 `[ "$output" = mask ]`); `probes-config.bats` 4 (line 111) and 6 (line 153, mask half) |
| 2 | `LC_ALL=C` prefix | `LC_ALL=C printf -v quoted` to `printf -v quoted` | red: `probes.bats` 6 (e-acute, line 126); `probes-lock-newline.bats` 7 (newline and e-acute); `probes-readonly.bats` 8 and 17 (curly path) |
| 3 | `%q` itself | `%q` to `%s` | red: `probes.bats` 3, 4, 6, 9; `probes-lock-newline.bats` 1-7 (all); `probes-readonly-members.bats` 6 |
| 4a | Site: absent, flag true (`gone`) | helper call to raw `printf 'path=%s\n' "$path"` | red: `probes-lock-newline.bats` 6, 7; `probes-config.bats` 6 line 162 (the `gone` half of the pathless test) |
| 4b | Site: absent, flag false (`mask`) | same | red: `probes.bats` 3, 4, 5, 6; `probes-lock-newline.bats` 1; `probes-config.bats` 4, 6 |
| 4c | Site: character device | same | red: `probes-lock-newline.bats` 5 |
| 4d | Site: held | same | red: `probes-lock-newline.bats` 4 |
| 4e | Site: gone after vanish mid-probe | same | **survived** (all of `probes.bats`, `probes-lock-newline.bats`, `probes-config.bats` green). Fixed: new test `git-lock vanishing mid-probe: ...`; rerun red on `assert_lines` (test 7 of 8) |
| 4f | Site: final orphan | same | red: `probes.bats` 9 (line 203); `probes-lock-newline.bats` 2, 3 |
| 4g | Site: `probe_readonly_path` | same | red: `probes-readonly-members.bats` 6; `probes-readonly.bats` 1, 8-14, 16, 17 |
| 5a | Removed guard, `probe_readonly_path` newline arm | `if [ -z "$path" ]` to `... \|\| [[ $path == *$'\n'* ]]` | red: `probes-readonly-members.bats` 6 (line 158, expects `writable`) |
| 5b | Removed guard, lock `pathline` | in the helper, `if [ -n "$1" ]` to `... && [[ $1 != *$'\n'* ]]` | red: `probes-lock-newline.bats` 1-8 (all), `probes-readonly-members.bats` 6 |
| 6 | Slice-5: `probes-config.bats` `appends .lock` | row 3 (`%q` to `%s`) | red: `probes-config.bats` 3, line 74 |
| 7 | Slice-5: `probes-config.bats` two `mask`/`gone` pathless sites | rows 1 and 4a | red at line 153 (mask) and 162 (gone), each its own assertion |
| 8 | Slice-5: `probes-readonly.bats` blank-form and curly literals (10 tests) | row 3 | red: tests 1, 8-14, 16, 17 |
| 9 | Slice-5: second site of each two-site test (`curly mkdir` x2, `touch`/`ln`, `curly`/`bash` on BSD) | helper corrupts every call after the first (marker file in `BATS_TEST_TMPDIR`) | red at the second site: `probes-readonly.bats` 8 (line 230), 14 (line 321), 17 (line 386); the first-site assertion passed in each |
| 10 | Slice-5: `probes.bats` non-UTF-8 byte and quote-and-space | row 3 | red: tests 3 (line 75) and 9 (line 203) |

Rows 2, 3, 4a-4g, 5a, 5b and 1 were run on the unmodified suite of the commit,
except 4e's rerun, which includes the new test.

## Issues Found

### Major Issues

1. **Print site after a mid-probe vanish was unpinned**
   - Location: `lib/probes.sh` (the `gone` print after the `stat` reads);
     `tests/probes-lock-newline.bats` header called it a residual with "no
     deterministic trigger".
   - Problem: mutation 4e (that site printing the raw path) left every test
     green. The trigger is deterministic: a `stat` stub on `PATH` that removes
     its last argument and exits 1.
   - Fix: added `git-lock vanishing mid-probe: a newline-bearing path gives
     gone and one encoded path= line` to `tests/probes-lock-newline.bats`. It
     runs with flag false, so an absent lock at the presence test would read
     `mask`; `gone` can only come from the vanish site. It asserts the lock is
     gone after the run and the stderr is empty. The header now says every
     print site is pinned.
   - **Status**: FIXED. Mutation 4e is red on `assert_lines`; the file runs 8
     passed unmutated.

### Minor Issues

None.

## Fixes Applied

- `tests/probes-lock-newline.bats` — new case for the vanish-mid-probe site;
  header sentence about "five of six sites" and the residual rewritten.

## Other checks

- **Every `path=` print site**: `command grep -rn "'path=\|\"path=" lib hooks`
  finds one hit, `lib/probes-readonly.sh:93` inside `_probe_path_line`. The
  other `path=` hits in the two files are variable assignments and comments.
- **shellcheck**: `shellcheck -x lib/probes.sh lib/probes-readonly.sh` clean.
- **bash 3.2.0** (`/tmp/claude/bash32/bash`): `probe_git_lock` under a cwd
  named `r<NL>age=99999<NL>x` prints `mask` then
  `path=$'<dir>/r\nage=99999\nx/.git/index.lock'`; under a cwd holding
  UTF-8 e-acute, with `LC_ALL=C.UTF-8` exported (`${#x}` = 1 for it), prints
  `path=$'<dir>/caf\303\251/.git/index.lock'`; `probe_config_lock` with no
  config-lock line prints `mask` alone; `probe_readonly_path` with no path
  prints `nopath`. `printf -v` and the `LC_ALL=C` prefix on a builtin both
  work on 3.2.
- **Whitespace safety**: `$1` quoted throughout; `%q` output assigned with
  `printf -v` and printed with `%s`; no splitting on the path. The empty test
  `[ -n "$1" ]` leaves the function's status 0 for an empty path under
  `set -e` (an `if` with a false test and no else).
- **Integration**: `probes.sh` sources `probes-readonly.sh` by
  `BASH_SOURCE`-relative path, so the helper is reachable from the lock probes
  and from the `probes*.bats` family that sources only `probes.sh`.
- **Not flagged** (scope OUT): the stale comments stating the old contract in
  `lib/probes.sh` (header lines 12, 111-112) and `lib/probes-readonly.sh`
  (Item 7.7); `lib/verdicts.sh` still showing backslash-escaped paths between
  Item 1.1 and Item 1.2 (the outline names that state).
- **Gate**: `just precommit` exit 0 with the added test: 376 passed, 0 failed
  (375 before the added case); shellcheck, `bash -n`, rumdl, line caps, links,
  python compile all passed.
- **Final `git diff`**: only `tests/probes-lock-newline.bats` (mine) and the
  not-this-job `.claude/handoff-todo.md`. `git diff -- lib` is empty; the
  mutations were all restored by string swap. Nothing committed.

## Positive Observations

- The helper is one place for the encoding, the pin and the empty rule, so
  the five tests pinning its output cover all seven sites.
- Expected literals in the tests are written out, not produced by `%q`, and
  each opens by asserting `BATS_TEST_TMPDIR` holds no byte `%q` escapes.
- The slice-5 rewrites kept each assertion as strong as before; the pathless
  cases now assert `[ "$output" = mask ]` / `gone` whole, which also rules out
  a stray `path=` line.
- The newline test in `probes-readonly-members.bats` runs the newline case
  first and compares the whole output.
