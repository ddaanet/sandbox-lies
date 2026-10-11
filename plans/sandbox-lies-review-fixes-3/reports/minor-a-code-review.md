# Minor batch A (findings 4, 7, 8) — code review

Reviewed `git show 235c2d1`. One defect fixed (a stale test comment); no
defect in `lib/verdicts.sh`.

## Review

- Correctness: `|| :` covers the only bare call in `verdict_config_lock`.
  `_verdict_unescape` restores `LC_ALL` on every path (the escape-error path
  `break`s to the restore; the early `return 1` calls in `_verdict_path_read`
  precede or follow it, never skip it). The `tail` odd-backslash test is right
  for `/x\` (odd, rejected) and `/x\\` (even, read). The relative and empty
  `$'...'` values fall to the `case` and return 1 with raw empty.
- Bash 3.2: no 4+ syntax. Beyond the green report's runs, the unset case was
  checked on 3.2.0 with `LANG=C.UTF-8`, and with only `LC_CTYPE=C.UTF-8`, `LC_ALL`
  unset: length 1 before and after, `LC_ALL` still unset.
- Performance: no new fork; `_verdict_unescape` is a plain function call and the
  split-once loop is unchanged.
- Locale sites: `LC_ALL` appears at exactly two assignments (lines 204, 245) in
  `lib/verdicts.sh`, both restoring; no `LANG`/`LC_*` elsewhere. No other
  caller of the two helpers.
- Size: `lib/verdicts.sh` 385 lines. Changelog entry matches the change.
  `just precommit` exit 0 (432 passed), so no detector fires.
- Fixed: the comment in the 3.2.0 locale case said the wire form `$'a'` reaches
  both sites, and still said the sites "hold a `local LC_ALL=C`". `$'a'` is
  relative now and returns before `_verdict_has_control`; `x` and `/x/y` reach
  it. Comment corrected (`tests/verdicts-readonly-path.bats`).

## Mutation proof

Each mutation was an exact replacement of a string occurring once, proved landed
by a count, run red, restored by the swapped replacement, restore proved by
count (mutation text 0, original 1) and a green run. `git diff -- lib` was empty
after each. One lapse: a first attempt at the lone-backslash mutation replaced
`[ ... ] || return 1` with `:`, which occurs 44 times, so the swap-back refused;
the file was restored by a swapped replacement with the unique context line
before it, and the case re-run green.

| Finding | Test | Mutation | Red on |
| --- | --- | --- | --- |
| 4 | verdicts-locks: set -e prints its paragraph | `_verdict_path_read "$wire" \|\| :` to the bare call | the first stdin `''`: `gave: []` |
| 7 | verdicts-readonly-path: locale on 3.2.0 | after `LC_ALL=C` in `_verdict_has_control`, `saved=C` | `_verdict_has_control x left the length 1 3` |
| 7 | same | after `LC_ALL=C` in `_verdict_unescape`, `saved=C` | `_verdict_path_read $'a' left the length 1 3` |
| 8 | reads `$''` as no path | case arm `/*)` to `/*\|'')` | `rc=1 raw=[] shown=[]` equality |
| 8 | reads a relative `$'...'` value | case arm `/*)` to `/*\|?*)` | same equality |
| 8 | reads a lone-backslash value | the parity check line to `:` | same equality |
