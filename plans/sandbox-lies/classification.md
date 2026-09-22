# Classification: sandbox-lies

- **Classification:** Complex
- **Implementation certainty:** Moderate — five matchers are measured over the
  transcript corpus and ship as is; the seven remaining conversions, the live
  probes and the hook wrapper are unbuilt and unmeasured.
- **Requirement stability:** High for the measured detectors (BRIEF.md fixes
  the contract, the channels and the hard constraints); Moderate for the
  conversions, the skill's home and the retirement sequence, which the brief
  leaves to the design.
- **Behavioral code check:** Yes — a PostToolUse hook, probe functions, seven
  new matchers. Moderate minimum; elevated to Complex by the open decisions.
- **Work type:** Production
- **Artifact destination:** production (`hooks/`, `lib/`, `tests/`),
  agentic-prose (`skills/`), investigation (`docs/design.md`)
- **Evidence:** BRIEF.md §Hard constraints and §The five phases;
  `plans/2026-09-03-sandbox-matcher-corpus-eval.md` §4 and §7;
  `memory/ddaanet/sandbox-effects.md` (12 sections, the source being
  translated); `plugin-craft:hook-authoring` §1–3 (channels, no tool
  injection, the redundant-verification cost of a user-only channel);
  `craft:directive-writing` (verdict wording).
