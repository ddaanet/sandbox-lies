# Runbook — sandbox-lies review fixes

Design: `plans/sandbox-lies-review-fixes/outline.md` (approved at proof
2026-10-04; its Decisions D1–D5 bind every item). Findings:
`plans/sandbox-lies/reports/deliverable-review.md` — "Major N" and "m-N" below
are its labels. Requirements: `docs/design.md` FR/NFR/D ids. Recall:
`recall-artifact.md`.

Standing rules for every item: `just precommit` passes before each commit;
markdown edits run `just format-docs` first; no live file may fire a detector
(`tests/docs.bats` — describe a diagnostic, build test text from fragments);
every new bats file loads `helpers/bsd-stubs`; no `fire-*`/`quiet-*` fixture by
hand; `.bin/claude` is never edited.

## Requirements mapping

| Requirement | Phase | Items | Notes |
| --- | --- | --- | --- |
| FR-11 line cap | 1, 5 | 1.1, 5.2 | `detectors.md` split; `design.md` move-out if needed |
| FR-3 (Major 3) | 2 | 2.1 | runtime-failure silence |
| NFR-4 (Major 4) | 2 | 2.2 | writes nothing on the probe path |
| FR-7 (Major 5) | 2 | 2.3 | curly quotes, tab-indented untracked |
| FR-4 (Major 6, m-5) | 2, 3 | 2.4, 3.4 | fact-table pins; positive config assertions |
| FR-5 (m-1) | 2 | 2.5 | flag pairing |
| D-16 (m-3 tests) | 3 | 3.1 | BSD `paste` stub, shim case |
| FR-11 (m-2 tests) | 3 | 3.2 | exit-2 paths |
| NFR-2 (m-4 tests) | 3 | 3.3 | host git config isolation |
| FR-4 (m-2 code) | 4 | 4.1 | D4 operand rule |
| FR-4 (m-3 code) | 4 | 4.2 | D3 absolute `match=` |
| NFR-2, D-12 (Major 2) | 4, 5 | 4.3, 5.2 | `SessionStart` jq check; README |
| FR-9 (Major 1) | 5 | 5.1, 5.2 | skill; docs |
| FR-7, FR-8, NFR-1, NFR-4 (doc Minors) | 5 | 5.2 | |
| hygiene (stale comments) | 5 | 5.3 | |

## Phase 1: make room (type: general)

- Item 1.1: `docs/references/detectors.md` → new
  `docs/references/readonly-path.md` — move §readonly-path (heading through the
  line before §tmpdir-unset) whole into the new node; leave in `detectors.md` a
  stub entry pointing at it, shaped like the git-lock and config-lock stubs that
  point at `lock-detectors.md`; repoint every inbound link to the moved section
  (run `scripts/check-links.sh` to find breaks); add the new node to any `docs/`
  index or "read before" sentence that lists `lock-detectors.md`. No wording
  change inside the moved text. Requirements: FR-11.
  - Interfaces:
    - `docs/references/readonly-path.md` — the readonly-path entry, including
      its Probe facts table (`readfile=`, `merge=1`, `partial=1`, `target=`,
      `match=` rows); Items 4.1, 4.2 and 5.2 edit it.

## Phase 2: pin hook, matcher and probe behaviour (type: general)

Every item here adds tests against unchanged code. Per outline D5, each new
assertion is shown red under the fault named, applied to the hook's per-test
copy (`hook_copy_tree`) or a scratch copy under `$TMPDIR`, never to a tracked
file; the report lists each fault and the test names it turned red. A new
assertion no fault turns red is not done.

- Item 2.1: `tests/hook-malformed.bats` (or the hook suite holding the FR-3
  cases) — FR-3's runtime-failure path (Major 3). Three cases, each through
  `hooks/annotate.sh` on a fixture whose detector has a probe or verdict: a
  probe stub that prints `writable` then exits 1; a verdict stub that prints a
  paragraph and human line then exits 1 after a probe; a probe-less verdict (a
  phantom one) stubbed to print then exit 1. Each asserts status 0 and empty
  stdout. Extend `tests/helpers/hook.bash`'s `stub_probe`/`stub_lib` usage
  rather than a new mechanism. Faults: in `hooks/annotate.sh`'s main loop, each
  of the three `|| exit 0` after `"$probe_fn"`, after `"$fn" "$outcome" "$flag"`
  and after `"$fn" </dev/null` turned to `|| true`, one at a time. Requirements:
  FR-3.
