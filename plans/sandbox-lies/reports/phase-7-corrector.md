# Review: Phase 7 boundary checkpoint

**Scope**: committed changes `c156a96..HEAD` (Items 7.1 and 7.2, the
`readonly-path` verdict rework, the `phantom-untracked` opening) and the
uncommitted memory retirement (`docs/changelog.md`, `docs/design.md` FR-10,
`memory/MEMORY.md`, `memory/ddaanet/MEMORY.md`,
`memory/ddaanet/sandbox-effects.md`). Phase 8 files reported on, not edited.
**Date**: 2026-09-26
**Mode**: review + fix. Nothing committed; nothing staged.

## Verdict

**Ready.** Five minor findings, all fixed. No critical or major issues. No
UNFIXABLE items. After the fixes: `rumdl fmt` re-wrapped two paragraphs;
`direnv exec . just precommit` exit 0 — `plugin.json, hooks.json, shellcheck,
bash -n, rumdl, line limits, links, tests` (199 bats passed);
`docs/design.md` 397 lines.

## 1. Verdict rework

**Text agreement.** The `writable` paragraph and the `nopath` human line are
byte-identical across `lib/verdicts.sh`, the `detectors.md` Verdicts list, and
`tests/verdicts.bats`'s transcription (`readonly_path_tail`); the
`hook-candidates.bats` substrings (`restore them from HEAD once they match the
target`, both human lines) match. The `verdicts.sh` header comment and the two
test comments say `"If a merge"` where the doc defines `nopath`'s tail from.
`phantom-untracked`: `verdicts.sh`, the doc's "opening 'The dotfile entries' in
place of 'The character-device entries'" definition, and the test's
`${chardev_para/#The character-device entries/The dotfile entries}` derivation
(with a non-identity guard) agree.

**FR-6.** Lengths before interpolation, measured with no probe lines on stdin:
`writable` 397, `readonly` 176, `nopath` 389, `phantom-untracked` 374. The
suite's `verdicts under 400 chars` covers all three `readonly_path` rows.
`writable` is three characters under the cap: any further wording change to
the shared tail must be measured.

**D-7 — no removal instructed.** The merge clause reads "files it wrote sit at
the target, HEAD unmoved, blocking a re-run: restore them from HEAD once they
match the target." `restore … from HEAD` is a checkout, not a removal; the
untracked files a target adds are not mentioned, and `detectors.md` says so
explicitly ("removes nothing … left to the skill's recovery procedure"). The
command-output-read clause and the `update-config` sentence are kept.

**Order of acts as hook context.** State (files at target, HEAD unmoved) →
consequence (re-run blocked) → guard (once they match the target) → act
(restore from HEAD) → act (re-run the whole call unsandboxed, or the writing
command for a command-output read). One reading per clause; "it" in "refused
it" and "it only read" resolves to the write and the call respectively. The
conditional "If a merge or checkout died" leaves the "Then re-run" sentence
applying to the non-merge case too, as the previous wording did.

**Skill consistency.** `SKILL.md` "Recovering a merge a sandbox refusal
killed" states the same tree state, adds `git checkout <branch>` as a second
trigger, the untracked-file removal (permitted in the skill; D-7 governs
verdicts), the `git diff <target> -- <file>` guard command, and the
`reset --hard` fallback. Nothing in it contradicts the verdict.

**`tests/verdict-premises.bats`.** Mutation re-run: with the three
partly-applied writes replaced by `:`, all three tests fail on their
assertions — tests 1 and 2 because the fast-forward succeeds (`status` 0),
test 3 because its `git diff --quiet "$TARGET" -- a.txt` guard finds `a.txt`
still at base. Restored byte-exact (`git diff --stat` empty), then the suite
passed 3/3. Test 3 is the paired positive proving the fixture's only difference
from a clean fast-forward is the partly-applied state, so tests 1 and 2 red for
the premise and not for an unrelated refusal. The header comment attributes
the untracked-file case to the skill, matching `detectors.md`. Conventions
match the other suites (`bats_require_minimum_version 1.5.0` in 15 of 19,
`load helpers/bsd-stubs` in all 19).

