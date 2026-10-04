# Runbook Review: sandbox-lies-review-fixes

**Artifact**: plans/sandbox-lies-review-fixes/runbook.md
**Design**: plans/sandbox-lies-review-fixes/outline.md (D1–D5 settled, not
reopened)
**Findings**: plans/sandbox-lies/reports/deliverable-review.md
**Date**: 2026-10-04
**Mode**: review + fix-all

## Summary

Every IN finding of the outline maps to an item and nothing OUT is built. The
draft had three classes of defect, all fixed in place. First, line caps: three
target test files were too near 400 lines to take their new cases, and
`just precommit` would have failed. Second, assertions that could not run or
could not fail: a `match=` line asserted through the hook, which never prints
it; negatives left bare after the absolute-name change; a Phase 3 fault that
could not turn its test red. Third, propagation gaps: prose citations of the
moved readonly-path entry, the `claude:*` wording in a fourth skill node, and
design text that the new `SessionStart` script contradicts. Six of the 23 fixes
are major. No critical issue, nothing unfixable.

**Overall Assessment**: Ready

## Requirements Coverage

| Requirement | Phase | Items | Coverage | Notes |
| --- | --- | --- | --- | --- |
| Major 1 (FR-9) | 5 | 5.1, 5.2 | Complete | skill hub + 4 nodes; lock-detectors, detectors, design, README, hook.md |
| Major 2 (NFR-2, D-12, FR-1) | 4, 5 | 4.3, 5.2 | Complete | D2 style reset now asserted |
| Major 3 (FR-3) | 2 | 2.1 | Complete | three faults, one per `|| exit 0` |
| Major 4 (NFR-4) | 2 | 2.2 | Complete | new `hook-writes.bats` + `probes-edges.bats` |
| Major 5 (FR-7) | 2 | 2.3 | Complete | |
| Major 6 (FR-4) | 2 | 2.4 | Complete | new `probes-readonly-members.bats` |
| Stale comments (4) | 5 | 5.3 | Complete | |
| Docs Minors (13, minus Unchosen host) | 5 | 5.1, 5.2 | Complete | D-5's 57 added beside detectors.md's |
| Tests m-1 | 2 | 2.5 | Complete | fixtures enumerated |
| Tests m-2 | 3 | 3.2 | Complete | fault corrected |
| Tests m-3 | 3 | 3.1 | Complete | |
| Tests m-4 | 3 | 3.3 | Complete | |
| Tests m-5 | 3 | 3.4 | Complete | expected tokens named |
| code m-2 | 4 | 4.1 | Complete | four slices |
| code m-3 | 4 | 4.2 | Complete | |
| detectors.md split, design.md move-out (NFR-5) | 1, 5 | 1.1, 5.2 | Complete | |
| OUT: m-1, m-6, m-7, m-8, m-9, Unchosen host, carry-forward, `.bin/claude` | — | none | Not built | README clone URL guarded in 5.2 |

## Review Findings

### Critical Issues

None.

### Major Issues

