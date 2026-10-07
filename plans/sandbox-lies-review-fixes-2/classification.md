# Classification — sandbox-lies-review-fixes-2

Input: `plans/sandbox-lies-review-fixes/reports/deliverable-review.md`. This is
implicit bundling: a deliverable-review finding list. The scope and the m-3
decision were fixed at dispatch. Each item is classified on its own, and the
job routes as its highest item.

## Per item

| Item | Behavioural code | Class | Work type | Destination |
| --- | --- | --- | --- | --- |
| m-3 code: `resume-lost` probe, verdict outcome, gate | Yes (new probe function, verdict branches on outcome) | Moderate | Production | production |
| m-3 docs: D-8, L-2, FR-4, NFR-4, `sandbox-state.md`, `detectors.md` | No | Simple | Production | investigation |
| m-11: glob or `$` operand gives a literal `readfile=` | Yes, if fixed (changed logic path); No, if documented | Moderate / Simple | Production | production |
| Major 1: trailing-slash pin | No (test only) | Simple | Production | production |
| m-14, m-16, m-18: test guards, spy, BSD-stub cases | No (tests only) | Simple | Production | production |
| m-15, m-17: helper comments | No | Simple | Production | production |
| m-9, m-10, m-13: name and comments | No | Simple | Production | production |
| m-12: `py_compile` step in `just precommit` | No (gate recipe line) | Simple | Production | production |
| m-1, m-6: design state layer, pinned-by lists | No | Simple | Production | investigation |
| m-2, m-4, m-5: skill accuracy | No | Simple | Production | agentic-prose |

## Job classification

- **Classification:** Moderate
- **Implementation certainty:** High.
  - The probe contract (A-3, FR-4) and the probe/verdict/gate seams already
    exist; the new probe is one more instance of them.
  - The empirical question m-3 left open is settled in
    `resume-probe-evidence.md`.
- **Requirement stability:** High. Scope and the m-3 remedy were fixed at
  dispatch. Four forks remain, each with a stated default: the flag policy, the
  `found` outcome, m-4 and m-11, and m-18.
- **Behavioral code check:** Yes. m-3 adds a probe and an outcome branch, and
  m-11 (if fixed) changes a logic path, so Moderate is the minimum.
- **Work type:** Production
- **Artifact destination:** production (mixed with agentic-prose and docs)
- **Evidence:**
  - the review's per-finding file:line sites;
  - `docs/design.md` at 399 of its 400-line cap, which forces an offset for
    every line the doc items add;
  - recall: `cc-project-dir-encoding` (search by id),
    `jsonl-sidechain-segregation` (`archived/` layout),
    `audit-a-contract-across-its-surfaces` (m-3 spans gate, probe, verdict and
    four docs), `reflow-joins-field-lines`, `no-stderr-suppression`.
