# Item 2.1 slice 2 — GREEN

Change to `scripts/check-line-limits.sh`: one new `case` arm,
`skills/*/SKILL.md) check_cap "$file" 200 ;;`, added after the existing
`docs/*.md` arm, plus the header "Scope" comment updated to mention the
200-line SKILL.md cap alongside docs/'s 400.

Out of scope per the dispatch, not touched: other `skills/` markdown at 400,
root `*.md` at 400, `*.sh`/`*.bash`/`*.bats`/`*.py` scope, `plans/`/
`plugin-dev/` exclusions, whitespace/edge-input/BSD-stub tests, the justfile
`precommit` wiring.

## Runs

`shellcheck scripts/check-line-limits.sh`: clean.

`scripts/run-bats.sh tests/check-line-limits.bats`:

```
1..3
ok 1 clean tree exits 0 silently
ok 2 oversized markdown is reported
ok 3 SKILL.md capped at 200
bats: 3 passed, 0 failed
```

Full suite, `scripts/run-bats.sh tests/`: 30 passed, 0 failed.

`just precommit`: `precommit passed: plugin.json, shellcheck, bash -n, rumdl, tests`.

SUT: `scripts/check-line-limits.sh`. Test: `tests/check-line-limits.bats`
(unchanged from the red/test-review reports).