1. **Three target test files overflow the 400-line cap**
   - Location: Items 2.2, 2.4 (and 4.1, 4.2, which add to 2.4's file)
   - Problem: `wc -l` gives `tests/hook.bats` 378, `probes-readonly.bats`
     386 and `probes-readonly-pins.bats` 358. Item 2.2 adds two
     scratch-repo hook cases plus a direct probe case. Item 2.4 adds five
     or so pin cases. Items 4.1 and 4.2 then add four slices and a direct
     case. Each file would cross 400 and `just precommit` would fail at the
     line-limit check.
   - Fix: Item 2.2's hook cases go in a new `tests/hook-writes.bats`; its
     direct `probe_readonly_path` case goes in `tests/probes-edges.bats`
     (311) beside the git-lock "probe writes nothing" case it mirrors.
     Item 2.4 creates `tests/probes-readonly-members.bats`, and Items 4.1
     and 4.2 put their tests there. Each new file gets its loads and its
     BSD-stub case. A standing rule now states the cap.
   - **Status**: FIXED
2. **Item 4.2 asserted a probe line through the hook, which never emits it**
   - Location: Item 4.2 slice 1
   - Problem: "through `hooks/annotate.sh` … the probe's `match=` line is
     `match=<repo>/<file>`". The hook prints only `additionalContext` and
     `systemMessage`, so the probe's lines cannot be observed there.
   - Fix: the slice is split into a direct `probe_readonly_path` call
     (`match=` lines with `cwd` a subdirectory) and a hook case (the restore
     clause names the absolute path), on a named `make_scratch_repo` setup.
   - **Status**: FIXED
3. **Item 4.2 left negative `match=` assertions vacuous**
   - Location: Item 4.2
   - Problem: the item said to update existing assertions but not the
     negatives. Once names are absolute,
     `run ! grep -qxF 'match=d'` can never fail. It also listed
     `verdicts-readonly.bats` as needing updates, but there `match=` lines
     are verdict input, not probe output.
   - Fix: negatives are named and updated to `match=<repo>/d`. The
     probe-output files are listed. Verdict-input `match=` lines are
     explicitly left alone.
   - **Status**: FIXED
4. **Item 3.2's fault could not turn its test red**
   - Location: Item 3.2
   - Problem: "`|| true` after the `ls-files`" inside the existing
     `if ! git … ls-files …; then … exit 2` parses as `(! git …) || true`.
     That is always true, so the failure case still exits 2 with its message
     and stays green.
   - Fix: the fault now replaces the `if ! … fi` guard with the bare call
     plus `|| true`, which turns a failed `ls-files` into an empty, clean
     walk (exit 0). The "non-repository root" route is dropped: a repository
     above `$BATS_TEST_TMPDIR` would answer it, which is Tests m-4's own
     hazard. A `git` stub exiting 128 replaces it.
   - **Status**: FIXED
5. **The readonly-path move left code and test citations pointing at the old
   node**
   - Location: Item 1.1
   - Problem: `scripts/check-links.sh` finds only markdown links. About
     twenty prose citations of "detectors.md's readonly-path …" sit in
     `lib/probes-readonly*.sh`, `lib/matchers.sh`, `lib/verdicts.sh`,
     `tests/verdicts.bats` (three test names), `tests/verdicts-readonly.bats`,
     `tests/probes-readonly-facts.bats`, `tests/helpers/verdicts.bash` and
     `tests/extract-fixtures.py`. The lock-detectors split set the precedent
     of repointing such citations.
   - Fix: the files and sites are enumerated in Item 1.1, along with the `rg`
     that lists them. Both "read before" index sentences are named
     (`detectors.md`, `hook.md`). No anchor link to `#readonly-path` exists,
     so the link step is a check, not a rewrite.
   - **Status**: FIXED
6. **D1 propagation missed a skill node, and D2 missed design text**
   - Location: Items 5.1, 5.2, 4.3
   - Problems:
     - `skills/sandbox-lies/references/recipes-and-claude.md` carries
       `claude:*` exclusion wording twice and was not in Item 5.1. Leaving it
       out also splits the skill's prose across items.
     - Item 4.3 dropped D2's "lead the `systemMessage` with a style reset".
     - The new `SessionStart` script contradicts FR-1's "One hook script"
       and the Architecture block, and neither was in Item 5.2.
     - `docs/references/hook.md`'s pilot claim that calls were unsandboxed by
       the `claude:*` exclusion rests on the old model.
   - Fixes:
     - `recipes-and-claude.md` is added to Item 5.1.
     - Item 4.3 slice 2 asserts the `\033[0m` lead.
     - FR-1, the Architecture block and the hook.md claim are added to Item
       5.2, and FR-1 to Item 4.3's requirements.
     - `BRIEF.md` is recorded as out of scope (a historical brief).
   - **Status**: FIXED

### Minor Issues

1. **Wrong requirement id for the line cap** — Items 1.1 and 3.2 and the
   mapping table cited FR-11 (Self-quiet). The line cap is NFR-5. Fixed.
   FR-11 stays on 5.2, for the `CLAUDE.md` self-quiet wording. **Status**:
   FIXED
2. **Item 4.1 slice 2 bundled two behaviours, and its `-e`/`-f` cases passed
   on arrival** — under a plain "skip the first operand" implementation,
   `sed -e s/a/b/x.log in.out` and `awk -f prog.log in.err` give the expected
   answer by accident. Fixed by splitting it into slice 2 (first operand is
   the pattern) and slice 3 (the `-e`/`-f` family). Slice 3 carries two cases
   that are red after slice 2: `grep -epat x.log` and
   `sed -e s/a/b/ -e s/c/d/x.log in.out`. uniq moves to slice 4. **Status**:
   FIXED
3. **Item 4.3 slice order** — the slices ran the full behaviour first and the
   degenerate case second. Fixed by swapping them: slice 1 is now registration
   with `jq` present (red with no `SessionStart` entry), and slice 2 adds the
   notice. Also added: the expected command string, the hooks.json
   `Interfaces` line, a missing-`TMPDIR` run for "writes nothing", and named
   BSD stub tools (the script calls none, so a bare `make_bsd_stubs` names
   nothing). **Status**: FIXED
4. **Item 2.1 named a file with "or"** — it now names
   `tests/hook-malformed.bats` alone. The fix also gives each case its
   fixture and stub, routes assertions through the file's
   `check_quiet`/`check_fires` pair, and asserts the stub was reached.
   **Status**: FIXED
5. **Item 2.2 would have run a real probe on a fixture's host path** —
   `helpers/hook.bash` forbids this ("no fixture's absolute path reaches the
   host filesystem"). The text is now built with `readonly_path_text` and
   `git_lock_error` over scratch trees. The payload `cwd` and the `git merge`
   command are set so `_readonly_print_facts` runs its git reads. **Status**:
   FIXED
6. **Phase 2 mutation mechanics** — direct-probe tests source
   `$ROOT/lib/probes.sh`, so a `hook_copy_tree` copy cannot carry a lib
   fault there. The preamble now says how to build a scratch copy and run
   the one bats file from it, one fault at a time. It also carries the
   `command grep` note from recall. **Status**: FIXED
7. **Item 2.3's BSD clause was conditional** ("if the file's pattern has one")
   — the clause now names the existing stub case that satisfies the rule.
   **Status**: FIXED
8. **Item 2.4 faults applied together, and negatives were unpaired** — the
   faults are now "each alone". Each writer-exclusion negative is paired with
   the tool's reader form, and the `awk …` placeholders became concrete
   commands. **Status**: FIXED
9. **Item 2.5 left fixture discovery to the executor** — the five unfed
   fixtures and the two absent-only ones (verified by `rg` over `hook*.bats`)
   are now named. So are the sweep shape, the home file and the
   string-`"true"` positive control. **Status**: FIXED
10. **Item 3.1's scratch shim copy** — a copy at another path computes another
    `root`, so `shim.bats`'s `--plugin-dir "$ROOT"` assertion would fail for
    the wrong reason. The fault is now applied in the scratch checkout copy,
    with the suite run from there. **Status**: FIXED
11. **Item 3.3: open choice, missing dependency, no red** — "new helper, or
    the existing one" is now the new `tests/helpers/git-env.bash`. The suites
    found by `rg` are listed, and the item now depends on Items 2.2 and 2.4,
    whose new files must load the helper. A red is stated for the added
    `assert_no_git_above` calls. A standing rule makes later suites load the
    helper. **Status**: FIXED
12. **Item 3.4's expected outcome and fault were vague** — run against
    unchanged code, the outcomes are `mask` with an empty `path=` line for
    config on git-lock text, and `mask` (flag false) or `gone` (flag true)
    for pathless text. These are named, with an instruction to confirm them
    against `lock-detectors.md` and report any disagreement. The fault is
    now concrete: the absent-path branch printing `unknown`. **Status**: FIXED
13. **Item 5.1 SKILL.md budget, and a conditional `description`** —
    `SKILL.md` is at 173 of 200 lines, and the item now says so. The
    `description` was checked: it does not name whole-call semantics, so it
    stays. **Status**: FIXED
14. **Item 5.2: D-5's 57, the design.md cap fallback, the clone URL** —
    D-5 repeats `detectors.md`'s 57, so it is added to the corpus-naming
    edit. Moving D-8 frees only about 7 lines, so if that is not enough the
    item now says to stop and report rather than trim prose. The README
    clone URL is guarded, since Unchosen host is OUT. The "pinned by" lists
    gain the new test files. **Status**: FIXED
15. **Item 5.3 justfile choice** — the item offered two mechanisms with no
    observable outcome. It now states the outcome: `just --list` shows
    `Checks that run before every commit.` Either mechanism (just 1.46)
    meets it. **Status**: FIXED
16. **Outline numbering drift** — the outline's OUT note refers to "Item 2.6"
    (now 3.1). The header now maps outline numbers to runbook numbers.
    **Status**: FIXED
17. **Requirements on Item 5.2** — NFR-2 (README `jq` prerequisite), NFR-5
    (design move-out) and FR-1 were missing. Added. **Status**: FIXED

## Fixes Applied

- Header — outline-to-runbook numbering map; standing rules for the line cap,
  BSD-stub case and `git-env` loading
- Requirements mapping — FR-11 → NFR-5 for the cap rows; FR-1 on Major 2;
  skill-side Minors on the FR-9 row
- Item 1.1 — enumerated prose citations; both index sentences; NFR-5
- Phase 2 preamble — scratch-copy mutation mechanics, one fault at a time,
  `command grep`
- Item 2.1 — single file; per-case fixtures and stubs; marker and paired
  positive
- Item 2.2 — new `hook-writes.bats` + `probes-edges.bats`; scratch-built
  text, `cwd`, command
- Item 2.3 — BSD clause resolved
- Item 2.4 — new `probes-readonly-members.bats`; faults each alone; paired
  negatives; concrete commands
- Item 2.5 — fixtures enumerated; sweep shape; positive control for the
  string flag
- Item 3.1 — fault run from the scratch checkout copy
- Item 3.2 — `git` stub; corrected fault; NFR-5
- Item 3.3 — helper decided; suites listed; dependency on 2.2 and 2.4; red
  for `assert_no_git_above`
- Item 3.4 — expected tokens; concrete fault; confirm-against-doc step
- Item 4.1 — four slices, each with a case red against the previous slice;
  test file named
- Item 4.2 — direct and hook assertions split; negatives; file scope;
  dependency on 2.4
- Item 4.3 — slices swapped; style-reset assertion; command string;
  hooks.json interface; `TMPDIR` run; stub tools; FR-1
- Item 5.1 — `recipes-and-claude.md` added; SKILL.md budget; description
  resolved
- Item 5.2 — hook.md pilot claim; FR-1 and Architecture; D-5's 57; "pinned
  by" lists; design.md stop-and-report fallback; clone URL guard; BRIEF.md
  out of scope; requirement ids
- Item 5.3 — observable `just --list` outcome

## Verified against the repo

Cited symbols and tests exist (checked with `rg` and reads):

- In `hooks/annotate.sh`: the three `|| exit 0` sites (:111, :122, :124), the
  flag-policy `case`, the jq `== true`.
- In the libs: `match_tmpdir_unset` (curly-quote alternation, :179) and
  `match_phantom_untracked` (`|[[:space:]]+`, :115); `_readonly_readfile_arg`
  and its four writer arms and `*.out | *.err`; `_readonly_merge_segment`;
  `_readonly_print_facts`; `_readonly_repo_facts`' `match=` append;
  `_readonly_git_dir`, which returns absolute; `_probe_lock_at`.
- In the test helpers: `hook_copy_tree`, `stub_probe`, `stub_lib`,
  `make_spy`, `make_scratch_repo`, `readonly_path_text`, `git_lock_error`,
  `assert_no_git_above`.
- In the suites: `check_quiet` and `check_fires`; "hooks.json names both
  events"; "hook needs no temp dir"; "probe writes nothing";
  `probes-config.bats` :96-101 and :131-151; `tracked.sh`'s `ls-files` guard;
  `check_cap`'s read guard.
- In the docs and reports: the SKILL.md sections and node sections named in
  5.1; design.md :130/:222/:271/:341/:379; `item-4-2-s1-code-review.md`,
  `item-4-3-s1-green.md`, `review-skill-fixes.md`; the `plans/2026-09-0*`
  evaluation files.

Current `_readonly_readfile_arg` output was run for every Item 2.4 and 4.1
fault and slice: each red case is red today, or under its stated fault. The
probe outcomes cited in Item 3.4 were observed on unchanged code.

## Design Alignment

- D1 runs through Items 5.1 and 5.2 as the documented every-command rule,
  recorded as not observed (2.288 and 2.289), with the decoy dropped and
  `git *` syntax. The added `recipes-and-claude.md` and hook.md sites are the
  same propagation.
- D2 maps to Item 4.3: printf-built JSON, writes nothing, exit 0, both
  channels, and now the style reset. The README half sits in 5.2.
- D3 maps to Item 4.2: absolute `<repo>/<name>`, where `repo` is already
  absolute.
- D4 maps to Item 4.1: one slice per clause, with the residual documented.
- D5 is the Phase 2 and 3 preamble. Mechanics were added; the policy is
  unchanged.
- Phase structure: Phase 1 (1 item), Phase 2 (5), Phase 3 (4), Phase 4 (3,
  tdd), Phase 5 (3). No phase is over 8 items or over 40%. There are no
  circular dependencies. Pins precede the code changes they guard (2.4 → 4.1).
