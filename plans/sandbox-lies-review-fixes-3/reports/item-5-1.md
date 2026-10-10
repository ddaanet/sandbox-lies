# Item 5.1 — probes.bats uses the shared locale and mtime helpers

## What changed

- `tests/probes.bats`, non-UTF-8 byte case: the literal `C.UTF-8` is replaced by
  `loc=$(utf8_locale)` (from `tests/helpers/locale.bash`, already loaded), and
  the precondition `sed` and the `run_probe` call use `LC_ALL="$loc"`. A missing
  UTF-8 locale makes `utf8_locale` fail, so the assignment fails the case rather
  than passing under a byte locale.
- `tests/probes.bats`, "BSD stat" case: `real_mtime=$(stat -c %Y "$lock")` is
  replaced by `real_mtime=$(index_mtime "$lock")` (from `tests/helpers/probes.bash`,
  loaded by probes.bats). The call stays before the `stat` stub goes on PATH.

The outline put the mtime call at line 302; in the current file it is at line
356 (the `stat -c %Y` read). The literal `C.UTF-8` sat at lines 65-71.

## Test counts

- Before (`scripts/run-bats.sh tests/probes.bats`): 15 passed, 0 failed.
- After (same command): 15 passed, 0 failed.

Behaviour of the cases is unchanged; both helpers resolve to the same locale
and mtime values on this host.

Portability: the helpers are portable by construction, unverified on a Mac.

## Precommit

`just precommit` (unsandboxed, foreground): exit status 0.
Recap: precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl,
line limits, links, python compile, tests (full suite 400 passed, 0 failed).

## Mutation proof

Not applicable: the cases were already green on the unchanged code and this
item is a refactor to shared helpers, not a new behaviour test.
