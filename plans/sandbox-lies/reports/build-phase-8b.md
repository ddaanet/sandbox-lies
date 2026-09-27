# Build — Phase 8, continuation (stopped at two gates, both answered)

Resumed from `build-phase-8.md` §Resume. Entry: verify-step CLEAN (227 bats).
Recall: the plan's recall artifact and its memory files. No `brief.md`.

## What was built

- **Item 8.0/4 — regression pins for the 8.0/3 review fixes**
  (`tests/probes-readonly-pins.bats`, 12 tests). `make_scratch_repo`,
  `run_probe_command` and `index_mtime` moved into `tests/helpers/probes.bash`.
  `run_probe_bounded` gained an optional command argument. The slice was proven
  by mutation: RED used one mutation per test, and the test review reproduced
  each test with a different mutation.
  - The test review found the central pin was decoration. The index-untouched
    test did not red when the probe reverted to porcelain `git diff`: git here
    compares stat to the whole second, and `touch d` landed in the same second
    as the `git add`.
  - Fixed with `touch -t 200501010000 d` plus a `diff-files` precondition. It
    now reds on the original defect 5 of 5.
  - Bundled sub-cases were split and a vacuous unborn-HEAD case fixed. Every
    negative got a positive control.
- **Item 8.0 list revision** after slice 3 (slice 4 added) is committed in
  `runbook.md`. After slice 4: none, because slice 4 is the item's last.
- **Item 8.1**: `.bin/claude` shim and `PATH_add .bin` last in `.envrc`. The
  shim is pinned by `tests/shim.bats` (each test fault-injected) and
  shellchecked through the justfile (`'.bin/*'` added to the shellcheck
  pathspec). Dogfooded, see below.
- **Skill carry**: `skills/sandbox-lies/references/masks-and-gates.md`, masks
  follow the sandboxed call's working directory (CC 2.1.281).
- **Item 8.2, parent part**: `docs/design.md` Status, `## Now` and
  Verified-against, then the corrector's state fixes. The memory part is edited
  in the tree and held at the gitlore gate (`## Open gate`).
- **Phase 8 boundary corrector** (`reports/phase-8-corrector.md`), standing in
  for Item 8.0's own checkpoint as well. Ten findings fixed and committed:
  - major: the shim looped forever on a `PATH` entry naming `.bin` with a
    trailing slash or relatively; it now strips by identity (`-ef`);
  - the skill act corrected (`cd` in a subshell or `git -C`, since a leading
    `cd` persists);
  - `hook.md` masks-follow-cwd;
  - probe residuals in `detectors.md`;
  - FR-1 → Done, FR-4/FR-6 pinned-by;
  - `bsd-stubs` in the two new bats files;
  - a changelog entry;
  - D-1's argument moved verbatim to `hook.md`. `design.md` is at 396 lines.

  One UNFIXABLE design finding is in `## Open gate`.

Final state: verify-step CLEAN, 243 bats, precommit checks plugin.json,
hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests.

## Item 8.1 dogfood numbers

- **Live run** 2026-09-27, CC 2.1.283 (transcript `version`), session
  `cb060248-60ff-4968-a23d-34701eb98e8f`, through `./.bin/claude -p`:
  - the skill listing holds `sandbox-lies:sandbox-lies`;
  - on `sh -c 'ls -la'` the transcript records `PostToolUse:Bash`
    `hook_additional_context` with the phantom-chardev verdict and
    systemMessage `phantom dotfiles — sandbox masks in listing`;
  - the hook took 111 ms.
