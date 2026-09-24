# Item 2.1 slice 2 — RED

Test added to `tests/check-line-limits.bats`: `SKILL.md capped at 200`.
Fixture: `skills/x/SKILL.md` tracked with 201 lines (`seq 201`), asserting
status 1 and `oversized-file: skills/x/SKILL.md: 201 lines > 200`.

The exact `> 200` string and the 201-line boundary pin the cap and the
off-by-one comparison: a 400 cap (docs/'s) would leave a 201-line file clean
(status 0), and a 199 or 201 cap would still flag the file but print a
different number.

The SUT (`scripts/check-line-limits.sh`) does not scope `skills/*.md` at
all yet — only `docs/*.md` at cap 400 — so this is a real gap, not a
quiet-pass risk.

## Run: `scripts/run-bats.sh tests/check-line-limits.bats`

```
1..3
ok 1 clean tree exits 0 silently
ok 2 oversized markdown is reported
not ok 3 SKILL.md capped at 200
# (in test file tests/check-line-limits.bats, line 66)
#   `[ "$status" -eq 1 ]' failed
```

Slice 1's two tests still pass. The new test fails on its first assertion
(`[ "$status" -eq 1 ]`, actual `0` — the script currently ignores
`skills/x/SKILL.md`, exits 0 with empty stdout) — an assertion failure, not
a harness error. No mutation-proof fallback needed.

SUT untouched.
