# Recall artifact — sandbox-lies-review-fixes

Memory files (store root `memory/`):

- `memory/ddaanet/classifier-no-verdict-plugin-dir.md` — a Write/Edit in this
  checkout may return "gave no verdict": write through a Python script under
  `$TMPDIR`, not a heredoc. Every dispatch that writes carries this.
- `memory/ddaanet/hook-output-channels.md` — `systemMessage` vs
  `additionalContext`, the leading style reset (Item 4.3's `SessionStart`
  check).
- `memory/ddaanet/no-stderr-suppression.md` — `2>/dev/null` in new shell code is
  a finding to justify.
- `memory/ddaanet/cc-grep-shell-function.md` — a hand probe of `grep` in the
  Bash tool runs ugrep; probe with `command grep` when verifying a mutation by
  hand.
- `memory/ddaanet/reflow-joins-field-lines.md` — field lists in reflowed
  markdown are nested lists.
- `memory/ddaanet/audit-a-contract-across-its-surfaces.md` — Major 1 spans the
  skill, the docs and the probe text; read them against each other.

## Skills to load before executing

- `craft:test-discipline` — every test item (Phases 2–4).
- `shell-scripting:shell-gotchas` — any shell or bats edit.
- `craft:directive-writing` — Item 4.3's hook text and Item 5.1's skill prose.
- `plugin-craft:hook-authoring` — Item 4.3.
