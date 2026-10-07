# Phase 3 report

Items 3.1 to 3.5, test-only. Seven of the eight Item 3.5 suites got a case;
`tests/hook-verdicts.bats` is stopped (see 3.5).

## Files changed

- 3.1: `tests/matchers-edges.bats`
- 3.2: `tests/hook-candidates.bats` (adds `load helpers/probes`, which holds
  `assert_no_git_above`)
- 3.3: `tests/check-jq.bats` (adds `load helpers/spy`)
- 3.4: `tests/helpers/probes.bash`, `tests/helpers/hook.bash` (comments only)
- 3.5: `tests/check-links.bats`, `tests/docs.bats`, `tests/hook-cap.bats`,
  `tests/hook-malformed.bats`, `tests/probes-config.bats`,
  `tests/probes-edges.bats`, `tests/probes-readonly-pins.bats`. Each suite
  already loaded `helpers/bsd-stubs`. In each, the re-run case's body moved
  into a named function that the original `@test` and the BSD `@test` both
  call, so the BSD case is the same assertions.
- Report: this file.

No mutation remains: `git diff --stat -- lib hooks scripts` is empty.

## Per new test: failing world state, and what else could produce the observable

- 3.1a "phantom-untracked counts a slash-suffixed name toward the threshold".
  Fails when a masked directory listed with a trailing slash is not counted,
  so a block of `.bashrc` plus `.claude/skills/` reads as one name. Alternative
  causes: the grep pattern's `/?` dropped (the mutation); a fixture where a
  third name carries the count. The block has exactly two names (asserted by
  counting tab-led lines), so only the slash line can make the second.
- 3.1b "counts one name once, with and without the slash". Fails when the
  strip leaves the slash, so `.claude/skills` and `.claude/skills/` are two
  `sort -u` entries. Alternative: any other second distinct name. The block
  holds the one name twice and nothing else, so reaching the threshold can
  only come from the slash surviving the strip. Dropping `/?` from the grep
  pattern instead leaves this case quiet (one line matches), which is why the
  two cases cover the two mutations separately.
- 3.2 guard in "the no-target merge clause ...". Fails when a `.git` entry
  sits at or above `$BATS_TEST_TMPDIR`; the case runs a real probe whose
  walk-up would then find that repository. Nothing else trips the guard.
- 3.3 spy assertion in "jq absent: TMPDIR naming a missing directory ...".
  Fails when the script runs `mktemp` at all. Stdout and stderr are unchanged
  by a silenced `mktemp` with a `/tmp` fallback, so only the spy log sees it.
- 3.5 BSD cases: each fails only when a stubbed tool is called with a
  GNU-only invocation on the exercised path. The stub's refusal reaches
  `$stderr`, the exit status or the verdict. Without the BSD tool set the same
  assertions are the plain case's, so a difference can only come from the
  tools.

## Mutation proof

| behaviour | mutation | red |
| --- | --- | --- |
| 3.1a trailing slash counts | `lib/matchers.sh`: drop `/?` from the `grep -Eo` pattern | case 9, `want [phantom-untracked] got []` |
| 3.1b same name counts once | `lib/matchers.sh`: drop `/?` from `s\|/?[[:space:]]*$\|\|` | case 10, `want [] got [phantom-untracked]` |
| 3.2 no `.git` above tmpdir | `TMPDIR` set to a directory holding a planted `.git` (no source mutation) | the new `assert_no_git_above` call failed (`tests/hook-candidates.bats` line 159) |
| 3.3 no `mktemp` call | `hooks/check-jq.sh`: `{ mktemp \|\| mktemp /tmp/sl.XXXXXX; } >/dev/null 2>&1` before the printf | `[ ! -e "$spy_log" ]` failed; cases 1, 2 and 4 stayed green |
| 3.5 check-links | `scripts/check-links.sh`: add `-e '\bnever-present\b'` to the `grep` | BSD case, `[ "$status" -eq 1 ]` |
| 3.5 docs | `lib/matchers.sh` `detect`: `printf x \| grep -qE '\bx\b' \|\| return 1` | `[ "$stubbed" = "$plain" ]` |
| 3.5 hook-cap | same line in `match_phantom_untracked` | `cap_run`'s matcher-fires guard |
| 3.5 hook-malformed | same line in `detect` | `assert_no_failures`: positive payloads did not fire, stub text on stderr |
| 3.5 probes-config | `lib/probes.sh`: `sed -n` to `sed --quiet` in `_probe_config_lock_path` | `[ -z "$stderr" ]` |
| 3.5 probes-edges | `lib/probes.sh`: `stat -f %m` to `stat -c %Y` in the first mtime read | `[ -z "$stderr" ]` |
| 3.5 probes-readonly-pins | `lib/probes-readonly.sh`: `sed -n` to `sed --quiet` in `_probe_readonly_path_from_line` | `[ -z "$stderr" ]` |

