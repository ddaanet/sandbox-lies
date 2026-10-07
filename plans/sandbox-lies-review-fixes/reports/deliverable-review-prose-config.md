# Deliverable review, Layer 1: prose and config

**Date:** 2026-10-07
**Range:** `52e6dd82b831a1cc2b7b516d4c248df6fb1ebc8c..HEAD`. The current tree
state of each partition file was reviewed, with the range history used for
context.
**Partition:** the skill (`SKILL.md` and its 4 nodes), the human docs
(`docs/design.md`, 7 `docs/references/` nodes, `docs/changelog.md`,
`README.md`, `CLAUDE.md`, and `BRIEF.md` for its range diff only), and the
configuration files.

## Checks run

- Read the baselines: the review-fixes outline (D1–D5, including the D1
  revision bullet), the runbook Phase 1 and Phase 5 items with their list
  revisions, `reports/item-5-1.md`, `delegate-status.md`, and the first-build
  `deliverable-review.md` and `build-finish.md` §Carry-forward.
- Read every partition file in full. `BRIEF.md`'s range diff is a pure
  re-wrap at 80 columns, with no wording change.
- Compared all verdict text in `detectors.md`, `lock-detectors.md` and
  `readonly-path.md` with `lib/verdicts.sh`. All of it matches, including the
  flag table, the config-lock update-config swap and the readonly tail and
  merge clauses.
- Compared the probe claims with the code: `lib/probes.sh` (path resolution,
  the newline `pathline` guard, `$3` in the header) and `hooks/check-jq.sh`
  against D2 and `hook.md`.
- Resolved every "pinned by" citation and test name: each cited `tests/*.bats`
  file exists, and so do `hook.bats` "hooks.json names the three events", the
  `check-jq.bats` cases, the `hook-writes.bats` and `hook-malformed.bats`
  runtime-failure cases, and FR-1's key assertions at `hook.bats:38-42`. All
  33 bats files load `bsd-stubs` (NFR-2).
- `scripts/check-links.sh` exit 0 and `scripts/check-line-limits.sh` exit 0.
  Line counts: `SKILL.md` 190 of its 200 cap, `design.md` 399 of 400, all
  others under 300.
- `just --list`: `precommit` shows "Checks that run before every commit."
- Grepped the partition for stale wording: `not honoured`, `whole call`,
  `git:*`, `claude:*`, `decoy`, `.bin/claude`, `shim.bats`, `paste`. Every hit
  that remains is historical (changelog entries, dated probes, `hook.md`'s
  pilot reading) or the legacy-syntax note.
- Verified the skill's claims about Claude Code against the current docs,
  fetched 2026-10-07 with `curl` from `code.claude.com/docs/en/`
  `{settings-reference,sandboxing,permission-modes}.md`.
  - The `WebFetch` summary of `settings-reference` was fabricated: a `["docker",
    "nix"]` example and a string-valued `allowUnsandboxedCommands`. It was
    discarded, and only the raw markdown was used.
  - Every D1 element matches the raw text: the every-command rule; the
    forfeiting shapes (`sudo`/`eval`/`xargs`, `cd`/`pushd`/`popd`,
    substitution, subshell or control flow, non-dup redirection, variable
    command name, the five git path-argument subcommands); `git -C` in
    sandboxing §git over SSH; `docker *` syntax; strict mode's key and
    Overrides label; the three auto-allow exceptions; and the decision order
    putting read-only commands behind server-side review.

## Prior finding status (first-build review, this partition)

