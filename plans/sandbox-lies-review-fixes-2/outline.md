# Outline — sandbox-lies-review-fixes-2

This job fixes the second deliverable review of `sandbox-lies`: Major 1, Minors
m-1 to m-6, and m-9 to m-18. m-3 adds a `resume-lost` probe and corrects four
docs. Classification: Moderate, Production (`classification.md`). Items use the
runbook item shape, so `/build` can walk this outline directly.

## Provenance

- **Derived from:** `plans/sandbox-lies-review-fixes/reports/deliverable-review.md`,
  superseding `plans/sandbox-lies-review-fixes/outline.md`
- **Base:** `52e6dd82b831a1cc2b7b516d4c248df6fb1ebc8c`, copied verbatim from
  the superseded outline. The review that motivated this job ran over that
  whole range.

## Scope

- **IN:** Major 1; m-1 to m-6; m-9 to m-18.
- **OUT:**
  - m-7 (`.gitlore/bin/claude`) and m-8 (`.claude/settings.json`). Both are
    fixed upstream, and briefs are already filed. Neither file is touched.
  - `plans/sandbox-lies-review-fixes/reports/deliverable-review-build-only-range.md`,
    a rejected run.
  - The previous job's carry lists, unless an item below names one.

## m-3: what the probe found, and the design it sets

The evidence is in `resume-probe-evidence.md` (CC 2.1.292, each sandboxed call
proving its own state).

- **A sandboxed `--resume` of an existing transcript succeeds** (E2, E3s).
  Sandboxing alone never makes `--resume` refuse a transcript that exists.
- **A cwd or project mismatch is not a cause.** `-p --resume <id>` finds the
  session in any project directory and appends to the original file (E3). The
  dispatch brief's "found under a different project directory" outcome
  therefore collapses into "found".
- **The observed cause for an existing transcript is a different config
  directory** (E5: `CLAUDE_CONFIG_DIR` pointing elsewhere gives the same
  refusal).
- **The fixture's case is `not found`** (E4 reproduces it live).
  - The ids in `fire-resume-lost-two-turn.txt` have no transcript.
  - So a sandboxed `cat` of the fixture still reads `lost`, and the probe alone
    does not silence it (Q3).
- **A sandboxed turn on a persisted session runs and answers, but is dropped**
  (E2). This fits the skill's "a sandboxed turn never persists", which can now
  name a verified CC version.

Design, D-a to D-d:

- **D-a — the probe.** `probe_resume_lost` in `lib/probes.sh`, following the
  A-3 contract. It takes every session id from a refusal line in its stdin; the
  line shape is `match_resume_lost`'s. It tests each id for a regular file
  `<root>/projects/*/<id>.jsonl`, where `<root>` is
  `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`.
  - The search is a shell glob over the project directories. It never derives a
    project-directory name from the cwd (`memory/ddaanet/cc-project-dir-encoding.md`)
    and needs no `find`.
  - The ids are hex digits and hyphens, so they are safe inside a glob.
  - **Outcome `lost`:** some id has no transcript.
  - **Outcome `found`:** every id has one.
  - No key lines, and the transcript is never opened, only tested for
    existence. NFR-4's read scope grows by that existence test.
  - **Residual:** `archived/` and `subagents/` sit below the glob's depth and are
    not searched, and whether `--resume` reads `archived/` is untested.
- **D-b — the verdict.** `verdict_resume_lost <outcome>`.
  - `lost` prints today's text unchanged.
  - `found` prints its own verdict (Q2): not a sandbox effect, unsandboxing will
    not help, and the call may be reading another config directory.
  - Any other outcome prints nothing, per the hook's verdict contract.
  - Draft `found` text, to be finalized under `craft:directive-writing` and
    transcribed into `detectors.md`:
    - Paragraph: "A transcript for this session exists, so the sandbox did not
      lose it and running unsandboxed will not help. `--resume` finds a session
      in any project under the config directory it reads: check that this call
      reads the same one (`CLAUDE_CONFIG_DIR`, `HOME`)."
    - Human line: `--resume — transcript exists, not the sandbox`.
- **D-c — the flag policy.** This is Q1 and is not presupposed. Item 1.1's last
  slice is written for either answer.
