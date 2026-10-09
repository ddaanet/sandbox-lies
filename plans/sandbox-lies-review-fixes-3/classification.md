# Classification — sandbox-lies-review-fixes-3

## Requirements-clarity gate

- **Requirements source:** the dispatch brief (my human partner's decided
  `printf %q` encoding and the open-item list), `.claude/handoff-todo.md`,
  `plans/sandbox-lies-review-fixes-2/reports/deliverable-review.md` and
  `deliverable-review-fixes.md`,
  `plans/sandbox-lies-review-fixes/reports/deliverable-review-code.md`,
  `plans/sandbox-lies/reports/build-finish.md` §Carry-forward, and the living
  `docs/design.md` FR/NFR set.
- **Completeness:** each item names a file:line site and a mechanism (Y). The
  NFRs it touches (NFR-2 portability, NFR-3 cost, NFR-4 hermetic, NFR-5 size)
  each carry a measurable criterion in `docs/design.md` (Y).
- **Routing:** proceed to triage. The five forks the first outline raised are
  answered by my human partner and folded into `outline.md`.

## Triage recall

Selected from the memory index: `harden-human-gates` (the probe-to-verdict
channel has a controlled producer), `guard-safety-visible-in-the-pattern` (the
`$'…'` grammar check), `audit-a-contract-across-its-surfaces` (the `path=`
contract spans probe, verdict and four docs), `jsonl-reader-type-guard` (m-9).
Nothing else matched.

## Multi-item decomposition

Trigger: implicit bundling (a carried finding list) plus explicit bundling (the
dispatch folds every open code item into one job).

| Item | Behavioural code | Class | Work type | Destination |
| --- | --- | --- | --- | --- |
| A. `path=` as `printf %q`, probe and verdict | Yes (encoder, decoder, guard removal) | Moderate | Production | production |
| B. Partial-checkout path from the worktree top | Yes (new resolution branch) | Moderate | Production | production |
| C. Phantom verdict wording | No (string change) | Simple | Production | production |
| D. m-1 tokenizer append | Yes (changed accumulation, same output) | Moderate | Production | production |
| E. Tests m-6 (suite on macOS) | No (tests only) | Simple | Production | production |
| F. m-7 line-cap coverage | Yes (one `case` arm) | Moderate | Production | production |
| G. m-8, m-9 Python tools | Yes (stale-file clearing, input guards) | Moderate | Production | production |
| H. `nopath` shapes | No (closed as a residual) | Simple | Investigation | investigation |
| I. Item 8.2 remainder | No (docs; one memory step for my human partner) | Simple | Investigation | investigation |

## Job classification

- **Classification:** Moderate.
- **Implementation certainty:** High. Every item reuses an existing seam: the
  A-3 probe contract, `_readonly_git_dir`, `_readonly_partial_checkout_text`,
  `index_mtime`, `utf8_locale`. The one new mechanism, the `%q` decoder, was
  probed on bash 5.2.37 and on a bash 3.2.0 built from GNU source
  (`evidence.md`).
- **Requirement stability:** High for every item. G and the Item 8.2
  disposition were forks; my human partner settled both.
- **Behavioural code check:** Yes (A, B, D, F, G), so Moderate is the minimum.
- **Work type:** Production.
- **Artifact destination:** production, with investigation-type doc edits.
- **Evidence:** per-item sites in `outline.md`; `docs/design.md` at 399/400
  lines, so every line it gains needs an offset; the bash 3.2.0 tokenizer
  timing (38.7 s on a 16384-character word), which moves D from a documented
  residual to a slice.

## Author-corrector coupling

Author change: none. No edify author skill is touched. Coupled corrector: none.
Update needed: no.
