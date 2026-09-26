# RED: Item 6.1 slice 4 — `silent unsandboxed`

**Scope**: `tests/hook-candidates.bats`. No SUT change: `hooks/annotate.sh`'s
flag-policy `case` (the `tmpdir-unset:false | resume-lost:true |
seccomp-init:true` line) has no `readonly-path` arm, so with the flag `true`
the probe still runs and the verdict still emits.
**Date**: 2026-09-26
**Mode**: RED

## Test written

### `tests/hook-candidates.bats`

One new case, `readonly-path flag policy`, added beside the other
`<detector> flag policy` cases (`tmpdir-unset flag policy`, `resume-lost flag
policy`, `seccomp-init flag policy`), immediately before `writable outcome
through the hook`: silent when the flag is `true` (the runbook's flag-policy
line, `docs/references/detectors.md`'s `### readonly-path` `**Flag
policy.**`).

Uses the readonly-path fire fixture (`fire-readonly-path-cp-tmp.txt`) as a
failure payload and `stub_probe readonly_path writable` (the helper that
records each call via the `$PROBE_CALLED` sentinel, reused rather than
`stub_probe_kv`, since the policy check needs no particular outcome text).
Positive twin first, as the sibling flag-policy cases do: flag absent yields
a non-empty verdict and `$PROBE_CALLED` exists. The sentinel is then removed
so the second run's absence is evidence of that run, not a leftover from the
first; flag `true` then asserts empty stdout and no `$PROBE_CALLED` file, so
the silence is the policy's doing and not an accident of the stub.

## Run: `direnv exec . scripts/run-bats.sh tests/hook-candidates.bats`

```
not ok 4 readonly-path flag policy
# (in test file tests/hook-candidates.bats, line 109)
#   `[ -z "$output" ]' failed

bats: 7 passed, 1 failed
```

Line 109 is the flag-`true` run's `[ -z "$output" ]`. Everything before it in
the same test passed: `status -eq 0`, non-empty `$output` on the flag-absent
run, and `$PROBE_CALLED` present after it — so the case reds exactly on the
silence assertion, not on the earlier probe-call assertion or on an error.
This is a genuine assertion failure: the unmodified hook has no
`readonly-path` arm in its flag-policy `case`, so the flag-`true` run still
runs the stubbed probe and still emits a non-empty verdict object.

No mutation proof needed: the flag-`true` silence this test asserts is not
yet present in `hooks/annotate.sh` at all (no `readonly-path` entry in the
`case`), so nothing here is a behaviour already in the SUT that could pass
vacuously — the test fails on its own assertion directly, with no fixture
question left to settle by mutation.

## Existing cases

Full suite (`direnv exec . just test`): 195 passed, 1 failed — exactly the
new case; no other test changed status.

## Self-quiet

```
$ bash lib/matchers.sh < tests/hook-candidates.bats; echo $?
1
```

Exit 1, empty stdout.

## File size

`tests/hook-candidates.bats`: 179 lines (was 158). Under the 400-line cap.

## Lint

`shellcheck tests/hook-candidates.bats`: clean, exit 0.

## Scope

No change to `hooks/annotate.sh`, `lib/*`, `docs/`, or `memory/` —
`git status --porcelain` shows only `tests/hook-candidates.bats` modified. No
commit made.
