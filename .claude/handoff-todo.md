## Open decisions

- FR-10 in `docs/design.md` now reads `Done (prose)`, the legend's status for a requirement no test or gate re-checks. That reverses the `Done` the outline asked for and was an agent default, never confirmed. Keep it, or put `Done` back.
- The `partial=1` gate in `lib/probes-readonly-facts.sh` matches git's phrases anywhere in the text, so a `cp` refusal whose quoted path holds one prints wrong `merge=1`/`partial=1` facts (never a wrong `readonly`/`writable` outcome). Anchor it per line and amend the whole-text contract in `docs/references/readonly-path.md`, or leave it. Recommendation given: anchor, as a separate change after the release.
- `inbox/brief-excluded-commands-every-segment.md` is untracked and unread by this work: decide whether it is taken up, and whether it blocks the release.

## Remaining

- Run `/gitlore:push`.
- Run `/ddaa:preflight` and resolve what it reports.
- Push the repo to `origin`, then cut the release.