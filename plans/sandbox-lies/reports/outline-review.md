# Outline Review: sandbox-lies

**Artifact**: plans/sandbox-lies/outline.md
**Date**: 2026-09-22
**Mode**: review + fix-all (PDR criteria)
**Requirements**: `BRIEF.md` (source), `docs/design.md` FR-1..FR-11 and
NFR-1..NFR-4, mechanism in `docs/references/detectors.md`

## Summary

The outline is a lean, well-sequenced plan that defers correctly to the
living design, but it inherited one architecture-level gap from the design
and several planning gaps. The critical one: in the CC 2.1.280 bundle a
failed Bash call (non-zero exit) fires `PostToolUseFailure`, not
`PostToolUse`, so the single-event hook would miss nearly every symptom it
exists for. The build also could not pass its own FR-11 gate on day one:
five tracked files already fire `git-lock`. All issues are fixed in the
outline. Where the fix needs a change in `docs/design.md` or `detectors.md`
(which this review did not edit), the outline now lists it as amendments
A-1 to A-8, each tied to the phase it gates.

**Overall Assessment**: Needs Iteration. The approach is sound once A-1 is
adopted. Eight open questions need the user's decision, and the Provenance
`Base:` is `TODO` pending an author decision (see Escalation).

## Requirements Traceability

| Requirement | Outline Section | Coverage | Notes |
|---|---|---|---|
| FR-1 annotate, never intervene | Phase 2 (`hooks.json`, `hook.bats`), A-1 | Complete (after fix) | Was Partial: the FR-1 "only two keys" assertion was missing from `hook.bats`, and the single event misses failures |
| FR-2 matcher contract | Phase 1, A-5 | Complete | Flag gating placed outside matchers (A-5) |
| FR-3 one hook composes | Phase 2, A-1 | Complete (after fix) | Text source per event (`error` vs `tool_response`) now specified |
| FR-4 probes, live proof | Phase 3, Phase 4, A-3, A-4, Q6 | Complete (after fix) | Was Partial: `held`, config-lock and tmp-full reproductions were missing; candidate probes had been sequenced before their detectors |
| FR-5 sandbox-state awareness | Phase 2, A-5 | Complete (after fix) | Was Partial: both-flag expectations undefined for most detectors |
| FR-6 verdict text | Phase 2 (`verdicts.bats`) | Complete | — |
| FR-7 catalogue, corpus figure | Phase 4 | Complete (after fix) | Was Partial: no ship rule; shipping figure taken from layer 1 instead of the shell-arbiter harness |
| FR-8 fixtures from corpus | Phase 4 | Complete | Payload fixtures added in Phase 2 are a separate class, exempt from docs.bats scope |
| FR-9 skill | Phase 5 | Complete (after fix) | Added the read-only-inspection default and `$TMPDIR` instability |
| FR-10 memory retirement | Phase 6, A-6 | Complete (after fix) | Was Partial: inbound links, root index line, existing `shared-claude.md` bullet and dead bats cases were missing |
| FR-11 self-quiet | Phase 1, Phase 2, A-2, A-7 | Complete (after fix) | Was infeasible as written: red on day one |
| NFR-1 precision | Phase 1 (harness promoted), Phase 4 | Complete (after fix) | Phase 1 had kept the harness in `plans/`, contradicting NFR-1's "under `tests/`" |
| NFR-2 portability | Phase 1 gate, Phase 3 (`stat`), Phase 4 (`timeout`) | Complete (after fix) | — |
| NFR-3 cost | Phase 2 (timeout, latency recorded) | Partial | Hot-path (no-verdict) cost is recorded, not gated; the design sets no bound (design finding D-11) |
| NFR-4 hermetic | A-8 | Complete (after fix) | Hook now writes nothing |
| BRIEF §1 repo init | Phase 1 first bullet, Phase 5 | Complete (after fix) | Staged tier mount was uncommitted and unmentioned |
| BRIEF §3 promote + `just test` | Phase 1 | Complete | — |
| BRIEF §3.1 hook | Phase 2 | Complete | — |
| BRIEF §3.2 layer-3 probes with live runs | Phase 3, Phase 4 | Complete (after fix) | — |
| BRIEF §3.3 convert ~7 sections | Phase 4, Phase 6 translation audit | Complete (after fix) | Audit added so no section is dropped silently |
| BRIEF §4 retirement + three loose ends | Phase 5 (skill home), Phase 6, Q4 | Complete | Store correction on the `!` path is already in the store and in L-1 |
| BRIEF §5 release | Scope OUT | Complete | Explicitly deferred; install blocker recorded |
| BRIEF still-open: phantom-gitadd re-measure | Scope OUT | Complete (after fix) | Now explicit |
| BRIEF still-open: self-polluting corpus | Phase 4 (date + pilot-traffic note) | Complete | — |
| BRIEF verification standard (fault injection) | Verification standard section | Complete (after fix) | Was Missing |

