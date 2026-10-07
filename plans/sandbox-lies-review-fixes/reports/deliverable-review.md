# Deliverable Review: sandbox-lies-review-fixes

**Date:** 2026-10-07
**Methodology:** `docs/references/deliverable-review.md` is cited by the edify
skill but does not ship in edify 0.3.0. This review uses the skill body's
review axes and its three severity levels in its place, and the Layer 1
delegates were given them inline.

## Inventory

**Range:** `52e6dd82b831a1cc2b7b516d4c248df6fb1ebc8c..HEAD`. This is what
`edify-review-range.sh plans/sandbox-lies-review-fixes/outline.md` printed
(exit 0), and it was reviewed whole. It covers 268 commits: the first build
(plan `plans/sandbox-lies/`) and the review-fixes build (base `a7ff5e5`, in
`.git/build-baseline`).

**Two documents scope the review more narrowly. This review does not follow
them:**

- The outline's §Provenance says the earlier review ran over `e873bf4..HEAD`
  and that "a reviewer of this job should do the same".
- `delegate-status.md` §Finish says the build's own review gate covered only
  this job's changes, leaving out the main session's `0bbb18c`, `161d958` and
  `11b96a4`/`533dca7`.

**Conformance baselines:**

- `plans/sandbox-lies-review-fixes/outline.md`, including its D1 revision of
  2026-10-05, and its `runbook.md`, for this job's items;
- `plans/sandbox-lies/outline.md`, the superseded first-build outline, for the
  rest of the range;
- the living `docs/design.md` and its `docs/references/` nodes;
- `plans/sandbox-lies/reports/deliverable-review.md`, whose findings this job
  fixes.

**Excluded as known:** the outline's OUT list, `build-finish.md`
§Carry-forward and `delegate-status.md` §Carry list. An item there is reported
only where the current tree shows it wrong or worse.

**Layers:**

- **Layer 1:** three opus delegates, one each for code, tests, and prose plus
  config, launched unnamed. Only the tests delegate ran bats, one file at a
  time.
- **Layer 2:** the main review session. It formed its own judgement from the
  deliverables before reading any Layer 1 report.
- **Gate:** `just precommit` ran on the current tree in this session and exited
  0. Its sign-off was "plugin.json, hooks.json, shellcheck, bash -n, rumdl,
  line limits, links, tests": 309 bats tests, 0 failed.

126 files, +14702 / −250 outside `plans/`, `tmp/` and the handoff files.

| Type | Files | Lines (current) |
| --- | --- | --- |
| Code: hook and lib | `hooks/annotate.sh`, `hooks/check-jq.sh`, `lib/matchers.sh`, `lib/probes.sh`, `lib/probes-readonly{,-command,-facts}.sh`, `lib/verdicts.sh` | 1653 |
| Code: gates and tooling | `scripts/check-line-limits.sh`, `scripts/check-links.sh`, `scripts/lib/{tracked.sh,strip-code.awk}`, `scripts/run-bats.sh` (1-line change), `tests/extract-fixtures.py`, `tests/corpus-eval.py`, `justfile` `precommit` | 894 + recipe |
| Test | 29 `tests/*.bats`, 7 `tests/helpers/*.bash` | 8135 |
| Test fixtures | 34 `fire-*`/`quiet-*` (all cut by `SPEC`), 2 `payload-*.json` | ~1077 |
| Agentic prose | `skills/sandbox-lies/SKILL.md` and its 4 `references/` nodes | 580 |
| Human docs | `docs/design.md`, `docs/references/{detectors,hook,lock-detectors,readonly-path,rejected-alternatives,sandbox-state}.md`, `docs/changelog.md`, `README.md`, `CLAUDE.md`, `BRIEF.md` (re-wrap only) | 1593 + BRIEF |
| Configuration | `hooks/hooks.json`, `.envrc`, `.gitignore`, `.rumdl.toml`, `pyproject.toml`, `uv.lock`, `.claude-plugin/plugin.json`, `.claude/settings.json`, `.gitmodules`, `LICENSE`, `.claude/gitlore-hook-setup` | ~200 |
| Not reviewed | `plugin-dev/` (vendored toolkit subtree, 9 files, +755/−183); `memory` (submodule added in range, with no prior pointer to diff from); `.gitlore/bin/claude` (gitlore-generated, read only for m-7) | — |

