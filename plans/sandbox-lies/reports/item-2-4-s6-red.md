# RED: Item 2.4 / slice 6 — no holder tool is unknown; review-added cases

**Scope**: `tests/probes.bats`, `tests/probes-edges.bats`,
`tests/helpers/probes.bash`. `lib/probes.sh` touched only for the four
mutation proofs below, and restored after each; no diff against HEAD remains
(`git diff --stat lib/probes.sh` is empty).
**Date**: 2026-09-25
**Mode**: RED

## Tests written

- `tests/probes.bats` — `no holder tool is unknown` (295 lines, under the
  400-line cap, so it stayed in `probes.bats` rather than moving to
  `probes-edges.bats`).
- `tests/probes-edges.bats` — `lock vanishing during the holder check reads
  gone`, `unexpected holder-tool stderr is passed through`, `lsof decides
  when present`, `dangling symlink lock is a quiet orphan` (276 lines).
- `tests/helpers/probes.bash` — new shared `tools_only_path <dir>` helper
  (37 lines): symlinks `cat sed head stat wc tr date mktemp` from this
  host's own `command -v` into `<dir>` (the probe's own external tools, plus
  `mktemp` for bats' own `run --separate-stderr`, which needs it internally
  — discovered when the first run of the restricted-PATH tests failed with
  `mktemp: command not found`). Neither `lsof` nor `fuser` is ever placed
  there by the helper, so a `PATH` set to exactly that directory can never
  find either unless a test writes one in itself.

Each PATH-restricted stub script that must call an external tool of its own
(`rm`, in the vanishing-lock stub) resolves that tool via `command -v`
*before* the PATH restriction takes effect and bakes the absolute path into
the heredoc, the same pattern the existing `vanished lock is gone` case uses
for its real `stat`.

## Run: full suite, current SUT (uncommitted tests, unmodified `lib/probes.sh`)

`cd /Users/david/code/sandbox-lies && scripts/run-bats.sh tests/probes.bats tests/probes-edges.bats`
(foreground): **16 passed, 1 failed**.

