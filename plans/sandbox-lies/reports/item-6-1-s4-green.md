# GREEN: Item 6.1 slice 4 — `silent unsandboxed`

**Scope**: `hooks/annotate.sh` (the candidate flag-policy `case`). No test
edits — the batch is the one failing case from RED/test-review,
`readonly-path flag policy` in `tests/hook-candidates.bats`.
**Date**: 2026-09-26
**Mode**: GREEN

## Growth

One test in the batch, one change. Added `readonly-path:true` as a fourth
arm of the flag-policy `case` in `hooks/annotate.sh` (the
`tmpdir-unset:false | resume-lost:true | seccomp-init:true` line), wrapped
onto a continuation line to stay under the column width the file already
uses:

```sh
case "$name:$flag" in
  tmpdir-unset:false | resume-lost:true | seccomp-init:true | \
    readonly-path:true) continue ;;
esac
```

Updated the comment immediately above it (which lists each candidate's
policy) to add `readonly-path` to the "silent when [the flag] is [true]"
clause, alongside `seccomp-init`.

## Order tests were made to pass

1. `readonly-path flag policy` (`tests/hook-candidates.bats`) — the batch's
   only failing test. Implemented the `case` arm and comment above in one
   step (the minimal change: a `case` gate with no probe call in either
   pattern-matched branch already places the gate before the probe runs, per
   `docs/references/hook.md`'s "skipped before any probe runs"). Ran the file
   alone first:

   ```
   $ direnv exec . scripts/run-bats.sh tests/hook-candidates.bats
   bats: 8 passed, 0 failed
   ```

   Passed on the first attempt; no second implementation attempt needed.

## Full suite

```
$ direnv exec . just test
scripts/run-bats.sh tests/
bats: 196 passed, 0 failed
```

195 (RED baseline) + 1 (the newly green case) = 196; no other test's status
changed.

## Lint / precommit

`shellcheck hooks/annotate.sh`: clean, exit 0 (the continuation-line `case`
pattern list parses cleanly). No `just lint` recipe exists in this repo
(`just --list` — `precommit` is the gate named in the dispatch).

```
$ direnv exec . just precommit > "$TMPDIR/pc.out" 2>&1; echo "exit=$?"; tail -3 "$TMPDIR/pc.out"
exit=0
scripts/run-bats.sh tests/
bats: 196 passed, 0 failed
precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests
```

No precommit warnings to record.

## Scope check

`docs/references/hook.md` does not enumerate the per-candidate flag
policies (it states the general skip-before-probe rule only), so it stays
unchanged — nothing there became false. `docs/references/detectors.md`'s
`readonly-path` entry already states "Flag policy. Silent when the flag is
true" (written in slice 1); unchanged here.

`git status --porcelain` after the change: only `hooks/annotate.sh` modified
beyond the slice's own tests and reports — no `lib/*` or other file touched.

## File size

`hooks/annotate.sh`: 148 lines. Under the 400-line cap.
