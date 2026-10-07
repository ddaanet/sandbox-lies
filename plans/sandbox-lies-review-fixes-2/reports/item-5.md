# Item 5 report — Phase 5 docs (Items 5.1 to 5.4)

Edits are unstaged and uncommitted. `just precommit` was not run, as the
dispatch said. No scratch directory was created.

## Item 5.1 — `docs/design.md`

- **Status:** now lists "the hook's lock and `resume-lost` probe calls" as built
  and tested, and is verified against `d8a8591` (2026-10-08).
- **§Now Focus:** "closing the review-fixes jobs — their review and TDD audit."
- **FR-3:** `tests/hook-malformed.bats` now covers "malformed ones and a probe
  or verdict that dies mid-run". Those are the cases "probe dying after output
  stays quiet", "verdict dying after a probe stays quiet" and "probe-less
  verdict dying stays quiet".
- **FR-4:** "Four probes", with transcript existence (`resume-lost`) added. The
  pinned-by list is now "the `tests/probes*.bats` family over synthetic trees
  and the `tests/hook-*.bats` family over the hook's calls". That covers
  `hook-locks-pathless.bats`, `hook-resume.bats`, `probes-resume.bats`,
  `probes-readonly-globs.bats` and the rest (m-6).
- **D-8:** adds "`resume-lost` ignores it: its probe tests the transcript
  itself." The accepted tradeoff now says a call an exclusion unsandboxed
  carries no flag, so a covered `git` whose lock was gone by probe time reads
  `mask`, whose re-run is harmless (D-a, D-d).
- **L-2:** a covered call "carries no flag or other trace in the payload (D-8)".
  The `resume-lost` independence and the git-lock residual are stated once, in
  D-8, which L-2 points to.
- **NFR-2:** "The suite re-runs itself with BSD-strict stubs" is replaced by "A
  suite whose code under test calls one of those five tools keeps one case
  re-run with BSD-strict stubs on `PATH`." The five are the
  `grep`/`sed`/`mktemp`/`stat`/`wc` named in the line before. This is the Q5
  rule, matching the edited `CLAUDE.md`.
- **NFR-4:** the read scope adds "whether each session id a `--resume` refusal
  names has a transcript, never opening one". The `tests/check-jq.bats` pin now
  reads "the `SessionStart` check with a `mktemp` spy" (m-16).
- **Line count:** 399 before (HEAD) and 399 after `just format-docs`.
  - Added lines: Status +0 (after rewording), FR-3 +0, NFR-2 +1, NFR-4 +1, D-8
    +1, L-2 +0.
  - Offset: the FR-4 enumeration, 12 lines down to 9 for the paragraph's whole
    tail, which is −3. The per-file list (`probes-readonly.bats`,
    `probes-readonly-members.bats`, `probes-readonly-operands.bats`,
    `hook-locks.bats`, `hook-candidates.bats`, `hook-writes.bats`) and the "with
    a character device at the lock path and no holder tool on `PATH`" detail are
    replaced by the two families.
  - No line exceeds 80 columns: rumdl reflows to 80 and its check passes.
- **Tried and reverted:** adding `tests/hook-resume.bats` to FR-5's flag-pairing
  list. That suite pairs both flag values too, so the FR-5 list lags, but the
  change cost a line and FR-5 is outside this item's list. FR-5 is unchanged,
  and its three named suites still pair both flags. A follow-up could name
  `hook-resume.bats` there. A family glob would overclaim: `hook-cap`,
  `hook-malformed`, `hook-writes` and others do not pair flags.

## Item 5.2 — `sandbox-state.md`, `detectors.md` §resume-lost

- **`docs/references/sandbox-state.md`:**
  - Dropped: the `No conversation found` sentence and the claim that "the probes
    cover the verdicts where it matters".
  - The accepted tradeoff now says the case is live: exclusions are honoured for
    a fully covered call, and the skill's baseline excludes `claude` and `git`.
  - It lists what the tradeoff costs per detector:
    - `resume-lost` does not depend on the flag (D-a). A covered refused
      `--resume` whose transcript exists reads `found`.
    - A lock that exists reads `held`, `orphan` or `unknown` from the probe.
    - What is left is a lock gone by probe time, which reads `mask` with no flag
      (`_probe_lock_at` in `lib/probes.sh`). Its re-run is harmless (D-d).
