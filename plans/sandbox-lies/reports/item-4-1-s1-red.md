# Item 4.1 slice 1 — RED

External contract slice: `mask outcome through the hook`, plus the flag-neutral
mask-wording pin, the BSD-stub re-run, and the `git_lock`/`config_lock` row
extension in `tests/verdicts.bats` with a sibling test transcribing
`lock-detectors.md`'s `mask`/`gone` text.

## SUT stub (k=1)

`lib/verdicts.sh` gains two inert stubs, appended after `verdict_phantom_gitadd`:

```sh
verdict_git_lock() {
  printf '\n\n'
}

verdict_config_lock() {
  printf '\n\n'
}
```

`hooks/annotate.sh` is untouched — it does not source or call `lib/probes.sh`
yet; that wiring is this slice's GREEN.

## New file: tests/hook-locks.bats

Three cases, all stubbing `probe_git_lock` in the copied `lib/probes.sh` via
`stub_lib` (the fixture's absolute path never reaches a real probe):

- `mask outcome through the hook` — `fire-lock-add-commit.txt` as a failure
  payload, stub prints `mask`; asserts `additionalContext` contains
  `Re-run the same command with` and `GIT_INDEX_FILE`, and `systemMessage`
  equals `index.lock — sandbox mask, not a real lock`.
- `mask paragraph is flag-neutral under flag true` — same fixture and stub,
  flag `true`; asserts `additionalContext` contains `once no sandboxed
  command is running` (the flag-neutral mask clause).
- `mask outcome through the hook under BSD stubs` — re-runs the first case
  with `make_bsd_stubs grep sed` on `PATH`.

## Changed file: tests/verdicts.bats

- `rows()` gains ten rows: `git_lock`/`config_lock` × `mask`/`gone`/`held`/
  `orphan`/`unknown`.
- New test `lock verdict text matches lock-detectors.md`, transcribing
  `git_lock`/`config_lock` `mask` and `gone` paragraphs and human lines from
  `docs/references/lock-detectors.md` verbatim (held/orphan/unknown are
  slices 2-3's, since they interpolate probe values).

## Per-test output (foreground run, `bats tests/hook-locks.bats
tests/verdicts.bats`)

```
1..8
not ok 1 mask outcome through the hook
# (in test file tests/hook-locks.bats, line 36)
#   `printf '%s' "$ctx" | grep -qF 'Re-run the same command with'' failed
not ok 2 mask paragraph is flag-neutral under flag true
# (in test file tests/hook-locks.bats, line 55)
#   `printf '%s' "$ctx" | grep -qF 'once no sandboxed command is running'' failed
not ok 3 mask outcome through the hook under BSD stubs
# (in test file tests/hook-locks.bats, line 70)
#   `[ "$sys" = 'index.lock — sandbox mask, not a real lock' ]' failed
not ok 4 verdicts under 400 chars
# (in test file tests/verdicts.bats, line 74)
#   `[ "$(printf '%s\n' "$text" | awk 'END { print NR }')" -eq 2 ]' failed
ok 5 verdict text is quiet
ok 6 verdict text matches detectors.md
not ok 7 lock verdict text matches lock-detectors.md
# (in test file tests/verdicts.bats, line 131)
#   `[ "$line1" = 'The lock in this error is a sandbox artefact and the repository is healthy. Re-run the same command with `dangerouslyDisableSandbox: true`; if it already ran that way, re-run it once no sandboxed command is running. A repeat failure on a commit whose hook stages files is that hook leaking `GIT_INDEX_FILE`, not the sandbox.' ]' failed
ok 8 no removal instruction
```

Tests 1, 2, 3 (new, `tests/hook-locks.bats`), 4 and 7 (changed/new,
`tests/verdicts.bats`) all fail on their stated assertion — a `grep -qF`
finding no match or a `[` string/count comparison — never on a missing
symbol. Verified the failure is a genuine mismatch rather than a masked
error: manually ran the hook with the same stub and payload outside bats —
exit 0, empty stdout (the hook never reaches its probe-driven text because
`annotate.sh` doesn't call the probe yet) — and confirmed `jq -r` on that
empty output exits 0 with no output rather than erroring, so the subsequent
`grep`/`[` comparisons fail cleanly on absent/empty text. Tests 5, 6, 8 are
pre-existing and unaffected by this slice's changes; they stay green.

Full suite (`bats tests/*.bats`, 135 tests): only the same five tests fail
(45-47, 131, 134 in the full numbering); no regressions elsewhere.

## Mutation proof

None required. Every new or extended assertion targets behaviour not yet
present in the SUT (`annotate.sh` does not call probes; `verdict_git_lock`/
`verdict_config_lock` are inert stubs; the row-table extension exercises text
that does not exist yet) — ordering itself supplies the red, per
`craft:test-discipline`'s rule that a mutation is needed only where the
behaviour already exists.

## Verification

- `shellcheck tests/hook-locks.bats lib/verdicts.sh tests/verdicts.bats` —
  clean.
- Line counts: `tests/hook-locks.bats` 71, `tests/verdicts.bats` 166,
  `lib/verdicts.sh` 37 — all well under the 400-line cap.

## Scope note

No commit. `hooks/annotate.sh` and `lib/probes.sh` are untouched (the
hook→probe wiring is GREEN scope for this slice). Slices 2-9 of Item 4.1 are
untouched.