- **tmpdir-unset** (`reports/item-8-1-dogfood-numbers.md`): 13 flag-true fires
  in the corpus. The newest is 2.1.270 (2026-09-13); none since, over 27
  flag-true `$TMPDIR` calls after 2.1.270 (the corrector's opportunity count),
  18 of them at 2.1.281 or later. So it is not observed on current CC, which is
  weaker than "never".
- **readonly-path `nopath`**:
  - 11 of 195 hits overall (5.6%);
  - 10 of 152 excluding this repo (6.6%), from 7 sessions;
  - all 195 hits are flag false.

  Shapes left unhandled: `tee: <path>:`, sed's `couldn't open temporary file`,
  git's `could not write config file`, `warning: failed to remove`, and an
  empty `cp` operand. The first three are in design `## Now` Next.
- Corpus: 4055 transcripts, 58716 Bash results, 4306 prefilter survivors.

## Deviations

- The 8.0/4 code review was not dispatched. The slice changed no
  implementation file (the diff over `lib/`, `hooks/`, `docs/` and `scripts/`
  was empty), so the orchestrator wrote `item-8-0-s4-code-review.md` stating
  that, and committed it as the slice's code-review commit.
- The Item 8.0 corrector checkpoint was folded into the Phase 8 boundary
  corrector, as the carry allowed.
- `tests/shim.bats` was added although Item 8.1 named only a manual check
  (automated by default).
- `01169db` committed the numbers report without running precommit first, and
  it fired `readonly-path` in `docs.bats` (FR-11 self-reference). `45c0316`
  requoted the lines as list items. That commit also carries the unrelated
  skill carry.
- Item 8.2 is partial by my human partner's decision. `sandbox-effects.md`
  stays because its zellij section has no detector, so the following stay
  deferred with the deletion that gates them: the translation-map audit
  column, the `tests/matchers.bats` live-file case, the `tests/docs.bats`
  retired-path case, and both index lines.
- The `shared-claude.md` bullet also names "the directory a sandboxed call ran
  from", beyond the runbook's `!`-clause and repoint. It carries the CC 2.1.281
  cwd finding into the always-on tier.

## For the run summary at Finish

From `build-phase-8.md` (previous delegate):

- Item 8.0 became a runbook item ahead of 8.1.
- `orphan`/`unknown` word their retry by the flag too.
- The update-config act replaces the re-run, and `readfile=` wins over it.
- A named target with no match gives no merge clause.
- D-17 pushed `design.md` over the cap. The arguments for D-6, D-13 and D-14
  moved to their nodes.
- `verdicts.bats` split.
- A `rumdl fmt` reflow of `runbook.md` was undone.
- The 8.0/3 code review found four defects GREEN missed (index rewrite,
  quadratic cost, stderr, bash 3.2 `set -u`). They are now pinned by 8.0/4.
- Named subagents could not be spawned, and no dispatch returned a
  SubagentHandback: the artifacts were read at their paths.

This delegate:

- List revision after 8.0/3: slice 4 added. After 8.0/4: none.
- The RED dispatch's explanation for its non-red (`GIT_OPTIONAL_LOCKS` on
  tmpfs) was wrong; the test review corrected it (whole-second stat
  comparison).
- Residual: the bash 3.2 empty-array abort is correct by construction and not
  executable on bash 5. The `git pull` test pins the outcome only.
- Deferred by the corrector:
  - the phantom verdicts say "the project root", which is wrong after a
    persisted `cd` (Item 8.0 scoped the phantom verdicts out);
  - the numbers report misstates readonly-path's flag policy in one sentence.
- No refactor signals. No remediation RCA.
- `/gitlore:push` is **held** until the plugin is published and installable in
  the other ddaanet repos.
- The dogfood session's own SessionStart reported that tier `ddaanet` has
  diverged from its remote `live`. That belongs to the held push: a
  `/gitlore:merge` or push reconciles it.

## Open gate

Two decisions, independent of each other.

1. **Phase 8 corrector UNFIXABLE (U-DESIGN), finding 1.** `merge=1` fires on
   command shape alone (`git merge|pull|checkout|switch|rebase|cherry-pick`).
   With no `target=`, the verdict then tells the agent to "restore them from
   HEAD" on no evidence. Over the corpus it fired 3 times, all false: a
   redirect refused before git ran, a config write refused after a successful
   checkout, and a refused `mkdir`. None of the 195 hits holds git's
   partial-checkout error. Options:
   - (a) print the no-target clause only when the text holds a
     partial-checkout needle, and add `cannot create directory at` to the
     needles;
   - (b) keep the trigger but word the no-target case without the restore act;
   - (c) keep it as is, with the residual documented (done).

   **Answer: (a) chosen; slice 8.0/5 goes to the next delegate.**

   Default was (a), as a new TDD slice 8.0/5 ahead of Finish. It changes the
   behaviour slices 2 and 3 fixed, so the spec in `detectors.md` changes
   first.
