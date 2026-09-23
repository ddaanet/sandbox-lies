# Simplification Report

**Runbook:** plans/sandbox-lies/runbook.md
**Date:** 2026-09-23

## Summary

- Items before: 22. Items after: 19. Three items were removed by
  consolidating one pattern.
- Lines before: 681. Lines after: 669. The runbook is still over the
  400-line soft cap. What is left is item-specific substance: interfaces,
  slices with stated assertions, and the corrector's stop conditions. No
  other genuine redundancy was found, so none was cut to reach a number.
- Self-quiet: `bash plans/sandbox-detector-pilot/matchers.sh` over the
  edited runbook printed nothing and exited 1, meaning no detector fired.
- Nothing is committed. The only file edited is the runbook.

## Consolidations Applied

### 1. Verdict-only candidates, Items 4.2–4.5 → Item 4.2

- **Type:** identical-pattern.
- **Items merged:** 4.2 `tmpdir-unset`, 4.3 `resume-lost`, 4.4
  `zellij-socket`, 4.5 `seccomp-init`.
- **Result:** Item 4.2, "the four verdict-only candidates". It has one
  row per detector with six columns: flag policy (each detector's original
  wording, kept verbatim), fires-with flag, silent-with flag, context
  substring, and the memory deletion (including the skill-mapped
  exceptions). It has two slices, and each case runs once per shipped row.
- **Rationale:** the four items had the same targets, the same
  dependencies (3.2, 4.1), the same requirements, and the same two-slice
  shape, which was already written as "as Item 4.2 slice 1 for X". Only
  the data differed. Every original assertion is still there as a
  parametrized case: fire fixture yields exactly the detector, quiet
  fixture yields nothing, context substring when the flag fires it, empty
  stdout otherwise.
- **Kept per candidate:** each candidate is still built only if it ships.
  The Phase 4 preamble now says that a candidate that stays gets no code
  and keeps its memory section, and that an item with no shipping
  candidate is skipped whole. The red flip, the corpus re-run and the
  verdicts.bats row are still required for each shipped candidate.
- **Follow-on edits:**
  - Items 4.2–4.5 are now Item 4.2. Old Item 4.6 (readonly-path matcher
    and probe) is now Item 4.3, with its content unchanged.
  - References updated to match: the cross-cutting Retirement list, the
    Item 2.3 `verdicts.bats` interface, Item 3.2's text and interface, the
    Phase 4 preamble, Item 5.1 `Depends on` (now Item 4.3), and Item 7.1
    (the remainders source and `Depends on`).
- **Phase 4 preamble:** the per-item rules now live in Item 4.2. What stays
  in the preamble applies to both 4.2 and 4.3.

## Patterns Not Consolidated

- **Items 2.1 and 2.2 (check-line-limits, check-links).** These are
  separate scripts with separate suites and four slices each. Merging them
  would make an eight-slice item spanning two components, a god item.
  Their shared fixture setup is already written once ("fixture roots as in
  Item 2.1").
- **Items 3.1 and 5.1 (live reproductions).** They are in different
  phases, and FR-4 requires each one to come before the verdict it gates.
- **Item 4.3 (readonly-path) with Item 4.2.** 4.3 has a probe, different
  targets and an extra dependency (2.4), and Item 5.1 consumes it.
- **Item 6.1 with Item 4.2.** It is in a different phase and has a
  three-outcome probe-driven verdict. It is gated by 5.1.
- **"Runs only if `readonly-path` ships" in 5.1 and 6.1.** Moving this into
  a preamble would save no lines.

## Requirements Mapping

I checked the table against each item's `Requirements:` line in both
directions, and checked every `Depends on:` target, using a script. The
final run reports no mismatches. All requirement IDs are mapped (FR-1 to
FR-11, NFR-1 to NFR-5, D-16), and every `Depends on:` target exists.

**Table rows changed by the renumbering:**

| Requirement | Items now |
|---|---|
| FR-4 | 2.4, 3.1, 4.1, 4.3, 5.1, 6.1 |
| FR-5 | 1.4, 2.3, 4.1, 4.2, 6.1 |
| FR-6 | 2.3, 4.1, 4.2, 6.1 |
| FR-7 | 3.2, 4.2, 4.3, 6.1 |
| FR-10 | 2.3, 4.1, 4.2, 6.1, 7.1, 8.2 |

**Mismatches that were already there before this pass, now fixed.** These
changes only affect traceability and are easy to revert.

- FR-1: the table row now includes 8.1, which already listed FR-1.
- FR-11: the row now includes 7.1 and 7.2, which already listed FR-11.
- FR-6: the table mapped it to 4.2–4.5, but those items did not list it.
  The merged 4.2 ships verdict text and now lists FR-6.
- NFR-1: the Phase 4 preamble (corpus re-run) and the corrector's coverage
  table both assign it to the candidate items, but neither the runbook
  table nor the items listed it. It is added to 4.2, to 4.3, and to the
  row.
- NFR-2: the table mapped it to 2.1 and 2.2, but their lines did not list
  it. Both items now list it.

**Open, not fixed:** the cross-cutting Portability rule requires one
`make_bsd_stubs` case per suite that exercises shell code. Items 2.1 and
2.2 name no such slice. Adding one would expand scope, which this pass
does not do. The cross-cutting rule still binds the executor. `/proof` may
want an explicit slice for each.
