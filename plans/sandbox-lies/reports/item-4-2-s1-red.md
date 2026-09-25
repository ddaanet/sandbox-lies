# Item 4.2 slices 1-2 — RED

Batched dispatch: slice 1 (`fire and quiet fixtures`, `tests/matchers.bats`)
and slice 2 (`<detector> flag policy`, `tests/hook-candidates.bats`), for the
three shipping rows `tmpdir-unset`, `resume-lost`, `seccomp-init`.
`zellij-socket` stays a candidate (zero corpus hits, `item-3-2.md`): no test,
code or memory change for it. `readonly-path` is Item 4.3, out of scope here.

## SUT stubs (k=1 for this item)

`lib/matchers.sh` gains `match_tmpdir_unset`, `match_resume_lost`,
`match_seccomp_init`, each `return 1` and none wired into `detect()` — wiring
an always-failing matcher in changes nothing observable, but the note in the
dispatch ("`detect` must not yet list them if that would make a test error
rather than fail") is about the verdict side, not this one; left unwired here
to keep the two stub sets symmetric until GREEN grows the real discriminator.

`lib/verdicts.sh` gains `verdict_tmpdir_unset`, `verdict_resume_lost`,
`verdict_seccomp_init`, each an empty body (`:`) — needed so
`tests/verdicts.bats`'s `rows()`-driven checks call a real function (an
undefined `verdict_tmpdir_unset` would error, not fail) while still printing
nothing.

## Test changes

`tests/matchers.bats`:

- `expected_for` rows for `fire-tmpdir-unset-redirect`, `fire-tmpdir-unset-cp-stat`,
  `fire-resume-lost-two-turn`, `fire-seccomp-init-sed` flipped from `: ;;` (no
  verdict) to their detector name — this flip is the slice's red, per the
  Phase 4 preamble. The three `quiet-*` rows for these detectors are
  unchanged (already `: ;;`); Item 3.2 already added them and they are
  already exercised by the pre-existing "the whole fixture sweep survives BSD
  grep, sed and mktemp" test, so no new quiet-side test was added — one would
  currently have no possible mutation (no matcher logic exists yet to flip),
  hence no non-vacuous test could be written for it in this slice.
