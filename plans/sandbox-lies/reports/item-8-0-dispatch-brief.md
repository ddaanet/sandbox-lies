# Item 8.0 dispatch brief

Shared context for every Item 8.0 slice dispatch (RED, test review, GREEN,
code review). Read it whole before the slice-specific prompt.

## Repository and rules

- Repository root: `/Users/david/code/sandbox-lies`. Start every shell command
  with `cd /Users/david/code/sandbox-lies &&` and use absolute paths. Never leave
  the shell cwd inside `memory/`.
- The item and its slices: `## Phase 8` → `Item 8.0` in
  `/Users/david/code/sandbox-lies/plans/sandbox-lies/runbook.md`. Read the item
  text and your slice verbatim there.
- Design: `/Users/david/code/sandbox-lies/plans/sandbox-lies/outline.md`, and
  `/Users/david/code/sandbox-lies/docs/design.md` FR-4, FR-5, FR-6, D-7, D-8,
  D-17.
- The spec the tests transcribe (committed): `docs/references/detectors.md`
  §readonly-path (Probe facts table, Verdicts, tail and merge clause),
  `docs/references/lock-detectors.md` §git-lock and §config-lock Verdicts
  (*Re-run*/*Retry* flag table, the config-lock settings act),
  `docs/references/hook.md` §Flow. Tests transcribe verdict text from these
  docs; they never parse the docs.
- Recall: Read
  `/Users/david/code/sandbox-lies/plans/sandbox-lies/recall-artifact.md`, then
  each file it lists. Skills it names that bear on this item:
  `shell-scripting:shell-gotchas`, `craft:test-discipline`,
  `craft:directive-writing` (load via the Skill tool, or Read the newest
  `~/.claude/plugins/cache/*/<plugin>/*/skills/<name>/SKILL.md`).
- Code under test: `lib/verdicts.sh`, `lib/probes-readonly.sh`,
  `hooks/annotate.sh`. Suites: `tests/*.bats`, helpers in `tests/helpers/`
  (`bsd-stubs.bash`, `hook.bash`). Constraints: bash 3.2, BSD
  grep/sed/stat (the suite re-runs under BSD stubs), `set -u` in lib files, no
  blanket `2>/dev/null`, whitespace-safe (NUL-delimited where lists of paths are
  read), `grep` typed in the Bash tool is ugrep — probe with `command grep`.
- Run tests in the foreground: `scripts/run-bats.sh tests/<file>.bats` for one
  file, `just precommit` for the full gate. Check `just precommit`'s own exit
  status; never chain it ahead of a commit.
- Git: commit with explicit pathspecs only. Forbidden: `git stash`,
  `git reset`, `git checkout -- <file>` on work in progress, `git add -A` or
  `git add .`, `--no-verify`, creating or switching branches or worktrees,
  pushing. Zero-byte or character-device dotfiles showing untracked in the root
  are sandbox masks: never delete, commit or report them.
- Sandbox: a sandboxed `touch /tmp/<name>` fails read-only; a scratch path for a
  test is `$BATS_TEST_TMPDIR`.

## Slice dispatch contract

- RED writes the slice's tests and proves each fails on its assertion against
  the unchanged code (or, where an earlier slice already implemented the
  behaviour, by one in-place mutation per test, restored by inverting the
  replacement and verified by grep plus a green run). RED commits nothing.
- Test review (corrector): scope is the slice's test files and the RED report;
  first check is mechanical — every listed test failed on an assertion or
  carries a mutation proof you reproduce with a different mutation; then hunt
  wrong-reason tests; fix tests, re-run to confirm still red. Commits nothing.
- GREEN makes the slice's tests pass one at a time, full `just precommit` green
  at the end, and commits once: tests, implementation, and the slice's RED,
  test-review and GREEN reports, staged by name. GREEN implements nothing the
  slice's tests do not demand — later slices must still be able to go red.
- Code review (corrector): scope is the implementation files of the slice;
  applies fixes; commits nothing.
- Every dispatch writes its report to the path its prompt names and replies with
  that path only, or `blocked: <reason>`.