- Item 2.2: `tests/hook.bats`, `tests/probes-readonly.bats` — NFR-4 on the probe
  path (Major 4). Re-run the "hook needs no temp dir" shape (`mktemp` spy on
  `PATH`, `TMPDIR` naming a nonexistent directory, output equal to an unspied
  run) on a payload whose detector runs a real probe: one readonly-path
  `writable` case and one git-lock case, each with its scratch repo. Add the
  same spy-and-nonexistent-`TMPDIR` check around a direct `probe_readonly_path`
  call on a `writable` refusal with a merge command, so `_readonly_print_facts`
  runs. Faults: a `mktemp` call inserted in `annotate.sh`'s probe branch; one
  inserted at the top of `_readonly_print_facts`. Requirements: NFR-4.
- Item 2.3: `tests/matchers-edges.bats` — two fire cases built from fragments
  (Major 5), each with a BSD-stub re-run if the file's pattern has one:
  `tmpdir-unset` on a GNU-style refusal whose path sits in curly single quotes
  (U+2018/U+2019) after the tool's words; `phantom-untracked` on a long-format
  `git status` untracked block, names tab-indented and one with a trailing
  slash, at least two masked names. Faults: `‘` and `’` dropped from
  `match_tmpdir_unset`'s alternation; the `|[[:space:]]+` alternative dropped
  from `match_phantom_untracked`'s pattern. Requirements: FR-7.
- Item 2.4: `tests/probes-readonly-pins.bats` — the unpinned fact-table members
  (Major 6), through `probe_readonly_path` on a `writable` refusal:
  `git switch <ref>`, `git rebase <ref>` and `git cherry-pick <ref>` each give
  `merge=1`; `git switch <ref>` with a file matching the target gives
  `target=<ref>`; `cat build.out` and `tail run.err` give `readfile=` those
  names; `sort -o out.log in.log`, `sort --output=out.log in.log`,
  `awk -i inplace … x.log` and `awk --include=lib.awk … x.log` give no
  `readfile=` line. Faults: `_readonly_merge_segment`'s subcommand case cut to
  `merge | pull | checkout`; `*.out | *.err` removed from
  `_readonly_readfile_arg`'s name case; the `sort:-o*`, `sort:--output*`,
  `awk:-i*`, `awk:--include*` arms removed. Requirements: FR-4.
- Item 2.5: `tests/hook*.bats` — flag pairing (m-1). Find the `fire-*` fixtures
  no hook case feeds and those fed with the flag absent only; add cases so each
  reaches the hook with the flag absent and with it `true`, asserting the
  detector's flag policy from `detectors.md` (phantom verdicts ignore it;
  `tmpdir-unset` fires only on `true`; `resume-lost`, `seccomp-init`,
  `readonly-path` silent on `true`). One case sets `dangerouslyDisableSandbox`
  to the string `"true"` on a `tmpdir-unset` fixture and asserts silence (read
  as false). Faults: the flag-policy `case` in `annotate.sh` emptied; the jq
  `== true` test replaced by a truthiness test. Requirements: FR-5.

## Phase 3: pin gates and harness (type: general)

Same D5 rule as Phase 2.

- Item 3.1: `tests/helpers/bsd-stubs.bash`, `tests/shim.bats` — a `paste` stub
  in `make_bsd_stubs` that refuses `-s` (alone or bundled, as `-sd:`) with no
  file operand, the way BSD paste reads no implicit stdin, and execs the real
  `paste` otherwise; one shim case re-run with the stub on `PATH` (m-3). Fault:
  the trailing `-` operand removed from a scratch copy of `.bin/claude` run in
  place of the shim. Requirements: D-16.
- Item 3.2: `tests/check-line-limits.bats`, `tests/check-links-edges.bats` — the
  exit-2 paths (m-2): `scripts/lib/tracked.sh`'s walk when `git ls-files` fails
  (e.g. a root that is not a repository, or a `git` stub exiting 128) gives
  status 2 and its `git ls-files failed` stderr line, through each gate script
  that uses it; `scripts/check-line-limits.sh` on a tracked file it cannot read
  (mode 000; skip with a stated reason when running as root) gives status 2 and
  `cannot read <file>`. Faults: `|| true` after the `ls-files`; the read guard's
  `if !` removed. Requirements: FR-11.
- Item 3.3: suites that run git — host git config isolation (m-4). A helper (new
  `tests/helpers/git-env.bash`, or the existing one each such suite loads)
  exports `GIT_CONFIG_NOSYSTEM=1` and `GIT_CONFIG_GLOBAL` pointing at a per-test
  file setting `user.name`, `user.email` and `commit.gpgsign=false`; every suite
  that runs git loads it. Real-probe cases that assume no repository above
  `$BATS_TEST_TMPDIR` call the existing `assert_no_git_above` first.
  Verification: the full suite passes with a host `GIT_CONFIG_GLOBAL` file
  setting `commit.gpgsign=true` and a bogus `gpg.program` exported, and fails
  without the helper. Requirements: NFR-2.