**Traceability Assessment**: Gaps identified and fixed.

## Scope-to-Component Traceability

| Scope IN Item | Component | Notes |
|---|---|---|
| Repo init completion | Phase 1 | Added |
| Pilot promotion + layer-2 harness | Phase 1 | Harness added |
| Hook on both events, verdicts, suites | Phase 2 | — |
| Lock probes + live reproductions | Phase 3 | — |
| Candidates + their probes | Phase 4 | Probes moved here from Phase 3 |
| Skill, README, LICENSE, CLAUDE.md | Phase 5 | — |
| Dogfood + retirement | Phase 6 | — |
| Design amendments A-1..A-8 | "Design amendments owed", each gating a phase | Added; previously the outline had no home for design-level corrections |
| Fault-injection standard | Verification standard | Added |

**Scope Assessment**: The original Scope said "IN: everything above". It
is now enumerated, and no item is orphaned.

## Review Findings

### Critical Issues

1. **A `PostToolUse`-only hook never sees a failed Bash call**
   - Location: Approach, Phase 2 (`hooks/hooks.json`); design FR-1, FR-3,
     D-3, Architecture
   - Problem: In the CC 2.1.280 bundle, the Bash tool throws its shell error
     when the exit code is non-zero. The throw is caught on the tool-failure
     path, which dispatches `PostToolUseFailure` with the result text in an
     `error` string. `PostToolUse` (with `tool_response`) runs only on
     success. The schema accepts `additionalContext` on
     `PostToolUseFailure`. Locks, config locks, the `git add` refusal, and
     every candidate except the listings are failing commands. The design
     would fire only on the piped cases, such as the `tail` fixture.
   - Fix: Amendment A-1. `hooks.json` registers the same script on both
     events. `annotate.sh` takes its text from `error` or `tool_response`
     depending on the event. Both payload shapes are recorded live before
     any test is written. Each call fires one event, so D-3's composition
     holds.
   - **Status**: FIXED in outline; design amendment owed (A-1)

### Major Issues

1. **Provenance: `Derived from:` names a prior artifact that has no `Base:`**
   - Location: Provenance
   - Problem: `plans/brief-sandbox-detector-pilot.md` resolves but carries
     no Provenance or `Base:` of its own, so the superseding route has no
     base to copy. `Derived from:` also names `BRIEF.md` (a requirements
     brief), not a review report.
   - Fix: `Base:` set to `TODO`, per the repair table. The replaced value
     was `52e6dd82b831a1cc2b7b516d4c248df6fb1ebc8c`. It is a full sha,
     reachable from HEAD, and equal to HEAD today. `Derived from:` is left
     as found.
   - **Status**: FIXED (repair applied); author decision escalated below

