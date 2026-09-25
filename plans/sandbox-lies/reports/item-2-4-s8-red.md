# RED: Item 2.4 / slice 8 — config-lock reads its own error, and $2's base resolution

**Scope**: `tests/probes-config.bats` (new file) and `tests/helpers/probes.bash`
(one shared fragment builder added). `lib/probes.sh` untouched at the end of
this dispatch (`git diff --stat lib/probes.sh` is empty); it was edited twice,
each time for a mutation proof, and restored immediately after.
**Date**: 2026-09-25
**Mode**: RED

## Item text followed (current runbook, not the stale brief copy)

Item 2.4's path-resolution clause, as revised in the runbook (not the brief's
stale copy): "a relative path resolves against the nearest ancestor of `$2`
(itself included) holding `.git`, falling back to `$2` … and a missing or
empty `$2` falls back to the probe's own working directory, never `/`."

## Tests written

New file `tests/probes-config.bats` (142 lines), loading `helpers/bsd-stubs`
and `helpers/probes` as directed. `tests/probes.bats` was left at 325 lines
(already near its cap); the new cases go here instead, per the dispatch's
placement guidance.

1. `config-lock reads its own error` — builds the config-lock error line
   (config file path, no `.lock` suffix, no quotes — unlike git-lock's
   quoted `<path>.lock`) with the new `config_lock_error` helper, absolute
   path so this case is independent of $2's base-resolution rules. Absent
   lock, flag `false`: expects `mask`, `path=<repo>/.git/config.lock`.
   Present 7-byte lock, same call: expects `orphan`, `bytes=7`, that `path=`.
2. `pathless text never names the base` — text with no lock line, `$2` an
   existing directory that the test's own shell also `cd`s into (so the
   probe's process cwd equals `$2`, matching the code-review's "a resolver
   that joins the empty path onto `$2` or the process cwd lands on a real,
   holdable directory" finding), flags `false` and `true`: line 1 neither
   `held` nor `orphan`, no `pid=` line, empty stderr.
3. `config-lock from a subdirectory` — config-lock text naming `.git/config`
   (relative), `$2 = <repo>/sub` (no `.git` of its own), the lock present at
   `<repo>/.git/config.lock`: expects `orphan`,
   `path=<repo>/.git/config.lock`.
4. `no .git above cwd keeps cwd` — relative git-lock text, `$2` a directory
   under `$BATS_TEST_TMPDIR` with no `.git` in it or in any ancestor up to
   `/` (asserted first, by a walk-up loop each of whose `[ ! -e
   "$ancestor/.git" ]` lines fails the test outright if it ever finds one —
   plus one more check on `/.git` itself), lock absent, flag `false`:
   expects `mask`, `path=$2/.git/index.lock`.
5. `missing or empty cwd uses the working directory` — relative git-lock
   text, `$2` absent and then `""`, the probe run (via bare `probe_git_lock`,
   not the shared `run_probe` helper, since it needs to omit or empty the
   third argument) from a repo dir holding a present 7-byte lock: expects
   `orphan`, `path=<repo>/.git/index.lock` both times.

`tests/helpers/probes.bash` gained `config_lock_error <path>`, mirroring
`git_lock_error`'s self-quiet fragment split and the split
`tests/matchers.bats` "detect sees past a NUL" already uses for
`match_config_lock`'s own pattern (`"...File"` then `" exists"`), so no
source line here reads git's config-lock `error: ...` text whole.

## Run: full suite, current SUT (uncommitted tests, `lib/probes.sh` unchanged)

`cd /Users/david/code/sandbox-lies && scripts/run-bats.sh tests/probes.bats tests/probes-edges.bats tests/probes-tools.bats tests/probes-config.bats`
(foreground): **26 passed, 3 failed**.

