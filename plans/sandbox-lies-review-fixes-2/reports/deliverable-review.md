# Deliverable Review: sandbox-lies-review-fixes-2

**Date:** 2026-10-08 **Methodology:** `docs/references/deliverable-review.md` is
cited by the edify skill but does not ship in edify 0.3.0 (its
`docs/references/` directory is absent). This review uses the skill body's
review axes and its three severity levels in its place, and the Layer 1
delegates were given them inline.

## Inventory

**Range:** `52e6dd82b831a1cc2b7b516d4c248df6fb1ebc8c..HEAD`, reviewed whole: 285
commits, 129 files, +15678 / −250 outside `plans/`, `tmp/` and the handoff
files. This job's own share, since the previous review's commit `1718c03`, is 16
commits, 35 files, +1222 / −246.

**How the range was established.**
`edify-review-range.sh plans/sandbox-lies-review-fixes-2/outline.md` printed
`UNRESOLVED:` followed by the base sha with a trailing comma, exit 1. That is a
parse failure, not an unresolvable base (finding m-1):

- The outline's `**Base:**` line puts a comma straight after the backticked sha.
  The script takes the value's first blank-delimited word, strips the backticks,
  and the comma left on it fails the 40-hex check.
- Checked by hand: the sha names commit `52e6dd8` ("add claude-plugin-dev
  toolkit"), it is an ancestor of `HEAD`, and the superseded outline
  `plans/sandbox-lies-review-fixes/outline.md` carries the same `Base:`. So the
  script's verdict would have been `RANGE:`, not `CONFLICT:`.
- The dispatch named this range and said not to narrow it, so the review
  proceeded on it rather than stopping to ask.

**Conformance baselines:**

- `plans/sandbox-lies-review-fixes-2/outline.md`: scope, decisions Q1 to Q6,
  design D-a to D-d, Items 1.1 to 6.1;
- `plans/sandbox-lies-review-fixes/reports/deliverable-review.md`, whose Major
  1, m-1 to m-6 and m-9 to m-18 this job fixes;
- the living `docs/design.md` and its `docs/references/` nodes;
- the evidence files `resume-probe-evidence.md` and `m4-reprobe-evidence.md`.

**Input, not proof:** the build's reports in `reports/` (per-slice RED, GREEN
and reviews, the review gate, `tdd-audit.md` and its remediation) and
`delegate-status.md`. Their mutation claims were sampled and re-run, not
trusted.

**Excluded as known:** the outline's OUT list (m-7 `.gitlore/bin/claude`, m-8
`.claude/settings.json`; neither has a diff since `1718c03`), the rejected
`deliverable-review-build-only-range.md`, and items carried from earlier
reviews. A carried item is reported only where the current tree shows it worse.

**Layers:**

- **Layer 1:** three opus delegates, launched unnamed. Code and prose-config ran
  together and were barred from any test process; the tests delegate ran alone
  afterwards, one bats file at a time, in the foreground.
- **Layer 2:** this session. It formed its own judgement on the job's code diff,
  the hook gate, the BSD-stub coverage, the helper lists, the cross-document
  paths and the design state before reading any Layer 1 report.
- **Gate:** `just precommit` ran on the current tree in this session, before any
  delegate, and exited 0: "precommit passed: plugin.json, hooks.json,
  shellcheck, bash -n, rumdl, line limits, links, python compile, tests", 358
  bats tests, 0 failed.
- **Tree after the delegates:** no change in `lib/`, `hooks/`, `scripts/`,
  `tests/` or `justfile`; the tests delegate restored all 31 mutations, and all
  three delegates removed their scratch directories.