## 2. Item 7.2

**README.** Describes annotation over command matching, the probe step, and
the never-block/never-rewrite/never-unsandbox contract (D-1, D-2). Install is
the `--plugin-dir` route with the reason stated; `.gitmodules` carries
`url = ./.git/gitlore-placeholder`, so the marketplace-abort claim holds. Nine
detectors listed, matching the nine `verdict_*` functions and the five
`Decision: ships` entries plus the four pilot detectors in `detectors.md`
(`zellij-socket` stays a candidate and is absent). Each one-liner matches its
`detectors.md` verdict: lock outcomes `mask`/`gone`/present with or without a
holder; `tmpdir-unset` "unsandboxed call … collapsed to `/`"; `resume-lost`
"transcript … never let persist"; `seccomp-init` "failing to start". Links to
`docs/references/detectors.md`, `docs/design.md`, `docs/references/hook.md`
and `LICENSE` all resolve (the link check passes). The skill paragraph names
`sandbox-lies:sandbox-lies` and the four authoring moments of the description.

**LICENSE.** MIT text verbatim, `Copyright (c) 2026 David Allouche`.

**CLAUDE.md.** Every claim checked against the repository: `hooks/annotate.sh`
exists; `just precommit` and `just format-docs` are recipes; `tests/docs.bats`
exempts `tests/fixtures/` and the three dated `plans/` files by name;
`tests/extract-fixtures.py` has `SPEC`; `tests/helpers/bsd-stubs.bash` defines
`make_bsd_stubs`; the `@memory/ddaanet/shared-claude.md` line is last. One
inaccuracy fixed (finding 2).

## 3. Memory retirement

`memory/ddaanet/sandbox-effects.md` now holds frontmatter, one context
paragraph and the zellij section — the runbook's post-state. Every removed
paragraph has a home; checked against the translation map and the file
bodies: baseline and CC 2.1.281 non-honouring → `excluded-commands.md`; mask
shapes, porcelain gate, `!`-expansion → `masks-and-gates.md` and the hub;
interrupted merge → hub; escapes, strict mode, read-only default, `$TMPDIR`,
cost 2, cost 3 → hub and `escapes-and-costs.md`; `excludedCommands` semantics
and the hook rationale → `excluded-commands.md`; `ps` → hub; multi-turn
`claude` and `claude -p` → `recipes-and-claude.md`. The symptom table went
with its rows (one section needs no map). Index lines in `memory/MEMORY.md`
and `memory/ddaanet/MEMORY.md` and the frontmatter `description` are
identical; the line carries the literal a session arrives holding (`"no active
session"`) and routes every other symptom to the plugin by name. No volatile
git state. One deictic fixed (finding 1).

## 4. Design and changelog

FR-9 `Done`, pinned by the skill file and `tests/docs.bats`: accurate. FR-10
`Partial (every section retired but zellij …; file deletion: Item 8.2)`:
accurate. The header `**Status:**` line omitted the skill (finding 3). The
changelog entry is accurate for the skill, the retirement and the three verdict
changes; it omitted Item 7.2 (finding 4). `docs/design.md` is 397 lines after
the edit and re-wrap.

## 5. Shipping hygiene

Grep over `skills/`, `README.md`, `CLAUDE.md`, `LICENSE`: no
`FR-n`/`NFR-n`/`D-n`/`L-n` ids, no `/Users/`, no `~/code/`, no `[[wikilink]]`,
no `Phase N`/`Item N.M`/`runbook`/`outline`, no second-person `you`/`your`.
Hub 147 lines, references 50–109.

## Findings

### Minor

1. **Deictic and pending framing in the memory context paragraph** —
   `memory/ddaanet/sandbox-effects.md`: "The zellij effect stays here: its
   detector is an unshipped candidate." `here` is on the memory-writing deictic
   list and "unshipped" is pending framing. **FIXED**: "The zellij effect has
   no detector; this file carries it."
