# Build report: Phase 7 (the skill and repository prose)

Delegate run of Phase 7 only, from the Phase 7 boundary resume block in
`build-phase-6.md`. Entry gate: verify-step CLEAN (bats 196). Recall: the
artifact's memory files, `plugin-craft:skill-authoring`, `gitlore:memory-writing`.

## What was built

Commits, in order:

1. ✨ Item 7.1 — the sandbox-lies skill: `skills/sandbox-lies/SKILL.md` (hub,
   147 lines) and four references (`excluded-commands.md`,
   `escapes-and-costs.md`, `masks-and-gates.md`, `recipes-and-claude.md`). FR-9
   to Partial. Checkpoint review `item-7-1-review.md` (Fable): Ready, 3 major
   and 9 minor fixed, among them the merge-recovery scope (the partial update
   is the harness-mounted case; a sibling-worktree merge aborts cleanly) and a
   misattributed `just evals`.
2. 📝 readonly-path verdict rework (see below), with the new suite
   `tests/verdict-premises.bats`.
3. 📝 Item 7.2 — `README.md`, MIT `LICENSE`, `CLAUDE.md` body; FR-9 Done.

Uncommitted, held by the gitlore memory gate (see Open gate): the memory
retirement (`memory/ddaanet/sandbox-effects.md` down to its context paragraph
and the zellij section; both index lines), FR-10's status, the changelog entry,
the design Status line, and the Phase 7 corrector's fixes to `CLAUDE.md` and
`tests/verdict-premises.bats`. `plans/sandbox-lies/reports/phase-7-corrector.md`
is staged. The gate refuses every parent commit while memory is dirty, so this
report is uncommitted too.

**Verdict rework.** The premise test ran first: git refuses a fast-forward
re-run over a file already at the target, and over an added file already
written untracked, and the restored tree re-runs cleanly (3 cases; red proven
by removing the partly-applied writes). Then the wording:

- `writable` tail: "If a merge or checkout died, files it wrote sit at the
  target, HEAD unmoved, blocking a re-run: restore them from HEAD once they
  match the target. Then re-run the whole call unsandboxed or, if it only read a
  command-output file (a `*.log`), the command that wrote it. For
  `.claude/settings.json`, use the `update-config` skill." `nopath` reuses it.
- `nopath` human line: `read-only — probably the sandbox, path not checked`.
- Item 7.1 carry: `phantom-untracked` opens "The dotfile entries in this
  listing" in place of "The character-device entries" (a status lists names).

Phase 7 corrector (`phase-7-corrector.md`, Fable): Ready, 5 minor fixed, no
UNFIXABLE. Suite 196 → 199.

## Deviations

- **Memory retirement deferred** from Item 7.1's commit to one gated commit at
  the phase end, as in Phases 4 and 6. The skill and the memory sections
  coexisted from commit 1 until the gated commit.
- **FR-6 budget.** The brief's shape measured 480 characters; fitting 400 cost
  `dangerouslyDisableSandbox: true` → "unsandboxed", "such as a" → "(a …)", and
  "refused the write" → "refused it". `writable` stands at 397 with the "The
  path" subject.
- **No per-item review** of the verdict rework and Item 7.2: the Phase 7
  boundary corrector, dispatched right after, reviewed both in full.
- **Agents unnamed**: teammates cannot name the agents they spawn. Neither
  corrector delivered a hand-back; their report files were read.

## Findings worth my human partner's attention

- **Item 8.2 is deferred by its own runbook condition.** It runs only when the
  memory file holds only its context paragraph; the zellij section (a stayed
  candidate) keeps it alive. The parts not depending on the deletion — the
  `shared-claude.md` repoint, `## Now`, the "Phase 6 step" phrase, the six
  inbound links — could still run.
- **`shared-claude.md`'s phantom bullet now points at the wrong place**: it
  says `sandbox-effects` has the mask mechanism, which this retirement moved to
  the skill (`references/masks-and-gates.md`). Left for Phase 8 as the carry
  list routes it.
- README's clone URL is the `plugin.json` homepage; the repository has no
  remote yet.

## For the run summary at Finish

- Two correctors, both Fable (one rung above the Opus drafter), both Ready.
- The gitlore gate blocks every parent commit while memory is dirty, including
  commits that do not stage memory: plan the retirement edits last.

## Gate: gitlore memory approval — closed