- **The `memory` submodule pointer moved during the review window.** After the
  code delegate's hand-back, `git diff memory` showed it at `cfdfeb5` (dirty).
  After the tests delegate's hand-back it was at `5428582` ("Update MEMORY.md
  for ddaanet tier merge"), with a new merge commit in `memory/ddaanet` ("merge
  ddaanet-memory from sandbox-lies"), both timestamped 17:40:50. This session
  issued no git write and no `claude` command, and neither delegate report
  records one; the origin is not established from here. The tests delegate's
  report calls the line "pre-existing", which is wrong: it moved while that
  delegate ran. It was left untouched.

| Type | Files | Lines (current) |
| --- | --- | --- |
| Code: hook and lib | `hooks/annotate.sh`, `hooks/check-jq.sh`, `lib/matchers.sh`, `lib/probes.sh`, `lib/probes-readonly{,-command,-facts}.sh`, `lib/verdicts.sh` | 1717 |
| Code: gates and tooling | `scripts/check-line-limits.sh`, `scripts/check-links.sh`, `scripts/lib/{tracked.sh,strip-code.awk}`, `scripts/run-bats.sh`, `tests/extract-fixtures.py`, `tests/corpus-eval.py`, `justfile` | 894 + 59 |
| Test | 32 `tests/*.bats`, 7 `tests/helpers/*.bash` | 8190 + 695 |
| Test fixtures | 34 `fire-*`/`quiet-*`, all in `SPEC`; 2 `payload-*.json`; none added by this job | ~1077 |
| Agentic prose | `skills/sandbox-lies/SKILL.md` and its 4 nodes | 620 |
| Human docs | `docs/design.md`, 6 `docs/references/` nodes, `docs/changelog.md`, `README.md`, `CLAUDE.md`, `BRIEF.md` (re-wrap only) | ~1730 + BRIEF |
| Configuration | `hooks/hooks.json`, `.claude-plugin/plugin.json`, `.envrc`, `.gitignore`, `.rumdl.toml`, `pyproject.toml`, `uv.lock`, `.gitmodules`, `LICENSE`, `.claude/gitlore-hook-setup`, `.claude/settings.json` | ~200 |
| Not reviewed | `plugin-dev/` (vendored toolkit subtree); `memory` (submodule, no prior pointer in range); `.gitlore/bin/claude` (gitlore-generated, OUT) | — |

**Design conformance:**

- Every in-scope finding produced its deliverable (§Gap Analysis). Each of Q1 to
  Q6 is implemented as decided.
- **Q1/Q2, D-a/D-b.** `hooks/annotate.sh` no longer gates `resume-lost` on the
  flag. `probe_resume_lost` resolves the config dir as D-a says, tests
  `<root>/projects/*/<id>.jsonl` with `[ -f ]`, and prints `lost`, `found` or
  `unknown`. `verdict_resume_lost` prints text for `lost` and `found` only. Both
  verdict texts are byte-identical in `lib/verdicts.sh` and `detectors.md`
  §resume-lost. The `found` text is the finalised form of the outline's draft
  and keeps its three elements.
- **Dogfood.** In this session an unsandboxed (flag-set) `cat` of
  `fire-resume-lost-two-turn.txt` drew the `lost` verdict from the installed
  hook. Under the old flag gate that call was silent, so the installed hook runs
  this job's code, and the real probe read the real config dir and found no
  transcript for the fixture ids, as Q3 accepted. The `found` path has no live
  run (m-13).
- **Two outline deviations, both justified in place:**
  - Item 3.5 named eight suites; seven got a BSD case. `hook-verdicts.bats`
    stubs `detect`, its verdict only `printf`s and `annotate.sh` calls only
    `jq`, so a stub case there cannot fail. L2, L1-tests and L1-prose each
    confirmed this independently. The deviation is recorded only in
    `delegate-status.md`.
  - Item 4.2 asked for `PYTHONDONTWRITEBYTECODE=1 python3 -m py_compile`; the
    `justfile` uses a `compile()` one-liner and says why. L1-code confirmed the
    reason: `py_compile` still wrote a `.pyc` under that variable.
