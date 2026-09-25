# RED: Item 2.4 / slice 10 — `tests/probes-tools.bats`

**Mode**: RED
**Scope**: new file `tests/probes-tools.bats` (four `@test` cases). No other
file changed — `lib/probes.sh`, `tests/probes.bats`, `tests/probes-edges.bats`
and `tests/helpers/probes.bash` are all byte-identical to HEAD; the helpers
this slice needed (`tools_only_path`, `run_probe`, `git_lock_error`) already
live in `tests/helpers/probes.bash`, loaded via `load helpers/probes`, so no
helper move was required.

## Tests written

1. `errored holder check is unknown` — new behaviour (Item 2.4 slice 6's code
   review, major 2). Two sub-cases on a 7-byte unheld lock, `tools_only_path`
   (no `lsof`, no `fuser` except the stub written for the case):
   - a `fuser` stub printing a permission-denied line naming the path on
     stderr, no pid, exit 1 → expect `unknown`, `bytes=7`, no `pid=`, that
     line on stderr.
   - a `fuser` whose shebang names `/nonexistent/interpreter` (an exec
     failure) → expect `unknown`, non-empty stderr.
2. `a file named %m in the cwd` — mutation-proof pin of the BSD branch's
   digit check (slice 9's code review) on its real GNU use: an empty file
   named `%m` in the probe's actual working directory, no stubs, a 7-byte
   unheld lock. Expect `orphan`, `bytes=7`, an `age=` integer, empty stderr.
3. `non-seconds stat output is dropped` — mutation-proof pin of the GNU
   branch's digit check (slice 9's code review, major 1): a `stat` stub that
   fails `-f` and answers `-c` with non-digit stdout (`12 junk`) plus a
   stderr line (`warn`), exit 0. Expect `orphan`, `bytes=7`, no `age=`, both
   lines on stderr.
4. `vanished lock is gone under BSD stat` — mutation-proof pin of slice 9's
   hand-checked case: the existing vanish-during-stat wrapper, but exec'ing
   `make_bsd_stubs stat` instead of the real `stat`, both flags. Expect
   `gone`, `path=`, empty stderr.

## RED run — new-behaviour test

```
$ scripts/run-bats.sh tests/probes.bats tests/probes-edges.bats tests/probes-tools.bats
not ok 21 errored holder check is unknown
# (in test file tests/probes-tools.bats, line 43)
#   `[ "${output%%$'\n'*}" = unknown ]' failed

bats: 23 passed, 1 failed
```

`errored holder check is unknown` fails on its own assertion (`output` line 1
is `orphan`, not `unknown`) — the current `_probe_holder_pids`/`probe_git_lock`
reads an errored holder check as `orphan`, exactly the gap slice 6's review
named. Not an `ImportError`/`AttributeError`-shape failure: the SUT already
defines every symbol the test calls. The test aborts on this first assertion,
so the second sub-case (missing-interpreter shebang) is not separately
exercised by this run; I additionally verified it by hand (outside bats, no
hang, no crash — see Mutation proof note below) that it too currently reads
`orphan` with a non-empty stderr, so it will red the same way once reached.

The other three tests (`a file named %m in the cwd`, `non-seconds stat output
is dropped`, `vanished lock is gone under BSD stat`) pin behaviour already
in the SUT since slice 9's code review (each was checked there by hand, not
by a test). They pass unmodified, per the same run (23 of 24 passed, only the
new-behaviour test failing) — proven by mutation below.

## Mutation proof

Each mutation was applied, the full three-file suite re-run, the target test
confirmed red on its own assertion, then the mutation was inverted, a `grep
-cF` for the mutant string confirmed 0, and the suite re-run confirmed green
(back to 23 passed / 1 failed, the one expected new-behaviour red). All three
proofs ran against unchanged `lib/probes.sh`; `git diff lib/probes.sh` is
empty after each restore, confirmed after the last one.

1. **`a file named %m in the cwd`** — string pair:
   - before: `    if mtime=$(stat -f %m "$path" 2>/dev/null) \` +
     `\n        && _probe_is_seconds "$mtime"; then\n        :`
   - after (mutant, drops the BSD branch's digit check):
     `    if mtime=$(stat -f %m "$path" 2>/dev/null); then\n        :`
   - Result: `not ok … a file named %m in the cwd` —
     `` `[ "$status" -eq 0 ]' failed `` (isolated run:
     `scripts/run-bats.sh tests/probes-tools.bats -f "a file named"` → 0
     passed, 1 failed). The GNU filesystem-report text from the stray `%m`
     operand reaches the age arithmetic and the probe errors out.
   - Restored (strings swapped back); `grep -cF 'if mtime=$(stat -f %m
     "$path" 2>/dev/null); then' lib/probes.sh` → 0; full suite back to 23
     passed, 1 failed.