| Finding | Status | Evidence |
|---|---|---|
| Major 1: `excludedCommands` model and re-probe | Fixed | `SKILL.md:18-25`, `:38-62`, `:66-68`, `:85-100`; `excluded-commands.md:1-43`, `:61-91`, `:143-167`; `escapes-and-costs.md:3-6`, `:25-31`, `:84-88`; `masks-and-gates.md:23-27`, `:47-49`, `:62-65`; `recipes-and-claude.md:3-6`, `:15-16`; `lock-detectors.md:89-113`, `:160-167`. The re-probe is the bare covered `git status` (one-way), and the cwd list is re-ranked. |
| Major 2: `jq` (documentation half) | Fixed | `README.md:32-34`; `design.md:58-63` (FR-1), `:211-214` (Architecture), `:189` (NFR-3), `:319-323` (D-12); `hook.md:25-71` |
| Stale help text: `just --list` precommit | Fixed | `justfile:6` `[doc('Checks that run before every commit.')]`; `just --list` confirms |
| `mv` target form | Fixed | `readonly-path.md:30-33` |
| NFR-4 read scope | Fixed | `design.md:193-201` |
| Payload `cwd` and a persisted `cd` | Fixed | `detectors.md:19-25` |
| Main session only | Fixed | `SKILL.md:87-90`; `masks-and-gates.md:15-19` |
| Batching contradiction, "no generation" | Fixed | `SKILL.md:74-77`; `escapes-and-costs.md:60-63` |
| Auto-allow exceptions | Fixed | `escapes-and-costs.md:46-51` |
| Strict mode key | Fixed (see m-2 for residual wording) | `SKILL.md:69-73`; `escapes-and-costs.md:10-18` |
| Platform scope | Fixed | `design.md:49-51`; `README.md:39-42` |
| NFR-1 re-measurement credit | Fixed | `detectors.md:139-143`; checked against `item-4-3-s1-green.md` §NFR-1 |
| Two hit counts (41 and 57) | Fixed | `detectors.md:94-100`, `:111-112`; `design.md:262-265`. The "four or more blanks" claim matches `plans/2026-09-02-sandbox-detector-replay.py:70` and `2026-09-03-…-eval.md:69`. |
| `design.md` leftovers (D-3 count, NFR order) | Fixed | `design.md:251-253` ("nine"); NFR-4 at `:193`, before NFR-5 at `:203` |
| FR-8 reproducibility | Fixed | `design.md:136-139`; the fixture count is still 34 |
| `CLAUDE.md` wording | Fixed | `CLAUDE.md:11-13` |

## Critical

None.

## Major

None.

## Minor

**m-1 — The `design.md` state layer is stale.**

- **Where:** `docs/design.md:3-8` and `:17-19`.
- **Axes:** accuracy, consistency.
- **Problem:** The Status line now lists "the `SessionStart` `jq` check" as
  built and tested (added by `a9ac616`). It still reads "**Verified against:**
  `0df5864e` (2026-09-27)", a commit that predates `hooks/check-jq.sh` and
  every review fix.
- **Also stale:** §Now's Focus is "closing the first build — its review and
  TDD audit", but both the first build and the review-fixes build have
  finished (`delegate-status.md` §Phase reached).

**m-2 — Strict mode is described as refusing the flag; the docs say it is
ignored.**

- **Where:** `SKILL.md:69` ("Strict mode refuses the per-call flag") and
  `escapes-and-costs.md:12` ("`dangerouslyDisableSandbox` is refused").
- **Axis:** constraint precision.
- **What the docs say:** settings-reference §`allowUnsandboxedCommands` and
  sandboxing §Turn off the retry (2026-10-07) say that "Claude Code ignores
  that parameter", so the call runs, sandboxed.
- **Why it matters:** an agent that reads "refused" may conclude the command
  never executed, but its sandbox-permitted side effects did happen.
- **Missing caveat:** the hub's "ask the human partner to run it as
  `! <command>`" does not mention that shell-mode commands also run sandboxed
  under strict mode in two cases: a background session, and a Linux session
  with `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB` set (same section).

**m-3 — The revised D1 makes D-8's accepted tradeoff live, and its
mitigation claim no longer holds.**

- **Where:** `docs/references/sandbox-state.md:53-57`; `design.md:285-288`
  (D-8) and `:383-384` (L-2).
- **Axes:** accuracy, consistency.
- **The claim:** for a call that an exclusion unsandboxed, "the probes cover
  the verdicts where it matters".
- **Why it no longer holds:** under the revised D1, exclusions are honoured,
  and the skill recommends `git *` and `claude *` entries. Covered calls
  therefore run unsandboxed with the flag absent, in the very configuration
  the skill recommends. Two verdicts go wrong in that case, and no probe
  covers either:
  - `resume-lost` fires when the flag is false (`detectors.md:192-193`). A
    bare `claude --resume` under `claude *` that fails for another reason is
    told the transcript was never written in the sandbox.
  - A `git-lock` from a covered `git` whose lock is gone by probe time reads
    `mask`, not `gone` (`lock-detectors.md:35`). It is wrongly called a
    sandbox artefact, although the re-run act is harmless.
- **Before the revision:** under the "not honoured" belief this case was
  theoretical. Neither Item 5.2 nor the D1 revision re-examined it.
- **Fix:** at least restate the tradeoff. The remedy itself is a design call.

**m-4 — The re-probe's one-way proof assumes no mask name is gitignored.**

- **Where:** `SKILL.md:22-29`, `excluded-commands.md:23-25` and
  `lock-detectors.md:110-112`.
