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
  `check-frontmatter`. `check-refs` and `check-size` read `TASK.md` and
  `TODO.md`; `check-frontmatter` reads only skills, agents and commands. It then
  runs `just task-files` (the matchers and the link check over `TASK.md` and
  `TODO.md` alone, never cached) and two independent sentinel gates, each
  printing `cached` while its inputs are unchanged. `gate-docs` parses
  `plugin.json`, runs the rumdl wrap check, the link check and `tests/docs.bats`
  over every tracked top-level entry that is not a code dir (derived from the
  index, so a new one needs no edit). `gate-code` parses `hooks.json`, runs
  shellcheck, `bash -n`, the Python compile check and every other bats suite
  over `lib hooks scripts bin tests plugin-dev`. A tracked shell file outside
  the code dirs fails `gate-docs`, since no gate lints it. A prose-only commit
  pays for `gate-docs` alone and a code-only one for `gate-code` alone; a file
  one gate's checks run from a code dir (`lib/matchers.sh`,
  `scripts/check-links.sh`) reruns both. Neither reads `TASK.md` or `TODO.md`,
  so editing either leaves both passes standing. `just test` runs every suite,
  `tests/docs.bats` too. `just format-docs` re-wraps markdown. After an `.envrc`
  edit, run it as `direnv exec . just precommit` until direnv is re-allowed.
- **No live file may fire a detector.** The matchers run over every tracked file
  except two exemptions: `tests/fixtures/`, and three dated pilot files under
  `plans/`. `tests/docs.bats` sweeps the files outside the code dirs and
  `tests/sweep-code.bats` those under them; `tests/helpers/sweep.bash` holds the
  one predicate that splits them. `TASK.md` and `TODO.md` are skipped there
  because `just task-files` covers them. Describe a diagnostic instead of
  quoting it with its follow-on text; a test that needs the text builds it from
  fragments at run time.
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
