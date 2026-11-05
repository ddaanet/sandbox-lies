# sandbox-lies

A Claude Code plugin: `hooks/annotate.sh` annotates Bash results the command
sandbox distorts, and `skills/sandbox-lies/` carries what has no symptom in the
output. Design and per-detector mechanism: `docs/design.md`, `docs/references/`.
User documentation, shipped: `manual/`; a change to what a detector or the hook
does updates it there.

- **Run `just precommit` before every commit** and read its own exit status. It
  first runs the toolkit's uncached `check-refs`, `check-size` (20000 bytes a
  file, 10000 a `SKILL.md`; a file that cannot be split, such as a recorded
  fixture, is marked `linguist-generated` in `.gitattributes`) and
  `check-frontmatter`, which read every non-ignored file, `TASK.md` and
  `TODO.md` included. It then parses the two JSON manifests and runs shellcheck,
  `bash -n`, the rumdl wrap check, the link check, a Python compile check and
  the bats suites. `just task-files`, which `precommit` depends on and never
  caches, runs the matchers and the link check over `TASK.md` and `TODO.md`
  alone; the main gate does not read them, so editing either leaves its cached
  pass standing. `just format-docs` re-wraps markdown. After an `.envrc` edit,
  run it as `direnv exec . just precommit` until direnv is re-allowed.
- **No live file may fire a detector.** `tests/docs.bats` runs the matchers over
  every tracked file except two exemptions: `tests/fixtures/`, and three dated
  pilot files under `plans/`. `TASK.md` and `TODO.md` are skipped there because
  `just task-files` covers them. Describe a diagnostic instead of quoting it
  with its follow-on text; a test that needs the text builds it from fragments
  at run time.
- **Fixtures come from the cutter, never by hand.** Every `fire-*` and `quiet-*`
  file under `tests/fixtures/` is a recorded tool result cut by
  `tests/extract-fixtures.py` from the transcript corpus; add a `SPEC` entry and
  cut it, since a hand-written fixture encodes what the output was expected to
  look like.
- **Every new bats file loads `helpers/bsd-stubs`**, and a suite whose code
  under test calls a stubbed tool (`sed`, `grep`, `mktemp`, `stat`, `wc`) keeps
  one case re-run with `make_bsd_stubs` on `PATH`. The code under test is what
  the suite's assertions are about: a library it only runs to build its input
  (`verdicts*.bats` pipe text through `lib/matchers.sh`) is covered by its own
  suites.
- **Prospective content goes in `plans/`.** A brief arriving from a session in
  *another* repository goes in `inbox/`, never the repo root, where it reads as
  a tracked project document.

@memory/ddaanet/shared-claude.md
