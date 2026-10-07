# Item 6.1 — skill: m-2, m-3, m-4, m-5

Edits are unstaged; nothing committed; `just precommit` not run (dispatcher's
step). Each of the four skill files took one edit pass, plus the changelog
append.

Skill loading: this agent has no Skill tool, so the bodies of
`craft:directive-writing` (craft 0.2.1) and `plugin-craft:skill-authoring`
(plugin-craft 0.1.3) were read from the plugin cache instead. Also read:
`memory/ddaanet/reflow-joins-field-lines.md`, the outline, the delegate-status
6.1 note, both evidence files, review findings m-2 to m-5 (and the prose-config
sub-report, the source of the two `!` cases and the allow-rule doc lines), and
the Phase 5 wording in `lock-detectors.md`, `detectors.md` §resume-lost,
`sandbox-state.md` and the last changelog entry. The m-4 probe was not re-run;
the CC 2.1.293 record in `m4-reprobe-evidence.md` was used.

## SKILL.md line count

- Before: 190.
- After `just format-docs`: 196 (cap 200).

## m-2 — strict mode ignores the flag; `!` sandboxed in two cases

- `skills/sandbox-lies/SKILL.md` §Leaving the sandbox: the bullet now reads
  "Strict mode ignores the per-call flag: the call still runs, sandboxed."
  Added: in a background session, and on Linux with
  `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB` set, a `!` command runs sandboxed too, so
  in those cases ask for the mode change.
- `skills/sandbox-lies/references/escapes-and-costs.md`: heading renamed to
  "Strict mode ignores the per-call flag". The body says CC ignores
  `dangerouslyDisableSandbox`: the call is not refused, it runs sandboxed, so
  what the sandbox permits still happens. A new paragraph names the two cases
  from the settings reference where a `!` command runs sandboxed too, and says
  to ask for the mode change there.

## m-3 — sandboxed turn on a persisted session (CC 2.1.292)

- `skills/sandbox-lies/references/recipes-and-claude.md` §Multi-turn: "(CC
  version not recorded)" is gone. Added: a sandboxed turn on a session whose
  transcript already exists is lost silently. It resumes and answers normally,
  but the turn is dropped and the transcript is unchanged afterwards. Both
  facts are marked verified on CC 2.1.292: the resume of a sandboxed session
  fails, and an existing session's sandboxed turn is dropped.
- The hub's "A sandboxed `claude --print` turn never persists its transcript"
  already covers the dropped-turn case, so it was left unchanged.

## m-4 — re-probe is `git status --porcelain --ignored` (CC 2.1.293)

- `SKILL.md` §Tell a sandboxed call, first bullet:
  - The observation now says "CC 2.1.289 and again on CC 2.1.293".
  - It names the uncovered form, the same status behind `true &&`, as the
    contrast that ran sandboxed and listed masks.
  - The re-probe is now a bare `git status --porcelain --ignored`. The reason
    given: without `--ignored`, a sandboxed listing leaves out every mask name
    the repository ignores.
- `SKILL.md`, second bullet: "no mask in a listing of the call's own working
  directory, ignored names included, proves the call ran unsandboxed". This is
  part of the cited `:22-29` range, and without the qualifier the one-way proof
  is what m-4 faults.
- `skills/sandbox-lies/references/excluded-commands.md` §Observed on CC
  2.1.289: the old re-probe paragraph is replaced by two paragraphs.
  - A CC 2.1.293 (2026-10-07) record of both forms:
    - the bare covered form listed the tree's ignored build directories as
      `!!` and no mask name;
    - the uncovered `true && command git status --porcelain --ignored`, shown
      sandboxed by a refused `/tmp/<name>` write in the same call, listed 20
      mask names as `??` and `.claude/settings.local.json` as `!!`.
    - That `!!` mask is the stated reason for the change: the repository
      ignores it, so a listing without `--ignored` leaves it out.
  - The re-probe instruction, with the one-way proof kept.
- `masks-and-gates.md` was checked and left untouched. Its `git status`
  statements are a 2026-08-16 observation and a "re-run unsandboxed" act. No
  re-probe claim there contradicts the change.

## m-5 — allow rules clear an unsandboxed command before the classifier

- `SKILL.md` §Writing an entry, last bullet: an allow rule covering the command
  clears it before any classifier call. So does the read-only validator for a
  bare read-only command from the original working directory. The server-side
  review caveat stays attached to the validator only.
- `SKILL.md` §Leaving the sandbox: "reaches the permission classifier unless an
  allow rule covering it or the read-only validator clears it".
- `escapes-and-costs.md` §Cost: the classifier.
  - The "unless" clause names the allow rule beside the validator.
  - The "Mitigation is shape, not settings" paragraph is rewritten. The
    documented mitigation is an allow rule. Per the sandboxing doc, a covered
    command runs outside the sandbox without a prompt, and a matching rule also
    approves the unsandboxed retry.
  - Allow rules are the human partner's settings, so the skill says to propose
    one rather than write it.
  - Without a rule, mitigation is shape, as before.
- `excluded-commands.md` §Approval: the section now opens "Two things clear it
  ahead of the classifier". The allow rule comes first (per the sandboxing
  doc), then the read-only auto-allow, whose text is unchanged. The classifier
  is reached only where no allow rule covers the command and the validator
  refuses it.

## Changelog

`docs/changelog.md`: one paragraph appended to the existing 2026-10-08 entry
("The skill follows: …"). It covers:

- the flag being ignored, and the two `!` cases;
- the allow rule, as what clears a command and as the mitigation;
- the `--ignored` re-probe, with CC 2.1.293;
- the dropped sandboxed turn, verified on CC 2.1.292.

No new entry.

## Consumer-text check

`rg` over `skills/sandbox-lies/` for internal ids (`m-N`, `D-N`, `QN`, `EN`),
`plans/`, `memory/` and "my human partner" found nothing (rg exit 1). No
diagnostic is quoted live. Refusals are described ("refused read-only", "the
read-only-filesystem error").

## Checks (foreground, one at a time)

1. `just format-docs`: exit 0. rumdl re-wrapped three paragraphs:

   ```text
   rumdl fmt -q --no-cache
   skills/sandbox-lies/SKILL.md:18:1: [MD013] Line length 81 exceeds 80 characters [fixed]
   skills/sandbox-lies/references/escapes-and-costs.md:52:1: [MD013] Paragraph could be normalized to use line length of 80 characters [fixed]
   skills/sandbox-lies/references/excluded-commands.md:138:1: [MD013] Paragraph could be normalized to use line length of 80 characters [fixed]
   ```

2. `rumdl fmt --check -q --no-cache`: no output, exit 0.
3. `scripts/check-line-limits.sh`: no output, exit 0.
4. `scripts/check-links.sh`: no output, exit 0.
5. `scripts/run-bats.sh tests/docs.bats`: exit 0.

   ```text
   bats: 2 passed, 0 failed
   ok 1 no tracked file outside the fixtures fires a detector
   ok 2 the matchers give the plain verdicts and refuse no BSD sed or grep call
   ```

## Tree state

`git status --short` shows the five edited files unstaged (` M`). The two
handoff files are still staged. The pre-existing untracked entries are
untouched. The listing also showed sandbox-mask dotfiles, which are not tree
content. No scratch directory was created.
