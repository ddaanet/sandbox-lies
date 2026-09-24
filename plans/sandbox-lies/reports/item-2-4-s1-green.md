# Item 2.4 / slice 1 — GREEN report

Dispatch: item-2-4-s1-green. Mode: GREEN.

## Slice

1. External contract: `absent lock, sandboxed, is mask` — error text naming
   `$BATS_TEST_TMPDIR/r/.git/index.lock` (absent), flag `false`: line 1
   `mask`, a `path=` line naming that path.

## Batch received

One failing test in `tests/probes.bats`: `absent lock, sandboxed, is mask`
(RED report `item-2-4-s1-red.md`, refined by `item-2-4-s1-test-review.md`).
No test file edits were needed or made — the review had already fixed the
three wrong-reason gaps and left the test red on its line-1 assertion only.

## Implementation, one test at a time

Only one test was in the batch, so "one at a time" is trivially the whole
step:

1. Added `_probe_lock_path` to `lib/probes.sh`: extracts the single-quoted
   path from git's `Unable to create '<path>': File exists` line via
   `sed -n "s/.*[Uu]nable to create '\([^']*\)'.*/\1/p" | head -n 1` —
   case-insensitive on the leading U, matching `lib/matchers.sh`
   `match_git_lock`'s `[Uu]nable to create` gate.
2. Grew `probe_git_lock`: reads stdin into `text`, extracts `path`, guards
   absence with `[ ! -e "$path" ] && [ ! -L "$path" ]` (no tool call, so no
   `2>/dev/null` needed), and when the flag is `false` prints `mask` then
   `path=<path>` and exits 0 via the trailing `printf`'s own status. No stdin
   read is skipped, so `run_probe`'s here-string never blocks.
3. `probe_config_lock` untouched — still the inert stub (slice 8 scope).

Ran `scripts/run-bats.sh tests/probes.bats` after this single change; it
passed on the first attempt, no second implementation attempt needed.

## `set -u` at top level

`lib/probes.sh` already carried `set -u` from the RED-mode stub. Kept it and
added a justifying comment: the file is consistent with `lib/matchers.sh` and
`lib/verdicts.sh`, both sourced by `hooks/annotate.sh`, which sets `-u` at
its own top (`hooks/annotate.sh:21`) before sourcing them — so their own
`set -u` is redundant there but harmless (same setting). `lib/probes.sh` will
be sourced the same way once Item 4.1 wires it in. It is also sourced
directly by `tests/probes.bats`, which does not set `-u` itself, so keeping
it here is what makes an unset variable error in that context too, matching
the bash-3.2-safe, whitespace-safe discipline the brief requires. No other
shell option changes were made.

## Scope held

Implemented only the flag-`false`, absent-lock, `mask` outcome. Left out of
this GREEN, per the dispatch: the flag-`true` `gone` outcome (slice 2),
present-lock outcomes `orphan`/`held`/`unknown`, size/age, the holder check,
`stat`/`wc -c` use (slices 3, 4, 6, 9), the character-device rule (slice 5),
relative-path resolution against `$2` (slice 7 — `$2` is accepted but unused
this slice), `probe_config_lock` (slice 8, still the inert stub), and the
`stat` stub in `tests/helpers/bsd-stubs.bash` (slice 9). The present-lock and
flag-`true` branches fall through `probe_git_lock` with no output, which is
undefined behaviour outside this slice's one test and is exactly what later
slices grow.

## Full suite and gates

`scripts/run-bats.sh tests/probes.bats`:

```
bats: 1 passed, 0 failed
```

`shellcheck lib/probes.sh tests/probes.bats`: no output, clean.

`just precommit`:

```
scripts/run-bats.sh tests/
bats: 96 passed, 0 failed — full log: /tmp/claude-1000/sandbox-lies-bats.LEZ26b
precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests
```

No warnings were emitted by the precommit run to record.

## Files touched

- `lib/probes.sh` — grew `probe_git_lock` and added `_probe_lock_path`;
  `probe_config_lock` unchanged.
- `tests/probes.bats` — unchanged in this dispatch (already fixed by the
  test review).