- **D-d — the git-lock half of m-3.** It is documentation only. A covered `git`
  whose lock was gone by probe time reads `mask`, and its act (re-run) is
  harmless. D-8 restates this as the remaining accepted tradeoff, in place of
  the claim that the probes cover it.

## Phase 1: `resume-lost` probe (type: tdd)

- Item 1.1: `lib/probes.sh`, `lib/verdicts.sh`, `hooks/annotate.sh` (gate
  only), and a new `tests/probes-resume.bats` with the hook cases in
  `tests/hook-candidates.bats`. The work is `probe_resume_lost` and an
  outcome-aware `verdict_resume_lost` (D-a, D-b). Requirements: FR-4, FR-5,
  NFR-4, m-3.
  - Isolation: every case points `CLAUDE_CONFIG_DIR` (or `HOME`, for the
    fallback slice) at a directory under `$BATS_TEST_TMPDIR`. No case reads the
    host's `~/.claude`. Hook cases that need only an outcome use the existing
    `stub_probe`.
  - Slices:
    1. Wiring through the hook, with the real probe. The config dir holds
       `projects/-p/<id>.jsonl` for both fixture ids. The hook on
       `fire-resume-lost-two-turn.txt` (flag absent) emits no `never written`
       paragraph. With the config dir empty, it emits today's exact
       `systemMessage`.
    2. Partial: only one of the two ids has a transcript, so the outcome is
       `lost`. The probe's stdout is exactly `lost`.
    3. Not a transcript: a directory named `<id>.jsonl`, or the file under
       `projects/-p/archived/`, is not counted, so the outcome is `lost`.
    4. Fallback root: with `CLAUDE_CONFIG_DIR` unset and `HOME` at a temp dir
       holding `.claude/projects/-p/<id>.jsonl`, the outcome is `found`.
    5. `found` verdict (Q2): the hook's context equals the finalized `found`
       paragraph and its `systemMessage` the finalized human line. If Q2 is
       answered "silence", the hook's stdout is empty instead.
    6. BSD re-run: slice 1's `lost` case, re-run with `make_bsd_stubs` ahead on
       `PATH`, gives identical stdout.
    7. Flag policy (Q1): with `dangerouslyDisableSandbox: true` and the config
       dir empty, the hook emits the `lost` verdict if the gate is dropped, or
       stays silent if it is kept. The existing "resume-lost flag policy" case
       is rewritten to match.
  - Also: `tests/verdicts.bats:90-94` and `tests/helpers/verdicts.bash:39` call
    the verdict with `-`. They pass `lost` now, and a `-` case asserts empty
    output.
  - Interfaces:
    - `probe_resume_lost <flag> <cwd> <command>`: stdin is the result text;
      stdout is `lost` or `found`; exit 0. The arguments are unused.
    - `verdict_resume_lost <outcome> [flag]`: stdout is a paragraph and a human
      line for `lost` or `found`, and nothing otherwise.

## Phase 2: `readfile=` glob operand (type: tdd)

- Item 2.1: `lib/probes-readonly-command.sh` (`:229-238`) and
  `tests/probes-readonly-operands.bats`. The change is contingent on Q4; if Q4
  is answered "document", this item is dropped and Item 5.3 carries m-11 alone.
  Requirements: FR-4, m-11.
  - Slices:
    1. `grep -l pat *.log` prints no `readfile=` line, where today it prints
       `readfile=*.log`.
    2. `cat $OUT.log` prints no `readfile=` line.
    3. `cat x.log` still prints `readfile=x.log`. This guards against an
       over-broad skip.
  - Rule: a candidate holding `*`, `?`, `[` or `$` is skipped, quoted or not.
    The scan keeps no quote state per character, so a quoted literal `*.log`
    is skipped too. That is the safe side, and Item 5.3 documents it.

## Phase 3: tests and helpers (type: general)

Each test-only item below proves itself with a named mutation, as the review
did: the mutation turns the new case red, and the case is green on the
unchanged code.

- Item 3.1: `tests/matchers-edges.bats:134-147`. Add a long-format block with
  exactly two masked names, one carrying the trailing slash (`.bashrc` and
  `.claude/skills/`), asserting `phantom-untracked`. Add the same name with and
  without the slash (`.claude/skills` and `.claude/skills/`), asserting no
  verdict, since it counts once. Mutations: drop `/?` from
  `lib/matchers.sh:117`, and drop the strip's `/?`. Each must turn one case
  red. Requirements: Major 1.
