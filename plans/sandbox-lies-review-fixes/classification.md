# Classification — sandbox-lies-review-fixes

Input: `plans/sandbox-lies/reports/deliverable-review.md` (implicit bundling: a
deliverable-review finding list) plus the scope and decisions my human partner
fixed at dispatch. Each item classified on its own; the job routes as its
highest item.

## Per item

| Item | Behavioural code | Class | Work type | Destination |
| --- | --- | --- | --- | --- |
| Major 1 — `excludedCommands` semantics in skill and docs | No | Moderate | Production | agentic-prose |
| Major 2 — missing `jq`: `SessionStart` check + README | Yes (new hook script, `hooks.json` entry) | Moderate | Production | production |
| Major 3 — FR-3 runtime-failure tests | No (tests only) | Simple | Production | production |
| Major 4 — NFR-4 writes-nothing pins on the probe path | No (tests only) | Simple | Production | production |
| Major 5 — two matcher sub-shapes without a fire case | No (tests only) | Simple | Production | production |
| Major 6 — readonly-path fact-table pins | No (tests only) | Simple | Production | production |
| m-2 — `readfile=` takes non-input words | Yes (changed logic path) | Moderate | Production | production |
| m-3 — `match=` names top-relative, printed bare | Yes (changed logic path) | Moderate | Production | production |
| Stale comments and help text (4) | No | Simple | Production | production |
| Docs against code or behaviour (13, minus Unchosen host) | No | Simple | Production | investigation |
| Tests group m-1..m-5 | No (tests and a test helper stub) | Simple | Production | production |
| Tests group m-6 (Linux-only suite) | — | Deferred: portability work | — | — |
| `detectors.md` §readonly-path split (forced: file at 399/400) | No | Simple | Production | investigation |

## Job classification

- **Classification:** Moderate
- **Implementation certainty:** High — every fix names its site; the two
  contract choices (m-2's operand rule, m-3's name form) are stated in the
  outline with defaults for my human partner's review.
- **Requirement stability:** High — scope and the two design decisions (Major 1
  rule, Major 2 mechanism) were fixed by my human partner at dispatch.
- **Behavioral code check:** Yes — Major 2, m-2, m-3 add or change logic paths →
  Moderate minimum.
- **Work type:** Production
- **Artifact destination:** production (mixed with agentic-prose and docs)
- **Evidence:** the review's per-finding file:line sites; `build-finish.md`
  §Carry-forward (line caps on `detectors.md` and `design.md` force a split);
  recall: `audit-a-contract-across-its-surfaces` (Major 1 spans skill, docs and
  probe text), `hook-output-channels` (Major 2 wording),
  `reflow-joins-field-lines` (item field lists as nested lists).
