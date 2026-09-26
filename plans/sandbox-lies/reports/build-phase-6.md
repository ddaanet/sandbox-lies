# Build report: Phase 6 (readonly-path verdict)

Delegate run of Phase 6 only, from the Phase 5 boundary resume block. Recall:
the artifact's `sandbox-effects.md` sections and `gitlore:memory-writing` at
the gate; the executors loaded the artifact's skills themselves.

**Entry gate.** verify-step reported `DIRTY`. The index held the main
session's staged precompact edits to `.claude/handoff-task.md` and
`.claude/handoff-todo.md`, which are real edits, not masks. I told the team
lead. Every Phase 6 commit used an explicit pathspec (`git commit -- <paths>`),
so those two files stayed staged and untouched throughout. In place of
verify-step, each check used `git status --porcelain --untracked-files=no`
(showing only those two lines) plus `just precommit` (exit 0, bats 181 at
entry).

## Commits

1. 📝 Item 6.1 list revision: path-extraction slice first; the readonly-path
   verdicts carry the command-output-read clause
2. ✨ Item 6.1/1: the readonly-path probe reads curly quotes, `mv`'s target
   and four unquoted forms
3. 🐛 Item 6.1/1 code-review fixes: anchored forms, exact curly capture,
   measured residual
4. ♻️ Item 6.1/1: the readonly-path probe split into `lib/probes-readonly.sh`
   (refactor the code review flagged; `lib/probes.sh` was at 392/400)
5. 📝 Item 6.1 list revision after slice 1: verdict rows split across slices 2
   and 3; `stub_probe_kv` moves to the helper
6. ✨ Item 6.1/2: readonly-path writable verdict through the hook
7. 🐛 Item 6.1/2 code-review fixes: backticked path, a subject when the path
   is missing