- Item 3.2: `tests/hook-candidates.bats:169-205`. Call
  `assert_no_git_above "$BATS_TEST_TMPDIR"` first. Requirements: m-14.
- Item 3.3: `tests/check-jq.bats:93-101`. Put a `make_spy` `mktemp` spy on the
  jq-less `PATH` in the missing-`TMPDIR` case and assert that its log is
  absent. Mutation: a stderr-silenced `mktemp` with a `/tmp` fallback in
  `hooks/check-jq.sh` turns it red. Requirements: m-16.
- Item 3.4: helper comments. `tests/helpers/probes.bash:209-211` drops
  `tests/shim.bats` and states that the 3 s bound is load-sensitive. The
  "shared by" lists at `tests/helpers/probes.bash:62` and `:150` and
  `tests/helpers/hook.bash:6` are completed from a whole-tree grep. Each list
  includes `probes-resume.bats` where Item 1.1 uses that helper. Requirements:
  m-15, m-17.
- Item 3.5: BSD-stub cases, per Q5. For each suite in scope, re-run one
  existing case with `make_bsd_stubs` ahead on `PATH` and assert identical
  output. Requirements: m-18, NFR-2.
  - **Default scope:** the eight suites whose code under test calls a stubbed
    tool (`sed`, `grep`, `mktemp`, `stat`, `wc`). They are `check-links`,
    `docs`, `hook-cap`, `hook-malformed`, `hook-verdicts`, `probes-config`,
    `probes-edges` and `probes-readonly-pins`.
  - **Excluded:** `verdicts`, `verdicts-locks`, `verdicts-readonly` and
    `verdict-premises`. `lib/verdicts.sh` calls none of the stubbed tools, and
    `verdict-premises` drives git only. A stub case there cannot fail.

## Phase 4: code comments and the gate (type: general)

- Item 4.1: `hooks/annotate.sh:9-12`. Scope the stderr sentence to the parse:
  the jq call cannot error, and the probes pass through failures they cannot
  classify (`lib/probes.sh` `stat` and holder tool). In the `lib/probes.sh:2-8`
  header, list the key lines per probe, `probe_readonly_path`'s and the
  key-less `probe_resume_lost` included. Requirements: m-10.
- Item 4.2: `justfile`. Rename `tracked()` to a name stating both scopes, for
  example `lint_paths()`, at every call site. Add a
  `report py_compile env PYTHONDONTWRITEBYTECODE=1 python3 -m py_compile tests/extract-fixtures.py tests/corpus-eval.py`
  step ahead of `tests`. Requirements: m-9, m-12.
- Item 4.3: `tests/corpus-eval.py:47-61`. Name the candidate each
  non-matcher string stands for. `"no active session"` is the `zellij-socket`
  candidate's (`detectors.md` §zellij-socket), so it stays, with a comment.
  Requirements: m-13.

## Phase 5: docs (type: general)

`docs/design.md` is at 399 of its 400-line cap. Each line added is offset
inside the file, after `just format-docs`, without lengthening any line. The
FR-4 test list is the offset: Item 5.1 replaces its enumeration with the
`tests/probes*.bats` and `tests/hook-*.bats` families, which also stops the
list from lagging (m-6).

- Item 5.1: `docs/design.md`. Requirements: m-1, m-3, m-6, m-16, m-18. Depends
  on: Items 1.1, 3.3 and 3.5.
  - Status: verified against this job's last code commit and date, with the
    `resume-lost` probe listed as built.
  - §Now Focus: closing the review-fixes jobs.
  - FR-3: names `hook-malformed.bats`'s runtime-failure cases.
  - FR-4: four probes, adding transcript existence (`resume-lost`), with the
    pinned-by families as above and `tests/hook-locks-pathless.bats` covered
    by the glob.
  - D-8 and L-2: state that a covered call carries no flag. `resume-lost` no
    longer depends on the flag for its fact (D-a), and what is left is the
    git-lock `mask`-for-`gone` case (D-d).
  - NFR-2: the BSD-case rule as Q5 settles it.
  - NFR-4: the transcript existence test joins the read scope, and
    `check-jq.bats` pins the no-write claim with a spy.