- **Caps:** `docs/design.md` 399/400, `SKILL.md` 200/200, neither met by crammed
  lines or shaved prose (L1-prose).

## Critical Findings

None.

## Major Findings

None.

## Minor Findings

### Process artefact

- **m-1. The outline's `**Base:**` value cannot be parsed.** [L2]
  - **Where:** `plans/sandbox-lies-review-fixes-2/outline.md:12`.
  - **Gap:** a comma follows the backticked sha with no blank before it, so
    `edify-review-range.sh` reads the sha with the comma attached and reports
    `UNRESOLVED:`. The superseded outline wrote `` `sha` — copied ``, which
    parses.
  - **Proposed upstream (edify, read-only from here):** `base_value_of` could
    strip trailing punctuation from the first word, or take the first 40-hex run
    inside backticks.

### Code

- **m-2. An absent or unreadable config tree reads `lost`.** [L1-code m-1]
  - **Where:** `lib/probes.sh:57-67`.
  - **Gap:** `unknown` covers only an empty root or no id. A missing root, an
    unreadable `projects/` or an unreadable project directory gives the same
    empty glob as "no transcript", so the hook states the sandbox cause about a
    tree it could not search. Shown by hand with `chmod 000` and a nonexistent
    `CLAUDE_CONFIG_DIR`. A relative `CLAUDE_CONFIG_DIR`, resolved against the
    hook's cwd, is the likeliest trigger.
- **m-3. The probe's subshell does not undo `set -f`.** [L1-code m-6]
  - **Where:** `lib/probes.sh:42-48`.
  - **Gap:** the comment says the glob is safe "whatever the caller's shell
    options", but only `failglob` is reset. Under `noglob` every id reads
    missing: shown `found` → `lost` by hand. No caller sets `-f` today.
- **m-4. The probe keeps its own copy of the matcher's line shape.** [L1-code
  m-3]
  - **Where:** `lib/probes.sh:54-55` against `lib/matchers.sh:190`.
  - **Gap:** `readonly-path` shares its discriminator to prevent drift
    (`_readonly_path_line`); this pair does not. If the matcher's id class
    widens alone, the probe prints `unknown` and the hook goes silent on a
    refusal it detected. The two agree today.
- **m-5. The `annotate.sh` stderr comment's next sentence lost its referent.**
  [L1-code m-2]
  - **Where:** `hooks/annotate.sh:11-16`.
  - **Gap:** after the inserted probe sentence, "`-Rs` takes it" reads as the
    probe's stderr rather than stdin, and line 16 is left unreflowed. The probe
    list also omits the documented `wc -c` and `detect`'s `tr` stderr paths.
    Item 4.1's scope is otherwise met.
- **m-6. The `readfile=` skip rule's residuals are incomplete.** [L1-code m-4,
  L1-prose m-11]
  - **Where:** `lib/probes-readonly-command.sh:237-238`;
    `docs/references/readonly-path.md:68-70`, `:96-125`; changelog `:286-287`.
  - **Brace expansion:** `cat {a,b}.log` gives `readfile={a,b}.log`, the same
    misdirection m-11 fixed for `*`. It is neither skipped nor documented.
  - **Backticks:** `` cat `echo a`.log `` gives a backtick `readfile=` name. The
    code comment names this residual; the doc's residual list does not, and its
    "a glob or an expansion … is passed over" overstates.

### Tests

- **m-7. "Never opens the transcript" is unpinned.** [L1-tests m-1]
  - **Where:** `tests/probes-resume.bats`, `tests/hook-resume.bats`, against
    `lib/probes.sh:34,64`.
  - **Gap:** a mutation making the probe `cat` every hit survived all 17 probe
    cases and all 10 hook cases. NFR-4 marks the read scope "review, not gated",
    hence Minor. A `chmod 000` transcript case asserting `found` and empty
    stderr would pin it.
