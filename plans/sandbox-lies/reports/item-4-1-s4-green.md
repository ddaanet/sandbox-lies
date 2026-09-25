# Item 4.1 slices 4-6 — GREEN

Batched dispatch: slice 4 (`probe receives flag and cwd`), slice 5
(`config-lock mask names config.lock and update-config`), slice 6 (`piped
lock failure on a success payload`). Slices 4 and 6 were already green at RED
time (existing behaviour, proven by mutation in the RED and test-review
reports) and needed no implementation change. Slice 5 was the batch's one
genuine red, fixed here.

## Tests run, in order made to pass

1. `probe receives flag and cwd` (slice 4) — already `ok` before this
   dispatch's edits (`hooks/annotate.sh` already forwards `"$flag" "$cwd"`).
   No implementation change; re-confirmed green after the slice-5 edit below
   (no shared code path).
2. `config-lock mask names config.lock and update-config` (slice 5) — red
   going in:
   ```
   not ok 1 config-lock mask names config.lock and update-config
   #   `printf '%s' "$ctx" | grep -qF 'config.lock'' failed
   ```
   Grown by editing, together, the three places carrying the config-lock
   `mask` paragraph text: `docs/references/lock-detectors.md` (source),
   `lib/verdicts.sh`'s `verdict_config_lock` `mask` case (mirror), and the
   transcribed assertion in `tests/verdicts.bats` (must keep matching the
   doc). All three changed in one edit since the doc, the verdict function
   and the transcription must stay byte-identical on this paragraph — editing
   them separately would leave the two non-test files disagreeing, or the
   test transcription stale, at every intermediate step.
   Change: in `config-lock`'s `mask` paragraph only (not `git-lock`'s, not
   `config-lock`'s `gone`/`held`/`orphan`/`unknown`), replaced the opening
   `The lock in this error` with `` The `config.lock` in this error ``.
   Ran `bats -f 'config-lock mask names config.lock and update-config'
   tests/hook-locks.bats`: `ok 1`.
3. `piped lock failure on a success payload` (slice 6) — already `ok` before
   this dispatch's edits (`PostToolUse` text-extraction branch and
   `verdict_git_lock`'s `mask` paragraph, carrying `GIT_INDEX_FILE`, already
   existed). No implementation change.

## Full suite after the slice-5 edit

`direnv exec . bats tests/hook-locks.bats`:

```
1..10
ok 1 mask outcome through the hook
ok 2 mask paragraph is flag-neutral under flag true
ok 3 mask outcome through the hook under BSD stubs
ok 4 held interpolates the pid
ok 5 orphan and unknown interpolate size and age
ok 6 orphan with neither bytes nor age interpolates no empty value
ok 7 probe receives flag and cwd
ok 8 config-lock mask names config.lock and update-config
ok 9 piped lock failure on a success payload
ok 10 orphan with one of bytes and age interpolates that one alone
```

`direnv exec . bats tests/verdicts.bats`:

```
1..7
ok 1 verdicts under 400 chars
ok 2 verdict text is quiet
ok 3 verdict text matches detectors.md
ok 4 lock verdict text matches lock-detectors.md
ok 5 verdict_git_lock held|orphan|unknown interpolate probe values
ok 6 verdict_config_lock held|orphan|unknown interpolate probe values
ok 7 no removal instruction
```

`direnv exec . bats tests/docs.bats`:

```
1..1
ok 1 no tracked file outside the fixtures fires a detector
```

(the doc stays quiet under the detectors it specifies — no diagnostic
appears together with its follow-on sentence in the edited paragraph.)

`direnv exec . just test`: `bats: 144 passed, 0 failed`.

## Character cap

The edited `config-lock` `mask` paragraph (the prose before the ` · `
separator, matching `tests/verdicts.bats`'s `line1`) measures 361 characters
(counted with `python3 -c "print(len(s))"` on the exact string), under the
400-char cap. `tests/verdicts.bats`'s own `verdicts under 400 chars` test
(`${#line1} -lt 400`) is green, confirming the same from inside the suite.

## `just lint`

No `lint` recipe exists in this repo's `Justfile` (`just --list`: `test`,
`precommit`, `prerelease`, `release`, `resume-release`, `format-docs`,
`check-version`, `update-plugin-dev`). Skipped; `just precommit` covers
shellcheck and the doc/line checks.

## `just precommit`

```
scripts/run-bats.sh tests/
bats: 144 passed, 0 failed — full log: /tmp/claude-1000/sandbox-lies-bats.Z5he9O
precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests
```

No warnings emitted.

## Scope

Only slice 5's paragraph text changed, in exactly the three places the
dispatch named: `docs/references/lock-detectors.md` (config-lock `mask`
paragraph only — git-lock's paragraph and config-lock's other outcomes
untouched), `lib/verdicts.sh` (`verdict_config_lock`'s `mask` case only), and
`tests/verdicts.bats` (the transcribed `config_lock mask` assertion in `lock
verdict text matches lock-detectors.md`). No test file edited. Slices 7-9,
the memory retirement, `design.md` status flips, and Items 4.2/4.3 untouched.

## Files in this commit

`tests/hook-locks.bats`, `tests/verdicts.bats`, `lib/verdicts.sh`,
`docs/references/lock-detectors.md`, plus this slice's three reports
(`item-4-1-s4-red.md`, `item-4-1-s4-test-review.md`,
`item-4-1-s4-green.md`).
