# GREEN: Item 2.4 / slice 8 — config-lock probe; relative lock paths resolve
from the nearest .git

**Scope**: `lib/probes.sh` (implementation), `tests/probes-config.bats` and
`tests/helpers/probes.bash` (from RED/test-review, unedited here — GREEN mode
never edits a test file), plus this report and the RED/test-review reports
staged into the same commit.
**Date**: 2026-09-25
**Mode**: GREEN

## Batch received (the failing contract this dispatch grows into)

From the test review's final run, 6 tests failing on their assertions against
unchanged `lib/probes.sh` (`cat >/dev/null` stub), 26 passing:

| Test | File | Failed assertion |
|---|---|---|
| `config-lock reads its own error` | probes-config.bats | `= mask` |
| `config-lock appends .lock to the named file` | probes-config.bats | `= orphan` |
| `each probe reads only its own lock line` | probes-config.bats | `= mask` |
| `config-lock from a subdirectory` | probes-config.bats | `= orphan` |
| `config-lock resolves at the nearest .git` | probes-config.bats | `= orphan` |
| `missing or empty cwd uses the working directory` | probes-config.bats | `= orphan` |

Two more tests in `probes-config.bats` (`pathless text never names the base`,
`no .git above cwd keeps cwd`) already passed against the unmodified SUT and
are mutation-pinned by the RED and test-review reports; my rewrite could not
touch a test file to change that, so they stayed as regression checks on this
GREEN.

## Growth applied

`lib/probes.sh`'s `probe_git_lock` was split as the item text and slice 5's
code review's `REFACTOR-NEEDED` note directed:

- `probe_git_lock` now only extracts the git-lock path (`_probe_lock_path`,
  unchanged), resolves it, and calls the new shared `_probe_lock_at <flag>
  <path>`.
- `probe_config_lock` extracts the config file named in git's `could not lock
  config file <file>: File exists` line with a new `_probe_config_lock_path`
  (mirrors `_probe_lock_path`'s LC_ALL=C, last-occurrence capture), appends
  `.lock` only when the extraction is non-empty (an empty extraction stays
  empty rather than becoming a literal `.lock`, which `_probe_resolve_path`
  would otherwise treat as an ordinary relative path and land on a real,
  holdable directory entry — the same failure mode slice 7's code review
  found and fixed for the pathless case), resolves it, and calls
  `_probe_lock_at`.
- `_probe_lock_at` holds everything that used to run after path extraction
  in `probe_git_lock`, byte-for-byte apart from its new `<flag> <path>`
  parameter list replacing the read of `$1`/`$path` from the enclosing
  scope: presence/absence, the character-device mask, the holder check, the
  BSD/GNU mtime read, the size read, and the outcome + key=value lines.
  Behaviour-preserving: no branch, comment or exception was reworded beyond
  what the parameter rename required.
- `_probe_resolve_path` gained the walk-up: for a relative, non-empty path,
  the base is `${2:-$PWD}` (the probe's own `$2`, or its process working
  directory when `$2` is missing or empty — never `/`, since `$PWD` is
  always a real directory the shell is sitting in), then a pure-shell loop
  (`${dir%/*}` parameter expansion, no `dirname` process, no git process)
  walks from that base upward, itself included, testing `[ -e "$dir/.git" ]`
  at each step (`-e` rather than `-d`, so a linked worktree's `.git` file
  counts) and stopping at the first hit; with none found by the time `dir`
  reaches `/`, it falls back to the original base unchanged. An absolute or
  empty extracted path still prints unchanged, as before slice 8.

## Tests made to pass, one at a time (recorded in this order)

Each test was run individually with `scripts/run-bats.sh
tests/probes-config.bats --filter "<name>"` against the completed
implementation above (the growth was designed as one coherent unit — the six
red tests all exercise the same shared resolver and the same new
`probe_config_lock` extraction path, so no smaller implementation slice would
pass one without the logic the others need too). Order:

1. `config-lock reads its own error` — 1 passed, 0 failed.
2. `config-lock appends .lock to the named file` — 1 passed, 0 failed.
3. `each probe reads only its own lock line` — 1 passed, 0 failed.
4. `config-lock from a subdirectory` — 1 passed, 0 failed.
5. `config-lock resolves at the nearest .git` — 1 passed, 0 failed.
6. `missing or empty cwd uses the working directory` — 1 passed, 0 failed.

No implementation attempt failed a test twice; each of the six passed on the
first run of the completed `lib/probes.sh`.

## Full suite

`cd /Users/david/code/sandbox-lies && scripts/run-bats.sh tests/probes.bats
tests/probes-edges.bats tests/probes-tools.bats tests/probes-config.bats`
(foreground): **32 passed, 0 failed** — the 26 pre-existing cases plus this
slice's 6 (2 of which were already green on arrival and are unchanged
regression checks, not part of this GREEN's growth).

`lib/probes.sh` line count: 257 (was 206; under the 400-line cap).

## Lint / precommit

No `just lint` recipe exists in this repo — `shellcheck`, `bash -n` and
`rumdl` run inside `just precommit` itself (checked against `justfile`), so
that single gate stands in for both steps this mode names.

`cd /Users/david/code/sandbox-lies && just precommit` (foreground):

```
scripts/run-bats.sh tests/
bats: 127 passed, 0 failed — full log: /tmp/claude-1000/sandbox-lies-bats.cHbuQU
precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests
```

No warnings emitted by any check; nothing deferred to code review.

## Self-quiet

`bash lib/matchers.sh < lib/probes.sh` prints nothing, exit 1 — the new
`_probe_config_lock_path` sed script's line does not start with `error: `
(match_config_lock is anchored `^error: could not lock config file .*: File
exists`), so quoting git's phrase inside the sed pattern does not fire it.
Already covered by `just precommit`'s `tests` check (`tests/docs.bats`), which
also passed.

## Scope held

- No test file was edited. `tests/probes-config.bats` and
  `tests/helpers/probes.bash` are exactly as the test review left them.
- `docs/design.md`'s pre-existing uncommitted FR-4 status-flip edit
  (`Planned` → `Partial`) was left untouched, per the dispatch, and is staged
  into this commit as-is.
- Not touched: the hook wiring (Item 4.1), live reproductions (Item 3.1),
  `lib/verdicts.sh`, `lib/matchers.sh`, `probe_readonly_path` (Item 4.3), and
  every other slice's tests.
- `_probe_holder_pids` and `_probe_is_seconds` are unchanged from HEAD.