2. **FR-11 gate is red on day one**
   - Location: Phase 1, Phase 2 `tests/docs.bats`
   - Problem: Running the pilot matchers over every tracked file outside the
     fixtures fires `git-lock` on five files: `matchers.sh` and
     `matchers.bats` (their grep literals hold git's follow-on sentence
     whole), plus the layer-1 replay script, its hits JSONL and the layer-2
     report, which Phase 1 keeps in `plans/`. The first two are promoted
     into the scope the test covers.
   - Fix: A-2. Literals are built from fragments, the dated `plans/`
     evidence is exempted by name, and the choice goes to the user (Q8).
   - **Status**: FIXED

3. **NFR-1 harness location contradicted**
   - Location: Phase 1
   - Problem: NFR-1 pins "the replay harness under `tests/`". Phase 1 kept
     both Python harnesses in `plans/`, and Phase 4 measured candidates with
     the layer-1 string replay rather than the shell matchers the brief's
     figures used.
   - Fix: The layer-2 harness is promoted to `tests/corpus-eval.py`. Phase
     4 triages with layer 1 and measures with layer 2, with the prefilter
     extended and the flag joined from the tool-use input.
   - **Status**: FIXED

4. **Probe/verdict interface mismatch**
   - Location: Phase 3; design FR-4, Architecture Flow, detectors.md
     Conventions
   - Problem: A probe "returns one outcome token", but the verdicts
     interpolate a pid, a byte count, an age, a path and percentages.
   - Fix: A-3 contract: outcome token on the first line, then `key=value`
     lines. The flag is passed as `$1`.
   - **Status**: FIXED

5. **Holder-check degradation would hand a held lock a removal
   instruction**
   - Location: Risks (original), Phase 3
   - Problem: The outline degraded to `orphan` when `lsof` was absent.
     `lsof` is absent on this Linux box today. A held lock also fails an
     identical retry, so the `orphan` verdict's "removing it is safe" would
     apply to it. That is the exact damage the plugin exists to prevent.
   - Fix: Try `lsof -t`, then `fuser` (present here). With neither, the
     outcome is `unknown` and its verdict carries no removal instruction
     (A-4). A test with no holder tool on `PATH` was added.
   - **Status**: FIXED

6. **`mask` verdict absorbs the hook-env leak**
   - Location: Phase 3; detectors.md git-lock verdicts
   - Problem: An `excludedCommands`-unsandboxed git call carries flag false
     (D-8), so a leak failure there lands in `mask`, whose text omits the
     repeat-failure route that `gone` has. The recall artifact requires
     that the git-lock verdict not absorb `git-hook-env-leak`.
     Separately, a lock that stats as a character device has no outcome in
     the table.
   - Fix: A-4 adds the clause to `mask` and a chardev → `mask` row. The
     chardev case is tested by pointing the probe at `/dev/null`.
   - **Status**: FIXED

7. **Both-flag expectations undefined**
   - Location: Phase 2 `hook.bats`; design FR-5; detectors.md
   - Problem: FR-5 pairs every fixture with both flag values, but
     flag-true behaviour is defined only for `git-lock` and some
     candidates. The assertions cannot be written.
   - Fix: A-5. A per-detector flag policy is set before Phase 2, and the
     gating lives in the hook or the verdict, not the matcher.
   - **Status**: FIXED

8. **Live reproductions incomplete; candidate probes mis-sequenced**
   - Location: Phase 3
   - Problem: FR-4 requires a live proof for every probe. `held`,
     config-lock and tmp-full had none. `probe_readonly_path` and
     `probe_tmp_full` were built before their detectors passed the replay.
     Sandboxed reproductions also have to nest the git call, because
     `git:*` unsandboxes a top-level call.
   - Fix: Added the `held` and config-lock reproductions and the nesting
     note. Candidate probes moved to Phase 4, built only if the detector
     ships. The tmp-full proof goes to the user (Q6).
   - **Status**: FIXED

