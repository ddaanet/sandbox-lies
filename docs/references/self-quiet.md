# Self-quiet

The argument behind `docs/design.md` D-10 and the files FR-11 exempts; read it
before adding text that quotes a diagnostic, or when `tests/docs.bats` or
`tests/sweep-code.bats` fires on a file.

## D-10 — Self-reference is handled at the document, not the matcher

Every false positive in the corpus is this project reading its own artefacts
back. The matchers do not special-case that: a command-text suppression would
need the fixture path, which is a convention a matcher should not know. Instead
the repository's live documents are constrained never to fire a detector
(FR-11), and two residuals are accepted by name: fixture reads, and the dated
pilot evidence under `plans/`, which quotes diagnostics verbatim and is frozen.
Accepted tradeoff: `cat tests/fixtures/fire-*.txt` or a read of the layer-2
report from inside this repo annotates itself.

## FR-11 — the exempt files

Two residuals are exempt by name: `tests/fixtures/`, and three dated pilot files
that quote live diagnostics (`plans/2026-09-02-sandbox-detector-replay.py`,
`plans/2026-09-02-sandbox-detector-hits.jsonl`,
`plans/2026-09-03-sandbox-matcher-corpus-eval.md`) (D-10).