8. ✨ Item 6.1/3: readonly-path readonly and nopath verdicts
9. ♻️ Item 6.1/3 code-review fixes: one shared tail literal, no subshell forks
10. 📝 Item 6.1: the verdicts ask for the comparison before the re-run, and
    readonly carries an act (from the slice 3 code review's wording concerns)
11. ✨ Item 6.1/4: readonly-path silent unsandboxed
12. 📝 Item 6.1/4: code review, no changes
13. 📝 Phase 6 — config and worktree memory retired; statuses flipped;
    checkpoint corrector Ready (landed after the gate was approved). It carries the memory
    retirement, the design.md status flips, the changelog entry, the
    translation-map row, the corrector's fixes and the reports
    `phase-6-retirement.md` and `phase-6-corrector.md`. The `--only` commit left
    a stale `memory` gitlink staged in the index; `git add memory` restaged it
    to match HEAD.
14. This report's commit.

## Per-slice outcome

- **Slice 1, path extraction** (new, from my human partner's decision). RED:
  six rows failed on assertion, and two regression/near-miss rows were
  mutation-proven. Test review: Ready; it added paths containing blanks and em
  dashes, a near-miss loop and a BSD-stubs case. GREEN: sed rules in order: mv
  target, straight quote, curly quote, then the four fixed unquoted forms. Code
  review: Ready. It anchored every form at the tool's prefix and fixed a curly
  byte-class bug. It also found the stated residual was wrong: an unquoted path
  containing `: ` is read whole, because the capture runs to the line's last
  `: ` and the kernel message holds none. It recorded the real residuals
  instead (see Deviations). Refactor: the probe moved to
  `lib/probes-readonly.sh`, which `lib/probes.sh` sources.
- **Slice 2, writable.** RED failed on assertion. Two verdict-row cases errored
  until the test review added an inert stub, which is now the fix path; the
  test review also added a verbatim transcription case. The retired
  `hook silent without a verdict` case is covered by `hook-locks.bats`'s
  fake-name `no probe without a verdict`. Code review: the path is now
  backticked, and "The path" is the subject when the path is missing.
- **Slice 3, readonly and nopath.** Red on assertion; review Ready; GREEN
  shares the tail literal. The code review flagged wording; I applied it in
  commit 10.
- **Slice 4, flag policy.** One `case` entry in `hooks/annotate.sh`; red on
  assertion; code review found nothing.
- Suite: bats 181 → 196 passed.

## Phase 6 boundary: corrector verdict

`phase-6-corrector.md`: **Ready**, no UNFIXABLE. Fixes it made, all
uncommitted and riding commit 13:

- FR-6 now reads "under 400 characters before a probe value is interpolated".
- Stale `lib/probes.sh` pointers corrected in the `lib/matchers.sh` comment and
  the `tests/probes-readonly.bats` header.
- A further extraction residual recorded: a curly-quoted or unquoted path
  holding two straight quotes.
- Comment and alignment fixes.
- Three scratch files deleted from `$TMPDIR`.

It changed no memory file.

## Findings worth my human partner's attention

- **FR-6 was reworded (the corrector's Major 1).** The `writable` paragraph is
  391 characters with no path. The path is interpolated, so the real paragraph
  reaches 400 characters once the path is 15 characters long. FR-6 now bounds
  the text before interpolation. The alternative is to shorten the verdict,
  which has 9 characters of headroom. Default: keep the reworded FR-6.
- **The residual you asked me to record did not hold.** You asked for "an
  unquoted path containing `: ` is misread". As built, that path is read whole,
  and tests pin it. `detectors.md` records the residuals that were measured
  instead: a quoted path holding its own closing quote, and a path holding two
  straight quotes. Default: keep the measured wording.
- **Verdict wording changed beyond the list revision** (commit 10). Two changes:
  - The partial-merge comparison now comes before the re-run, in both
    `writable` and the shared `nopath` tail.
  - `readonly` gained an act: "Unsandboxing will not help: write somewhere
    writable, or ask before changing its permissions."
  - `nopath` has its own human line, `read-only — sandbox allowlist`. Earlier,
    `detectors.md` gave it none.
- **Memory judgement calls** (`phase-6-retirement.md` §Judgement calls):
  - The merge-recovery procedure stays under a new `Interrupted merge` heading.
    The `git reset --hard <branchtip>` fallback moved in with it.
  - Cost 3 keeps its guidance and loses only the quoted diagnostic.
  - The sibling section's classifier note moved into cost 2 (my edit).
  - Dropped with nothing to receive them: the CC 2.1.233 `update-config`
    verification with its open `enabledPlugins` question, and the false claim
    that `git:*` unsandboxes git.

## For the Finish run summary

- The executors' commits used `--only` pathspecs, because the main session's
  staged handoff edits sat in the index all phase.
- The refactor was dispatched at slice 1 (split of `lib/probes.sh`).
- The retirement was deferred to one gated commit after the slices, as in
  Phase 4.
- The report-only commit 12 was made before its gate run. The gate was run
  right after it: exit 0.
- List revisions: two (commits 1 and 5); none after slices 2–4.

## Deviations

- **Slice order.** The extraction slice went first, so the verdict slices
  became 2–4. That kept the retirement on the final verdict slice.
- **Verdict rows.** Split between slices 2 and 3, so slice 3 kept a genuine
  red.
- **Retirement and status flips.** Deferred from slice 4's commit to one gated
  commit, as Phase 4 did.
- readonly-path verdict wording (partial-merge clause, nopath human line)
  questioned by my human partner at the Phase 6 gate; rework carried to Phase 7.
- **Agents.** Dispatched unnamed, because teammates cannot name the agents they
  spawn. None of them delivered a hand-back message, so their report files were
  read instead.

## Gate: gitlore memory approval — closed

My human partner approved the summary as written, kept FR-6's
pre-interpolation wording and the measured-residual wording, and did not
accept the verdict wording (Deviations). The approved summary:

> Retire the config-path and sibling-worktree sections now that readonly-path
> annotates them
>
> **Reduce ddaanet/sandbox-effects:** the file no longer carries three things:
> the harness-mounted config paths section (`Device or resource busy` /
> `Read-only file system` on `.claude/settings.json`, `.git/config`, a plugin's
> live `hooks/hooks.json`), the sibling worktree writes section, and cost 3's
> quoted `inter-device move failed` diagnostic. Their symptom-table rows and
> description clauses went with them. When one of those refusals fires, the
> sandbox-lies plugin's `readonly-path` detector now annotates it: it probes
> whether the path is writable outside the sandbox, then tells the agent to
> compare a partial merge against its target, to re-run unsandboxed (or re-run
> the command that wrote a command-output file), and to use `update-config` for
> `.claude/settings.json`. What no detector carries stays for the plugin's
> skill. That is the merge-recovery procedure with its `git reset --hard`
> fallback, now under `Interrupted merge: recover before retrying` with its own
> symptom row and description clause (a merge killed mid-way leaves files
> updated with HEAD unmoved). It is also cost 3's recipe guidance without the
> quote, and the note that the classifier lets through an unsandboxed retry of a
> write the user's prompt asked for, moved into cost 2. Two things were dropped
> with nothing to receive them: the CC 2.1.233 `update-config` verification
> with its untested `enabledPlugins` question, and the claim that `git:*`
> unsandboxes the git forms, which CC 2.1.281 does not honour.

## Phase 7 boundary resume block

```text
Resume /build at Phase 7 of /Users/david/code/sandbox-lies/plans/sandbox-lies/runbook.md.
Phase 6 closed at commit "Phase 6 — config and worktree memory retired; statuses flipped; checkpoint corrector Ready", followed by this report's commit (plans/sandbox-lies/reports/build-phase-6.md).
Build baseline: .git/build-baseline. verify-step: /Users/david/.claude/plugins/cache/ddaanet/edify/0.3.0/skills/build/scripts/verify-step.sh (run unsandboxed).
Next: first rework the readonly-path verdict wording my human partner questioned at the Phase 6 gate: the partial-merge "compare modified files against the target" clause (why not clean up and re-run?) and the nopath human line `read-only — sandbox allowlist` (obscure); text in detectors.md, lib/verdicts.sh, tests/verdicts.bats, tests/hook-candidates.bats. Then Item 7.1 (the skill), Item 7.2, then the Phase 7 boundary corrector, then Phase 8.
Item 7.1 carry: skill-mapped remainders left in memory/ddaanet/sandbox-effects.md: the zero-byte mask shape (2.3), $TMPDIR instability and the multi-turn eval-harness consequence (4.2), and from 6.1 the `Interrupted merge: recover before retrying` section, cost 3's recipe guidance, and the cost 2 classifier notes; revisit the untracked verdict's opening "character-device entries" wording.
Staged in the index by the main session (if still there): .claude/handoff-*.md; commit with explicit pathspecs.
Sandbox facts (CC 2.1.281; stamp versions from the transcript `version` field, never `claude --version`): git:* in excludedCommands does NOT unsandbox git; masks are visible from every process while any sandboxed command runs; the mask-free test is `touch /tmp/<name>`.
Sizes: docs/design.md 397/400; detectors.md ~345; tests/probes-readonly.bats 386; tests/hook-locks.bats ~360; lib/probes.sh ~285.
Splitting is authorized (my human partner, standing): split any doc an edit pushes past 400 lines, per craft:design-doc-writing, fix inbound links, record in docs/changelog.md.
Item 8.2 carry: detectors.md translation map says the audit "is a Phase 6 step" (outline numbering; the runbook item is 8.2).
Shared dispatch context for Phase 6 (reusable as a base): .git/phase6-dispatch.md.
```

## Context usage

About 190k tokens of this delegate's own context at the close.