9. **`tmp-full` cannot fire through a `/tmp` buffer**
   - Location: Phase 2; `lib/matchers.sh` `detect`
   - Problem: `detect` buffers via `mktemp` under `${TMPDIR:-/tmp}`. Hooks
     run outside the sandbox with `$TMPDIR` unset, so the buffer lands in
     `/tmp`. When `/tmp` is full, the buffer fails and the detector goes
     silent exactly when it should fire.
   - Fix: A-8. The hook holds the text in a shell variable.
   - **Status**: FIXED

10. **Candidate matchers as bare substrings break FR-11 and precision**
    - Location: Phase 4; detectors.md Candidates
    - Problem: Each candidate is specified as an unanchored literal. Once
      built, those literals fire on `detectors.md`, the skill, and this
      repo's own traffic. Those are the self-reference classes the pilot's
      discriminators were designed to remove.
    - Fix: A-7. Each candidate gets a replay-selected shape discriminator,
      and the reference describes strings rather than quoting them. The
      skill does the same.
    - **Status**: FIXED

11. **No ship rule for candidates**
    - Location: Phase 4
    - Problem: FR-7 requires a figure but no threshold. The pilot shipped
      detectors at 64% and 67%, so the rule is implicit.
    - Fix: Proposed rule: at least one true positive, and every false
      positive classified as self-reference or as a named residual. It is
      marked proposed and goes to the user (Q5).
    - **Status**: FIXED (new decision, flagged for confirmation)

12. **Retirement incomplete**
    - Location: Phase 6
    - Problem: Six other ddaanet facts link `[[sandbox-effects]]`. The root
      index carries a second line. `shared-claude.md` already has the
      phantom-dotfile bullet, pointing at the retiring file, so Q4's "add a
      line" would duplicate it. The two live-memory bats cases would skip
      forever after deletion, breaking the "0 skip" invariant silently. The
      tier was never published.
    - Fix: Phase 6 now lists every link and both index lines, amends the
      existing bullet, deletes the two cases, adds a section-by-section
      translation audit before deletion, and publishes the tier.
    - **Status**: FIXED

13. **FR-10's reference check fails on the design itself**
    - Location: Phase 6; design FR-10
    - Problem: "Fails if the file is still referenced from this repo"
      fails on `docs/design.md`, the changelog, `BRIEF.md` and `plans/`.
    - Fix: A-6 limits the check to live pointers.
    - **Status**: FIXED

14. **Scope IN not enumerated**
    - Location: Scope
    - Problem: "IN: everything above" fails the PDR's enumeration
      criterion.
    - Fix: IN and OUT are now bulleted. OUT gains `PostToolBatch`,
      prompt hooks, L-1, "Not detectors", and the phantom-gitadd re-measure.
    - **Status**: FIXED

15. **Dogfood route unstated; install blocker; knowledge gap**
    - Location: Phase 6, Risks
    - Problem: `/plugin install` clones with submodules, and this repo's
      `.gitmodules` url is the relative local placeholder, so install aborts
      (memory `plugin-recurse-clone`). Retiring a shared-tier fact before
      release leaves repos without the plugin with neither the fact nor the
      hook.
    - Fix: Q7 proposes `--plugin-dir` and asks whether retirement waits for
      release. Both points are added to Risks.
    - **Status**: FIXED (decision escalated as Q7)

16. **Fault-injection standard missing**
    - Location: (absent)
    - Problem: The brief's verification standard ("a fixture suite that
      has never been fault-injected is not evidence") was not carried into
      the new suites.
    - Fix: A "Verification standard" section was added.
    - **Status**: FIXED

### Minor Issues

1. **Q3 premise stale.** The root `memory/MEMORY.md` measures 22,147 bytes
   today, under the ~24,985 cutoff, so the overshoot no longer argues for
   early retirement. Q3 was updated with the measurement. **Status**: FIXED
2. **Lock-path resolution contradicted `detectors.md`.** The outline
   resolved against `CLAUDE_PROJECT_DIR`, while the reference says "the
   repository the call ran in". git prints the path absolute (fixtures
   confirm). A relative path now resolves against the payload `cwd`.
   **Status**: FIXED
