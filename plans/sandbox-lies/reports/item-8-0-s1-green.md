# Item 8.0 slice 1 — GREEN report

`lock verdicts word the re-run by the flag`. Implements `lib/verdicts.sh`
(`verdict_git_lock`, `verdict_config_lock`, `_verdict_lock_present` take the
flag as `$2`, absent reads `false`; two new helpers `_lock_rerun`/`_lock_retry`
carry lock-detectors.md's *Re-run*/*Retry* flag table; `verdict_config_lock`
mask reads stdin `path=` and swaps in the settings act for a
`.claude/settings.json.lock` path) and `hooks/annotate.sh` (passes `"$flag"`
as the probed verdict's `$2`). No test file edited. `verdict_readonly_path`,
the probes and `tool_input.command` are untouched (slices 2 and 3).

## Growth

The six failing tests all exercise one shared mechanism — the flag threaded
through `verdict_git_lock`/`verdict_config_lock`'s `mask`/`orphan`/`unknown`
branches and `_verdict_lock_present` — inside function bodies with no
intermediate state that passes one test while leaving the others red (e.g.
`mask`'s wording and `orphan`/`unknown`'s wording share the same two new
helpers). The mechanism was grown as one unit — signature change, the two
helpers, the mask/settings-act branch, the hook passthrough — then each test
was run individually, in this order, to confirm it passes:

1. `lock verdict text matches lock-detectors.md` (verdicts.bats) — pass
2. `verdict_git_lock held|orphan|unknown interpolate probe values`
   (verdicts.bats) — pass
3. `verdict_config_lock held|orphan|unknown interpolate probe values`
   (verdicts.bats) — pass
4. `lock verdicts word the re-run by the flag` (verdicts.bats) — pass
5. `mask paragraph words the re-run by the flag` (hook-locks.bats) — pass
6. `config-lock mask names config.lock and the settings act by path`
   (hook-locks.bats) — pass

Verified individually with `scripts/run-bats.sh tests/<file>.bats --filter
'<anchored test name>'`, one `bats: 1 passed, 0 failed` (or `2 passed` where
the filter, a regex, matched an unintended second case by substring — checked
by anchoring `^...$`) per test, no failures at any point.

## Full suite

- `scripts/run-bats.sh tests/verdicts.bats` — 12 passed, 0 failed.
- `scripts/run-bats.sh tests/hook-locks.bats` — 13 passed, 0 failed.
- `scripts/run-bats.sh tests/hook.bats` — 13 passed, 0 failed (regression
  check: readonly_path and other probed verdicts now receive an extra `$2`
  argument from the hook).
- `scripts/run-bats.sh tests/hook-candidates.bats` — 8 passed, 0 failed.
- `scripts/run-bats.sh tests/probes.bats` — 12 passed, 0 failed.
- `just test` (full suite) — 200 passed, 0 failed.

No regression at any point; nothing to fix one at a time.

## `just precommit`

`just precommit` stops at the `line limits` check:

```
oversized-file: tests/verdicts.bats: 468 lines > 400
```

`tests/verdicts.bats` grew from 318 to 468 lines in this slice's RED dispatch
(the row table, `text_lacks`, and the new/extended assertions this slice's
tests need). GREEN may not edit a test file, so this is out of scope here —
per this dispatch's contract, a line-limit warning is the code review's
judgement call, not GREEN's growth to perform. Every other `just precommit`
step was run individually and passes:

- `jq empty .claude-plugin/plugin.json` — clean.
- `jq empty hooks/hooks.json` — clean.
- `shellcheck -x` on every tracked `*.sh`/`*.bash`/`*.bats` — clean.
- `bash -n` on every tracked `*.sh` — clean.
- `rumdl fmt --check -q --no-cache` — clean.
- `scripts/check-links.sh` — clean.
- `just test` — 200 passed, 0 failed (above).

Only `scripts/check-line-limits.sh` fails, on `tests/verdicts.bats` alone.

## Commit

One commit, pathspecs: `lib/verdicts.sh`, `hooks/annotate.sh`,
`tests/verdicts.bats`, `tests/hook-locks.bats`,
`plans/sandbox-lies/reports/item-8-0-dispatch-brief.md`,
`plans/sandbox-lies/reports/item-8-0-s1-red.md`,
`plans/sandbox-lies/reports/item-8-0-s1-test-review.md`,
`plans/sandbox-lies/reports/item-8-0-s1-green.md`. Subject: `feat: Item
8.0/1 — lock verdicts word the re-run by the flag`.
