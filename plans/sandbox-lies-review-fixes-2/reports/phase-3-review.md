# Review: Phase 3 (Items 3.1–3.5, test-only pins)

**Scope**: `git show HEAD`
(`Phase 3 — Major 1 pin, m-14 guard, m-16 spy, helper comments, BSD-stub cases`),
against `outline.md` §Decisions Q5 and Phase 3, `delegate-status.md` §Mutation
testing, the executor's `reports/phase-3.md`, and findings Major 1 and m-14 to
m-18 of `plans/sandbox-lies-review-fixes/reports/deliverable-review.md`.
**Date**: 2026-10-07 **Mode**: review + fix

## Summary

Items 3.1, 3.2 and 3.3 hold: each new assertion went red under a second
mutation, different from the one the executor recorded. Two Item 3.5 cases could
not detect what they claimed to detect, and both are now fixed:

- The `docs.bats` BSD case passed with a GNU-only `grep -P` in a matcher.
- The `probes-edges.bats` BSD case never read the `wc` output it stubs.

The Item 3.4 lists were checked against a whole-tree grep. Two were wrong, and
both are corrected.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

1. **The `docs.bats` BSD case cannot see a refused `grep` or `sed` call in most
   matchers.**
   - Location: `tests/docs.bats`, the case "the exempt files give the same
     verdicts, and lib and hooks stay quiet, with BSD tools".
   - Problem: the case has two halves, and neither catches a refusal.
     - **The exempt-file comparison** checks git-lock alone. The three exempt
       files fire only `git-lock`. Suppose the stubs refuse a call in any other
       matcher. That matcher then fires on none of the three files, stubbed or
       plain, so the verdicts still match.
     - **The `lib/` and `hooks/` sweep** has no failing state of its own. A stub
       either refuses or runs the real tool, so a file can fire under the stubs
       only where it fires plainly. The stubbed sweep is therefore implied by
       the plain sweep.
   - Evidence: I changed `match_seccomp_init` from `grep -qE` to `grep -qP`.
     That is a GNU-only option, and a BSD `grep` refuses it, so the matcher
     would never fire on macOS. The case stayed green (36 s run).
   - Fix: the case now runs the exempt files and every tracked file under `lib/`
     and `hooks/` with the stubs on `PATH`. For each file it asserts:
     - the plain verdicts, unchanged;
     - an empty stderr;
     - for the exempt files only, a non-empty plain verdict, so the comparison
       is not between two empty results.

     A stub writes its refusal to stderr whether or not its matcher would fire.
     `detect` runs every matcher on every input, so a refusal anywhere shows up.
     The plain sweep is the original `@test` again. Its `<prefix>` parameter had
     no caller left, so I removed it with the `sweep_tracked_files` function.
   - **Status**: FIXED. The same mutation now goes red on the stderr assertion,
     with `grep: invalid option -- -qP` for the first exempt file.

2. **The `probes-edges.bats` BSD case stubs `wc` but never reads `wc`'s
   output.**
   - Location: `tests/probes-edges.bats` `future_mtime_case`.
   - Problem: the lock holds `1234567`, and the probe prints a `bytes=` line,
     but the case asserts only `orphan` and `age=0`. BSD `wc` pads its count. So
     the BSD case's `wc` stub had nothing to fail.
   - Evidence: I dropped `| tr -d '[:space:]'` from the probe's `bytes=` read.
     That strip is the part that removes BSD `wc`'s padding. All 10 cases stayed
     green.
   - Fix: `future_mtime_case` now asserts `bytes=7`.
   - **Status**: FIXED. Under the same mutation the BSD case goes red on the new
     assertion (`tests/probes-edges.bats:42`), and the plain case stays green.

### Minor Issues

1. **The `hook.bash` "shared by" list merged two helpers' caller lists.**
   - Location: `tests/helpers/hook.bash:6-8`.
   - Note: the comment credits both `stub_probe` and `stub_probe_kv` to four
     suites. A whole-tree grep gives each helper three:
     - `hook-locks-pathless` uses only `stub_probe_kv`.
     - `hook-malformed` uses only `stub_probe`.
   - **Status**: FIXED. The comment now lists each helper's own callers.

2. **The `probes.bash` file header was stale, and this commit made it more so.**
   - Location: `tests/helpers/probes.bash:1-7`.
   - Note: the header lists nine suites. Fifteen load the helper, and this
     commit's `load helpers/probes` in `hook-candidates.bats` is one of the ones
     missing from the list.
   - **Status**: FIXED. The header now names the `tests/probes*.bats` family and
     the three hook suites that load the helper (`hook-candidates`,
     `hook-locks-pathless`, `hook-writes`). Naming the family stops the list
     from falling behind each time a probe suite is added.

3. **The `hold_lock` comment had an unwrapped line.**
   - Location: `tests/helpers/probes.bash`, the "Shared by" line above
     `hold_lock`.
   - Note: the line was over 120 columns.
   - **Status**: FIXED. Rewrapped to 80 columns.