3. **`jq empty hooks/hooks.json` in Phase 1**, before the file exists.
   Moved to Phase 2. **Status**: FIXED
4. **Skip count.** `run-bats.sh` counts a skip as passed, so the gate now
   reads the TAP log. **Status**: FIXED
5. **Unquoted `${CLAUDE_PLUGIN_ROOT}`** in the hook command. Now quoted.
   **Status**: FIXED
6. **Live-payload capture mechanism unstated**, and whether an unset flag
   is absent or `false`. Both are now specified, including the scratch
   directory because `claude -p` runs `SessionStart` hooks. **Status**: FIXED
7. **Hook failure mode.** The hook now fails open (exit 0, no output),
   with a `select(type == "object")` guard (memory
   `jsonl-reader-type-guard`) and a malformed-payload test. JSON is built
   with `jq -n --arg`. **Status**: FIXED
8. **Lock verdicts before probes exist.** Phase 2 had no outcome for
   git-lock or config-lock. Those cases now join in Phase 3. Probes are
   stubbed in `hook.bats` so fixtures' foreign absolute paths never reach
   the host filesystem. **Status**: FIXED
9. **Portability.** The outline now covers GNU vs BSD `stat` and the
   missing `timeout` on macOS. **Status**: FIXED
10. **Repo init completion.** The staged tier mount was uncommitted and
    unmentioned. It is now the first step of Phase 1. **Status**: FIXED
11. **Skill content.** Added the read-only-inspection default and
    `$TMPDIR` instability across sandboxed calls, which were unassigned in
    the translation. Strings are described, not quoted. **Status**: FIXED
12. **Harness's own sandbox-violation annotation.** The bundle appends one
    to sandboxed failure output, which may change matcher input and overlap
    readonly-path. Added to Risks. **Status**: FIXED
13. **NFR-3 hot path.** Hook latency on a quiet fixture is now recorded.
    **Status**: FIXED

## Findings on docs/design.md and detectors.md (not edited)

Each finding is carried into the outline as an amendment. They are listed
here so the design owner can apply them.

- **D-1 (Critical)** FR-1, FR-3, D-3, Architecture: name both
  `PostToolUse` and `PostToolUseFailure`; the Flow's "stdout, newline,
  stderr" applies to the success payload only (A-1).
- **D-2** FR-11 / D-10: record the dated `plans/` evidence as a second
  residual beside fixture reads, or require its removal (A-2).
- **D-3** FR-4 and the detectors.md Conventions: the probe output is a
  token plus values, not one token (A-3).
- **D-4** detectors.md git-lock: add `unknown` (no holder tool) and chardev
  → `mask`. The `mask` verdict needs the hook-env-leak repeat-failure clause
  (A-4).
- **D-5** detectors.md: state flag-true behaviour for `config-lock`,
  `phantom-chardev`, `phantom-untracked`, `phantom-gitadd` (A-5).
- **D-6** FR-10 pin: live pointers only (A-6).
- **D-7** detectors.md Candidates: matchers given as bare quoted
  substrings. They need discriminators, and the quotations will fire FR-11
  once built (A-7).
- **D-8** NFR-4: the hook runs with `$TMPDIR` unset, so "writes only under
  `$TMPDIR`" means `/tmp`, and `detect`'s file buffer defeats `tmp-full`
  (A-8).
- **D-9** D-2 contradicts itself. It says "the agent may still act on the
  result before reading the verdict", then "It cannot". Keep one.
- **D-10** FR-4 names only `tmpdir-unset` and `resume-lost` as flag-only,
  but `zellij-socket` and `readonly-path` are flag-gated too.
- **D-11** NFR-3 bounds the verdict path only. The no-verdict path runs
  after every Bash call and has no bound.
- **D-12** FR-6: eleven verdicts at 400 chars each can exceed the 2 KB
  composition limit. There is no rule for co-firing verdicts, for example
  both phantom detectors on one listing.