- Item 5.2: `docs/references/sandbox-state.md` and
  `docs/references/detectors.md` §resume-lost. Requirements: m-3, FR-4. Depends
  on: Item 1.1.
  - `sandbox-state.md`: rewrite the D-8 mitigation claim per D-a and D-d.
  - `detectors.md`: a Probe paragraph, the flag policy as Q1 settles it, both
    verdicts verbatim, and the live reproduction (E1 to E5, CC 2.1.292). FR-4
    requires each probe's reproduction recorded in `references/`.
- Item 5.3: `docs/references/readonly-path.md` (the `readfile=` residual list
  at `:90-121`). Add the glob or `$` rule, Item 2.1's skip or the residual, as
  Q4 settles it. Also check `lock-detectors.md:110-112` against Q6's re-probe.
  Requirements: m-11, m-4.
- Item 5.4: `docs/changelog.md`. One entry for this job. Requirements: all.

## Phase 6: skill (type: general)

- Item 6.1: `skills/sandbox-lies/SKILL.md` and its nodes `escapes-and-costs.md`,
  `excluded-commands.md` and `recipes-and-claude.md`. Each file is one edit
  pass. Load `craft:directive-writing`. Requirements: m-2, m-4, m-5, m-3.
  - m-2: strict mode ignores the per-call flag, so the call runs sandboxed
    (`SKILL.md:69`, `escapes-and-costs.md:12`). Add the two cases where a `!`
    command also runs sandboxed under strict mode: a background session, and
    Linux with `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB`.
  - m-4: the re-probe becomes `git status --porcelain --ignored` (Q6 default),
    recorded with the CC version it was re-observed on. The build runs the
    bare covered form and `true && …` once each and records both
    (`SKILL.md:22-29`, `excluded-commands.md:23-25`).
  - m-5: allow rules, beside the read-only validator, clear an unsandboxed
    command before the classifier (`SKILL.md:54-57`, `:74-77`;
    `escapes-and-costs.md:51-53`; `excluded-commands.md:121-134`).
  - m-3: `recipes-and-claude.md:10-12`. "CC version not recorded" becomes
    verified on 2.1.292. Add that a sandboxed turn on a persisted session
    answers but is dropped (E2).

## Requirements map

| Finding | Items |
| --- | --- |
| Major 1 | 3.1 |
| m-1, m-6 | 5.1 |
| m-2, m-5 | 6.1 |
| m-3 | 1.1, 5.1, 5.2, 6.1 |
| m-4 | 6.1, 5.3 |
| m-9, m-12 | 4.2 |
| m-10 | 4.1 |
| m-11 | 2.1 (if fixed), 5.3 |
| m-13 | 4.3 |
| m-14 | 3.2 |
| m-15, m-17 | 3.4 |
| m-16 | 3.3, 5.1 |
| m-18 | 3.5, 5.1 |

## Execution notes

- **Route:** `/build plans/sandbox-lies-review-fixes-2`, with no runbook.
  - The only sequencing is Item 1.1 ahead of the docs and skill, which
    `Depends on:` carries.
  - Prose edits commute.
  - Every edit target is named.
- **Commits:** one per phase, each after `just precommit` exits 0, staged by
  explicit path. `.claude/handoff-task.md` and `.claude/handoff-todo.md` are
  never included.
- **Memory:** one test process at a time, in the foreground.
- **Skills to load:**
  - `craft:test-discipline` (Phases 1 to 3);
  - `shell-scripting:shell-gotchas` (any shell or bats edit);
  - `craft:directive-writing` (D-b and Item 6.1).
- **Recall for executors:**
  - `memory/ddaanet/classifier-no-verdict-plugin-dir.md`: write via a script
    under `$TMPDIR` if a Write gets no verdict;
  - `memory/ddaanet/no-stderr-suppression.md`;
  - `memory/ddaanet/cc-grep-shell-function.md`: mutation checks by hand use
    `command grep`;
  - `memory/ddaanet/reflow-joins-field-lines.md`.

Author change: none (no edify author skill is modified). Coupled corrector:
none. Update needed: no.
