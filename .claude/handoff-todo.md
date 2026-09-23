## Open decisions

- D-15 residual naming (Item 3.2): who may name a new false-positive class that lets a candidate ship? Default: a class not already listed as an expected residual in docs/references/detectors.md goes to my human partner before the candidate ships. Resolving it may amend D-15 in docs/design.md.
- Runbook length: 669 lines against the 400-line soft cap for plans; the overage is item-specific detail, not repetition. Default: accept, no split.
- Item 1.2 adds rumdl (uv sync venv via .envrc, never uvx) ahead of the line-limit gate — not in the outline, required by the shared conventions; reflow takes docs/design.md from 400 to 391 lines. Default: keep.
- Items 2.1 and 2.2 (check-line-limits, check-links) name no BSD-stubbed slice although the runbook's cross-cutting portability rule requires one per suite. Default: add one slice to each during proof.

## Remaining

- Run /edify:proof over plans/sandbox-lies/runbook.md, folding the open decisions above into the relevant items' verdicts, then batch-apply.
- Start /build on the proofed runbook in a fresh session.
- GITLORE_LAUNCHED was unset this session, so auto-memory writes go to ~/.claude/projects instead of the submodule: my human partner runs `direnv allow` or /gitlore:install-launcher and restarts.