My human partner approved the summary as written (relayed by the team lead).
The approved summary:

> Retire the sandbox-effects sections the sandbox-lies skill now carries
>
> **Reduce ddaanet/sandbox-effects:** the file keeps only a context paragraph
> and the zellij section. Everything else moved into the sandbox-lies plugin's
> `sandbox-lies:sandbox-lies` skill: the baseline exclusions and the CC 2.1.281
> finding that `excludedCommands` is not honoured; mask visibility and the
> `touch /tmp` test; the zero-byte mask shape; the porcelain cleanliness gate;
> the `!`-expansion path no hook sees; merge recovery with its
> `git reset --hard` fallback; the escapes, strict mode and the
> read-only-inspection default; `$TMPDIR` instability; the classifier's refusal
> of benign compounds and the rule that a recipe must run entirely unsandboxed;
> `excludedCommands` whole-call semantics and why `git:*` replaced a rewriting
> hook; `ps` blindness to background tasks; multi-turn `--resume` flows with the
> eval-harness signatures; and sandboxed `claude -p` dropping every
> `SessionStart` hook. The symptom table went with its rows. zellij stays
> because its detector remained a candidate. The description and both index
> lines now route zellij's "no active session" here and every other sandbox
> effect to the plugin by name.

Default: approve as written. On approval: write the summary (without the `>`
markers) to `/Users/david/code/sandbox-lies/.claude/gitlore-memory-message`,
then `just precommit` (own exit status), then commit with explicit pathspecs:
`CLAUDE.md docs/changelog.md docs/design.md memory tests/verdict-premises.bats
plans/sandbox-lies/reports/phase-7-corrector.md
plans/sandbox-lies/reports/build-phase-7.md`, subject "📝 Phase 7 — skill-mapped
memory retired; checkpoint corrector Ready".

## Resume

Hard context stop reached at the gate (about 200k tokens). Last commit: "📝
Item 7.2 — README, MIT LICENSE, and a CLAUDE.md body for agents working here".
Slice step: Phase 7 boundary, corrector done; the gate was approved and the
gated commit carries this report.
Decisions given: the lead's verdict-rework defaults (no override arrived).
Carry: the gated commit above, then verify-step, then stop at the Phase 8
boundary.

## Phase 8 boundary resume block

```text
Resume /build at Phase 8 of /Users/david/code/sandbox-lies/plans/sandbox-lies/runbook.md.
Phase 7 closes with the gated commit "Phase 7 — skill-mapped memory retired; checkpoint corrector Ready" (see plans/sandbox-lies/reports/build-phase-7.md, Open gate).
Build baseline: .git/build-baseline. verify-step: /Users/david/.claude/plugins/cache/ddaanet/edify/0.3.0/skills/build/scripts/verify-step.sh (run unsandboxed).
Item 8.1 dogfood checks, beyond the runbook's: does `tmpdir-unset` ever fire on current CC (an unsandboxed call's $TMPDIR read /tmp on CC 2.1.281, not unset); how often `readonly-path` still yields `nopath`.
Item 8.2: its runbook condition defers it — memory/ddaanet/sandbox-effects.md keeps the zellij section (zellij-socket stayed a candidate). Ask whether to run the deletion-independent parts: repoint the memory/ddaanet/shared-claude.md phantom-dotfile bullet (it says `sandbox-effects` has the mechanism; the skill's references/masks-and-gates.md has it) and add its `!`-expansion clause; refresh docs/design.md `## Now` (its Next line predates Phases 6-7) and its Verified-against line; fix docs/references/detectors.md's "is a Phase 6 step" to Item 8.2; the six inbound [[sandbox-effects]] links. The /gitlore:push in 8.2 needs my human partner's confirmation relayed by the main session.
Sandbox facts (CC 2.1.281; version stamps from the transcript `version` field): git:* in excludedCommands is not honoured; a visible mask never proves which call was sandboxed; the mask-free test is `touch /tmp/<name>`.
The gitlore pre-commit gate refuses every parent commit while memory is dirty: make memory edits last in a phase.
Sizes: docs/design.md 397/400; docs/references/detectors.md 339; skills/sandbox-lies/SKILL.md 147/200. Splitting any doc past 400 lines is authorized (craft:design-doc-writing; record in docs/changelog.md).
```

## Context usage

About 200k tokens of this delegate's own context at the close.
