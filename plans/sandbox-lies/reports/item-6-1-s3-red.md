# RED: Item 6.1 slice 3 — `readonly and nopath`

**Scope**: `tests/hook-candidates.bats`, `tests/verdicts.bats`. No SUT change:
`lib/verdicts.sh`'s `verdict_readonly_path` still handles only the `writable`
outcome; `readonly` and `nopath` fall through the `case` with no matching arm
and print nothing.
**Date**: 2026-09-26
**Mode**: RED

## Tests written

### `tests/hook-candidates.bats`

Two new cases, added beside `writable outcome through the hook`, both using
`fire-readonly-path-cp-tmp.txt` as a failure payload, flag absent (readonly-path
has no flag policy wired yet — that is slice 4):

- `readonly outcome through the hook` — `stub_probe_kv readonly_path readonly
  'path=/r/y'`; asserts `additionalContext` contains `not a sandbox effect` and
  `systemMessage` equals `read-only — real`.
- `nopath outcome through the hook` — `stub_probe_kv readonly_path nopath`
  with no extra line, matching the probe contract (`nopath` carries no `path=`
  line); asserts `additionalContext` contains `write allowlist` and `compare
  modified files against the target`, and `systemMessage` equals `read-only —
  sandbox allowlist`.

Two cases rather than one: each pins a distinct outcome's own text and human
line independently, and a shared case would leave the reader guessing which
probe run produced which failure.

### `tests/verdicts.bats`

- Two rows added to `rows()`: `readonly_path readonly` and `readonly_path
  nopath`.
- One new case added beside `readonly-path writable verdict text matches
  detectors.md`: `readonly-path readonly and nopath verdict text matches
  detectors.md`. It transcribes detectors.md's Verdicts list:
  - `readonly` — `` `<path>` is not writable outside the sandbox either; this
    is not a sandbox effect. `` — checked both with a `path=` line (the path
    interpolated in backticks, the same tricky string `/r/a b&c\1/x` the
    writable case uses) and with empty stdin (`The path` fallback), mirroring
    how the writable case pins both forms.
  - `nopath` — composed, per the runbook's list revision, from its opening
    sentence (`The sandbox's write allowlist most likely refused this
    write.`) plus the writable paragraph's text from `Re-run` on (`` Re-run
    the whole call with `dangerouslyDisableSandbox: true` or, if it only read
    a command-output file such as a `*.log`, the command that wrote that
    file. For `.claude/settings.json`, use the `update-config` skill. A merge
    or checkout that died here may be partial: compare modified files
    against the target first. ``). Checked with no `path=` line, as the
    probe contract gives none for `nopath`.
  - Human lines `read-only — real` and `read-only — sandbox allowlist`.

## Run: `direnv exec . scripts/run-bats.sh tests/verdicts.bats
tests/hook-candidates.bats`

```
not ok 1 verdicts under 400 chars
# (in test file tests/verdicts.bats, line 80)
#   `[ "$(printf '%s\n' "$text" | awk 'END { print NR }')" -eq 2 ]' failed
not ok 6 readonly-path readonly and nopath verdict text matches detectors.md
# (in test file tests/verdicts.bats, line 188)
#   `[ "$line1" = "\`$p\` is not writable outside the sandbox either; this is not a sandbox effect." ]' failed
not ok 15 readonly outcome through the hook
# (in test file tests/hook-candidates.bats, line 120)
#   `printf '%s' "$ctx" | grep -qF 'not a sandbox effect'' failed
not ok 16 nopath outcome through the hook
# (in test file tests/hook-candidates.bats, line 136)
#   `printf '%s' "$ctx" | grep -qF 'write allowlist'' failed

bats: 13 passed, 4 failed
```

Each failure is a genuine assertion failure, not an error:

- `verdicts under 400 chars` — the row loop runs under bats' implicit
  `errexit` and stops at the first row that fails; `readonly_path writable`
  (already implemented) passes first, then `readonly_path readonly` yields
  zero lines from `verdict_text`, so `NR -eq 2` fails.
- `readonly-path readonly and nopath verdict text matches detectors.md` —
  `verdict_readonly_path readonly` prints nothing (no matching `case` arm),
  so `line1` is empty and the equality fails.
- `readonly outcome through the hook` — confirmed manually
  (`printf '%s' "$payload" | bash <copy>/hooks/annotate.sh` with a probe
  stub printing `readonly`/`path=/r/y`) that the hook's output is empty:
  the verdict contributes no paragraph or human line, so `context` and
  `human` both stay empty and `annotate.sh` exits 0 with no stdout at all.
  `ctx`/`sys` then read as empty strings (`jq -r` on empty stdin exits 0
  with no output), and the `grep -qF` assertion fails on that empty string
  — not an error.
- `nopath outcome through the hook` — confirmed the same way with a probe
  stub printing `nopath` alone; same empty-output mechanism, same
  non-erroring assertion failure.

No mutation proof: none of the new assertions passes against the unmodified
SUT (`verdict_readonly_path` implements no `readonly` or `nopath` behaviour
at all — the case statement has no arm for either), so nothing here needed
naming as already-present behaviour.

## Existing cases

Full suite (`direnv exec . just test`): 190 passed, 4 failed — exactly the
four listed above; no other case changed status. Of those four, only
`verdicts under 400 chars` is a pre-existing case: the two new rows turn it
red on the `NR -eq 2` assertion (documented above). The other three are new
cases in this slice's own diff.

## Self-quiet

```
$ bash lib/matchers.sh < tests/hook-candidates.bats; echo $?
1
$ bash lib/matchers.sh < tests/verdicts.bats; echo $?
1
```

Both exit 1 with empty stdout.

## File sizes

- `tests/hook-candidates.bats`: 157 lines (was 126).
- `tests/verdicts.bats`: 302 lines (was 274).

Both under the 400-line cap.

## Lint

`shellcheck tests/hook-candidates.bats tests/verdicts.bats`: clean, exit 0.

## Scope

No change to `lib/verdicts.sh`, `hooks/annotate.sh`, `lib/probes*.sh`,
`docs/`, or `memory/`. No commit made.