2. **gitlore memory gate** for the Item 8.2 memory edits, uncommitted in
   `memory/ddaanet`. The gate blocks every parent commit while memory is
   dirty, so this report is staged but **not committed**: the next delegate
   commits it with the memory. Drafted summary, in the gate's format, held
   against `gitlore:memory-writing` (no index line changes; all seven facts
   stay in the `ddaanet` tier):

   > Retarget sandbox pointers at the sandbox-lies plugin
   >
   > **Update ddaanet/shared-claude:** the phantom-dotfile bullet placed masks
   > in a repo root and sent readers to the `sandbox-effects` memory for the
   > mechanism. It now also covers masks under the directory a sandboxed call
   > ran from (seen on CC 2.1.281, when a persisted cwd inside the memory
   > submodule put masks there). It adds that a slash command's
   > `` !`git status` `` context runs sandboxed with no hook to annotate it, so
   > `git status` is re-run unsandboxed before acting on it. It points at the
   > `sandbox-lies:sandbox-lies` skill's `references/masks-and-gates.md`, which
   > now owns the mechanism.
   >
   > **Update ddaanet/git-add-untracked-deletion:** the stranded-`index.lock`
   > aside linked `[[sandbox-effects]]`; it now says the `sandbox-lies` plugin
   > annotates that error, since the plugin's hook took over the lock
   > translation.
   >
   > **Update ddaanet/cc-bash-background-no-duration-cap:** the measured `ps`
   > gap is now found in the `sandbox-lies:sandbox-lies` skill, not the
   > `sandbox-effects` memory, which no longer carries it.
   >
   > **Update ddaanet/classifier-denied-self-config:** the related sandbox
   > pointer names the `sandbox-lies:sandbox-lies` skill in place of
   > `[[sandbox-effects]]`.
   >
   > **Update ddaanet/codex-review-of-design-docs:** the same pointer change.
   >
   > **Update ddaanet/cc-worktree-bash-guard:** "the other refusal surface a
   > Bash command meets" names the skill in place of `[[sandbox-effects]]`.
   >
   > **Update ddaanet/bang-shell-shared-cwd:** the related push-classifier
   > pointer names the skill in place of `[[sandbox-effects]]`.

   **Answer: approved as drafted; committed with this report.**

   Default was approve as drafted. On approval, the next delegate writes
   `.claude/gitlore-memory-message` with that summary, then commits this
   staged report (the gate commits memory with it), and does not push.

## Finish resume block

```text
Prerequisite: slice 8.0/5 (merge-clause option (a), chosen) is built first.
Finish of /edify:build for plans/sandbox-lies/runbook.md; the memory gate in
plans/sandbox-lies/reports/build-phase-8b.md is closed.
Repo: /Users/david/code/sandbox-lies. Every command starts with
`cd /Users/david/code/sandbox-lies &&`.
Baseline: .git/build-baseline (whole build). Item 8.0's range starts after 7c4f811.
verify-step: /Users/david/.claude/plugins/cache/ddaanet/edify/0.3.0/skills/build/scripts/verify-step.sh
  run unsandboxed, foreground, timeout 600000 ms. A DIRTY listing only phantom
  dotfiles means: use `git status --porcelain --untracked-files=no` plus
  `just precommit` instead.
tdd-audit: every tdd item's slice reports under plans/sandbox-lies/reports/
  (item-2-*, item-4-*, item-6-1-*, item-8-0-s1..s4-*) and the commit range
  $(cat .git/build-baseline)..HEAD. Slice 8.0/4 is proven by mutation (RED and
  test-review tables). Its code review was orchestrator-written because the
  implementation diff was empty. The `git pull` pin is an outcome pin (bash 3.2
  path not executable here).
Review gate: the whole diff since the baseline, weighted to Phase 8. Check
  D-17 across lib/verdicts.sh, the probes and the docs; the shim; the design
  state layer (docs/design.md is at 396 of 400 lines, and the next move-out is
  D-8's or D-10's argument); the skill carry. Carry forward the deferred
  phantom "project root" wording and the nopath shapes named in design Now.
Held: /gitlore:push, until the plugin is published and installable in the
  other ddaanet repos. Other repos stay read-only.
```

## Context usage

About 185k tokens of this delegate's own context at the stop. Most of it went
to the build and recall skill bodies, the review reports read back, and seven
dispatch round-trips.