- **m-8. The verdict unit case pins "no text" with `-`, not `unknown`.**
  [L1-tests m-3]
  - **Where:** `tests/verdicts.bats:112-118`.
  - **Gap:** giving `unknown` the `lost` text survived `verdicts.bats` and was
    caught only end to end in `hook-resume.bats`. `-` is a token the probe never
    prints.

### Docs and skill

- **m-9. FR-5's "pinned by" list omits `tests/hook-resume.bats`.** [L2, L1-prose
  m-6, L1-tests m-2]
  - **Where:** `docs/design.md:101-103`.
  - **Gap:** the resume-lost flag pairing moved there from
    `hook-candidates.bats`, whose header says so. The review gate deferred this
    to save a line. FR-5's general clause ("the verdict says so or the detector
    stays silent") also lacks the carve-out D-8 and `detectors.md:212-215` make.
  - **The pairing itself holds:** four transcript states × both flag values,
    each gated half red under a re-added gate (L1-tests #11, #12).
- **m-10. The Status line's "Verified against" lags the last code commit.** [L2,
  L1-prose m-9]
  - **Where:** `docs/design.md:8`, `d8a8591`.
  - **Gap:** `9bd925e` later touched `hooks/annotate.sh` and
    `lib/probes-readonly-command.sh` (comments only), `tests/probes-resume.bats`
    and `detectors.md`'s `unknown`. Item 5.1 asked for the last code commit.
    Behaviour is unchanged, so the claim is true but stale.
- **m-11. NFR-4's pins do not name the new read scope's pin.** [L1-prose m-7]
  - **Where:** `docs/design.md:190-199`.
  - **Gap:** `probes-resume.bats:129` (`HOME/.claude` not read when
    `CLAUDE_CONFIG_DIR` is set) pins it; NFR-4 does not say so. See also m-7.
- **m-12. NFR-2 and `CLAUDE.md` leave "code under test" undefined.** [L1-prose
  m-8]
  - **Where:** `CLAUDE.md:22-24`, `docs/design.md:177-180`.
  - **Gap:** `verdicts.bats` and `verdicts-readonly.bats` pipe text through
    `lib/matchers.sh`, which calls `grep -E` and `sed -E`, yet are excluded on
    the ground that `lib/verdicts.sh` calls no stubbed tool. `hook-verdicts` was
    excluded by asking what runs. The rule's wording, not coverage, is the
    defect: `matchers*.bats` cover the matchers under stubs.
- **m-13. FR-4's "proved once against a live reproduction" is short for
  `resume-lost`.** [L1-prose m-10, L2]
  - **Where:** `docs/design.md:90-92`, `:3-8`; `detectors.md:228-249`.
  - **Gap:** E1 to E5 record CC's behaviour, but no run of `probe_resume_lost`
    itself on a live refusal is recorded, unlike `lock-detectors.md:79-87`'s
    `probe_git_lock` run. The Status line's dogfood date (2026-09-27) predates
    the probe. This session's live `lost` (§Design conformance) is the kind of
    run FR-4 asks for; `found` has none. Conforms to Item 5.2's literal ask.
- **m-14. `sandbox-state.md`'s per-detector cost list is incomplete.** [L1-prose
  m-13]
  - **Where:** `docs/references/sandbox-state.md:16-32`; D-8.
  - **Gap:** besides the lock `mask`-for-`gone` case it calls "what is left", a
    covered call also silences `tmpdir-unset`, draws the lock verdicts'
    add-the-flag wording, and, with the gate dropped, a flagged refusal of an id
    that never existed now reads `lost`. Only `detectors.md:252-254` records the
    last.
- **m-15. The `resume-lost` Probe paragraph does not say whose environment picks
  the config dir.** [L1-prose m-12]
  - **Where:** `docs/references/detectors.md:192-197`.
  - **Gap:** the probe reads the hook's (the session's) environment; a
    `CLAUDE_CONFIG_DIR=` prefix on the Bash call never reaches it. That
    asymmetry is why `found` fits E5.