- Item 3.4: `tests/probes-config.bats` — the cases that assert only what the
  outcome is not (m-5: the two blocks the review cites, in the cases around the
  config-lock outcome) gain an assertion of the outcome token they expect.
  Fault: the probe's outcome swapped for another token the negative assertion
  allows. Requirements: FR-4.

## Phase 4: behaviour changes (type: tdd)

- Item 4.1: `lib/probes-readonly-command.sh` `_readonly_readfile_arg` — outline
  D4's operand rule (m-2). Requirements: FR-4. Depends on: Item 2.4, Item 1.1.
  - Slices:
    1. Options are never input: `probe_readonly_path` on a `writable` refusal
       with command `grep --include=*.log pat build.log` prints
       `readfile=build.log`; with `grep -r --include=*.log pat .` it prints no
       `readfile=` line.
    2. Pattern and program operands: `grep x.log y.out` prints `readfile=y.out`;
       `sed -e s/a/b/x.log in.out` prints `readfile=in.out`;
       `awk -f prog.log in.err` prints `readfile=in.err`; `sed s/a/b/ in.log`
       still prints `readfile=in.log`.
    3. `uniq` with an output operand is a writer: `uniq in.txt out.log` prints
       no `readfile=` line; `uniq in.log` prints `readfile=in.log`.
  - Docs (same item, after GREEN): `docs/references/readonly-path.md` Probe
    facts table `readfile=` row and residuals (other options' separate arguments
    stay unrecognised); the function's header comment.
- Item 4.2: `lib/probes-readonly-facts.sh` — outline D3's absolute `match=`
  names (m-3). The site is the merge pass that appends
  `out="${out}match=${files[$i]}"`; the name becomes `<repo>/<name>` with the
  repository root the function already holds. Requirements: FR-4. Depends on:
  Item 1.1.
  - Slices:
    1. Through `hooks/annotate.sh` with the payload `cwd` a subdirectory of a
       scratch repo, a merge command, and a worktree file whose content equals
       the target's: the probe's `match=` line is `match=<repo>/<file>` and the
       `additionalContext` restore clause names `` `<repo>/<file>` ``. Every
       existing `match=` assertion in `tests/probes-readonly*.bats`,
       `tests/verdicts-readonly.bats` and the hook suites is updated to the
       absolute form in the same GREEN.
  - Docs (same item): `readonly-path.md` Probe facts table `match=` row.