Each mutation was an exact one-occurrence replacement, proved landed with
`command grep`, then undone by the inverse replacement; the restore was proved
by a zero `command grep -c` and the case green. For the 3.3 mutation a first
attempt without the `>/dev/null` redirection put `mktemp`'s name on stdout and
reddened the notice assertion instead; it was restored and redone with the
redirection, so the red is the spy's. For 3.5 hook-cap a first mutation (in
`detect`) reddened at a `jq` parse in `cap_hook`; it was replaced by the
`match_phantom_untracked` mutation above, red on the guard.

## Item 3.4 detail

- `tests/helpers/probes.bash` `run_probe_bounded`: `tests/shim.bats` dropped;
  the 3 s bound (30 polls of 0.1 s) stated as load-sensitive.
- "Shared by" lists from a whole-tree `command grep -lw` per function:
  - `make_scratch_repo`: `probes-readonly-facts`, `probes-readonly-members`,
    `probes-readonly-pins`, `probes-edges`, `hook-writes`.
  - `hold_lock` and `kill_holder`: `probes`, `probes-edges`,
    `probes-lock-newline`.
  - `run_probe_bounded`: `probes-edges`, `probes-config`,
    `probes-readonly-pins` (the list is otherwise unchanged).
  - `hook.bash` `stub_probe` and `stub_probe_kv`: `hook-locks`,
    `hook-locks-pathless`, `hook-malformed`, `hook-candidates`.
- `tests/probes-resume.bats`, `tests/hook-resume.bats` and
  `tests/probes-readonly-globs.bats` use none of these functions, so none is
  added to any list. (`tests/hook-candidates.bats` now also uses
  `assert_no_git_above`; that helper's comment names no callers.)

## Item 3.5 notes and deviations

- `tests/hook-verdicts.bats`: stopped, no case added. Its only case stubs
  `detect` with a function that prints names, so `hooks/annotate.sh` runs
  neither a matcher nor a probe; `annotate.sh` and `lib/verdicts.sh` call none
  of `sed grep mktemp stat wc`. The only `sed` in the file is the test's own
  `sed -n`. A BSD case there cannot fail. It already loads `helpers/bsd-stubs`.
  Outline and `CLAUDE.md` text that lists it among the eight needs revising
  (docs are another item).
- `tests/docs.bats`: the plain sweep takes about 90 s here (about 2 min under
  load). A full second sweep would double it, so the BSD case checks the three
  exempt files for identical verdicts under both tool sets, then sweeps only
  `lib/` and `hooks/` under the stubs. The sweep body is the shared
  `sweep_tracked_files [<prefix>...]`; with no prefix it is the original case.
- Stub sets: check-links `grep mktemp`; docs `sed grep`; hook-cap
  `sed grep wc`; hook-malformed `sed grep`; probes-config and probes-edges
  `sed stat wc`; probes-readonly-pins `sed`.
- All bats files stay under 400 lines (largest touched: `probes-readonly-pins`
  and `probes-config`, well under).

## Precommit

`just precommit` (unsandboxed, foreground) exit status 0. Its recap:
`precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests`
(bats: 357 passed, 0 failed).

The first two runs failed shellcheck: SC2030 and SC2031 (info) on
`check-links`, `probes-edges` and `probes-readonly-pins`, because the shared
case function was defined after an earlier test that sets `$status` and
`$output` through `run`. The three functions (with their original comments)
now sit ahead of the first `@test` that uses `run`, which cleared it.
