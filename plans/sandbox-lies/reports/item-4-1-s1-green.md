# Item 4.1 slice 1 — GREEN

## What changed

- `hooks/annotate.sh`:
  - Sources `lib/probes.sh` beside `lib/matchers.sh` and `lib/verdicts.sh`,
    same guarded pattern (`. "$lib_dir/probes.sh" || exit 0`).
  - The single jq call now also extracts `tool_input.dangerouslyDisableSandbox`
    (as literal `"true"`/`"false"`, guarded with `?` so a non-object
    `tool_input` cannot make the call error) and the payload `.cwd` (via
    `(.cwd | strings) // ""`, so a missing or non-string `cwd` reads as
    empty rather than erroring), printed ahead of the text parts. The bash
    side now splits on the first three newlines (event, flag, cwd) before
    the remaining text, mirroring the existing single-split idiom.
  - The per-name loop: for a detected name whose `verdict_<name>` and
    `probe_<name>` are both defined, runs the probe with the text on stdin
    and `"$flag" "$cwd"` as its arguments; the probe's first line becomes the
    verdict's outcome argument, and any lines after it become the verdict's
    stdin. A name with only a verdict (the three phantom detectors) keeps
    the prior no-probe, no-stdin call.
- `lib/verdicts.sh`:
  - `verdict_git_lock` and `verdict_config_lock` replace the inert stubs
    with a `case "$outcome"` over `mask`/`gone`/`held`/`orphan`/`unknown`,
    text transcribed from `docs/references/lock-detectors.md`. `mask` and
    `gone` are exact; `held`, `orphan` and `unknown` carry the paragraph and
    human line with the `N` placeholders left literal (interpolating
    `pid=`/`bytes=`/`age=` is slices 2–3).
  - Header comment now names `docs/references/lock-detectors.md` as the
    source for `git_lock`/`config_lock` text, alongside `detectors.md` for
    the rest.

## Tests made to pass, in order

1. `tests/verdicts.bats` — `lib/verdicts.sh`'s new `case` bodies alone make
   all five cases in this file green (`verdict text matches detectors.md`
   and the other pre-existing three were already green and stayed so):
   ```
   1..5
   ok 1 verdicts under 400 chars
   ok 2 verdict text is quiet
   ok 3 verdict text matches detectors.md
   ok 4 lock verdict text matches lock-detectors.md
   ok 5 no removal instruction
   ```
2. `tests/hook-locks.bats` — with `hooks/annotate.sh`'s jq extraction and
   probe-then-verdict wiring added, all three new cases go green together
   (they share the same wiring path, so there was no smaller increment that
   turned one green without the others):
   ```
   1..3
   ok 1 mask outcome through the hook
   ok 2 mask paragraph is flag-neutral under flag true
   ok 3 mask outcome through the hook under BSD stubs
   ```
3. Full suite (`just test` -> `scripts/run-bats.sh tests/`): 135 passed, 0
   failed — no regressions in `tests/hook.bats`, `tests/hook-malformed.bats`
   or elsewhere.

## `just precommit` final line

```
scripts/run-bats.sh tests/
bats: 135 passed, 0 failed — full log: /tmp/claude-1000/sandbox-lies-bats.DnBbXD
precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests
```

No `just lint` recipe exists in this repo's `justfile` (`precommit` runs
shellcheck, `bash -n`, rumdl, line limits and link checks inline); ran
`just precommit` only, per the done criteria.

## Precommit warnings

None. `shellcheck` on the two changed source files and the new test file
reports nothing; no complexity or line-limit warnings (`lib/verdicts.sh` 83
lines, `hooks/annotate.sh` 134 lines, `tests/hook-locks.bats` 97 lines — all
well under the 400-line cap).

## Scope note

`lib/probes.sh` is unchanged (Item 4.1's contract text and the RED report
both name it as an existing file this slice only sources and calls, never
edits). Slices 2–9 of Item 4.1, and Items 4.2/4.3, are untouched.
