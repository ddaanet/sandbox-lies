# Item 4.3 slices 2-5 — RED: probe_readonly_path, no probe without a verdict

2026-09-26. Mode RED. Scope: `probe_readonly_path`'s stub in `lib/probes.sh`,
new `tests/probes-readonly.bats`, `tests/helpers/probes.bash` (one new
builder), `tests/hook-candidates.bats` (slice 5's case), and a mechanical
move of the shared `stub_probe` helper from `tests/hook-locks.bats` into
`tests/helpers/hook.bash` so `hook-candidates.bats` can reuse it, per the
dispatch's own standing rule ("`tests/hook-locks.bats` has `stub_probe
<name> <outcome>` … reuse it"). Out of scope: any readonly-path verdict or
flag policy (Item 6.1), memory, docs/, the matcher (Item 4.3 slice 1,
already shipped).

## SUT stub

`probe_readonly_path` added to `lib/probes.sh`, inert (`cat >/dev/null`, no
output, exit 0) — k=1 for the probe, since slice 1 built only the matcher.
Placed after `probe_config_lock`, before the shared lock-probe internals it
does not use.

## Interpretation flagged (relative quoted path)

The `### readonly-path` entry's Probe paragraph ("Extract the first quoted
path … `test -w` on it, or on its parent") is silent on what a *relative*
quoted path resolves against. The cut `fire-readonly-path-python-errno`
fixture's own path is relative (`hooks/hooks.json`). Per the dispatch's
instruction, this RED asserts the reviewer's-eye reading: resolution against
the payload `cwd` ($2), the same contract `_probe_lock_at`'s
`_probe_resolve_path` already gives the lock probes. New test `relative path
resolves against cwd` (not named by the slice list, added under this
interpretation) pins it: `path=` comes out `$cwd/hooks/hooks.json`. This is
an interpretation, not a spec-cited fact — the code review should confirm or
override it before GREEN grows the join.

## Tests added (`tests/probes-readonly.bats`, new file)

Refusal lines are the cut `fire-readonly-path-cp-tmp` and
`-python-errno` fixtures with their quoted path replaced at run time
(`readonly_path_text`, `tests/helpers/probes.bash`), never held whole in
this file (self-quiet, FR-11). `RO_DIR` reset empty in `setup`; `teardown`
restores `chmod 755` on it unconditionally, a no-op when unset.

| test | slice | asserts | result against inert stub |
|---|---|---|---|
| `writable path` | 2 | `writable` + `path=` a file under `$BATS_TEST_TMPDIR` | not ok — `[ "${output%%$'\n'*}" = writable ]` failed (output empty) |
| `relative path resolves against cwd` | interpretation (above) | `writable` + `path=$cwd/hooks/hooks.json` | not ok — same assertion, output empty |
| `absent file checks its parent` | 3 | missing file in a writable dir → `writable`; the same in a `chmod 555` dir → `readonly` | not ok — writable-branch assertion fails first (output empty); the `chmod 555` half is unreached this run since bats aborts the test at the first failed `[ ]` |
| `no quoted path` | 4 | `nopath`, no `path=` line | not ok — `[ "${output%%$'\n'*}" = nopath ]` failed (output empty) |
| `writable path survives BSD grep and sed` | Portability (runbook cross-cutting) | `writable path`'s input, re-run under `make_bsd_stubs grep sed` | not ok — same assertion, output empty |

`absent file checks its parent` skips its `chmod 555` half when `id -u` is
`0` (root can write through the mode anyway); this run was uid 1000, so the
skip did not trigger — the run stopped at the writable-branch assertion
before reaching it regardless, for the reason stated above.

## Test added (`tests/hook-candidates.bats`, slice 5)

`hook silent without a verdict`: `fire-readonly-path-cp-tmp.txt` as a
`PostToolUseFailure` payload, flag absent, `stub_probe readonly_path mask`
(now the shared helper). Asserts `$status` 0, empty `$output`, and
`$PROBE_CALLED` absent. This test passed unmodified against the current
tree — the behaviour it names (no `verdict_readonly_path` exists yet, so
`hooks/annotate.sh`'s `declare -F "$fn"` gate never reaches the probe) is
already shipped, generically, by Item 4.1. Proved by mutation below rather
than left as an unproven pass.

## Commands run

| command | result |
|---|---|
| `direnv exec . bats tests/probes-readonly.bats` | 1..5, all 5 not ok, each on its named assertion, none errored |
| `direnv exec . bats tests/hook-candidates.bats tests/hook-locks.bats` (pre-mutation) | 1..18, all ok, including `hook silent without a verdict` (4) and the pre-existing `no probe without a verdict` (17) |
| `direnv exec . shellcheck -x tests/probes-readonly.bats tests/hook-candidates.bats tests/hook-locks.bats tests/helpers/hook.bash tests/helpers/probes.bash lib/probes.sh` | exit 0, no findings |
| `direnv exec . bats tests/docs.bats` | ok — self-quiet holds with the new files in place |
| `direnv exec . just test` (full suite, pre-mutation) | `bats: 174 passed, 5 failed` — exactly the five `probes-readonly.bats` cases above, no other file regressed |

## Mutation proof

One mutation, exact-string replace in `hooks/annotate.sh` (the SUT for this
one test — `probe_readonly_path` itself has no behaviour yet to prove).
`declare -F "$fn" >/dev/null || continue` occurs once in the file, at line
94, gating the verdict lookup before a probe is ever run — replacing its
`continue` with a no-op makes the hook call a probe whose verdict is
missing, per the dispatch's own suggested proof.

| # | test | mutation | before → after | red confirmed | restore confirmed |
|---|---|---|---|---|---|
| 1 | `hook silent without a verdict` | let the verdict-gate fall through instead of skipping | `declare -F "$fn" >/dev/null \|\| continue` → `declare -F "$fn" >/dev/null \|\| :` | `hook silent without a verdict` (4) reds on `[ -z "$output" ]` (the now-undefined `verdict_readonly_path` call errors, its "command not found" text reaching `$output` through the hook's own stderr, merged by `run`'s default capture); the pre-existing `no probe without a verdict` (17) in `tests/hook-locks.bats` reds the same way, on the same shared gate — expected, not a new test, since both exercise the identical mechanism. Every other case (1-3, 5-16, 18) stayed green | `grep -c 'declare -F "\$fn" >/dev/null \|\| :' hooks/annotate.sh` → `0`; `direnv exec . bats tests/hook-candidates.bats tests/hook-locks.bats` → 1..18, all ok |

`git diff --stat hooks/annotate.sh` after the restore is empty — the file is
byte-identical to what this dispatch received.

## Full suite after restore

`direnv exec . just test`: `bats: 174 passed, 5 failed` — the same five named
`probes-readonly.bats` cases, unchanged; `hooks/annotate.sh` carries no
uncommitted change.

## Files touched

- `lib/probes.sh` — `probe_readonly_path` stub (inert), placed after
  `probe_config_lock`.
- `tests/probes-readonly.bats` (new) — the five cases above.
- `tests/helpers/probes.bash` — `readonly_path_text` builder; header comment
  now lists this new file among its loaders.
- `tests/helpers/hook.bash` — `stub_probe`, moved here from
  `tests/hook-locks.bats` for the second caller (`hook-candidates.bats`);
  header comment notes the shared use.
- `tests/hook-locks.bats` — its local `stub_probe` definition removed
  (comment left pointing at the shared one); no test's behaviour changed.
- `tests/hook-candidates.bats` — `hook silent without a verdict` (slice 5).
- `hooks/annotate.sh` — untouched net of this dispatch (mutated and restored
  for the proof above only).

No commit: RED leaves the tests and this report uncommitted for the slice's
GREEN commit to carry.