- Four new named cases (`detector D: shipped candidates` section, mirroring
  the file's per-fixture style): `tmpdir-unset fires on a bash redirect
  collapsed under root`, `tmpdir-unset fires on a cp stat of a path collapsed
  under root`, `resume-lost fires on a lost transcript refusal`,
  `seccomp-init fires on a sandbox init failure` — each `assert_fixture` on
  its fire fixture.

`tests/verdicts.bats`:

- `rows()` gains `tmpdir_unset -`, `resume_lost -`, `seccomp_init -`.
- New case `candidate verdict text matches detectors.md`, transcribing the
  three candidates' `Verdict.` paragraphs and human lines from
  `docs/references/detectors.md` verbatim, checked against
  `verdict_tmpdir_unset`/`verdict_resume_lost`/`verdict_seccomp_init`.

`tests/hook-candidates.bats` (new file, first to exist for candidate hook
cases per the Phase 4 preamble — carries the one BSD-portability case any
such file owes):

- `tmpdir-unset fires only when the flag is true` — `fire-tmpdir-unset-redirect`
  (failure payload, its first line is `Exit code 1`), flag `true`: context
  contains `/tmp/claude/`; flag absent: empty stdout.
- `resume-lost fires only when the flag is false` — `fire-resume-lost-two-turn`
  (post payload, no `Exit code` first line), flag absent: context contains
  `one unsandboxed call`; flag `true`: empty stdout.
- `seccomp-init stays silent when the flag is true` — `fire-seccomp-init-sed`
  (failure payload), flag absent: context contains `Retry the identical
  command once`; flag `true`: empty stdout.
- `tmpdir-unset flag policy survives BSD grep and sed` — the `tmpdir-unset`
  fire case re-run under `make_bsd_stubs grep sed`, flag `true`, same context
  assertion.

Each hook-candidates.bats case asserts `[ -n "$output" ]` (with a diagnostic
message) before extracting `additionalContext` via `jq`, specifically so the
current all-empty-output state fails on that explicit assertion rather than
on a `jq` parse error over empty input.

## Red run

```
$ direnv exec . bats tests/matchers.bats
...
not ok 17 tmpdir-unset fires on a bash redirect collapsed under root
#   fixture fire-tmpdir-unset-redirect: expected [tmpdir-unset] got []
not ok 18 tmpdir-unset fires on a cp stat of a path collapsed under root
#   fixture fire-tmpdir-unset-cp-stat: expected [tmpdir-unset] got []
not ok 19 resume-lost fires on a lost transcript refusal
#   fixture fire-resume-lost-two-turn: expected [resume-lost] got []
not ok 20 seccomp-init fires on a sandbox init failure
#   fixture fire-seccomp-init-sed: expected [seccomp-init] got []
not ok 30 the whole fixture sweep survives BSD grep, sed and mktemp
#   fixture fire-resume-lost-two-turn: expected [resume-lost] got []
(29 other tests pass)

$ direnv exec . bats tests/verdicts.bats
...
not ok 1 verdicts under 400 chars
#   `[ "$(printf '%s\n' "$text" | awk 'END { print NR }')" -eq 2 ]' failed
not ok 4 candidate verdict text matches detectors.md
#   `[ "$line1" = '`$TMPDIR` is unset outside the sandbox, ...' ]' failed
(6 other tests pass)

$ direnv exec . bats tests/hook-candidates.bats
not ok 1 tmpdir-unset fires only when the flag is true
#   `|| { echo "no verdict emitted, flag true" >&2; return 1; }' failed
#   no verdict emitted, flag true
not ok 2 resume-lost fires only when the flag is false
#   `|| { echo "no verdict emitted, flag absent" >&2; return 1; }' failed
#   no verdict emitted, flag absent
not ok 3 seccomp-init stays silent when the flag is true
#   `|| { echo "no verdict emitted, flag absent" >&2; return 1; }' failed
#   no verdict emitted, flag absent
not ok 4 tmpdir-unset flag policy survives BSD grep and sed
#   `|| { echo "no verdict emitted under BSD stubs, flag true" >&2; return 1; }' failed
#   no verdict emitted under BSD stubs, flag true
```

Every red fails on a value/emptiness assertion (`expected [x] got []`, a
2-line-count check, a string equality, an explicit `[ -n "$output" ]` probe)
— never an `ImportError`/`command not found` equivalent or a missing symbol.
`match_tmpdir_unset`/`match_resume_lost`/`match_seccomp_init` and
`verdict_tmpdir_unset`/`verdict_resume_lost`/`verdict_seccomp_init` are
defined (stubs), so every failure runs the real (inert) code path rather
than erroring on an absent function.

Full suite: `direnv exec . scripts/run-bats.sh tests/` — 146 passed, 11
failed, 157 total. 11 = 4 new matchers.bats cases + 1 pre-existing
matchers.bats case flipped by the `expected_for` edit (`the whole fixture
sweep survives BSD grep, sed and mktemp`) + 1 pre-existing verdicts.bats case
flipped by the `rows()` edit (`verdicts under 400 chars`) + 1 new
verdicts.bats case + 4 new hook-candidates.bats cases. No other test
regressed (`git status --porcelain -- tests` shows only `matchers.bats`,
`verdicts.bats` modified and `hook-candidates.bats` new; `lib/` shows only
the stub additions, and re-running the pre-existing lock/phantom/config-lock
sections in `matchers.bats`, `verdicts.bats` and `hook-locks.bats` stayed
green throughout).

No mutation proof needed: every new and newly-red test fails on a genuine
assertion mismatch produced by the stubbed-inert SUT, none of them passed on
first run.

## Checks passed

- `shellcheck lib/matchers.sh lib/verdicts.sh tests/hook-candidates.bats
  tests/matchers.bats tests/verdicts.bats`: clean
- `wc -l`: `tests/matchers.bats` 351, `tests/verdicts.bats` 251,
  `tests/hook-candidates.bats` 90, `lib/matchers.sh` 149, `lib/verdicts.sh`
  109 (400-line cap)
- `direnv exec . bats tests/matchers.bats tests/verdicts.bats
  tests/hook-candidates.bats`: the 11 intended reds, no error-class failure
- `direnv exec . scripts/run-bats.sh tests/`: 146 passed, 11 failed, 157
  total — the 11 above, no other regression
- `direnv exec . bats tests/docs.bats`: passes (self-quiet: no tracked file
  outside fixtures fires a detector)
- `git status --porcelain`: `lib/matchers.sh`, `lib/verdicts.sh`,
  `tests/matchers.bats`, `tests/verdicts.bats` modified,
  `tests/hook-candidates.bats` new; no other tracked file touched