- **m-16. The changelog entry omits the test-side fixes.** [L1-prose m-14]
  - **Where:** `docs/changelog.md:274-301`.
  - **Gap:** no mention of the Major 1 pin, the m-14 guard, the m-16 spy or the
    seven BSD cases, unlike the previous entry's closing line.
- **m-17. `masks-and-gates.md:34` still says masks show as `??`
  "unconditionally".** [L1-prose m-1, checked in L2]
  - **Gap:** the hub now says "Masks the repository does not ignore";
    `m4-reprobe-evidence.md` call 3 shows a gitignored mask only under
    `--ignored`, as `!!`. The review gate left the node on the ground that `??`
    is the only form without `--ignored`, but an ignored mask is then not listed
    at all.
- **m-18. `masks-and-gates.md:25-27` keeps "each cost a classifier call"
  unqualified.** [L1-prose m-2, checked in L2]
  - **Gap:** the hub's twin sentence gained "absent an allow rule"; this node
    was outside Item 6.1's file list. A residual of the previous m-5.
- **m-19. "Clears it before any classifier call" overstates for auto mode.**
  [L1-prose m-4]
  - **Where:** `SKILL.md:58-60`, `:81-82`; `excluded-commands.md:139-148`;
    `escapes-and-costs.md:58-60`, `:67-71`.
  - **Gap:** per `permission-modes.md` (fetched 2026-10-08 by L1-prose), auto
    mode drops broad allow rules (`Bash(*)`, wildcarded interpreters), and a
    command carrying per-command allowed domains still goes to the classifier.
    The skill's baseline has auto mode on, so "propose one" should say "a narrow
    rule".
- **m-20. `escapes-and-costs.md:21-23` cites the settings reference for the two
  `!` cases.** [L1-prose m-3]
  - **Gap:** they are in `sandboxing.md` §"Turn off the retry with strict
    sandbox mode"; the content is right, the citation is not.
- **m-21. "Honoured in strict mode too" is unqualified.** [L1-prose m-5]
  - **Where:** `SKILL.md:72-73`; `escapes-and-costs.md:3-6`, `:18`;
    `excluded-commands.md:175`.
  - **Gap:** strict mode set by managed settings or `--settings` ignores the
    repository's loosening settings, `excludedCommands` included. The text
    predates this job but is in range; the skill's user-scope baseline is
    unaffected.
- **m-22. The hub's 2.1.293 summary simplifies the uncovered form.** [L1-prose
  m-15]
  - **Where:** `SKILL.md:22-24`.
  - **Gap:** it says `true &&` before `git status`; what ran was
    `true && command git status --porcelain --ignored`, since a local hook
    refuses the literal form. The node and `lock-detectors.md` give it exactly.

### Carried, not counted

