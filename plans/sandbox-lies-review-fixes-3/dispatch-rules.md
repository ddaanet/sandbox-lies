# Dispatch rules — sandbox-lies-review-fixes-3

Binding on every subagent of this build. The dispatching delegate cites this
file by path in each prompt.

## Repository and shell

- Repository: `/Users/david/code/sandbox-lies`. Start every Bash call with
  `cd "/Users/david/code/sandbox-lies" && ...`.
- Read `/Users/david/code/sandbox-lies/CLAUDE.md` and
  `/Users/david/code/sandbox-lies/memory/ddaanet/shared-claude.md` first and
  follow them.
- `git`, `find`, `ls` and `claude` are in `sandbox.excludedCommands`. A Bash
  call using any of them must set `dangerouslyDisableSandbox: true`; a
  PreToolUse hook refuses it otherwise. `just precommit` also runs
  unsandboxed.
- Scratch files go in your own `mktemp -d` under `$TMPDIR`. Clean up only that
  directory, never with a shared glob. `$TMPDIR` does not survive between Bash
  calls when one is sandboxed and the next is not: keep a scratch path in one
  call, or use `/tmp/claude/<your-dir>` made with `mkdir -p`.
- A hand probe of grep's behaviour uses `command grep`: the Bash tool's `grep`
  is a shell function running ugrep (`memory/ddaanet/cc-grep-shell-function.md`).
- If a `Write` returns "gave no verdict (it skipped this action)", write the
  file from a Python script saved under `$TMPDIR` and run with `python3`, never
  a heredoc (`memory/ddaanet/classifier-no-verdict-plugin-dir.md`).
- No new `2>/dev/null` without a written reason
  (`memory/ddaanet/no-stderr-suppression.md`).
- A markdown bullet holding one field per line is a nested list
  (`memory/ddaanet/reflow-joins-field-lines.md`).

## Tests

- **Memory:** about 2 GB of RAM. Run one test process at a time, always in the
  foreground: never `run_in_background`, never two suites at once. Run one
  file with `scripts/run-bats.sh tests/<file>.bats`, or `bats -f '<name>'
  tests/<file>.bats` for one case.
- Every new bats file loads `helpers/bsd-stubs`.
- **No live file may fire a detector** (`tests/docs.bats`). A tracked file
  holding a diagnostic line as it appears live (for example the `--resume`
  refusal at a line start) fails that suite. Read the text from a fixture file
  under `tests/fixtures/`, or build it from fragments at run time.
- **Fixtures come from the cutter** (`tests/extract-fixtures.py` `SPEC`), never
  by hand.
- `resume-lost` cases point `CLAUDE_CONFIG_DIR` (or `HOME`, with
  `CLAUDE_CONFIG_DIR` unset, for the fallback case) at a directory under
  `$BATS_TEST_TMPDIR`. No case reads the host's `~/.claude`.

## Evidence for each test

- A new test is evidence only when it fails on a failed **assertion** against
  the unchanged code. A test erroring because a function, file or probe does
  not exist does not count.
- For each test, name in your report the state of the world that fails it, and
  what else could produce what it checks. Rebuild the fixture until nothing
  else can.
- **Mutation proof**, for a test green on the unchanged code because the
  behaviour already exists:
  1. Mutate the subject in place by an exact string replacement, of a string
     that occurs once in the file.
  2. Prove the mutation landed (`command grep` for the new text).
  3. Run the test and show it red on its own assertion.
  4. Restore by applying the replacement with the strings swapped, never from
     a backup copy, `git checkout`, `git stash` or `git reset`.
  5. Prove the restore: `command grep` finds no mutation text, and the test is
     green.
  Use one mutation per test, and record each one in the report under a
  `Mutation proof` heading.

## Git

- Never create or switch branches or worktrees. Never `git stash`,
  `git reset`, `git checkout -- <file>`, `git add -A` or `git add .`.
- `.claude/handoff-todo.md` is modified and not this job's: leave it alone, out
  of every commit. Stage your own paths explicitly and commit with explicit
  pathspecs (`git commit -m … -- <path>…`).
- Do not touch the untracked `.claude/gitlore-memory-message`, `inbox/`, or any
  zero-byte or character-device dotfile (sandbox masks). Edit nothing under
  `memory/`. Never push.
- A committing dispatch runs `just precommit` (unsandboxed, foreground) and
  reads its exit status before the commit. Never `--no-verify`. If the gitlore
  memory gate blocks a commit, stop and report it; never write
  `.claude/gitlore-memory-message`.
- Out of scope always: `.gitlore/bin/claude`, `.claude/settings.json`.

## Report

Write your report to the path your prompt names, under
`plans/sandbox-lies-review-fixes-3/reports/`. Reply with one line: that path,
or `blocked: <reason>`.

## Added for this build

- **bash 3.2.0 build:** `/tmp/claude/bash32/bash` once the build dispatch has
  made it (rebuild recipe: `plans/sandbox-lies-review-fixes-3/evidence.md`).
  Use it for any behaviour the outline says to check on 3.2.
- **Suite split:** the recall artifact is
  `plans/sandbox-lies-review-fixes-3/recall-artifact.md`; Read it and each file
  it lists.
- **Tdd dispatches:** a RED dispatch commits nothing and leaves tests and its
  report in the tree. A GREEN dispatch commits the slice group with the RED,
  test-review and GREEN reports. A slice group is all of one Item's slices run
  together (recorded in `delegate-status.md`).
- **`docs/design.md`** sits at 399 of 400 lines: no edit may grow it.
