# Item 8.0 slice 1 — RED report

`lock verdicts word the re-run by the flag`. No implementation touched:
`lib/verdicts.sh` and `hooks/annotate.sh` are unchanged from `main`. Every
red below is a genuine assertion failure against the unchanged SUT (a
verdict called with an extra `$2` today simply ignores it) — no mutation
proof was needed for any test in this slice.

## Files changed

- `tests/verdicts.bats` — `rows()`/`verdict_text()`/`all_verdict_text()`
  extended with an optional third (flag) field; the row table gained
  `git_lock`/`config_lock` `mask`/`orphan`/`unknown` rows at flag `true`; a
  new `text_lacks` helper (mirrors `hook-locks.bats`'s `assert_lacks`); the
  transcription test now covers mask at both flag values plus the
  config-lock settings act; the two interpolation tests now pass an explicit
  flag to `orphan`/`unknown`; a new test
  `lock verdicts word the re-run by the flag` added.
- `tests/hook-locks.bats` — `mask paragraph is flag-neutral under flag true`
  replaced by `mask paragraph words the re-run by the flag`; `config-lock
  mask names config.lock and update-config` replaced by `config-lock mask
  names config.lock and the settings act by path` (the old test always
  expected `update-config` regardless of the probed path — that assumption
  is what D-17's config-lock settings act now makes path-conditional; the
  hook-level test had to be adjusted to the same conditional or it would
  regress under GREEN with no way for GREEN to fix it, since GREEN may not
  edit tests).

## Per-test failing output

### tests/verdicts.bats

**`lock verdict text matches lock-detectors.md`** (updated)
```
not ok 8 lock verdict text matches lock-detectors.md
# (in test file tests/verdicts.bats, line 253)
#   `[ "$line1" = 'The lock in this error is a sandbox artefact and the repository is healthy. Re-run the same command with `dangerouslyDisableSandbox: true`. A repeat failure on a commit whose hook stages files is that hook leaking `GIT_INDEX_FILE`, not the sandbox.' ]' failed
```
(Current `verdict_git_lock mask` appends the old flag-neutral "if it already
ran that way, re-run it once no sandboxed command is running." clause, so
the exact-match against the new flag-false wording fails.)

**`verdict_git_lock held|orphan|unknown interpolate probe values`** (updated)
```
not ok 9 verdict_git_lock held|orphan|unknown interpolate probe values
# (in test file tests/verdicts.bats, line 330)
#   `[ "$line1" = 'The lock exists outside the sandbox (7 bytes, age 12s) and no process holds it. Retry the command with `dangerouslyDisableSandbox: true`; a second identical failure means the lock predates this session.' ]' failed
```
(Current `orphan` text reads "Retry the command unsandboxed; …", not the
flag-worded "Retry the command with `dangerouslyDisableSandbox: true`; …".)

**`verdict_config_lock held|orphan|unknown interpolate probe values`** (updated)
```
not ok 10 verdict_config_lock held|orphan|unknown interpolate probe values
# (in test file tests/verdicts.bats, line 376)
#   `[ "$line1" = 'The lock exists outside the sandbox (7 bytes, age 12s) and no process holds it. Retry the command with `dangerouslyDisableSandbox: true`; a second identical failure means the lock predates this session.' ]' failed
```
(Same cause as above, config-lock side.)

**`lock verdicts word the re-run by the flag`** (new)
```
not ok 11 lock verdicts word the re-run by the flag
# (from function `text_lacks' in file tests/verdicts.bats, line 89,
#  in test file tests/verdicts.bats, line 414)
#   `text_lacks "$text" 'once no sandboxed'' failed
```
(`verdict_git_lock mask false`'s current text contains both the
`dangerouslyDisableSandbox: true` wording and the "once no sandboxed"
wording in the same fixed sentence, so the flag-false exclusion check reds
first.)

Unaffected by this slice, still green: `verdicts under 400 chars` and
`verdict text is quiet` (extended to run every new flag-`true` row; the
length/quiet invariants they check are orthogonal to the wording change and
already hold), `verdict text matches detectors.md`, `candidate verdict text
matches detectors.md`, the three `readonly-path * verdict text matches
detectors.md` tests, `no removal instruction`.

### tests/hook-locks.bats

**`mask paragraph words the re-run by the flag`** (replaces `mask paragraph
is flag-neutral under flag true`)
```
not ok 2 mask paragraph words the re-run by the flag
# (from function `assert_lacks' in file tests/hook-locks.bats, line 36,
#  in test file tests/hook-locks.bats, line 81)
#   `assert_lacks "$ctx_false" 'once no sandboxed'' failed
```
(`hooks/annotate.sh` does not yet pass `"$flag"` to the verdict; the fixed
mask text carries both wordings under either flag today.)

**`config-lock mask names config.lock and the settings act by path`**
(replaces `config-lock mask names config.lock and update-config`)
```
not ok 8 config-lock mask names config.lock and the settings act by path
# (from function `assert_lacks' in file tests/hook-locks.bats, line 36,
#  in test file tests/hook-locks.bats, line 214)
#   `assert_lacks "$ctx" 'update-config'' failed
```
(Current `verdict_config_lock mask` always mentions `update-config`
regardless of the probed `path=`; the new test asserts it is absent for a
`.git/config.lock` path.)

Unaffected, still green: `mask outcome through the hook`, `mask outcome
through the hook under BSD stubs`, `held interpolates the pid`, `orphan and
unknown interpolate size and age`, `orphan with neither bytes nor age
interpolates no empty value`, `probe receives flag and cwd`, `piped lock
failure on a success payload`, `orphan with one of bytes and age
interpolates that one alone`, `every lock fixture yields its verdict`, `no
probe without a verdict`, `probe reads the result text on stdin`.

## Mutation proof

None required: every new or changed assertion above fails on its own value
comparison against the unchanged `lib/verdicts.sh`/`hooks/annotate.sh`, not
on a missing symbol, and none of them passed vacuously against the current
wording.

## Commands run

- `shellcheck -x tests/verdicts.bats` — clean.
- `shellcheck -x tests/hook-locks.bats` — clean.
- `scripts/run-bats.sh tests/verdicts.bats` — 8 passed, 4 failed (listed
  above).
- `scripts/run-bats.sh tests/hook-locks.bats` — 11 passed, 2 failed (listed
  above).

No commit made.