**Design conformance:**

- Every in-scope item of the review-fixes outline produced its deliverable,
  except one: Item 2.6 (runbook Item 3.1, the BSD `paste` stub and the
  `shim.bats` case).
  - It landed and was later removed with `.bin/claude` by `0bbb18c`, the
    migration to the toolkit's shim (D-16).
  - The prose is consistent with that removal. One stale test comment remains
    (m-15).
- D1 as revised now appears consistently across the skill, its four nodes,
  `lock-detectors.md`, `hook.md`, `design.md`, `README.md` and the changelog.
- D2, D3 and D4 conform, and so do Items 5.4 and 5.5.
  - Each was checked by direct runs (L1-code) and by named faults
    (L1-tests, 39 mutations).
  - Layer 2 independently re-ran `hooks/check-jq.sh` with a jq-less `PATH`. It
    produced one JSON object with `hookEventName` `SessionStart`, `jq` named in
    both channels, no raw ESC byte, empty stderr and exit 0, and nothing when
    `jq` is present.
- The first build's six Majors: five are fixed, and Major 5 is partly fixed
  (Major 1 below).

**Process note:**

- During its mutation runs, the tests delegate's cleanup glob over
  `/tmp/claude-1000/cj.*` deleted two files it had not created (`cj.out`,
  `cj.err`). No tracked file was touched.
- The only check-jq capture in this review that could have used them is
  L1-code's, so Layer 2 repeated that run from a private `mktemp -d`
  directory. The result above is that repeat.
- The tests delegate was then told to use a per-reviewer scratch directory.

## Critical Findings

None.

## Major Findings

1. **The trailing-slash form of `phantom-untracked` is still unpinned (first
   review Major 5, partly fixed).** [L1-tests M-1, checked by reading in L2]
   - **Where:** `tests/matchers-edges.bats:134-147`, against
     `lib/matchers.sh:117-118`. The requirement is `detectors.md:93`'s
     "optional trailing slash" and Item 2.3.
   - **Axes:** coverage, vacuity.
   - **Gap:** the new case's block holds three masked names, and only
     `.claude/skills/` carries the slash. The other two already meet the
     threshold of two, so dropping `/?` from the pattern changes nothing.
   - **Evidence:** that mutation left `matchers-edges.bats` and
     `matchers.bats` green.
   - **Impact:** a regression that stops counting slash-terminated directory
     masks passes the suite. Long-format and porcelain status both print
     directories with the slash.
   - **Fix:** a block of exactly two masked names, one carrying the slash.
     That also pins the strip that counts `x` and `x/` once.

## Minor Findings

### Docs and skill against behaviour or evidence

- **m-1. The `design.md` state layer is stale.** [L1-prose m-1, L2]
  - The Status line (`docs/design.md:3-8`) lists the `SessionStart` `jq` check
    as built and tested, yet still reads "Verified against `0df5864e`
    (2026-09-27)", a commit that predates every review fix.
  - §Now's Focus (`:19`) still says "closing the first build".
- **m-2. Strict mode does not refuse the per-call flag; it ignores it.**
  [L1-prose m-2; L2 checked the settings reference, fetched 2026-10-07]
  - `SKILL.md:69` and `escapes-and-costs.md:12` say "refused". The settings
    reference says "Claude Code ignores that parameter", so the command runs,
    sandboxed.
  - An agent can read "refused" as "never executed".
- **m-3. The revised D1 makes D-8's accepted tradeoff live, and its
  mitigation claim no longer holds.** [L1-prose m-3, L2, found independently]
  - **Where:** `docs/references/sandbox-state.md:12-16`; `design.md:285-288`
    (D-8) and `:383-384` (L-2); the flag policy at `detectors.md:192-193`;
    the gate at `hooks/annotate.sh:97`.
  - **The claim:** "the probes cover the verdicts where it matters".
  - **Why it no longer holds:** exclusions are now recorded as honoured, and
    the documented baseline (`excluded-commands.md:47-51`) excludes `claude`.
    A covered `claude --resume` therefore runs unsandboxed with no flag.
  - **Consequence:** if it fails for any other reason, `resume-lost`, which has
    no probe, tells the agent the transcript was never written inside the
    sandbox. A `git-lock` on a covered `git` whose lock was gone by probe time
    reads `mask`; its act is harmless.
  - **Not re-examined:** neither the D1 revision nor Item 5.2 revisited this.
    The remedy is a design call.
