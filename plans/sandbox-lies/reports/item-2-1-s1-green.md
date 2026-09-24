# Item 2.1 slice 1 — GREEN

`scripts/check-line-limits.sh` replaces the `exit 2` stub with the slice's
scope only: `ROOT` defaults to `.`; a NUL-delimited `git ls-files -z` walk of
`ROOT`, spooled to a `mktemp` temp file so `git`'s own exit status is
observable (a `< <(git ls-files -z)` process substitution would discard it,
letting a non-git `ROOT` read as an empty, clean tree); each tracked path
matching `docs/*.md` (a `case` pattern, so it matches `/` too — recursive
under `docs/`) checked against a 400-line cap via `wc -l`; one
`oversized-file: <path>: <n> lines > 400` line to stdout per overage. Exit 0
clean, 1 on any overage, 2 when `ROOT` is missing/not a git work tree (`git
ls-files` fails) or the walk-list temp file can't be created or a matched
file can't be read.

Out of this slice, left for later slices per the dispatch: the SKILL.md 200
cap, shell/python files, the `plans/`/`plugin-dev/` exclusions, root and
`skills/` markdown, whitespace-path handling beyond the NUL-safe walk (not
specially handled, but not exercised either — slice 4), BSD-stub cases
(slice 5), and the `precommit` wiring (lands with the item's last slice). No
allowlist (dropped per the port instruction).

## Run

`scripts/run-bats.sh tests/check-line-limits.bats`, foreground:

```
bats: 2 passed, 0 failed
```

Both slice 1 cases pass: `clean tree exits 0 silently` (400-line
`docs/a.md`, status 0, empty stdout and stderr) and `oversized markdown is
reported` (401-line `docs/a.md`, status 1, stdout exactly `oversized-file:
docs/a.md: 401 lines > 400`).

`shellcheck scripts/check-line-limits.sh`: clean.

Full suite `scripts/run-bats.sh tests/`: `bats: 29 passed, 0 failed` — the
27 pre-existing plus these two, no regressions.

`direnv exec . just precommit`, foreground:

```
scripts/run-bats.sh tests/
bats: 29 passed, 0 failed
precommit passed: plugin.json, shellcheck, bash -n, rumdl, tests
```

## Left in the tree (uncommitted, per dispatch)

- `scripts/check-line-limits.sh` (green, executable — `100755` on disk,
  confirmed with `ls -la` before commit)
- `tests/check-line-limits.bats` (unchanged from the test-review report)
- `plans/sandbox-lies/reports/item-2-1-s1-red.md`,
  `plans/sandbox-lies/reports/item-2-1-s1-test-review.md` (prior reports)
- this report
