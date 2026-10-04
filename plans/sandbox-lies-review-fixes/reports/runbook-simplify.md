# Simplification Report

**Runbook:** plans/sandbox-lies-review-fixes/runbook.md
**Date:** 2026-10-04

## Summary

- Items before: 15 (1.1; 2.1–2.5; 3.1–3.4; 4.1–4.3; 5.1–5.3)
- Items after: 15
- Consolidated: none. The runbook was not modified.

The runbook is already consolidated where the three patterns apply. Item 2.4
holds every unpinned fact-table member in one parametrized item, Item 4.1 holds
D4's four operand-rule slices, and Items 5.1 and 5.2 each hold all of their
prose artifacts. Every other pair either fits none of the three categories or
is blocked by a constraint.

## Consolidations Applied

None.

## Patterns Not Consolidated

- **Items 4.1 + 4.2** (tdd, Phase 4) are the strongest candidate. They have
  the same dependencies (Items 1.1 and 2.4) and the same requirement (FR-4).
  Both add cases to `tests/probes-readonly-members.bats` and both edit
  `readonly-path.md`'s Probe facts table. They were not merged for three
  reasons:
  - They are not a same-module pair. 4.1 changes `_readonly_readfile_arg` in
    `lib/probes-readonly-command.sh` (D4) and 4.2 changes
    `_readonly_repo_facts` in `lib/probes-readonly-facts.sh` (D3). These are two
    separate design decisions with separate review boundaries.
  - The merged item would carry about 17 assertions. 4.1's four slices have
    about 12, and 4.2's slice has about 5 new ones plus the absolute-form
    rewrite across three files. That is past the 8-assertion cap the cap rule
    would split back at, and it would split back along the same line.
  - Merging would save no red/green cycle, because every slice keeps its own
    RED either way.
- **Phase 2 pins (2.1–2.5)** were not merged. Each targets a different file:
  `hook-malformed`, `hook-writes`/`probes-edges`, `matchers-edges`,
  `probes-readonly-members` and `hook-candidates`. Each has a different
  requirement (FR-3, NFR-4, FR-7, FR-4, FR-5) and its own D5 fault set.
  - 2.1 and 2.5 are both hook pins, but they share no file and no assertion
    shape.
  - Merging any of these items would bundle unrelated fault-injection
    obligations into one red-evidence report and save nothing per assertion.
- **Phase 3 (3.1–3.4)** was not merged. The four items have distinct targets:
  the `paste` stub/shim, the gate exit-2 paths, the git-env helper and the
  probes-config positives. Their requirements are distinct too (D-16, NFR-5,
  NFR-2, FR-4).
  - Item 3.3 depends on Phase 2 (Items 2.2 and 2.4), so it can only take
    same-phase partners, and none of them shares its pattern.
- **Item 2.4 → 4.1** (both add to `probes-readonly-members.bats`), **Item
  1.1 → 5.3** (both edit `lib/matchers.sh` comments) and **Item 4.3 → 5.2**
  (both edit `hook.md`) were not merged. Each pair spans two phases, and 2.4/4.1
  and 4.3/5.2 also mix a general item with a tdd item.
- **Items 5.2 + 5.3** (general, Phase 5) were not merged because they are
  different kinds of work:
  - 5.2 is docs prose with dependencies on Phase 4.
  - 5.3 is code comments plus `justfile` help text, with no requirement and no
    dependencies.
  - The two items share no artifact.
  - Folding 5.3 into 5.2 would put independent hygiene work behind 5.2's
    dependency chain. 5.2 is already the largest item.

## Prose-artifact spread (not changed here)

Four prose artifacts are each edited by more than one item. None of these could
be fixed by a permitted merge, because each one crosses phases, mixes tdd and
general items, or both. I am reporting them, not changing them:

- `docs/references/readonly-path.md`: created by 1.1. The tdd docs halves of
  4.1 (`readfile=` row) and 4.2 (`match=` row) edit it, and so does 5.2 (`mv`'s
  `to`).
- `docs/references/hook.md`: 1.1 (the "read before" sentence), 4.3
  (`SessionStart` registration) and 5.2 (the D-1 pilot reading).
- `docs/references/detectors.md`: 1.1 (the move-out and stub) and 5.2
  (Conventions, Candidates, exclusion wording).
- `lib/matchers.sh` comments: 1.1 (repointing the readonly-path citation) and
  5.3 (header and the `CLAUDE_PROJECT_DIR` claim).

If the "one item per prose artifact" rule is meant to cover these artifacts,
moving content between items is a restructure, not a consolidation. The only
way to satisfy the rule would be to move 4.1's, 4.2's and 4.3's "Docs (same
item)" bullets into 5.2. That would separate each doc update from the GREEN that
makes it true. It is a call for the planner.

## Requirements Mapping

No changes: all mappings are preserved. I checked the table against the items:

- Every item's `Requirements:` line is in the table.
- Every id in Item 5.2's list (FR-1, FR-7, FR-8, FR-9, FR-11, NFR-1, NFR-2,
  NFR-4, NFR-5, D-12) appears in a 5.2 row.
- Items 1.1 and 3.2 map to NFR-5. The outline says FR-11, but `docs/design.md`
  defines NFR-5 as "Size and links" and FR-11 as "Self-quiet", so the runbook's
  mapping is the correct one.

Phase structure and X.Y numbering are intact, and there are no forward
dependencies:

- 3.3 depends on 2.2 and 2.4.
- 4.1 and 4.2 depend on 1.1 and 2.4.
- 5.2 depends on 1.1, 4.1–4.3 and 5.1.