- **m-4. The bare-`git status` re-probe assumes no mask name is gitignored.**
  [L1-prose m-4]
  - **Where:** `SKILL.md:22-29`, `excluded-commands.md:23-25` and
    `lock-detectors.md:110-112`.
  - **Gap:** `git status` omits ignored paths, so in a repository ignoring the
    mask names, a sandboxed run lists none and reads as proof of an
    unsandboxed one.
  - **Fix:** qualify the proof, or use `--ignored` or `ls -a`.
- **m-5. Allow rules are missing from what clears an unsandboxed command.**
  [L1-prose m-5]
  - **Where:** `SKILL.md:54-57`, `:74-77`; `escapes-and-costs.md:51-53`;
    `excluded-commands.md:121-134`.
  - **Gap:** only the read-only validator is named. The sandboxing doc also
    lets allow rules approve an escaped command; L2 confirmed its line
    "commands your allow rules cover run without a prompt".
- **m-6. "Pinned by" lists lag this job's last tests.** [L1-prose m-6]
  - FR-3 (`design.md:77-80`) does not name the runtime-failure cases in
    `hook-malformed.bats`.
  - FR-4 (`:91-98`) never names Item 5.5's `tests/hook-locks-pathless.bats`.
    Its `tests/probes*.bats` glob does cover `probes-lock-newline.bats` and
    `probes-readonly-pins.bats`.
- **m-7. `.gitlore/bin/claude:4` points at "docs/design.md 'Memory Redirect
  Launcher' (D10)"**, which in this repository is sandbox-lies' own design.
  The file is gitlore-generated, so the fix is upstream. [L1-prose m-7]
- **m-8. An unquoted `${CLAUDE_PROJECT_DIR}` in `.claude/settings.json:9`**
  (the version-guard hook) splits on a blank. The line predates the range and
  is written by the toolkit installer, so the fix is upstream in
  claude-plugin-dev. [L1-prose m-8]
- **m-9. The `justfile` helper `tracked()` now also lists
  untracked-unignored files**, while `scripts/lib/tracked.sh` and
  `tests/docs.bats` keep the tracked-only meaning. One word now covers two
  scopes. [L1-prose m-9]

### Code

- **m-10. `hooks/annotate.sh:9-12` says that with `jq` present the hook
  writes nothing to stderr.** [L1-code m-1, L2]
  - **The code disagrees:** the probes pass unexpected stderr through by
    design, at `lib/probes.sh:130` (`stat`) and `:281` (holder tool).
  - **Evidence:** reproduced with a stub `lsof` that writes to stderr.
  - **Related:** the `lib/probes.sh:6-7` header lists only the lock keys,
    although it introduces every probe.
- **m-11. An unquoted glob or `$VAR` in a reader's operand becomes a literal
  `readfile=` name.** [L1-code m-2]
  - **Where:** `lib/probes-readonly-command.sh:229-238`.
  - **Example:** `grep -l pat *.log` makes the verdict say "Re-run the command
    that wrote `*.log`".
  - **Docs:** the residual list in `readonly-path.md` does not name this.
- **m-12. `just precommit` never compiles `tests/extract-fixtures.py` or
  `tests/corpus-eval.py`, and no suite runs them.** A syntax error passes the
  gate. This is distinct from the carried m-7. [L1-code m-3]
- **m-13. `tests/corpus-eval.py:61`: the prefilter string "no active
  session"** belongs to no matcher or candidate discriminator, and the comment
  at `:47-51` gives no reason for it. [L1-code m-4]

### Tests

- **m-14. `tests/hook-candidates.bats:169-205` has no `assert_no_git_above`
  guard.** [L1-tests m-1]
  - The case runs a real probe from `$BATS_TEST_TMPDIR`. A repository above
    the temp root with a `feat2` branch turns it red (shown by the delegate).
  - `item-3-3.md`'s list of guarded cases misses it. The failure is loud,
    not a wrong pass.
- **m-15. `tests/helpers/probes.bash:209-211` names the deleted
  `tests/shim.bats` as a caller of `run_probe_bounded`.** It also does not
  mention that the 3 s bound is sensitive to load. [L1-tests m-3,
  L1-prose note, L2]
