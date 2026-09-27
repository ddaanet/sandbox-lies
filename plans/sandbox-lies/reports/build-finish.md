# Build — Finish: review gate, triage, TDD audit, run summary

Finish of `/edify:build` for `plans/sandbox-lies/runbook.md`, entered from
`build-phase-8c.md` §Finish resume block. Every item is built. Baseline
`e873bf4` (`.git/build-baseline`); entry HEAD `0df5864`, 186 commits.

## Finish steps

- **Review gate (§1).** Two groups were dispatched, in parallel with the
  audit:
  - Code, tests, scripts and docs: `edify:corrector` (opus),
    `reports/review-code.md`. Verdict Ready, no UNFIXABLE, six findings fixed.
    Committed with its fixes as `3c30baa`.
  - Skill definitions: `plugin-dev:skill-reviewer` (opus, report-only),
    `reports/review-skill.md` (findings, relayed by the main session), fixes by
    an `edify:corrector` (opus) in `reports/review-skill-fixes.md`. Committed
    as `35fbbfa`.
- **Triage feedback (§2).** `triage-feedback.sh sandbox-lies e873bf4`: 329
  files, 225 reports, behavioural code yes, verdict `match`. The script
  appended its row to `plans/reports/triage-feedback-log.md`.
- **Final review (§3.1).** Not dispatched: §1 covered the whole baseline diff
  outside `plans/` and `memory/`.
- **TDD audit (§3.2).** `edify:tdd-auditor` (opus), `reports/tdd-audit.md`.
  Verdict: compliant with findings. No critical violation, six Important, eight
  Minor. All are process findings on committed history; none asks for a change
  to the shipped code. See §TDD audit.

## Review outcomes

### Code, tests and docs (`review-code.md`, fixed in `3c30baa`)

D-17 holds across `lib/verdicts.sh`, the probes, `hooks/annotate.sh` and the
docs. `partial=1` alone selects the no-target merge clause, `merge=1` keeps its
meaning, and the `match=` clause never reads `partial=1`. The shim, the 8.0/3
review fixes and slice 8.0/5 were found correct and pinned. Fixes:

- **Major:** the ls-tree merge pass in `_readonly_repo_facts` (the 8.0/3
  linear-cost fix) had neither unequal-name branch tested; swapping `<` for `>`
  left all 37 related tests green. Two tests in
  `tests/probes-readonly-pins.bats` now pin both branches, each proven by
  mutation.
- Minor:
  - `detectors.md` Conventions named two probe arguments, not three;
  - `path=` is now declared in the readonly-path and git-lock Probe paragraphs;
  - design `## Now` Focus named the Item 8.2 memory edits, which had landed;
  - FR-10's pinned-by asserted a `docs.bats` case that is deferred with the
    file's deletion;
  - a test comment cited a residual no node carries.
- The design's Verified-against stamp advanced from `45c03163` to `0df5864e`
  after the corrector checked every hub claim against it.

Precommit after the fixes: exit 0, 251 bats (249 before).

### Skill (`review-skill.md`)

The reviewer found no UNFIXABLE and rated the skill Needs Improvement: 5
major, 14 minor. It has no Write tool, and its hand-back reached the main
session, which transcribed it to `review-skill.md`. One corrector applied the
findings (`review-skill-fixes.md`):

- **M1–M3:** the masks-follow-the-cwd carry could not be reached from the hub,
  and its `(cd <dir> && …)` act conflicted with `excluded-commands.md`. Now it
  has a hub section, "Keeping the working directory at the project root", and
  a description trigger. Its acts are ordered: absolute paths or `git -C`
  first, a trailing `cd <root>` next, a subshell last. `escapes-and-costs.md`
  no longer recommends a leading `cd`.
- **M4, m13:** the description gained triggers for a `claude -p` run for a
  `SessionStart` side effect, whether a call ran sandboxed, where masks land,
  and a `` !`cmd` `` context block. It grew from about 595 to 723 characters,
  roughly 30 tokens in every session with the plugin enabled.
- **M5, by probe:** the skill said a background task is absent from any `ps`
  the agent can take. A live probe (2026-09-27, CC 2.1.281) showed a sandboxed
  `ps` lists 5 lines and no background `sleep`, while an unsandboxed one lists
  204 lines with it. The claim now covers a sandboxed `ps` only, and the act is
  to check with an unsandboxed one. `detectors.md`'s "Not detectors" entry was
  reworded to match, in this session.