- **Axis:** determinism.
- **Problem:** `git status` omits ignored paths. In a repository whose own
  or global ignore rules cover the mask names (for example `.idea`,
  `.vscode`, `.claude/settings.local.json`), a sandboxed bare `git status`
  can list no masks, and the skill reads that as proof that the call ran
  unsandboxed. An `ls -a` of the root has no such gap.
- **Fix:** add the qualifier "with no mask name ignored", or prescribe
  `git status --ignored`.

**m-5 — Allow rules are left out of what clears an unsandboxed command.**

- **Where:** `SKILL.md:54-57` and `:74-77`; `escapes-and-costs.md:51-53`;
  `excluded-commands.md:121-134`.
- **Axis:** functional completeness.
- **Problem:** the skill names only the read-only validator as what clears an
  escaped command before the classifier.
- **What the docs say:** sandboxing §Run commands outside the sandbox: "Read-only
  commands and commands your allow rules cover run without a prompt". §The
  unsandboxed retry escape hatch: a matching allow rule "also approves the
  retry".
- **Why it matters:** the cost section offers only "shape" as mitigation,
  although an allow rule is the documented one.

**m-6 — "Pinned by" lists lag this job's tests.**

- **Axis:** completeness.
- **FR-3** (`design.md:77-80`) cites `hook-malformed.bats` "over malformed
  ones". It does not mention that the runtime-failure cases that close Major 3
  live there (`hook-malformed.bats:172-206`).
- **FR-4** (`:91-98`) omits:
  - `tests/probes-lock-newline.bats` and `tests/hook-locks-pathless.bats`
    (Item 5.5);
  - `tests/probes-readonly-pins.bats`.
  Item 5.2 required the pinned-by lists to name this job's new files; Item 5.5
  came later and was not folded in.

**m-7 — `.gitlore/bin/claude:4` points at the wrong design doc.**

- **Axis:** accuracy.
- **Problem:** the pointer reads "see docs/design.md 'Memory Redirect
  Launcher' (D10)". In this repository that path is sandbox-lies' design,
  whose D-10 is self-reference.
- **Fix:** the file is gitlore-generated ("Identical in both placements"), so
  the fix is upstream in gitlore, not here.

**m-8 — An unquoted `${CLAUDE_PROJECT_DIR}` in `.claude/settings.json:9`.**

- **Axis:** robustness (whitespace).
- **Problem:** the version-guard command splits on a project path that holds
  a blank. The two dogfood entries (`:18`, `:28`) quote it.
- **Fix:** the line predates the range (`52e6dd8`) and is written by the
  toolkit installer, so the fix belongs in claude-plugin-dev.

**m-9 — `justfile:22` names its helper `tracked()`, but it now lists
untracked-unignored files too (`--others --exclude-standard`).**

- **Axis:** naming.
- **Problem:** the comment at `:17-19` says what the helper does; the name
  does not. Meanwhile the line-cap, link and self-quiet checks
  (`scripts/lib/tracked.sh:66`, `tests/docs.bats:37`) still read tracked files
  only. Two scopes now sit under one word.

**Out of partition, for the tests reviewer:** `tests/helpers/probes.bash:210`
still cites `tests/shim.bats`, which `0bbb18c` removed.

## Known carry-forward confirmed (not counted)

- **Unchosen host:** `README.md:23`, `plugin.json:9-10`.
- **`tmpdir-unset` unobserved since CC 2.1.270:** the caveat at
  `detectors.md:177-180` stands. The current sandboxing doc §Temporary
  directories now says an unsandboxed `$TMPDIR` never expands empty, which
  supports it.
- **The phantom verdicts' "project root" wording after a persisted `cd`:**
  `hook.md:102-105`.
- **The readonly-path partial-checkout path:** resolved from the payload `cwd`
  (`readonly-path.md:43-45`).
- **The owed live `git-lock` `mask` reproduction:** `lock-detectors.md:89`.
- **FR-10 Partial / Item 8.2 remainder:** `design.md:150-161`.
- **`design.md` at 399 of 400:** the next addition needs a move-out.
- **A `path=` encoding that carries newlines** (carry list).
- **A design-doc routing table in `CLAUDE.md`** (carry list).
- **The m7 cwd probe:** `build-finish.md` still lists it, but
  `masks-and-gates.md:19-21` already records it as probed 2026-09-27 (CC
  2.1.281, `2ade145`). The carry-forward entry is what is stale, not the
  skill.
- **`.bin/claude`, `tests/shim.bats` and the BSD paste stub removal**
  (`0bbb18c`): the prose is consistent. D-16 (`design.md:341-349`),
  `.envrc:8-9`, `.gitignore:14-15` and changelog `:233-243` describe the
  toolkit shim. The only remaining references are historical changelog
  entries and the tests helper noted above.