2. **CLAUDE.md understates `just precommit`** — the recipe's first two checks
   are `jq empty` over `plugin.json` and `hooks.json`; the bullet listed only
   the six that follow. **FIXED**: "It parses the two JSON manifests, then runs
   shellcheck, …".
3. **Design `**Status:**` line predates the skill** — `docs/design.md:3-6`
   enumerated the built-and-tested components without the skill FR-9 now
   marks `Done`. **FIXED**: "… the `readonly-path` verdicts with the hook's
   call to their probe, and the skill." `**Verified against:**` still names
   `52e6dd8…` (2026-09-22); that re-verification is the final audit's, left.
4. **Changelog entry omits Item 7.2** — `docs/changelog.md` 2026-09-26 entry
   covered the skill, the retirement and the verdicts only. **FIXED**: one
   sentence naming `README.md`, the MIT `LICENSE`, the `CLAUDE.md` body and the
   `--plugin-dir` install with its reason.
5. **Premise test 2 asserts less than test 1** — `tests/verdict-premises.bats`
   "an added file already written is refused" checked exit status and HEAD but
   not that the refusal left the tracked files untouched, which test 1 does
   for `b.txt`. **FIXED**: added `[ "$(cat "$REPO/a.txt")" = 'a base' ]`.

### Judged acceptable, not changed

- **README clone URL.** `https://github.com/ddaanet/sandbox-lies.git` — the
  checkout has no remote and `gh repo view ddaanet/sandbox-lies` resolves
  nothing. The URL matches the committed `plugin.json` `homepage` and
  `repository` fields, so it is the recorded publication target rather than a
  README invention; releasing is out of the plan's scope. Worth a glance from
  my human partner at publication time.
- **`phantom-untracked` opening** "The dotfile entries in this listing are
  sandbox masks over dotfiles" repeats "dotfile"; the brief fixes the subject,
  the doc defines the paragraph by that substitution alone, and the test
  derives it the same way. Rewording would touch all three for style.
- **`writable` at 397 characters** — under the cap; noted above as the
  margin any future edit to the shared tail has.

## Phase 8 items this phase touched or left (reported, not edited)

- `docs/design.md` `## Now` **Next** still reads "corpus replay for the five
  candidate detectors; each shipped section leaves the memory file in the same
  commit" — done as of this phase; Item 8.2 rewrites it.
- `docs/references/detectors.md` Translation map still says the audit "is a
  Phase 6 step" (Item 8.2).
- `docs/design.md` `**Verified against:**` sha and date predate Phases 6–7.
- Nothing this phase made wrong in `.bin/claude`, `.envrc`,
  `memory/ddaanet/shared-claude.md`, the six `[[sandbox-effects]]` files,
  `tests/matchers.bats` or `tests/docs.bats`: the memory file still exists at
  its path, so the inbound links and the docs.bats pointer check are unchanged
  until Item 8.2 deletes it.

## UNFIXABLE

None.

## Files changed

- `/Users/david/code/sandbox-lies/memory/ddaanet/sandbox-effects.md` — context
  paragraph's last sentence (finding 1)
- `/Users/david/code/sandbox-lies/CLAUDE.md` — precommit bullet (finding 2);
  re-wrapped by `rumdl fmt`
- `/Users/david/code/sandbox-lies/docs/design.md` — `**Status:**` line
  (finding 3)
- `/Users/david/code/sandbox-lies/docs/changelog.md` — 2026-09-26 entry, one
  sentence appended (finding 4); re-wrapped by `rumdl fmt`
- `/Users/david/code/sandbox-lies/tests/verdict-premises.bats` — one assertion
  in test 2 (finding 5)

`tests/verdict-premises.bats` was also mutated for the red check and restored
byte-exact before the edit above. Gate log: `/tmp/claude/phase-7-pc.out`.
