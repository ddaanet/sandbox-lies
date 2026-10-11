# Minor batch A (findings 4, 7, 8) — GREEN report

## Changes

`lib/verdicts.sh` (edited by the prior agent, reviewed here), `docs/changelog.md`
(one entry), tests unchanged by this dispatch.

- Finding 4: `verdict_config_lock` calls `_verdict_path_read "$wire" || :`, so
  a mask with no decodable path prints the paragraph under `set -e`.
- Finding 7: `_verdict_has_control` and the new `_verdict_unescape` set
  `LC_ALL=C` by assignment and restore the caller's value (or unset it) on
  every return, instead of `local LC_ALL=C`.
- Finding 8: `_verdict_path_read` returns 1 with both outputs empty for `$''`,
  a relative `$'...'` value, and a `/` value ending in an odd run of
  backslashes. The escape loop moved to `_verdict_unescape` unchanged apart
  from the locale restore.

Review of the diff: shellcheck clean; the decoder loop forks nothing (only
`printf -v`, `read -a`, parameter expansion); no bash 4+ syntax (`${var-}`,
`${var+x}`, `read -d ''`, `[[ =~ ]]` with the pattern in a variable, all 3.2
safe), confirmed by the 3.2.0 runs below.

## Evidence

- `scripts/run-bats.sh` one file at a time: `tests/verdicts-locks.bats` 6
  passed; `tests/verdicts-readonly-path.bats` 21 passed;
  `tests/verdicts.bats` 11 passed.
- Round trip: script `rt.sh` in `/tmp/claude/rt.UyghD1` (scratch, own dir);
  command per cell: `[env -u LC_ALL | LC_ALL=C.UTF-8] <bash> rt.sh <repo>`
  with `<bash>` = `bash` (5.2.37) and `/tmp/claude/bash32/bash` (3.2.0). It
  sources `lib/probes-readonly.sh` and `lib/verdicts.sh`, runs 5580 paths (bytes
  1..255 before each of 16 following characters, then 1500 random byte strings,
  seed `RANDOM=42`, each prefixed `/`) through `_probe_path_line` and
  `_verdict_path_read` and compares `_verdict_path_raw` byte for byte.

| bash | locale | paths | mismatches |
| --- | --- | --- | --- |
| 5.2.37 | default | 5580 | 0 |
| 5.2.37 | C.UTF-8 | 5580 | 0 |
| 3.2.0 | default | 5580 | 0 |
| 3.2.0 | C.UTF-8 | 5580 | 0 |

- Hand run `hand.sh` (same scratch dir), identical output on 5.2.37 and 3.2.0:
  - 7: with `LC_ALL=C.UTF-8` exported, after `_verdict_has_control` and a
    `$'...'` decode, `LC_ALL` is still `C.UTF-8`; with it unset, it stays unset.
  - 8: `$''` rc=1 raw empty; `$'rel'` rc=1 raw empty; `/a\` rc=1 raw empty;
    `/a\\` rc=0 raw `/a\`.
  - 4: `printf 'path=\n' | verdict_config_lock mask false` under `set -e`
    exits 0 and prints "The `config.lock` behind this error is a ...".

## Precommit

`just precommit` unsandboxed, exit 0: plugin.json, hooks.json, shellcheck,
bash -n, rumdl, line limits, links, python compile, tests (432 passed, 0
failed).
