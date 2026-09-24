# Item 2.4 / slice 2 — GREEN report

Dispatch: item-2-4-s2-green. Mode: GREEN.

## Slice (from the runbook, current text)

2. `absent lock, unsandboxed, is gone` — same text, flag `true`: `gone`.
   `non-UTF-8 byte in the path` (slice 1's code review; proven by mutation of
   the extractor's `LC_ALL=C`) — an absent lock under a directory whose name
   holds byte `\351`, flag `false`, run under `LC_ALL=C.UTF-8`: `path=`
   byte-exact.

## Failing batch (from RED + test review)

- `absent lock, unsandboxed, is gone` — red on `[ "${output%%$'\n'*}" = gone ]`
  (the review also added a `path=$lock` exact-line assertion to this test).
- `non-UTF-8 byte in the path` — already green pre-dispatch (mutation-proofed
  by RED and independently reproduced by the test review); no implementation
  change was needed or made for it.

Confirmed the starting state before touching `lib/probes.sh`:

```
not ok 2 absent lock, unsandboxed, is gone
# (in test file tests/probes.bats, line 63)
#   `[ "${output%%$'\n'*}" = gone ]' failed

bats: 2 passed, 1 failed
```

## Implementation

`lib/probes.sh`, `probe_git_lock`: the absent-lock branch printed `mask` only
for `flag = false` and fell through (no output) for `flag = true`. Added the
`gone` branch, keeping `path=` common to both:

```bash
    if [ ! -e "$path" ] && [ ! -L "$path" ]; then
        if [ "$flag" = false ]; then
            printf 'mask\n'
        else
            printf 'gone\n'
        fi
        printf 'path=%s\n' "$path"
    fi
```

Nothing else in `lib/probes.sh` changed. `probe_config_lock` is still the
`cat >/dev/null` stub (out of scope — Item 2.4 slice 8). No present-lock
branch, holder check, `stat`/`wc -c`, character-device rule, or
`probe_config_lock` growth was added — all out of scope for this slice.

## Tests made to pass, one at a time

Only one test needed implementation work:

1. `absent lock, unsandboxed, is gone` — after the edit above, ran the single
   test in isolation and confirmed pass.

`non-UTF-8 byte in the path` required no change; it was already green going
in and stayed green throughout (confirmed by rerunning the full file each
time, per below).

## Full suite run

`cd /Users/david/code/sandbox-lies && scripts/run-bats.sh tests/probes.bats`:

```
bats: 3 passed, 0 failed
```

All three tests in the file pass: slice 1's `absent lock, sandboxed, is mask`,
and this slice's `absent lock, unsandboxed, is gone` and
`non-UTF-8 byte in the path`.

## Lint / precommit

No `just lint` recipe exists in this repo's justfile (`error: Justfile does
not contain recipe 'lint'`) — went straight to `just precommit` per the
dispatch's done criteria.

`cd /Users/david/code/sandbox-lies && just precommit`, final line:

```
scripts/run-bats.sh tests/
bats: 98 passed, 0 failed
precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests
```

No warnings were emitted by precommit for this change.

## Scope held

Only `lib/probes.sh` was edited (the `gone` branch above). `tests/probes.bats`
was not touched in this dispatch — it already carried the RED + test-review
state (both tests plus the `path=` assertion and locale precondition) coming
in. Present-lock outcomes (`orphan`/`held`/`unknown`), size/age, the holder
check, `stat`/`wc -c`, the character-device rule, relative-path resolution
against `$2`, `probe_config_lock`, the `stat` stub, and every other slice
remain untouched and out of scope for this dispatch.