- **m3:** dated claims carry their CC version where one targeted transcript
  grep found it, else "CC version not recorded".
- **m12:** hub-to-node and node-to-node pointers are links, so the link check
  now resolves them.
- The other minors are wording corrections against the nodes and the
  2026-09-27 reproduction.
- **m7, second half, DEFERRED:** the claim that a `cd` at the head of a call
  persists is left unchanged. The probe needs a main session, because a
  subagent's cwd resets between calls (checked). The wrapper read during the
  M5 probe captures `pwd -P` after an `eval` of the command in the same shell.
  That predicts that a top-level `cd` anywhere persists and one inside `( … )`
  does not, but this is a reading, not an observation.

Precommit after the fixes: exit 0, 251 bats.

## TDD audit (`tdd-audit.md`)

48 RED → test review → GREEN cycles over 60 planned slices, in Items 2.1–2.4,
4.1–4.3, 6.1 and 8.0. Every slice has its reports, each resolving to one adding
commit; every test review fixed at least one weakness. 39 of 48 cycles are
fully compliant. The Important findings:

- **I1, commits past a red gate:** `0492468` (8.0/1 GREEN, `verdicts.bats`
  over the cap, split in `89e6824`) and `01169db` (Item 8.1, fired
  `readonly-path` in `docs.bats`, fixed in `45c0316`). The 4.1/7–4.1/9 GREEN
  reports claim a green suite that the 4.2/1 GREEN's blocker contradicts at the
  same HEAD (`run` unsets a local named `stderr`); which one was right was
  never settled.
- **I2, multi-slice commits without a runbook list revision:** Items 4.1, 4.2
  and 4.3, recorded only in `build-phase-4.md` and in commit subjects.
- **I3, GREEN edited a test file:** `34362ca` (4.1/4) and `e708088` (2.3/7),
  both benign in content.
- **I4, behaviour changed outside any slice:** `eddd452` (a readonly-path
  wording change between 6.1/3 and 6.1/4) and `09179d3` (the Phase 7 verdict
  rework).
- **I5, code reviews shipping untested fixes** that later slices pinned by
  mutation. Eight cycles are wholly mutation-proven, and the largest case is
  the 8.0/3 review (`b56fe5b`).
- **I6:** 7 of 8.0/4's 12 tests carry only one mutation proof.

Its recommendations are about the build skill's contracts: record batching as
a list revision, a GREEN blocked by a test-file concern returns `blocked:`,
behaviour-changing review fixes go back through RED. The build skill lives in
the edify repo, which is read-only from here. Carried forward as a proposal,
not applied. The runbook is a frozen planning artifact, so the retroactive
Items 4.1–4.3 list revision the audit suggests was not written either.

## Run summary

Per phase, what the phase reports carried to Finish. Each item's dispatches
and reports follow the naming scheme under `plans/sandbox-lies/reports/`:
`item-N-M.md` or `item-N-M-review.md` for general items, and
`item-N-M-s<k>-{red,test-review,green,code-review,refactor}.md` for tdd slices.
Phase checkpoints are `phase-N-corrector.md`; memory retirements are
`phase-4-retirement.md` and `phase-6-retirement.md`. Named subagents could not
be spawned in any phase, and no dispatch returned a hand-back message, so every
artifact was read at its path. No remediation RCA was written in any phase.

- **Phase 1** (Items 1.1–1.4, general): the pilot promoted into `lib/` and
  `tests/`, the rumdl formatter and precommit gate, the `docs.bats`
  self-quiet guard, and the recorded payloads. `phase-1-corrector.md` narrowed
  three doc claims to what the recording shows.
- **Phase 2** (Items 2.1–2.4, tdd, 31 cycles): gate scripts, the hook, lock
  probes. A refactor signal from the 2.4/5 review was folded into 2.4/8 GREEN.
  Slice 2.4/11 had no implementation change: tests only, no GREEN or code
  review. `design.md` reached its cap and was later split in Phase 4.
- **Phase 3** (Items 3.1–3.2, general, evidence):
  - **git-lock `mask` is proved by composition**, not live (gate 2, my human
    partner, 2026-09-25). No shape reproduced an index-lock mask in that
    session; the "owed" paragraph and the recorded `sh -c` shapes stay.
    config-lock `mask` was proved live.
  - **readonly-path false-positive rulings** (gate 3, 2026-09-25): false
    positives 1–4 are true positives by the command-output-file rule, 5 is the
    widened residual, and `readonly-path` ships at 99%.
  - Shipping candidates: `tmpdir-unset`, `resume-lost`, `seccomp-init`.
    `zellij-socket` stays a candidate with no corpus hits.
  - `git:*` in `excludedCommands` did not unsandbox a visible git call.