- **`docs/references/detectors.md` §resume-lost:**
  - New **Probe** paragraph. It covers the id extraction from refusal lines, the
    `<config dir>/projects/*/<id>.jsonl` glob, the config dir
    (`CLAUDE_CONFIG_DIR` when set, else `$HOME/.claude`) and the fact that the
    probe only tests existence and prints no key lines.
  - All three outcomes: `lost`, `found`, and `unknown`. `unknown` means no id
    extracted, `CLAUDE_CONFIG_DIR` set but empty, or both it and `HOME` unset;
    the verdict has no text for it, so the hook is silent.
  - The residuals: `archived/` and `subagents/` are not searched, and the
    fixture read still gives `lost` (D-10).
  - **Flag policy:** "None: the probe decides under either flag", with the
    reason (Q1).
  - **Verdicts:** `lost` and `found`, paragraph and human line each. A script
    checked both against `verdict_resume_lost lost|found` output after
    whitespace normalisation: all four strings match verbatim.
  - **Live reproduction (2026-10-07, CC 2.1.292):** E1, E2, E3, E3s, E4 and E5
    as bullets, citing
    `plans/sandbox-lies-review-fixes-2/resume-probe-evidence.md`. It also
    records that interactive `--resume` and `--continue` were not tested. The
    refusal is described, never quoted.
  - **Corpus:** one sentence added. The third match (all-zero id, flag set) was
    silent under the old flag gate. With no gate it would read `lost`, a false
    positive. This is a consequence of Q1 that the outline did not name, and it
    was not re-measured.
- **`docs/references/detectors.md` — `docs.bats` and the quotes:** `detect` run
  directly over every edited file prints nothing, and `tests/docs.bats` passes.
  The verdict quotes fire no detector.

## Item 5.3 — `readonly-path.md`, `lock-detectors.md` check

- **The skip, confirmed in `lib/`:** `lib/probes-readonly-command.sh:236-239`
  tests `${word##*<}` against `*[*?[\$]*`. So the candidate tested is the text
  after the last `<`. The tokenizer has already removed quotes, so a quoted
  literal is skipped too.
- **`docs/references/readonly-path.md`:**
  - The paragraph before the residuals now states the rule. A `readfile=`
    candidate holding `*`, `?`, `[` or `$` is passed over for the next one, and
    in a word holding `<` only the name after the last `<` is tested.
  - Examples: `grep pat *.log x.err` gives `x.err`, `cat $OUT.log` gives no
    line, and `grep 'err.*'<x.log` gives `x.log`.
  - The residual list gains a last bullet: a quoted literal naming a real file
    is skipped too (`grep -l pat '*.log'` gives no line), the safe side (Q4).
  - Each example is an existing case in `tests/probes-readonly-globs.bats`.
- **`lock-detectors.md:110-112` check: mismatch found, fixed.**
  - The file named the re-probe as the bare `git status` (`--porcelain`, no
    `--ignored`), from the CC 2.1.289 observation.
  - The 2.1.289 observation is kept. The CC 2.1.293 re-observation from
    `m4-reprobe-evidence.md` is added:
    - the bare covered form listed no mask name;
    - `true && command git status --porcelain --ignored`, shown sandboxed by a
      refused `/tmp/<name>` write, listed 20 masks as `??` and a gitignored one
      as `!!`.
  - The re-probe is now a bare `git status --porcelain --ignored`, with the
    reason: without `--ignored`, a sandboxed listing in a repository that
    ignores every mask name shows none.

## Item 5.4 — `docs/changelog.md`

- One entry appended:
  `## 2026-10-08 — review fixes: a transcript probe for \`resume-lost\``.
- It covers:
  - the D-8 finding, the CC 2.1.292 probe result, and the probe with its three
    outcomes and no flag policy;
  - D-8's narrowed tradeoff and the `readfile=` glob/expansion skip;
  - the `--ignored` re-probe on CC 2.1.293;
  - the narrowed NFR-2 rule, the FR-4 family lists and the Python compile check.
- It does not cover the skill changes (Phase 6), which have not landed.

## Not touched, noted

- `README.md:57` describes `resume-lost` as a resume "whose transcript the
  sandbox never let" persist. That still reads true for `lost` but not for
  `found`. It is out of this dispatch's scope.

## Checks (foreground; the last four were issued in one batch, not strictly one
at a time — none is a test process)

- `just format-docs` exited 0. Its output:

  ```text
  rumdl fmt -q --no-cache
  docs/references/readonly-path.md:65:1: [MD013] Paragraph could be normalized to use line length of 80 characters [fixed]
  docs/references/readonly-path.md:124:1: [MD013] List item could be normalized to use line length of 80 characters [fixed]
  docs/references/sandbox-state.md:19:1: [MD013] Line length 81 exceeds 80 characters [fixed]
  docs/references/sandbox-state.md:27:1: [MD013] Line length 81 exceeds 80 characters [fixed]
  format-docs rc=0
  ```

- `rumdl fmt --check -q --no-cache` printed nothing and exited 0.
- `scripts/check-line-limits.sh` printed nothing and exited 0. `docs/design.md`
  is 399 lines.
- `scripts/check-links.sh` printed nothing and exited 0.
- `scripts/run-bats.sh tests/docs.bats` exited 0, with output
  `bats: 2 passed, 0 failed — full log: /tmp/sandbox-lies-bats.cZbcMB`.
