# Item 2.2 slice 1 — GREEN

`scripts/check-links.sh` replaces the RED stub: walks `git ls-files -z`
spooled through a `mktemp` temp file (mirrors `scripts/check-line-limits.sh`),
restricted by a `case` arm to `docs/*.md`, skipping a symlink or a path
missing from the work tree. For each surviving file, `grep -oE
'\[[^]]*\]\([^)]*\)'` extracts each inline link occurrence; the target is
peeled out with parameter expansion (`${link#*(}`, `${link%)}`) and resolved
as `$ROOT/$(dirname "$file")/$target` — the linking file's own directory, not
ROOT or CWD. A missing target prints `broken-link: <file> -> <target>` to
stdout (as written, unresolved) and sets the exit code; a clean tree exits 0
with no output. Arity check, default ROOT `.`, and the `mktemp`/`git
ls-files` failure paths (exit 2) mirror the sibling script line for line.

## Tests

Both tests in the slice share one code path (`check_links_in`, resolving
against the linking file's own directory) with no branch between the passing
and broken-link cases, so there was no meaningful intermediate state to land
one test on before the other: the full implementation was written in one
pass and both tests went green on the first run against it.

## Checks run (foreground)

- `shellcheck scripts/check-links.sh` — clean.
- `bash -n scripts/check-links.sh` — OK.
- `scripts/run-bats.sh tests/check-links.bats` — `bats: 2 passed, 0 failed`.
- `scripts/run-bats.sh tests/` — `bats: 45 passed, 0 failed` (the 43 prior
  passes plus these 2; no regression).
- `just precommit` — `precommit passed: plugin.json, shellcheck, bash -n,
  rumdl, line limits, tests`.

## Exec bit

`scripts/check-links.sh` is `rwxr-xr-x` in the working tree; staged for
commit by name so the index records `100755`.

## Scope carried forward (not implemented here)

`skills/`, root and exclusions (slice 2); skipping URLs, `mailto:`, pure
anchors and `#fragment` stripping (slice 3); ignoring code spans and fenced
blocks (slice 4); whitespace-specific handling beyond the NUL walk (slice 5);
BSD-stub tests (slice 6); the justfile `precommit` wiring for this script
(the item's last slice).