- **Phase 4** (Items 4.1–4.3, tdd): Item 4.1 ran nine slices as five cycles,
  two GREENs in session. A code review edited `tests/corpus-eval.py` outside
  its slice's file list. The retirement was deferred to one gated commit, and
  `design.md` was split (`references/hook.md`).
- **Phase 5** (Item 5.1, general): `readonly-path`'s probe proved live
  (`writable`), 2026-09-26. Every CC stamp that came from `claude --version`
  was corrected against the transcript `version` field (2.1.281).
  **Precommit-pipe slip:** the stamp commit landed with precommit failing on
  an unreflowed paragraph, because the gate was piped into `tail` and chained
  with `&&`, so tail's exit status stood in for the gate's. A follow-up
  commit reflowed it, and the gate was re-run with its own exit status
  captured (exit 0, 181 bats). Shell-redirection failures reach `nopath` by
  design.
- **Phase 6** (Item 6.1, tdd, 4 cycles): the readonly-path verdict. The
  refactor split `lib/probes.sh`. FR-6 was reworded to bound the text before
  interpolation. The verdict wording my human partner questioned at the Phase
  6 gate went into the Phase 7 rework.
- **Phase 7** (Items 7.1–7.2, general): the skill and repository prose, and
  the verdict rework. Two Fable correctors, both Ready. The gitlore gate blocks
  every parent commit while memory is dirty, so retirement edits go last.
- **Phase 8** (Items 8.0–8.2):
  - **D-17 rework, Item 8.0** (tdd, five slices), added to the runbook ahead
    of 8.1: the script decides every condition. Lock verdicts take the flag.
    The hook passes `tool_input.command` to each probe. `probe_readonly_path`
    prints `merge=1`, `target=`, `match=`, `readfile=` and, from 8.0/5,
    `partial=1`. `orphan` and `unknown` word their retry by the flag, the
    update-config act replaces the re-run, and `readfile=` wins over it. D-17
    pushed `design.md` over the cap, so the arguments for D-6, D-13 and D-14
    moved into their nodes, then D-1's. `verdicts.bats` was split. A `rumdl
    fmt` reflow of `runbook.md` was undone.
  - **Four review-found probe defects:** the 8.0/3 code review found four that
    GREEN's tests missed: `git diff` rewrote `.git/index` even with optional
    locks off; cost grew with the square of the command length plus two forks
    per file; some repo states wrote to stderr; `git pull` aborted under bash
    3.2 `set -u`. Slice 8.0/4 pinned them by mutation. The test review found
    the central index pin was decoration (git compares stat to the whole
    second) and fixed it. The `git pull` pin is an outcome pin only, since
    bash 3.2 is not executable here. The Finish review then pinned the merge
    pass's unequal branches, which were still unpinned.
  - **Slice 8.0/5**: the Phase 8 corrector's UNFIXABLE (U-DESIGN) found the
    no-target merge clause firing on command shape alone: 3 corpus fires, all
    false. My human partner chose **option (a)**: the clause needs git's
    partial-checkout error. The probe prints the fact **`partial=1`** when the
    text holds a needle, and the verdict gives the no-target restore clause
    only under it. **The new needle `cannot create directory at` was grounded
    by a live reproduction** (2026-09-27, CC 2.1.281, git 2.47.3) before the
    spec named it: both merge and checkout die on it when the target adds a
    directory, and HEAD stays put. Its spec and fixtures went in `f05d3a8`,
    ahead of RED.
  - **Item 8.1**: the `.bin/claude` shim, pinned by `tests/shim.bats`.
    Dogfooded 2026-09-27 on CC 2.1.283: the phantom-chardev verdict landed as
    `hook_additional_context` in 111 ms.
  - **Item 8.2**: partial by my human partner's decision. `sandbox-effects.md`
    stays for its zellij section; the memory-tier pointer edits landed through
    the gitlore gate.
  - **Corrector-deferred phantom "project root" wording:** the phantom
    verdicts say "the project root", which is wrong after a persisted `cd`.
    Item 8.0 scoped the phantom verdicts out, so it is carried below.
  - The skill carry: masks follow the sandboxed call's working directory (CC
    2.1.281), in `references/masks-and-gates.md`.

**List revisions.** Recorded in `runbook.md` after 2.1/1–5, 2.2/1–6, 2.3/1–8,
2.4/1–9 plus the 2.4/8 gate and slice 11, 4.1 and 4.3 (before slice 1), 6.1
(before and after slice 1), and 8.0 (spec, /1, the formatter undo, /3 adding
slice 4, and slice 5). None after the last slice of any item. The full list
with commits is in `tdd-audit.md` §List Revisions.

**Follow-up:** `/deliverable-review plans/sandbox-lies` (opus, fresh session).

## Fixes applied

- `3c30baa` — Finish corrector fixes, with `review-code.md` and
  `tdd-audit.md`.
- `35fbbfa` — skill review fixes and the `detectors.md` `ps` entry, with
  `review-skill.md` and `review-skill-fixes.md`.

## Deviations

- The design document `docs/design.md` went to `edify:corrector` with the code
  group, not to `edify:design-corrector`. That agent reviews a
  `plans/<job>/design.md` before planning. The Finish checks the resume block
  names are cross-cutting: D-17 across code and docs, and the state layer
  against the committed code. Splitting the doc from the code would have
  broken those checks.
- `plans/` (the frozen runbook and the reports) and `memory/` were not routed
  through the review gate: planning artifacts route by artifact, reports are
  exempt, and memory passed the gitlore approval gate.
- All three dispatches ended without a hand-back message. The two with files
  were read at their paths. The skill reviewer, which has no Write tool, was
  resumed by SendMessage to deliver its findings in parts.
- The tdd-auditor was told not to run the suite, so that only the corrector
  ran bats while the three agents shared the box.
- The skill reviewer's hand-back went to the main session, not this one, even
  after a SendMessage asking it to resend. The main session transcribed it
  unchanged.
- `detectors.md`'s `ps` entry was outside the skill corrector's scope. The
  orchestrator reworded it in place, since the probe settled it, and the file
  stays at 399 lines.

## Carry-forward (later work, not Finish work)

- The `readonly-path` `nopath` shapes left unhandled: `tee: <path>:`, sed's
  temporary file, git's `could not write config file`,
  `warning: failed to remove`, and an empty `cp` operand. The first three are
  in design `## Now` Next.