- **m-16. `check-jq.bats` cannot see a silent write.** [L1-tests m-2]
  - **Gap:** its missing-`TMPDIR` case has no `mktemp` spy.
  - **Evidence:** a stderr-silenced `mktemp` with a `/tmp` fallback survived.
  - **Consequence:** NFR-4's "pinned by `tests/check-jq.bats`"
    (`design.md:197-200`) overstates what is pinned.
- **m-17. Helper "shared by" comments are incomplete.** They are at
  `tests/helpers/probes.bash:62` and `:150`, and `tests/helpers/hook.bash:6`.
  [L1-tests m-4]
- **m-18. The per-suite BSD-stub rule is unevenly met.** [L1-tests m-5, L2]
  - **The rule:** NFR-2 (`design.md:182-183`) says "every bats file loads
    it", which holds. But `CLAUDE.md` asks that a suite exercising shell code
    keep one `make_bsd_stubs` case.
  - **Suites with no such case:** twelve. `probes-config`, `probes-edges` and
    `probes-readonly-pins` among them drive `stat`/`wc`/`sed` code.
  - **Mitigation:** sibling suites cover those paths under stubs, and the
    state dates from the first build.

## Gap Analysis

| Design requirement | Status |
| --- | --- |
| Item 1.1: `readonly-path` split into its own node | Covered |
| Item 2.1 (Major 3): FR-3 runtime-failure silence | Covered: three faults, each red |
| Item 2.2 (Major 4): NFR-4 on the probe path | Covered (here-document residual documented) |
| Item 2.3 (Major 5): curly quotes, tab-indented names with a trailing slash | Partial: Major 1 |
| Item 2.4 (Major 6): fact-table members | Covered |
| Item 2.5 (Tests m-1): flag pairing, string flag | Covered |
| Item 2.6 / runbook 3.1 (Tests m-3): BSD `paste` stub, shim case | Superseded: removed with `.bin/claude` by `0bbb18c` (D-16); stale comment m-15 |
| Item 2.7 / 3.2 (Tests m-2): gate exit-2 paths | Covered |
| Item 2.8 / 3.3 (Tests m-4): host git config isolation | Covered; residual m-14 |
| Item 2.9 / 3.4 (Tests m-5): positive config assertions | Covered |
| Item 3.1 / 4.1 (code m-2): D4 operand rule | Covered; undocumented residual m-11 |
| Item 3.2 / 4.2 (code m-3): D3 absolute `match=` | Covered |
| Item 3.3 / 4.3 (Major 2): D2 `SessionStart` jq check | Covered; test specificity m-16 |
| Item 4.1 / 5.1 (Major 1): skill per D1 as revised | Covered; m-2, m-4, m-5 |
| Item 4.2 / 5.2: doc halves and doc Minors | Covered; m-1, m-3, m-6 |
| Item 4.3 / 5.3: stale comments and help text | Covered; the rewritten `annotate.sh` stderr sentence overreaches (m-10) |
| Item 5.4: readonly `path=` newline guard | Covered |
| Item 5.5: lock-probe `path=` newline guard | Covered |
| Outline-scoped line caps (`detectors.md`, `design.md` ≤ 400) | Covered: 286 and 399 |
| First-build scope (superseded outline), rest of the range | Covered per the first review; its unfixed items are this job's OUT list and carry lists, re-confirmed by the delegates and not counted here |

## Summary

| Severity | Count |
| --- | --- |
| Critical | 0 |
| Major | 1 |
| Minor | 18 |

Minors by group: docs and skill 9, code 4, tests 5.

- **Merged duplicates, each counted once:** L1-prose m-3 with L2's D-8 /
  `resume-lost` finding; L1-prose m-1 with L2's state-layer finding; L1-code
  m-1 with L2's stderr finding; L1-tests m-3 with L1-prose's out-of-partition
  note and L2; L1-tests m-5 with L2's BSD-stub check.
- **Shape:** the one Major is a verification gap left from the first
  review's Major 5. The Minors are mostly accuracy and staleness in prose and
  comments, plus one design consequence of the D1 revision (m-3) that needs a
  decision.

## Sub-reports

- `plans/sandbox-lies-review-fixes/reports/deliverable-review-code.md`
- `plans/sandbox-lies-review-fixes/reports/deliverable-review-tests.md`
- `plans/sandbox-lies-review-fixes/reports/deliverable-review-prose-config.md`