## Wrong-reason hunt, per item

- **3.1a, slash counts toward the threshold.**
  - **Failing state:** a line ending in `/` is not counted.
  - **Other causes:** none. The block has exactly two tab-led lines, which is
    asserted. The `Untracked files:` header cannot match, because it has no
    leading whitespace. There is no porcelain `??` line. So nothing but the
    `.claude/skills/` line can be the second name.
- **3.1b, one name counts once.**
  - **Failing state:** the strip leaves the slash, so the name is counted twice.
  - **Bare negative:** this case passes trivially when the grep drops the slash
    line. 3.1a is its positive and goes red in that state, so the pair is not
    vacuous.
- **3.2, the guard.**
  - **Placement:** it is the first statement after `local`, ahead of both
    `run_hook` calls.
  - **Reach:** both walk-ups start under `$BATS_TEST_TMPDIR`.
    - The mkdir fixture's path `newdir2` and the config-busy fixture's
      `.git/config` are both relative, and the probe joins them onto the payload
      `cwd`, which is `$BATS_TEST_TMPDIR`.
    - The guard therefore covers every ancestor the walk can reach.
    - `newdir2` itself does not exist.
- **3.3, the `mktemp` spy.**
  - **On the right `PATH`:** `run_nojq` puts `spy-bin` ahead of `nojq-bin` in
    the `env -i` environment. The registered command resolves `bash` from
    `nojq-bin`, and the script resolves `mktemp` from `spy-bin`.
  - **Log path:** `$BATS_TEST_TMPDIR/mktemp.log` is absolute and writable
    whatever `TMPDIR` names.
  - **Order:** the spy assertion comes after the stdout comparison. A mutation
    that also changes stdout reds earlier, as the executor saw.
  - **Residual (not fixed, outside m-16):** the spy sees only an external
    `mktemp`. A builtin redirect such as `>"$TMPDIR/x"`, silenced and with a
    `/tmp` fallback, would also go unseen. NFR-4's "pinned by `check-jq.bats`"
    should claim no more than "never calls `mktemp`".
- **3.5, the BSD cases.**
  - **Stubs reach the process under test:** in every case, `PATH=… fn` puts the
    stubs on `PATH` for the whole function body. Every process the body starts
    inherits them: `run`'s subshell, the `bash annotate.sh` child and the
    `check-links.sh` process.
  - **`hook-cap`:** the executor's mutation went red only at `cap_run`'s
    precondition, which runs in the test's own `bash -c`. My mutation sits in
    `annotate.sh`'s cap line, which only the hook process runs. It went red at
    the cap assertion, which shows the hook process has the stubs.
  - **`check-links`:** the `mktemp` stub adds nothing. The one template
    (`scripts/lib/tracked.sh:60`) ends in `X`, so the stub passes it to the real
    tool. That is harmless, and it is not a gap: BSD accepts that template.
  - **`hook-cap`:** the `wc` stub reaches only the test's own `byte_count`,
    which strips the padding arithmetically.

## Item 3.5 judgements

- **The `docs.bats` partial re-run:**
  - **Why the executor's shape was unsound:** by the argument under Major issue
    1 above, a stubbed sweep of any subset can never fail where the plain sweep
    passes. The exempt-file comparison covered `git-lock` only. So the cost
    question (a 90 s second sweep) was the wrong axis.
  - **Why a full second sweep is unnecessary:** stderr detects a refusal on any
    input, so there is nothing for it to add.
  - **What the fixed case checks:** stderr and verdicts over 3 exempt files plus
    `lib/` and `hooks/`.
  - **Cost:** the fixed `docs.bats` took 2 min for both cases here, on a loaded
    box.
- **Skipping `tests/hook-verdicts.bats` is right.** There, `detect` is stubbed
  to print names. Of those names, `phantom-gitadd` has no probe (the probes
  defined are `probe_readonly_path`, `probe_resume_lost`, `probe_git_lock` and
  `probe_config_lock`), and `no-such-detector` has no verdict. Neither
  `lib/verdicts.sh` nor `hooks/annotate.sh` calls `sed`, `grep`, `mktemp`,
  `stat` or `wc` (a whole-file grep found none). The only stubbed-tool calls are
  in the test's own `sed -n`. A BSD case there has no failing state.
  - **Doc follow-up:** the outline's Q5 list of eight suites becomes seven. The
    NFR-2 text (Item 5.1) and the `CLAUDE.md` rule should name a suite "whose
    code under test calls a stubbed tool". `hook-verdicts` falls outside that.

## Mutation proof

Each mutation was an exact single-occurrence replacement, done in place and
shown to land with `command grep`. Each was restored by the inverse replacement,
with a zero `command grep -c` and the touched file green afterwards. Every
mutation differs from the executor's recorded one.