- `tests/corpus-eval.py:47`'s "strictly broader than any matcher" is still false
  for `crw-` against `c[rwx-]{9}` (first review's code m-8); Item 4.3 rewrote
  the lines below it. [L1-code m-5]
- `tests/extract-fixtures.py:158,163` still crash on a null timestamp or a
  non-dict input (first review's code m-9). [L1-code]
- Observation [L1-prose]: `git status --porcelain --ignored` collapses a wholly
  ignored directory to one `!!` line, so a mask nested in one would not appear
  by name. Root-level masks still do.

## Gap Analysis

| Design requirement | Status |
| --- | --- |
| Major 1 → Item 3.1: slash-suffixed `phantom-untracked` pins | Covered: each `/?` drop reds exactly one new case (L1-tests #22, #23) |
| m-1 → Item 5.1: design state layer | Covered; Verified-against lag m-10 |
| m-2 → Item 6.1: strict mode ignores the flag, two `!` cases | Covered; citation m-20, qualification m-21 |
| m-3 → Item 1.1: `resume-lost` probe (D-a) | Covered: 10 behaviours mutation-proven; never-open unpinned m-7; unreadable tree m-2; `noglob` m-3; shape duplication m-4 |
| m-3 → Item 1.1: `found` verdict (Q2, D-b), no flag policy (Q1, D-c) | Covered: L1-tests #11 to #15, L1-code end-to-end runs, L2 diff; unit specificity m-8 |
| m-3 → Items 5.1, 5.2: D-8, L-2, `sandbox-state.md`, `detectors.md` (D-d) | Covered; m-13, m-14, m-15 |
| m-3 → Item 6.1: `recipes-and-claude.md` verified on 2.1.292, dropped turn | Covered |
| m-4 → Items 6.1, 5.3: `--ignored` re-probe on 2.1.293 (Q6) | Covered: versions match the evidence; m-17, m-22 |
| m-5 → Item 6.1: allow rules | Covered in the named files; m-18, m-19 |
| m-6 → Item 5.1: pinned-by families | Covered for FR-3, FR-4; FR-5 m-9 |
| m-9 → Item 4.2: `lint_paths` | Covered at the definition and both call sites |
| m-10 → Item 4.1: stderr scope, probe key lines | Covered; comment wording m-5 |
| m-11 → Items 2.1, 5.3 (Q4): glob and `$` skip, quoted-literal residual | Covered: each metacharacter mutation-proven (L1-tests #16 to #21); brace and backtick m-6 |
| m-12 → Item 4.2: Python compile step | Covered, by `compile()` instead of `py_compile`, reason verified |
| m-13 → Item 4.3: corpus-eval candidate comments | Covered; carried block-comment claim not counted |
| m-14 → Item 3.2: `assert_no_git_above` | Covered: first statement of the real-probe case |
| m-15, m-17 → Item 3.4: helper comments | Covered: every "shared by" list matches a whole-tree grep (L2, L1-tests) |
| m-16 → Items 3.3, 5.1: `mktemp` spy, NFR-4 | Covered (L1-tests #24); NFR-4 pin naming m-11 |
| m-18 → Items 3.5, 5.1 (Q5): BSD cases, narrowed rule | Covered: seven suites, each red under a GNU-only form (L1-tests #25 to #31); `hook-verdicts` skip justified; rule wording m-12 |
| Item 5.4: changelog entry | Covered; test-side omission m-16 |
| Carry list: `unknown` outcome documented | Covered: `lib/probes.sh` header and `detectors.md` Probe paragraph |
| Line caps (`design.md` ≤ 400, `SKILL.md` ≤ 200) | Covered: 399 and 200 |

## Summary

| Severity | Count |
| --- | --- |
| Critical | 0 |
| Major | 0 |
| Minor | 22 |

Minors by group: process artefact 1, code 5, tests 2, docs and skill 14.

- **Merged duplicates, each counted once:** L1-code m-4 with L1-prose m-11
  (m-6); L2's FR-5 check with L1-prose m-6 and L1-tests m-2 (m-9); L2's
  Verified-against check with L1-prose m-9 (m-10); L2's dogfood observation with
  L1-prose m-10 (m-13).
- **Mutation evidence:** 31 mutations by L1-tests, 30 red; the one survivor is
  m-7. Every BSD case added by this job went red under a GNU-only form, so none
  is blind.
- **Shape:** every finding this job set out to fix is closed, and the two
  outline deviations each carry a verified reason. What remains is robustness
  edges of the new probe (m-2 to m-4), two test specificity gaps (m-7, m-8),
  traceability and state-layer lag in `design.md` (m-9 to m-13), and skill nodes
  the job's file list did not reach (m-17, m-18) or claims that need a qualifier
  (m-19, m-21).

## Sub-reports

- `plans/sandbox-lies-review-fixes-2/reports/deliverable-review-code.md`
- `plans/sandbox-lies-review-fixes-2/reports/deliverable-review-tests.md`
- `plans/sandbox-lies-review-fixes-2/reports/deliverable-review-prose-config.md`
