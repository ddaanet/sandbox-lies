# Review gate — skill (Phase 6)

Reviewer: `plugin-dev:skill-reviewer` (fable, report-only, one rung above the
opus implementer). Scope: commit f5ddf6d, `skills/sandbox-lies/SKILL.md` and
the nodes `escapes-and-costs.md`, `excluded-commands.md`,
`recipes-and-claude.md`. The calling session wrote this report from the
reviewer's returned findings and applied the fixes.

Findings: critical 0, major 2, minor 6. All FIXED. No UNFIXABLE.

Scope completeness: m-2, m-3, m-4 and m-5 each have a deliverable. Hygiene: no
internal ids, no `plans/` or `memory/` paths, no quoted live diagnostic.
Frontmatter unchanged, so triggering is unchanged.

## Major

- **M1 — FIXED.** `escapes-and-costs.md` and `excluded-commands.md` said a
  command an allow rule covers "runs outside the sandbox without a prompt",
  which reads as a third way out of the sandbox and contradicts the hub's rule
  (a call runs unsandboxed only with the flag or an entry covering every
  command). Both now say such a command gets no prompt when it runs outside
  the sandbox.
- **M2 — FIXED.** `SKILL.md` §Writing a cleanliness gate said masks are
  reported as `??` "unconditionally", contradicted by the new `--ignored`
  finding (an ignored mask name shows only as `!!`). Now: masks the repository
  does not ignore are reported as `??`. The same wording in
  `masks-and-gates.md` was out of scope and is left as is: without
  `--ignored`, `??` is the only form a mask takes there, so it is not wrong in
  that file's context.

## Minor

- **m1 — FIXED.** `SKILL.md` §Writing an entry: "it" was ambiguous and the
  trailing "unless" read as qualifying the allow rule too. Split into two
  sentences, the server-side-review exception attached to the validator only.
- **m2 — FIXED.** `SKILL.md` working-directory paragraph: forfeiting shapes
  "cost a classifier call" now reads "absent an allow rule, cost a classifier
  call".
- **m3 — FIXED.** `excluded-commands.md` heading now "Observed on CC 2.1.289
  and 2.1.293".
- **m4 — FIXED.** `excluded-commands.md`: the uncovered form's `command` is
  explained (unwrapped for matching, so `true` alone makes it uncovered).
- **m5 — FIXED.** `SKILL.md`: "re-probe with a bare `git status --porcelain
  --ignored`" now "… alone in its call", since "bare" means "no arguments"
  elsewhere in the hub.
- **m6 — FIXED.** `SKILL.md` §Writing a recipe: the hub now carries the
  dropped-turn case (a turn on a persisted session answers but is dropped, CC
  2.1.292), not only the never-persisted case.

## Verification

- `just format-docs`, then `rumdl fmt --check`, `scripts/check-line-limits.sh`
  and `scripts/check-links.sh`: all passed.
- `SKILL.md` is at 200 lines, exactly its 200-line hub cap (196 before the
  fixes). No line was crammed to get there; the next addition to the hub must
  move detail to a node.
- `just precommit` runs before the commit carrying this report.
