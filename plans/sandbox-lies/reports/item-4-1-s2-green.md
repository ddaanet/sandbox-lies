# Item 4.1 slices 2-3 — GREEN

Batched dispatch: slice 2 (`held interpolates the pid`) and slice 3 (`orphan
and unknown interpolate size and age`, plus the neither/one-of-bytes-or-age
cases from Item 2.4 slice 3's code review and this slice's test review).

## Implementation

`lib/verdicts.sh`: `verdict_git_lock` and `verdict_config_lock` each gained a
stdin-reading prologue — a `while IFS= read -r line || [ -n "$line" ]; do
… done` loop, keyed on `pid=`/`bytes=`/`age=` prefix (any other key,
`path=` included, ignored) — before their existing `case "$outcome"`. This
reads the function's own stdin directly; no subshell, no command
substitution, no temp file. `held` interpolates `pid` into the paragraph's
`(pid N)` clause and the human line's `by pid N`, dropping both when `pid` is
empty. `orphan`/`unknown` build a `size_clause` from whichever of
`bytes`/`age` is non-empty (`" (N bytes, age Ns)"`, `" (N bytes)"`,
`" (age Ns)"`, or `""`), spliced into the paragraph; the human lines are
unchanged (they never named the values). The two functions duplicate this
block rather than sharing a helper: the file already duplicates each
outcome's full case body between them (differing only in `index.lock` vs
`config.lock`, and the mask/gone `GIT_INDEX_FILE` clause), and a helper here
would need either a subshell (a fork the dispatch note said to avoid where
parameter expansion suffices) or bash's dynamic-scope variable mutation,
which is less legible than the six-line duplication it would save.

`hooks/annotate.sh`, `lib/probes.sh` and the rest of `lib/verdicts.sh`
(mask/gone bodies, the three phantom verdicts) are untouched.

## Tests run, in the order made to pass

One test at a time, `direnv exec . bats -f '<name>' <file>` after each
change, per `craft:test-discipline`:

1. `held interpolates the pid` (`tests/hook-locks.bats`) — red before, green
   after adding the stdin loop and the `held` branch's `pid` interpolation to
   `verdict_git_lock`.
2. `orphan and unknown interpolate size and age` (`tests/hook-locks.bats`) —
   green already, from the same edit (the `orphan`/`unknown` branches' size
   interpolation was written in the same pass as `held`'s).
3. `orphan with neither bytes nor age interpolates no empty value`
   (`tests/hook-locks.bats`) — green already, same edit: `size_clause` is
   `""` when both are absent, so the parenthetical is dropped, not emptied.
4. `orphan with one of bytes and age interpolates that one alone`
   (`tests/hook-locks.bats`) — green already, same edit: the `elif` arms
   produce `" (N bytes)"` / `" (age Ns)"` alone.
5. `verdict_git_lock held|orphan|unknown interpolate probe values`
   (`tests/verdicts.bats`) — green already, same edit.
6. `verdict_config_lock held|orphan|unknown interpolate probe values`
   (`tests/verdicts.bats`) — red until the identical stdin-loop and
   interpolation edit was applied to `verdict_config_lock`; green after.

After all six: `direnv exec . bats tests/hook-locks.bats tests/verdicts.bats`
— all 14 pass (the 8 pre-existing plus the 6 above), none newly broken.

Full suite: `direnv exec . scripts/run-bats.sh tests/` — `bats: 141 passed, 0
failed`.

`direnv exec . just precommit` — `precommit passed: plugin.json, hooks.json,
shellcheck, bash -n, rumdl, line limits, links, tests`. (This repo's
`justfile` has no `lint` recipe; `precommit` already runs shellcheck, `bash
-n`, rumdl and the line-limit check, so those checks ran as part of this
gate.)

## Precommit warnings

None. The gate's `report` wrapper prints only the passing-check list on
success; no check emitted a warning.

## Line counts

`lib/verdicts.sh` 140 (was 83), `tests/hook-locks.bats` 217 (unchanged from
the reviewed RED), `tests/verdicts.bats` 224 (unchanged from the reviewed
RED) — all under the 400-line cap.

## Scope

`verdict_config_lock`'s interpolation was in scope here because
`tests/verdicts.bats`'s `verdict_config_lock held|orphan|unknown interpolate
probe values` case — added by the slice's test review, batched into this
report's failing set — exercises it directly; nothing else in
`verdict_config_lock` (its `mask`/`gone` bodies, or the hook route, which
Item 4.1 slice 1 already pins for `config-lock` via `mask`) changed.
Slices 4-9, Items 4.2/4.3, `docs/`, the memory retirement and `design.md`
status flips are untouched, per the dispatch's scope note.