| behaviour | mutation | red or survived (and fixed) |
| --- | --- | --- |
| 3.1a slash-suffixed name counts (grep) | `lib/matchers.sh:117` `(${alt})/?` → `(${alt})\.?` | red: case 9, `want [phantom-untracked] got []`; case 10 green |
| 3.1b one name counts once (strip) | `lib/matchers.sh:118` `s\|/?[[:space:]]*$\|\|` → `s\|/?[[:space:]]+$\|\|` (strip only before trailing blanks) | red: case 10, `want [] got [phantom-untracked]`; the other 12 green |
| 3.2 guard precedes the probe | no source mutation: `TMPDIR` under a real repository holding branch `feat2` (m-14's own scenario), not a bare `.git` | red: case 7 at `assert_no_git_above` (`hook-candidates.bats:159`), before either `run_hook`; the other 11 green |
| 3.3 no `mktemp` call | `hooks/check-jq.sh`: `: "$(mktemp -u 2>/dev/null \|\| mktemp -u /tmp/sl-mut.XXXXXX)"` before the `printf` (silent, stdout unchanged, writes nothing) | red: case 3 at `[ ! -e "$spy_log" ]`; cases 1, 2, 4 green |
| 3.5 docs: no BSD refusal in any matcher | `lib/matchers.sh:197` `match_seccomp_init` `grep -qE` → `grep -qP` | **survived**, then fixed (Major issue 1 above): red at `[ ! -s "$err" ]`, `grep: invalid option -- -qP` |
| 3.5 hook-cap: the hook process carries the stubs | `hooks/annotate.sh:148` `[ "$candidate_bytes" -gt 2048 ] && continue` → `… && printf x \| grep -qP x 2>/dev/null && continue` | red: the BSD case only, at `[ "$(byte_count "$ctx")" -lt 2048 ]` (`hook-cap.bats:114`), past `cap_run`'s guard; the other 6 green |
| 3.5 probes-edges: BSD `wc` padding stripped | `lib/probes.sh:181` drop `\| tr -d '[:space:]'` from the `bytes=` read | **survived** (10/10 green), then fixed (Major issue 2 above): red at `bytes=7` (`probes-edges.bats:42`), the BSD case only |

Before the precommit run, `git diff -- lib hooks scripts` printed 0 lines.

## Fixes Applied

- `tests/docs.bats`:
  - `sweep_tracked_files` folded back into the original `@test`, without the
    `<prefix>` filter that had lost its only caller.
  - The BSD case replaced by "the matchers give the plain verdicts and refuse no
    BSD sed or grep call". It runs the exempt files plus the tracked files under
    `lib/` and `hooks/`, and asserts equal verdicts, an empty stderr and, for
    the exempt files, a non-empty plain verdict.
- `tests/probes-edges.bats` `future_mtime_case`: a `bytes=7` assertion, with a
  comment naming it as the BSD re-run's `wc` check.
- `tests/helpers/hook.bash:6-9`: a separate caller list for each of `stub_probe`
  and `stub_probe_kv`.
- `tests/helpers/probes.bash:1-4`: the header names the `tests/probes*.bats`
  family plus `hook-candidates`, `hook-locks-pathless` and `hook-writes`.
- `tests/helpers/probes.bash`, the `hold_lock` "Shared by" comment: rewrapped.
- This report.

Every bats file stays under 400 lines; the largest is `tests/hook-locks.bats` at
391, untouched.

Not touched: `plans/sandbox-lies-review-fixes-2/delegate-status.md` shows as
modified in the tree, but that change is not mine.

## Requirements Validation

| Requirement | Status | Evidence |
| --- | --- | --- |
| Major 1 (3.1) | Satisfied | Two cases; each slash mutation reds exactly one |
| m-14 (3.2) | Satisfied | Guard first; m-14's `feat2` scenario reds at the guard |
| m-15, m-17 (3.4) | Satisfied after fixes | Lists match `git grep -lw` per helper |
| m-16 (3.3) | Satisfied (for `mktemp`) | Silent `mktemp -u` reds the spy; builtin-redirect residual noted |
| m-18 / NFR-2 (3.5) | Satisfied after fixes | 7 of 8 suites; `hook-verdicts` skip is correct |

## Positive Observations

- In each BSD case, the shared-body extraction runs the exact plain assertions,
  so the two cases cannot drift apart.
- The executor caught and redid its own wrong-reason reds: the 3.3 stdout red
  and the 3.5 hook-cap `jq` parse red.
- Every Item 3.4 list in the commit except `hook.bash` matched the grep exactly.

## Precommit

`just precommit` ran unsandboxed after every fix, with no other test process
alongside, and exited 0. Its recap listed `plugin.json`, `hooks.json`,
`shellcheck`, `bash -n`, `rumdl`, `line limits`, `links` and `tests` (bats: 357
passed, 0 failed). It was launched in the foreground, but the tool moved it to
the background when it passed its 600 s call limit, and it finished there.
Nothing committed.
