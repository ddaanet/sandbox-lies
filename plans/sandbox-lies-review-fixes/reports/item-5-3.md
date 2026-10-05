# Item 5.3 — comments and help text

Executed in session by the orchestrator (four comment-only edits and one `just`
attribute; no behaviour change). Review falls to the Phase 5 corrector.

- `lib/matchers.sh`: header now says these are the shipped matchers, one per
  detector, pointing at `docs/references/detectors.md`; the comment above
  `match_phantom_chardev` drops the `CLAUDE_PROJECT_DIR` anchoring claim
  (nothing reads that variable) and names the `ls -la /dev` false positive as an
  accepted residual that `detectors.md` records.
- `lib/probes.sh`: the header's probe contract gains `tool_input.command` as
  `$3`, read by `probe_readonly_path` only.
- `hooks/annotate.sh`: the header no longer says nothing reaches stderr; it says
  so only while `jq` is on `PATH`, that without it bash prints a
  command-not-found line there, that the hook still exits 0 so Claude Code
  ignores it, and that `hooks/check-jq.sh` reports the missing `jq` at session
  start.
- `justfile`: `precommit` carries
  `[doc('Checks that run before every commit.')]`; `just --list` now shows that
  sentence. The comment above keeps the `report` mechanism.

`just precommit` exit 0 (plugin.json, hooks.json, shellcheck, bash -n, rumdl,
line limits, links, tests).
