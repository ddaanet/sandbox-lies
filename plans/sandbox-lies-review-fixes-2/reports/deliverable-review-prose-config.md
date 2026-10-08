# Deliverable review, Layer 1: prose and config (sandbox-lies-review-fixes-2)

**Date:** 2026-10-08
**Range:** `52e6dd82b831a1cc2b7b516d4c248df6fb1ebc8c..HEAD`, reviewed whole. The
closest scrutiny went to this job's changes, `1718c03..HEAD`.
**Partition:** the skill (`SKILL.md` and its 4 nodes); the human docs
(`docs/design.md`, the 6 `docs/references/` nodes, `docs/changelog.md`,
`README.md`, `CLAUDE.md`, and `BRIEF.md`'s re-wrap); and the configuration
files.

## Method

- **Baselines read:** `outline.md` (Q1-Q6, D-a to D-d, Items 5.1-5.4 and 6.1);
  the previous `deliverable-review.md` and its prose-config sub-report;
  `resume-probe-evidence.md` and `m4-reprobe-evidence.md`. The build reports
  `review-docs.md`, `review-skill.md`, `item-5.md`, `phase-3.md` and
  `phase-3-review.md` were read as input, not as proof.
- **Files read:** every partition file in full or across its full range diff.
- **Claims checked against code:**
  - `lib/verdicts.sh` (`verdict_resume_lost` run for `lost` and `found`);
  - `lib/probes.sh` (`probe_resume_lost`) and `lib/matchers.sh`
    (`match_resume_lost`);
  - `hooks/annotate.sh`'s flag-gate `case`;
  - `lib/probes-readonly-command.sh` (`_readonly_tokenize` plus
    `_readonly_readfile_arg`, run by hand on six commands);
  - `tests/helpers/bsd-stubs.bash`, and a per-suite count of `load` and
    `make_bsd_stubs`;
  - the `@test` names in `hook-resume.bats`, `probes-resume.bats`,
    `hook-malformed.bats`, `verdicts.bats` and `check-jq.bats`.
- **Claims checked against Claude Code's docs:** raw markdown fetched today
  with `curl` from `code.claude.com/docs/en/{sandboxing,settings-reference,permission-modes}.md`.
- **Gates run by hand once each:**
  - `scripts/check-links.sh` exited 0, and so did
    `scripts/check-line-limits.sh`.
  - `.venv/bin/rumdl fmt --check -q --no-cache` exited 0.
  - A path sweep checked every `tests|lib|hooks|scripts|plans|docs|skills|memory/…`
    path cited in the partition. One is missing, `tests/shim.bats`, which only
    a historical changelog line cites.
  - Character-count line lengths: no prose line is over 80 characters. The two
    hits are the `design.md` Architecture code block and a changelog heading.
    So no cap was met by cramming.
- **Not run:** no test process, no `just`, no `claude`, and nothing under
  `~/.claude`.

## Critical

None.

## Major

None.

## Minor

### m-1. `masks-and-gates.md:34` still says masks are reported as `??` "unconditionally"

- **Axes:** consistency, accuracy (agentic prose).
- **The conflict:** the hub was corrected to "Masks the repository does not
  ignore are reported as `??` lines" (`SKILL.md:143-146`).
  `m4-reprobe-evidence.md` call 3 shows a gitignored mask
  (`.claude/settings.local.json`) appearing only as `!!` under `--ignored`. A
  plain `git status --porcelain` omits it entirely.
- **The build's reason for leaving it is unsound.** `review-skill.md` M2 left
  the node as it was because "without `--ignored`, `??` is the only form a mask
  takes there". But "unconditionally" claims every mask is listed, and an
  ignored one is not listed at all.
- **Why it matters:** the node is where the hub sends a reader for "Mask shapes
  and placement".

### m-2. `masks-and-gates.md:25-27` keeps the unconditional "each cost a classifier call"

- **Axes:** consistency, constraint precision. This is a residual of m-5.
- **The gap:** the hub's twin sentence gained "absent an allow rule"
  (`SKILL.md:105-107`, review-skill m2). This node was outside Item 6.1's file
  list and was not touched.
- **History:** the previous review's m-5 locations did not name this line
  either.

### m-3. `escapes-and-costs.md:21-23` cites the wrong document for the two `!` cases

- **Axes:** accuracy.
- **The text:** "The settings reference names two cases where it runs
  sandboxed too".
- **What the docs say:** the background-session and
  `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB` cases are in `sandboxing.md` §"Turn off
  the retry with strict sandbox mode". `settings-reference.md`
  §`sandbox.allowUnsandboxedCommands` does not mention them (fetched
  2026-10-08).
- **Not affected:** the content of the claim is correct.

### m-4. "An allow rule covering the command clears it before any classifier call" overstates for auto mode

- **Where:** `SKILL.md:58-60`, `:81-82`; `excluded-commands.md:139-148`;
  `escapes-and-costs.md:58-60`, `:67-71`.
- **Axes:** constraint precision.
- **What the decision order says:** `permission-modes.md` gives two exceptions.
  - On entering auto mode, broad allow rules are dropped: blanket `Bash(*)`,
    wildcarded interpreters and package-manager run commands.
  - A shell command carrying per-command allowed domains routes to the
    classifier even when an allow rule matches.
- **Why it matters:** the skill's own baseline (`excluded-commands.md:59-61`)
  has auto mode on. Its advice to "propose one for a command escaped routinely"
  should say "a narrow rule". The hub's flat "clears it before any classifier
  call" fails for exactly the broad rule an agent is most likely to propose.

### m-5. "Honoured in strict mode too" is unqualified

- **Where:** `SKILL.md:72-73`, `escapes-and-costs.md:3-6` and `:18`,
  `excluded-commands.md:175`.
- **Axes:** constraint precision. The text predates this job but is inside the
  range.
- **What `sandboxing.md` says:** strict mode set in managed settings or with
  `--settings` makes the sandbox admin-required. Claude Code then ignores the
  repository's settings that loosen the sandbox, "`excludedCommands` entries
  included".
- **Why it matters:**
  - A project-scope entry is therefore not honoured under that form of strict
    mode.
  - `escapes-and-costs.md:18`'s "Strict mode is a user setting" is incomplete
    for the same reason.
  - The skill's baseline uses user-scope entries, so the common case holds.

### m-6. FR-5's pinned-by list omits `tests/hook-resume.bats` (known deferred item, confirmed still open)

- **Where:** `docs/design.md:101-103`.
- **Axes:** completeness, consistency.
- **The gap:** FR-5 names `hook.bats`, `hook-locks.bats` and
  `hook-candidates.bats`. The `resume-lost` flag-pairing cases are in
  `hook-resume.bats:145-163`, and `hook-candidates.bats:3-4` itself says so.
  `review-docs.md` Minor 3 deferred this to save a line.
- **A second lag:** FR-5's general clause, "a symptom on a call that ran
  unsandboxed has a different cause, and the verdict says so or the detector
  stays silent", now has an exception. D-8 (`:285`) and `detectors.md:212-215`
  carve it out, but FR-5 does not.

### m-7. NFR-4's pinned-by list does not cover the new read scope

- **Where:** `docs/design.md:190-199`.
- **Axes:** completeness.
- **The gap:** NFR-4's read scope gains the transcript-existence test. The
  pins listed are all lock, readonly or `SessionStart` pins: "`tests/probes-edges.bats`
  those two probes".
- **The unnamed pin:** the case that pins the new scope is
  `probes-resume.bats:129` ("CLAUDE_CONFIG_DIR set, HOME/.claude is not read").
  No pin is named for the no-write half on the `resume-lost` path.
- **Mitigation:** the status reads "read scope: review, not gated", which
  softens this.

### m-8. NFR-2 and the `CLAUDE.md` rule leave "code under test" undefined, and the exclusions apply it inconsistently

- **Where:** `CLAUDE.md:22-24`; `docs/design.md:177-180`; outline Q5 and
  Item 3.5.
- **Axes:** constraint precision, determinism.
- **The excluded suites:** `verdicts`, `verdicts-locks`, `verdicts-readonly`
  and `verdict-premises`. The stated reason is that `lib/verdicts.sh` calls
  none of the stubbed tools.
- **Why that reason is incomplete:**
  - `tests/verdicts.bats:41` and the `verdicts-readonly.bats` cases (`:34`,
    `:47`, `:61` and more) pipe text through `lib/matchers.sh`. That file calls
    `grep -E` and `sed -E` (`matchers.sh:67-134`).
  - `hook-verdicts` was skipped by asking what runs; asked the same way, these
    two suites run stubbed tools.
- **No coverage gap:** `matchers.bats` and `matchers-edges.bats` exercise the
  matchers under stubs. The defect is in the rule's wording and its stated
  rationale.
- **No pin:** NFR-2's "Done" is pinned by "every bats file loads it", and no
  gate checks that, or the per-suite case.

### m-9. The Status line's "Verified against" lags this job's last code-touching commit

- **Where:** `docs/design.md:8`, which reads "`d8a8591` (2026-10-08)".
- **Axes:** accuracy (state layer).
- **What came later:** `9bd925e` changed `hooks/annotate.sh` and
  `lib/probes-readonly-command.sh` (comments only), `tests/probes-resume.bats`,
  and `detectors.md`'s definition of `unknown`.
- **Against the outline:** Item 5.1 asked for "this job's last code commit". If
  comment-only commits do not count, the lag is defensible, but the doc does
  not say so.

### m-10. FR-4's "each probe is proved once against a live reproduction" is not met for `resume-lost` as the other probes meet it

- **Where:** `docs/design.md:90-92` (FR-4) and `:3-8` (Status);
  `detectors.md:228-249`.
- **Axes:** conformance, completeness.
- **What the reproduction records:**
  - E1-E5 record Claude Code's behaviour, and E1 confirms the
    `projects/<dir>/<id>.jsonl` layout the glob relies on.
  - E4's "installed hook fired" was the build before the probe existed.
  - No run of `probe_resume_lost` itself on a live refusal against a real
    config dir is recorded. Compare `lock-detectors.md:79-87`: "`probe_git_lock
    true <repo>` on that text printed `orphan`".
- **Related:** the Status line still says "Dogfooded 2026-09-27 on CC 2.1.283",
  before the probe shipped. That is short of the shared rule "dogfood the day it
  ships".
- **Mitigation:** the outline's Item 5.2 asked only for E1-E5, so this conforms
  to the outline but not to FR-4's own standard.

### m-11. The `readfile=` glob/expansion rule overstates what it skips

- **Where:** `docs/references/readonly-path.md:68-70`, and the changelog at
  `:286-287`.
- **Axes:** accuracy.
- **The claim:** a candidate holding `*`, `?`, `[` or `$` "is a glob or an
  expansion ... and is passed over".
- **The exception:** a backtick substitution is an expansion and is not passed
  over. Run by hand, `cat \`echo a\`.log` gives `readfile=` ``a`.log``.
  - The code comment (`lib/probes-readonly-command.sh:137-139`) names this
    residual.
  - The doc's residual list (`:96-125`) does not. Only the general sentence
    "does not parse ... backticks" (`:85`) implies it.
- **The rest of the paragraph is correct.** Its three examples reproduce
  exactly: `grep pat *.log x.err` gives `x.err`, `cat $OUT.log` gives nothing,
  and `grep 'err.*'<x.log` gives `x.log`. So does the new quoted-literal
  residual (`:123-125`).

### m-12. The `resume-lost` Probe paragraph does not say whose environment picks the config dir

- **Where:** `docs/references/detectors.md:192-197`.
- **Axes:** usability, accuracy.
- **What the paragraph says:** "The config dir is CC's own resolution:
  `CLAUDE_CONFIG_DIR` when set, else `$HOME/.claude`".
- **What it leaves out:** the probe reads the hook process's environment, which
  is the session's. A `CLAUDE_CONFIG_DIR=` prefix on the Bash call never
  reaches the probe.
- **Why it matters:** that asymmetry is what makes `found` the right verdict for
  E5's mismatch, so a maintainer needs it stated to reason about the outcomes.

### m-13. `sandbox-state.md`'s per-detector cost list is incomplete

- **Where:** `docs/references/sandbox-state.md:16-32`, and D-8 at
  `design.md:283-288`.
- **Axes:** completeness.
- **The claim:** after "What it costs, per detector", D-8 and this node call the
  `mask`-for-`gone` lock case "what is left". Three effects of the missing flag
  on a covered call are not listed:
  - `tmpdir-unset` fires only on flag true (`detectors.md:166`), so on a
    covered call that ran unsandboxed it is silent. That is a false negative,
    and probably theoretical given `detectors.md`'s caveat that this has not
    been observed since 2.1.270.
  - The lock verdicts' *Re-run* and *Retry* wording (`lock-detectors.md:53-56`)
    tells a covered call to add `dangerouslyDisableSandbox` under `mask`
    (character device), `orphan` and `unknown`. That is harmless, but it is a
    cost.
  - With the flag policy dropped, a flagged unsandboxed refusal of an id that
    never existed now reads `lost`, which was silent before. Only
    `detectors.md:252-254` (Corpus) records this new false positive, not D-8 or
    this node.

### m-14. The changelog entry leaves out the test-side fixes

- **Where:** `docs/changelog.md:274-301`.
- **Axes:** completeness, consistency with the previous entry's convention.
- **The gap:** the previous entry closes with "The suite gained pins for the
  review's verification gaps". This one does not mention:
  - the Major 1 trailing-slash pin;
  - m-14 (the `assert_no_git_above` guard);
  - m-16 (the `mktemp` spy, although NFR-4 relies on it);
  - the BSD cases added to seven suites.

### m-15. The hub's 2.1.293 summary simplifies the uncovered form

- **Where:** `SKILL.md:22-24`.
- **Axes:** accuracy (minor).
- **The text:** "the same status behind `true &&`".
- **What ran:** `true && command git status --porcelain --ignored`. In that
  environment, `prohibitions`' hook refuses the literal `true && git status …`
  (`m4-reprobe-evidence.md:27-30`).
- **Not affected:** the node (`excluded-commands.md:23-30`) and
  `lock-detectors.md:112-115` give the exact form. The hub summary is not
  wrong in substance.

## Observation (not counted)

- **The `--ignored` proof has one theoretical hole.**
  - `git status --porcelain --ignored` (traditional mode) collapses a wholly
    ignored directory to one `!! dir/` line. So a mask nested inside a real,
    wholly ignored directory, such as `.claude/` in a repository that ignores
    it, would not appear by name.
  - Root-level masks (`.bashrc`, `.mcp.json`, …) still appear, so "no mask name
    in the listing" stays sound in practice.
  - The claim "every mask name appears" (`excluded-commands.md:32-37`,
    `lock-detectors.md:116-118`) is slightly broader than that.

## Previous findings in this partition: re-verified

| Finding | Status | Evidence |
|---|---|---|
| m-1 (state layer) | Fixed, with a lag (m-9 above) | Status names the `resume-lost` probe call; §Now Focus reads "closing the review-fixes jobs" |
| m-2 (strict mode) | Fixed (wrong citation: m-3) | `SKILL.md:74-80` and `escapes-and-costs.md:8-24` say "ignores", "runs sandboxed", and give both `!` cases. Matches `sandboxing.md` §Turn off the retry and `settings-reference.md` §allowUnsandboxedCommands verbatim |
| m-3 (D-8 mitigation) | Fixed (completeness: m-13) | D-8 `design.md:283-288`, L-2 `:383-384`, `sandbox-state.md:14-32` follow D-a and D-d. `detectors.md` §resume-lost has the Probe paragraph with `lost`/`found`/`unknown`, flag policy "None", both verdicts and E1-E5. `recipes-and-claude.md:10-15` reads "verified on CC 2.1.292" and adds the dropped turn |
| m-4 (`--ignored` re-probe) | Fixed | `SKILL.md:22-33`, `excluded-commands.md:8-37`, `lock-detectors.md:110-120`. Version 2.1.293, 20 `??` plus one `!!`, and `command git` all match `m4-reprobe-evidence.md` |
| m-5 (allow rules) | Fixed in the named files (residuals: m-2, m-4) | `SKILL.md:58-62`, `:81-84`, `:105-107`; `escapes-and-costs.md:58-75`; `excluded-commands.md:139-148`. Matches `sandboxing.md:217,320` |
| m-6 (pinned-by lag) | Fixed for FR-3 and FR-4; FR-5 lags (m-6 above) | FR-3's runtime-failure cases exist at `hook-malformed.bats:184,200,218`. The FR-4 families cover `hook-locks-pathless`, `hook-resume`, `probes-resume` and `probes-readonly-globs` |
| m-7, m-8 | OUT, unchanged | `.gitlore/bin/claude` and `.claude/settings.json` have no diff in `1718c03..HEAD` |
| m-9 (`tracked()`) | Fixed | `justfile:17-25` names it `lint_paths`, and its comment states the wider scope |
| m-11 (doc half) | Fixed (overstatement: m-11 above) | `readonly-path.md:68-73` states the rule; `:123-125` gives the quoted-literal residual (Q4) |

## Checked and conforming

- **Verdict text.** `detectors.md` §resume-lost `lost` and `found` (paragraph
  and human line) are byte-identical to `verdict_resume_lost lost|found` after
  whitespace normalisation. `found` is 279 characters, under FR-6's 400.
  - The `found` text is the finalised version of the outline's draft. It keeps
    Q2's three elements: not the sandbox, unsandboxing will not help, check the
    config dir.
- **Probe description against `probe_resume_lost`.**
  - The id regex, the glob `"$root"/projects/*/"$id".jsonl` and the `[ -f ]`
    test match the code.
  - So do `unknown` for an empty `CLAUDE_CONFIG_DIR`, an unset or empty `HOME`
    and no id or a `sed` failure, and the residuals (`archived/`,
    `subagents/`).
  - The matcher and the probe anchor on the same line shape.
- **Hook.** `annotate.sh`'s comment and gate have no `resume-lost` policy,
  which matches Q1, `hook.md:16-17` and `detectors.md:212`.
- **Evidence facts.** Every CC-behaviour claim checked matches the evidence
  file it cites:
  - 2.1.292 for E1-E5;
  - 2.1.293 for the `--ignored` re-probe;
  - E2's dropped turn;
  - E3's any-project lookup;
  - E5's config-dir cause;
  - the fixture ids having no transcript;
  - "interactive `--resume` and `--continue` not tested".
- **Design state.**
  - FR-4 reads "Four probes" and names the families.
  - NFR-2 matches Q5's wording, and `CLAUDE.md:22-24` matches NFR-2.
  - The suites carrying a `make_bsd_stubs` case are the seven of Q5's eight
    plus `hook-resume` and `probes-resume`. The `hook-verdicts` skip is
    justified, since `detect` is stubbed there.
- **Design cap.** `design.md` is at 399 of 400, offset by the planned FR-4
  enumeration swap. No prose was shaved elsewhere: the range diff holds only
  the Status, Focus, FR-3, FR-4, NFR-2, NFR-4, D-8 and L-2 hunks.
- **Skill cap and triggering.**
  - `SKILL.md` is at 200 of 200. Its growth (+10) is all m-2, m-3, m-4 and m-5
    content, with no long lines.
  - The frontmatter description is unchanged and still names the
    multi-turn `--resume`, `excludedCommands` and cleanliness-gate triggers.
- **Directive quality.** The new hub text gives an act for each case: ask for
  the mode change where a `!` command is sandboxed too; re-probe with
  `--ignored` alone in its call; propose an allow rule rather than writing
  one.
- **README.** "Nine ship" equals FR-7's five plus four, and the new
  `resume-lost` line agrees with the `lost`/`found` outcomes.
- **Honesty about the trade.** `detectors.md:252-254` states that the
  all-zero-id corpus match would now read `lost`.
- **Changelog.** The entry is dated 2026-10-08. Its claims (2.1.292, 2.1.293,
  `unknown` silent, the families, the Python compile check) match the docs and
  the `justfile`.
- **`CLAUDE.md` gate list.** It matches the `justfile` `precommit` order: the
  manifests, shellcheck, `bash -n`, rumdl, line limits, links, the Python
  compile check, tests.
- **Links and paths.** Every cross-document link and anchor resolves, including
  `detectors.md#resume-lost` and `#matching`. Every cited repository path
  exists except the historical `tests/shim.bats`. The `plans/…` evidence paths
  cited from `detectors.md` and `lock-detectors.md` exist.
- **Configuration.** `hooks/hooks.json`, `.claude-plugin/plugin.json`
  (`jq`-valid), `.envrc`, `.gitignore`, `.rumdl.toml`, `pyproject.toml`,
  `uv.lock`, `.gitmodules`, `LICENSE` and `.claude/gitlore-hook-setup` have no
  diff in `1718c03..HEAD`. They were re-read and are consistent with D-16, the
  README and the previous review. The `justfile` structure is sound: every
  check goes through `report`, and a clean run ends with the list of checks
  that passed.
- **`BRIEF.md`.** Its range change is a re-wrap only, as the previous review
  found.
