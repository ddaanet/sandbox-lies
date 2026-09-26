# sandbox-lies

A Claude Code plugin: `hooks/annotate.sh` annotates Bash results the command
sandbox distorts, and `skills/sandbox-lies/` carries what has no symptom in the
output. Design and per-detector mechanism: `docs/design.md`, `docs/references/`.

- **Run `just precommit` before every commit** and read its own exit status. It
  parses the two JSON manifests, then runs shellcheck, `bash -n`, the rumdl wrap
  check, the line caps, the link check and the bats suites. `just format-docs`
  re-wraps markdown. After an `.envrc` edit, run it as
  `direnv exec . just precommit` until direnv is re-allowed.
- **No live file may fire a detector.** `tests/docs.bats` runs the matchers over
  every tracked file outside `tests/fixtures/` and three dated pilot files under
  `plans/`. Describe a diagnostic instead of quoting it with its follow-on text;
  a test that needs the text builds it from fragments at run time.
- **Fixtures come from the cutter, never by hand.** Every `fire-*` and `quiet-*`
  file under `tests/fixtures/` is a recorded tool result cut by
  `tests/extract-fixtures.py` from the transcript corpus; add a `SPEC` entry and
  cut it, since a hand-written fixture encodes what the output was expected to
  look like.
- **Every new bats file loads `helpers/bsd-stubs`**, and a suite exercising
  shell code keeps one case re-run with `make_bsd_stubs` on `PATH`.

@memory/ddaanet/shared-claude.md