- `tmpdir-unset` has not been observed firing since CC 2.1.270: 27 flag-true
  `$TMPDIR` calls after it, 18 at 2.1.281 or later.
- The readonly-path relative-path resolution for git's partial-checkout
  errors: git prints the path from the worktree top, while the probe joins it
  onto the payload `cwd`. From a subdirectory the path is wrong; recommended
  fix: resolve from the nearest `.git` ancestor when the line carries git's
  prefix. `git -C` stays a residual under D-1 (`phase-8c-corrector.md`
  Deferred Items).
- The phantom verdicts' "the project root" wording, wrong after a persisted
  `cd`.
- Line caps: `docs/references/detectors.md` is at 399 of 400. Its next
  addition splits §readonly-path into its own node. `docs/design.md` is at 395
  of 400; its next move-out is D-8's or D-10's argument.
- Item 8.2's remainder, deferred with the deletion of `sandbox-effects.md`:
  the translation-map audit column, the `matchers.bats` live-file case, the
  `docs.bats` retired-path case, and both index lines.
- The TDD audit's recommendations for the edify build skill (§TDD audit), as a
  proposal to that repo.
- The m7 cwd probe, in a main session: `true; cd <dir>` then `pwd`, and
  `(cd <dir>)` then `pwd`, each in its own call, with the version recorded.
  Then word `masks-and-gates.md`'s "a `cd` at the head of a call persists" to
  match (`review-skill-fixes.md`).
- The 4.1/7–4.1/9 suite-count discrepancy (audit I1) was never settled:
  re-running those commits' trees would show whether they were red.
- `/gitlore:push` is held until the plugin is published and installable in
  the other ddaanet repos.

## Open gate

None. No reviewer returned UNFIXABLE, triage matched, and every applied fix is
committed. The deferred m7 probe and the audit's recommendations are
carry-forward, not decisions.

## Context usage

About 120k tokens of this session's own context. Most of it is the phase
reports' summary sections, the two review reports and the audit, and the
review diffs. The four dispatches ran in their own contexts.