- **D-13** Architecture "Scope anchor" says the `phantom-*` verdicts anchor
  on `CLAUDE_PROJECT_DIR`, but those detectors have no probe and read text
  only. The anchoring mechanism is unstated.

## Fixes Applied

- Provenance — `Base:` set to `TODO` (replaced value quoted above).
- Intro, Approach — both hook events; pointer to the amendments.
- New section "Design amendments owed" — A-1 to A-8, each gating a phase.
- Phase 1 — repo-init commit; live-memory path; literal split; layer-2
  harness promoted; `jq empty` deferred; TAP-log skip count.
- Phase 2 — live payload recording for both events; two-event
  `hooks.json`, quoted; text source per event; in-memory buffer; fail-open;
  `jq -n --arg`; probe dispatch; `hook.bats` FR-1 assertion, malformed
  payload, stubbed probes, flag policy, latency; docs.bats exemptions.
- Phase 3 — renamed "lock probes"; A-3 contract; path resolution via
  payload `cwd`; `lsof`/`fuser`/`unknown`; portable `stat`; chardev and
  no-tool cases; `held` and config-lock reproductions; nesting under
  `git:*`.
- Phase 4 — layer-1 triage plus layer-2 measurement with flag join; A-7
  discriminator; proposed ship rule; candidate probes moved here;
  portable time bound.
- Phase 5 — read-only-inspection default, `$TMPDIR` instability, strings
  described.
- Phase 6 — enable route via Q7; translation audit; both index lines; six
  inbound links; amend existing bullet; delete the two live-memory cases;
  tier publish; live-pointer scope.
- New section "Verification standard".
- Scope — IN and OUT enumerated; install blocker noted.
- Open questions — Q2, Q3 and Q4 updated; Q5 to Q8 added.
- Risks — result-text shape extended to both events and the harness
  annotation; holder check; FR-11 day one; organic-verdict wait; install
  blocker; knowledge gap.

Every edit was checked with the pilot matchers over the outline and this
report; both are silent.

## Positive Observations

- The outline defers to the living design and does not restate D-1..D-12.
  That is the right split between a frozen plan and a living doc.
- The phase order is sound: measured detectors ship before candidates, and
  retirement waits for dogfooding (D-11).
- It records a live-payload check before any test is written, which is
  the step that caught A-1's class of problem.
- It treats zero-hit candidates as results and keeps them as candidates,
  consistent with NFR-1.
- Scope OUT names the neighbouring repos whose gates this plugin must not
  touch.

## Recommendations

- Apply A-1 to `docs/design.md` first. It changes FR-1's pinned assertion
  and the Architecture diagram, and every Phase 2 test depends on it.
- Re-verify A-1 on the recorded live payloads. The bundle reading
  (2.1.280) establishes which event fires, and the payload settles the
  `error` text shape.
- Decide Q7 before Phase 6 starts. The install blocker and the knowledge
  gap both affect the other ddaanet repos, not only this one.
- Consider stamping the outline's bundle evidence (CC 2.1.280) into
  `detectors.md` beside the corpus figures, for the same self-dating reason.

## Escalation

- **Provenance `Base:` is `TODO`.** `Derived from:` supersedes
  `plans/brief-sandbox-detector-pilot.md`, which has no `Base:`. The pilot
  ran in gitlore, and its artefacts entered this repo in the init commit.
  If this outline is the first plan in this repo, the author should set
  `Derived from: none` and restore
  `Base: 52e6dd82b831a1cc2b7b516d4c248df6fb1ebc8c`. That sha is reachable
  from HEAD and was the value found. The reviewer may not overwrite
  `Derived from:` or write the base itself.
- **Open questions Q5–Q8** carry proposed defaults but need a user
  decision. Q5 in particular is a new decision this review introduced.

---

**Ready for user presentation**: Yes, with the escalation above: Provenance
`Base:` needs an author decision, and Q1–Q8 need answers.
