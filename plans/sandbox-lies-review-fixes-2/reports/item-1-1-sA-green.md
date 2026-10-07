# Item 1.1 Slice A — GREEN report

Implementation: `probe_resume_lost` in `lib/probes.sh` (ids from refusal
lines by `sed -nE`, glob `<root>/projects/*/<id>.jsonl` with `[ -f ]`, root
`${CLAUDE_CONFIG_DIR:-$HOME/.claude}`; comment states the archived/subagents
residual) and the `[ "${1-}" = lost ] || return 0` guard in
`verdict_resume_lost` (`lib/verdicts.sh`). Text unchanged; no `found` text,
gate and header comment untouched.

## Order made green

The probe was written whole (its ten cases share one mechanism), then the
verdict guard; suites run per file.

1. `tests/probes-resume.bats`: 10 passed (found, partial lost both
   orientations, unrelated id, id outside refusal, directory, archived,
   fallback to HOME, HOME not read, BSD found).
2. `tests/hook-resume.bats`: 3 passed (case 1 needed the verdict guard).
3. `tests/verdicts.bats`: 9 passed (the `-` case needed the guard).
4. `tests/hook-candidates.bats`: 13 passed.

## Full suite and gate

`just precommit` (unsandboxed, foreground): exit 0; 323 bats passed, 0
failed; plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits,
links, tests passed. No warnings reported.