```
1..17
ok 1 absent lock, sandboxed, is mask
ok 2 absent lock, unsandboxed, is gone
ok 3 non-UTF-8 byte in the path
ok 4 present unheld lock is orphan
ok 5 unexpected flag reads as sandboxed
ok 6 quote and space in the lock path
ok 7 held lock names the holder
ok 8 held lock under a quoted, spaced path
ok 9 character device is mask
not ok 10 no holder tool is unknown
# (in test file tests/probes.bats, line 293)
#   `[ "${output%%$'\n'*}" = unknown ]' failed
ok 11 vanished lock is gone
ok 12 non-regular lock has no size
ok 13 future mtime is age 0
ok 14 lock vanishing during the holder check reads gone
ok 15 unexpected holder-tool stderr is passed through
ok 16 lsof decides when present
ok 17 dangling symlink lock is a quiet orphan
```

### `no holder tool is unknown` — the new, unimplemented case

Fails on its own assertion (`[ "${output%%$'\n'*}" = unknown ]`), not on a
missing symbol. Confirmed manually: with `PATH` restricted to a directory
holding only `cat sed head stat wc tr date mktemp` (no `lsof`, no `fuser`)
over a present 7-byte unheld lock, the current SUT prints:

```
orphan
bytes=7
age=0
path=/…/.git/index.lock
```

— i.e. it reads a present unheld lock as `orphan` whatever holder tools
exist, exactly the failure mode the dispatch named. No mutation applies: the
`unknown` outcome does not exist in `lib/probes.sh` yet (slice 6's own
behaviour to add in GREEN).

The other four cases in this batch (`lock vanishing …`, `unexpected
holder-tool stderr …`, `lsof decides …`, `dangling symlink …`) all pass
against the unmodified SUT, since their behaviour already landed with slice
4's and slice 5's code reviews. Each is proven non-vacuous by mutation below.

## Mutation proof

Each mutation was applied to `lib/probes.sh`, the named test re-run alone,
then reverted by the exact inverse string swap, `grep`-confirmed absent, and
the full two-file suite re-run green (modulo the still-unimplemented
`unknown` case) before moving to the next mutation. One mutation per test;
all four are independent single-string edits inside `_probe_holder_pids`
except the `lsof` one.

1. **`lock vanishing during the holder check reads gone`**
   String pair (remove / restore), inside `_probe_holder_pids`:
   ```
   remove:  "    if [ ! -e \"$path\" ]; then\n        return 0\n    fi\n    printf '%s\\n' \"$err\" >&2"
   restore: "    printf '%s\\n' \"$err\" >&2"
   ```
   (i.e. deleted the `[ ! -e "$path" ]` early-return clause entirely).
   Re-run of `tests/probes-edges.bats` alone: **5 passed, 2 failed** —
   `lock vanishing during the holder check reads gone` red on
   `[ -z "$stderr" ]` (line 164), and `dangling symlink lock is a quiet
   orphan` also red on the same assertion (collateral: both cases depend on
   this one guard). Restored by swapping the two strings back; `grep -c`
   for the mutated one-line form returned 0, and
   `scripts/run-bats.sh tests/probes.bats tests/probes-edges.bats` returned
   to 16 passed, 1 failed (only the still-unimplemented `unknown` case).

2. **`unexpected holder-tool stderr is passed through`**
   String pair, the guard's trailing line:
   ```
   remove:  printf '%s\n' "$err" >&2
   restore: :
   ```
   (dropped the final passthrough `printf`, replacing it with a no-op `:`).
   Re-run of `tests/probes-edges.bats` alone: **6 passed, 1 failed** —
   `unexpected holder-tool stderr is passed through` red on
   `printf '%s\n' "$stderr" | grep -qF "fuser: something odd"` (line 199).
   Restored by the inverse swap; `grep -n '^    :$' lib/probes.sh` found no
   hit, and the full two-file run returned to 16 passed, 1 failed.

3. **`lsof decides when present`**
   String pair, the lsof invocation:
   ```
   remove:  lsof -w -t "$path"
   restore: lsof -t "$path"
   ```
   (dropped `-w`). Re-run of `tests/probes-edges.bats` alone: **6 passed, 1
   failed** — `lsof decides when present` red on
   `[ "$(cat "$calls")" = "-w -t $lock" ]` (line 245). Restored by the
   inverse swap; `grep -n 'lsof -t "\$path"' lib/probes.sh` found no hit,
   and the full two-file run returned to 16 passed, 1 failed.

4. **`dangling symlink lock is a quiet orphan`**
   String pair, the guard the slice-5 review narrowed:
   ```
   remove:  if [ ! -e "$path" ]; then
   restore: if [ ! -e "$path" ] && [ ! -L "$path" ]; then
   ```
   (re-added the `[ ! -L "$path" ]` clause the slice-5 code review dropped).
   Re-run of `tests/probes-edges.bats` alone: **6 passed, 1 failed** —
   `dangling symlink lock is a quiet orphan` red on `[ -z "$stderr" ]` (line
   262). Restored by the inverse swap; `grep -n '\[ ! -L "\$path" \]'
   lib/probes.sh` showed only the two legitimate occurrences in
   `probe_git_lock` (the absence check and the `stat`-failure check), not a
   third one inside `_probe_holder_pids`, and the full two-file run returned
   to 16 passed, 1 failed.

After the fourth restore, `git diff --stat lib/probes.sh` is empty: the file
is byte-identical to HEAD.

## shellcheck

`cd /Users/david/code/sandbox-lies && shellcheck tests/probes.bats tests/probes-edges.bats tests/helpers/probes.bash`
reports two `SC1091 (info)` notices, both on the pre-existing
`source "$ROOT/lib/probes.sh"` lines (`tests/probes.bats:16`,
`tests/probes-edges.bats:15`), unrelated to this dispatch's edits — the same
notice fires against the committed HEAD copy of `tests/probes.bats` run
alone (`git show HEAD:tests/probes.bats | shellcheck -`, rc 1), and
disappears when shellcheck runs over the whole tracked `*.sh`/`*.bash`/
`*.bats` set together (as `just precommit`'s `shellcheck` step does — that
run returns rc 0 unmodified), because it can then resolve the `source`
target for itself. No new shellcheck finding was introduced.

## Self-quiet check

```
cd /Users/david/code/sandbox-lies && for f in tests/probes.bats tests/probes-edges.bats tests/helpers/probes.bash; do bash lib/matchers.sh < "$f"; echo "$f rc=$?"; done
```
No stdout from any of the three; each line printed `<file> rc=1`.

## Line counts

```
 295 tests/probes.bats
 276 tests/probes-edges.bats
  37 tests/helpers/probes.bash
 152 lib/probes.sh   (unchanged from HEAD)
```

## Scope

Touched only `tests/probes.bats`, `tests/probes-edges.bats`,
`tests/helpers/probes.bash`, plus the four transient mutations of
`lib/probes.sh`, each reverted before the dispatch ended. Nothing committed.
The `unknown` implementation, slices 7–9, and everything else the brief
lists as out of scope were not touched.