2. **`non-seconds stat output is dropped`** — string pair:
   - before: `    elif ! mtime=$(stat -c %Y "$path" 2>&1) \` +
     `\n        || ! _probe_is_seconds "$mtime"; then`
   - after (mutant, drops the GNU branch's digit check):
     `    elif ! mtime=$(stat -c %Y "$path" 2>&1); then`
   - Result: `not ok … non-seconds stat output is dropped` —
     `` `[ "$status" -eq 0 ]' failed ``. The stub's non-digit `-c` output
     (merged with its stderr line via `2>&1`) reaches the age arithmetic.
   - Restored; `grep -cF 'elif ! mtime=$(stat -c %Y "$path" 2>&1); then'
     lib/probes.sh` → 0; full suite back to 23 passed, 1 failed.

3. **`vanished lock is gone under BSD stat`** — string pair (the elif
   branch's absence check; unique by its 8-space indent — the identical
   4-space-indented line at the top of `probe_git_lock` is a different exact
   string):
   - before: `        if [ ! -e "$path" ] && [ ! -L "$path" ]; then`
   - after (mutant, forces the check always false):
     `        if [ ! -e "$path" ] && [ ! -L "$path" ] && false; then`
   - Result: `not ok … vanished lock is gone under BSD stat` —
     `` `[ -z "$stderr" ]' failed `` (the BSD refusal text — "illegal option
     -- c" — now reaches stderr instead of the vanish being recognised).
     This mutation also reds two pre-existing tests sharing the same
     GNU-fallback code path (`vanished lock is gone`,
     `lock vanishing during the holder check reads gone`), both in
     `tests/probes-edges.bats` — expected, since the check is shared, not
     duplicated; full run showed 20 passed, 4 failed.
   - Restored; `grep -cF '] && false; then' lib/probes.sh` → 0; full suite
     back to 23 passed, 1 failed.

`git diff lib/probes.sh` is empty at the end of this dispatch.

## Other checks

- `shellcheck` over the full tracked `*.sh`/`*.bash`/`*.bats` batch plus the
  new file (as `just precommit` invokes it): exit 0. In isolation the new
  file gets one SC1091 info ("not following" the sourced
  `$ROOT/lib/probes.sh`) — the same info-level note `tests/probes.bats` and
  `tests/probes-edges.bats` already carry in isolation; it disappears when
  shellcheck runs over the batch, as precommit does.
- `bash -n tests/probes-tools.bats` reports a syntax error at the first
  `@test … { … }` block — expected: bats' `@test` syntax is not plain bash,
  and `just precommit`'s `each_bash_n` step re-scopes to tracked `*.sh` only,
  never `*.bats` (confirmed the same failure on the already-committed
  `tests/probes.bats`).
- Self-quiet: `bash lib/matchers.sh < tests/probes-tools.bats; echo rc=$?` →
  no output, `rc=1` (quiet).

## Line counts

- `tests/probes-tools.bats`: 146 lines (new file)
- `tests/probes.bats`: 325 lines (unchanged)
- `tests/probes-edges.bats`: 358 lines (unchanged)
- `tests/helpers/probes.bash`: 70 lines (unchanged)
- `lib/probes.sh`: 200 lines (unchanged; restored after every mutation)

## Not committed

Per RED mode, nothing is committed. `git status --porcelain -- tests lib`
shows only `tests/probes-tools.bats` as untracked.