- Item 4.3: new `hooks/check-jq.sh`; `hooks/hooks.json` — outline D2's
  `SessionStart` check (Major 2). Tests in a new `tests/check-jq.bats`.
  Requirements: NFR-2, D-12.
  - Slices:
    1. External contract through the registration: the test reads the
       `SessionStart` command string from `hooks/hooks.json`, runs it with
       `CLAUDE_PLUGIN_ROOT` set to the checkout and a `PATH` holding the tools
       the script needs but no `jq`; stdout parses (with the test's own `jq`) as
       one object whose `systemMessage` contains `jq` and says Bash result
       annotations are off, whose `hookSpecificOutput.hookEventName` is
       `SessionStart`, and whose `hookSpecificOutput.additionalContext` contains
       `jq`; status 0; stderr empty. The same case re-runs with `make_bsd_stubs`
       on `PATH`. The existing "hooks.json names both events" case in
       `tests/hook.bats` is extended to the third.
    2. With `jq` on `PATH`: stdout and stderr empty, status 0.
  - Interfaces:
    - `hooks/check-jq.sh` — stdin ignored; stdout empty or one JSON object built
      by `printf` from fixed text; exit 0 always; writes nothing.
  - Docs (same item): `docs/references/hook.md` registration and the script's
    role.

## Phase 5: prose (type: general)

- Item 5.1: `skills/sandbox-lies/SKILL.md`,
  `skills/sandbox-lies/references/excluded-commands.md`,
  `references/escapes-and-costs.md`, `references/masks-and-gates.md` — Major 1
  per outline D1, and the skill-side Minors. One item: the skill is edited as a
  whole. Requirements: FR-9.
  - `SKILL.md`: §"Tell a sandboxed call from an unsandboxed one" first bullet —
    the 2.288/2.289 observations and the single-writer re-probe; §"Writing an
    `excludedCommands` entry" — D1's every-command rule as CC's documented
    mechanism, `git *` syntax, no decoy, the forfeiting shapes; §"Leaving the
    sandbox for one call" — strict mode named
    `sandbox.allowUnsandboxedCommands: false` (Strict sandbox mode in
    `/sandbox`), and the batching rule matching the reference; §"Keeping the
    working directory at the project root" — the persisted `cd` holds in the
    main session (a subagent's cwd resets per call), and the order re-ranked: a
    trailing `cd <root>` and a subshell now both forfeit an exclusion, so the
    subshell's "misses an honoured exclusion" reason goes; the `description`
    frontmatter if it names whole-call semantics.
  - `excluded-commands.md`: retitled; the D1 rule replaces "one matching segment
    unsandboxes the entire call" and the decoy; the 2.281 probe marked
    confounded (its uncovered `touch` keeps it sandboxed under the documented
    rule) beside the 2.288 and 2.289 single-writer probes; Matching bullets
    re-read against D1 (redirections other than descriptor duplication, a `cd`,
    a variable command name now keep a call sandboxed); "Settings reload live"
    kept as observed earlier, version not recorded; the `git:*`-vs-hook section
    reworded to `git *` and the D1 limits.
  - `escapes-and-costs.md`: opening paragraph; §Strict mode (the key);
    §read-only-inspection default (`git *` baseline); §Cost (the auto-mode
    exceptions the sandboxing doc lists — per-command allowed domains,
    server-side review of sandboxed commands; one batching rule; drop "with no
    generation", since the classifier generates a verdict); the recipe line on
    `git:*`.
  - `masks-and-gates.md`: the cwd paragraph (main-session qualifier, re-ranked
    order, exclusion wording); the `` !`cmd` `` paragraph's exclusion wording.
- Item 5.2: docs — Major 1 and 2 doc halves and the doc Minors. Requirements:
  FR-7, FR-8, FR-9, FR-11, NFR-1, NFR-2, NFR-4, D-12. Depends on: Items 1.1,
  4.1, 4.2, 4.3, 5.1.
  - `docs/references/lock-detectors.md`: the `mask` reproduction and config-lock
    corpus paragraphs — the 2.281 `/tmp` probe restated as confounded; D1's
    single-writer probe and its 2.288/2.289 results.
  - `docs/references/detectors.md`: Conventions — open question whether the
    payload `cwd` follows a persisted top-level `cd`, and that the lock and
    readonly probes resolve relative paths against it; Candidates intro — credit
    the shipped matchers' re-measurement
    (`plans/sandbox-lies/reports/item-4-2-s1-code-review.md`,
    `item-4-3-s1-green.md`), not a scratch shell matcher; phantom-untracked's 41
    and 57 each name their corpus (from `plans/2026-09-0*` evaluation files), or
    say it is not established; Translation map and Not-detectors exclusion
    wording.
  - `docs/references/readonly-path.md`: `mv`'s `to` names the target only in the
    inter-device form.
  - `docs/design.md`: NFR-4's read scope (the refused path's repository, and
    paths from the error text); a platform statement (symptoms and figures
    recorded on Linux, macOS unverified); D-3's hook count; NFR-4 ordered before
    NFR-5; FR-8 qualified (25 of 34 fixtures re-cut byte for byte at review
    time, two undated entries pick other calls, seven not found, cause not
    established); FR-9, D-8, Rejected alternatives and L-2 exclusion wording;
    D-12 names the `SessionStart` check. If `just format-docs` leaves it over
    400 lines, move D-8's argument to a new `docs/references/` node with a
    one-paragraph stub and link.
  - `README.md`: §Install names `jq` as a prerequisite and the `SessionStart`
    notice; the platform statement; the skill blurb's exclusion wording.
  - `CLAUDE.md`: the self-quiet bullet says the three pilot files are exempted
    from the sweep.
  - `docs/changelog.md`: one entry for this job's user-visible changes.
- Item 5.3: comments and help text (stale group). Requirements: none (hygiene).
  - `lib/matchers.sh`: the file header (no longer the pilot's candidate
    matchers); the comment above the listing matchers claiming
    `CLAUDE_PROJECT_DIR` anchoring closes the `/dev` listing false positive —
    nothing reads that variable, and `detectors.md` accepts it as a residual.
  - `lib/probes.sh`: the header's probe contract gains `tool_input.command` as
    `$3`.
  - `justfile`: the `precommit` recipe's comment ends on a sentence that reads
    whole in `just --list` (or a `[doc(...)]` attribute).