```
not ok 25 config-lock reads its own error
# (in test file tests/probes-config.bats, line 31)
#   `[ "${output%%$'\n'*}" = mask ]' failed
not ok 27 config-lock from a subdirectory
# (in test file tests/probes-config.bats, line 91)
#   `[ "${output%%$'\n'*}" = orphan ]' failed
not ok 29 missing or empty cwd uses the working directory
# (in test file tests/probes-config.bats, line 133)
#   `[ "${output%%$'\n'*}" = orphan ]' failed
```

All 22 pre-existing cases in `tests/probes.bats`, `tests/probes-edges.bats`
and `tests/probes-tools.bats` stay green (untouched by this dispatch). Two
new cases (`pathless text never names the base`, `no .git above cwd keeps
cwd`) pass immediately against the unmodified SUT — expected per the
dispatch, and proven non-vacuous by mutation below.

### `config-lock reads its own error` — line 31, `[ "${output%%$'\n'*}" = mask ]`

`probe_config_lock` is still `cat >/dev/null`: it consumes stdin and prints
nothing, so `$output` is empty and `${output%%$'\n'*}` is `""`, not `mask`.
Real assertion failure, not a missing-symbol error — `probe_config_lock`
exists (as an inert stub) and is called successfully.

### `config-lock from a subdirectory` — line 91, `[ "${output%%$'\n'*}" = orphan ]`

Same cause: the stub prints nothing regardless of `$2` or the lock's
presence, so line 1 is `""`, not `orphan`. This case also exercises the
still-unimplemented walk-up (a plain join onto `$2` would look for
`<repo>/sub/.git/config.lock`, which the fixture never creates), but the
stub reds it before that logic is even reached.

### `missing or empty cwd uses the working directory` — line 133 (first `run` block, `$2` omitted)

A manual reproduction against the unmodified SUT:

```
$ cd /Users/david/code/sandbox-lies && source lib/probes.sh
$ repo="$(mktemp -d)/r3"; mkdir -p "$repo/.git"; printf '1234567' >"$repo/.git/index.lock"
$ cd "$repo"
$ printf "fatal: Unable to create '.git/index.lock': File exists.\n" | probe_git_lock false
mask
path=/.git/index.lock
```

`_probe_resolve_path`'s default arm joins the relative extracted path onto
`"$2"`, which is empty when `$2` is unset or `""`: `printf '%s/%s\n' "" "$1"`
prints a leading `/` followed by the relative path — `/.git/index.lock`,
rooted at the filesystem root rather than the probe's actual working
directory — exactly the failure mode the dispatch names ("the current join
puts `/` in front"). The path is absent there, so the outcome also reads
`mask` instead of `orphan`. Real assertion failure at line 133
(`[ "${output%%$'\n'*}" = orphan ]`), the first of the two `run` blocks (the
`$2`-omitted case); the second block (`$2 = ""`) was not reached because bats
stops a test at its first failing line.

## Mutation proof

### `pathless text never names the base`

- Mutation: in `lib/probes.sh` `_probe_resolve_path`, `/* | '') printf
  '%s\n' "$1" ;;` → `/*) printf '%s\n' "$1" ;;` (dropping the `| ''` arm, a
  string occurring once in the file).
- Run: `scripts/run-bats.sh tests/probes-config.bats --filter "pathless text never names the base"`
  (foreground).
- Result: 0 passed, 1 failed — `not ok 1 pathless text never names the base`,
  failing at line 60 on `[ -z "$stderr" ]` (the false-flag call): with the
  empty extracted path now joined onto `$2` (the directory the test's own
  shell sits in via `cd`), the probe finds that directory present, runs the
  holder check against it, and the local `fuser`/`lsof` install reports the
  test's own shell as a holder — non-empty stderr, and (per a follow-up
  manual check) `held` on line 1 with a `pid=` line, both of which the test
  rejects.
- Restored by the inverse exact-string replacement (`/*)` →
  `/* | '')`). Grep-proved: `grep -c "/\* | ''" lib/probes.sh` → `1`; `grep
  -n "/\*)" lib/probes.sh` → no hit. Full suite re-run
  (`scripts/run-bats.sh tests/probes.bats tests/probes-edges.bats
  tests/probes-tools.bats tests/probes-config.bats`, foreground): back to
  26 passed, 3 failed — the same three genuine reds above, nothing else
  disturbed.

### `no .git above cwd keeps cwd`

- Mutation: in `lib/probes.sh` `_probe_resolve_path`, `*) printf '%s/%s\n'
  "$2" "$1" ;;` → `*) printf '%s\n' "$1" ;;` (dropping the `$2` join, a
  string occurring once in the file).
- Run: `scripts/run-bats.sh tests/probes-config.bats --filter "no .git above cwd keeps cwd"`
  (foreground).
- Result: 0 passed, 1 failed — `not ok 1 no .git above cwd keeps cwd`,
  failing at line 115 on `printf '%s\n' "$output" | grep -qxF
  "path=$lock"`: with `$2` dropped from the join, the relative extracted
  path (`.git/index.lock`) passes through unresolved, so `path=` never
  matches `$2/.git/index.lock`.
- Restored by the inverse exact-string replacement (`printf '%s\n' "$1" ;;`
  → `printf '%s/%s\n' "$2" "$1" ;;`). Grep-proved: `grep -n '\*) printf'
  lib/probes.sh` shows only the restored `*) printf '%s/%s\n' "$2" "$1" ;;`
  line; `git diff --stat lib/probes.sh` is empty. Full suite re-run
  (same four files, foreground): back to 26 passed, 3 failed — the same
  three genuine reds, nothing else disturbed.

`lib/probes.sh` ends this dispatch byte-for-byte as committed (`git diff
--stat lib/probes.sh` empty both after this proof and at report time).

## shellcheck

```
cd /Users/david/code/sandbox-lies && shellcheck tests/probes-config.bats tests/helpers/probes.bash
```
One `SC1091 (info)` notice on `tests/probes-config.bats`'s pre-existing-style
`source "$ROOT/lib/probes.sh"` line — the same notice every other probes
suite carries, unrelated to this dispatch, resolved when shellcheck runs over
the whole tracked set (`just precommit`). No finding on
`tests/helpers/probes.bash`.

## Self-quiet check

```
cd /Users/david/code/sandbox-lies && bash lib/matchers.sh < tests/probes-config.bats; echo rc=$?
cd /Users/david/code/sandbox-lies && bash lib/matchers.sh < tests/helpers/probes.bash; echo rc=$?
```
No stdout from either; `rc=1` both times.

## Line counts

```
142 tests/probes-config.bats
 84 tests/helpers/probes.bash
206 lib/probes.sh
```
All under the 400-line cap; `lib/probes.sh` unchanged from HEAD (206 lines
before and after this dispatch).

## Scope held

Touched `tests/probes-config.bats` (new) and `tests/helpers/probes.bash`
(one helper added). `lib/probes.sh` was edited only for the two mutation
proofs above and is restored to its committed state at the end of this
dispatch. Not touched: `probe_config_lock`'s real extraction, the
helper-lift GREEN work, the `$2`-ancestor walk-up, the `$2` fallback to the
working directory, `docs/`, and every slice other than 8. `docs/design.md`'s
pre-existing uncommitted orchestrator edit was left alone. Nothing committed.
