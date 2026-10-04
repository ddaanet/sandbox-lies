# Item 2.3 — curly-quoted and tab-indented matcher inputs

## Cases added

`tests/matchers-edges.bats` (166 -> 199 lines), new section "FR-7: curly quotes, tab-indented names":

- "tmpdir-unset fires on a GNU refusal with the path in curly quotes" — path
  `/a` between U+2018/U+2019 (spelled as bytes) after `cp: cannot stat`, message
  built from fragments; fires `tmpdir-unset`. Near-miss on `/a/b` stays quiet.
- "phantom-untracked fires on a long-format status block, tab-indented" —
  long-format `git status` block, three tab-indented masked names (`.bashrc`,
  `.claude/skills/` with trailing slash, `.gitconfig`); fires
  `phantom-untracked`. A one-name block stays quiet (threshold).

No BSD-stub case of its own; the existing "a near-miss pair survives BSD grep
and sed" is the BSD case.

## Faults (scratch copy under /tmp/claude-1000/sl/scratch-2-3, deleted)

Each alone, in the copy's `lib/matchers.sh`.

- Fault A, curly quotes dropped from `match_tmpdir_unset` alternation. Red:
  tmpdir-unset fires on a GNU refusal with the path in curly quotes (failing
  `assert_verdict tmpdir-unset`: want [tmpdir-unset] got []). Only that test.
- Fault B, `|[[:space:]]+` dropped from `match_phantom_untracked`. Red:
  phantom-untracked fires on a long-format status block, tab-indented (failing
  `assert_verdict phantom-untracked`: want [phantom-untracked] got []). Only that
  test.

On the real tree all 11 cases in the file are green.

## Gate

`just precommit` exit 0: precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests (bats: 260 passed, 0 failed).
