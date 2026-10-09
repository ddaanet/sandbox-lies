# Item 1.2 GREEN — decode and display (slices 1-4, one group)

Changes: `lib/verdicts.sh` (new `_verdict_path_read`, `_verdict_has_control`;
`verdict_readonly_path` and `verdict_config_lock` call the reader) and
`tests/verdicts.bats` (two existing cases, see below). No test file from the RED
dispatch was edited. No eval, no new `2>/dev/null`.

## Order the tests were made to pass

Each step was run alone before the next.

1. `hook-writes.bats` "hook names a blank-holding path raw, with no backslash"
   and `verdicts-readonly-path.bats` "decodes the backslash form without running
   what it holds": reader with the `/` arm only (`IFS= read` without `-r` from a
   process substitution), wired into `verdict_readonly_path` for the subject and
   the `writable:*/.claude/settings.json` match. Both green.
2. "shows a UTF-8 path byte-exact", "reads an escaped quote", "malformed path
   value as no path": the `$'` arm (regex grammar, strip, `\'` swap with pattern
   and replacement in variables, `printf -v ... %b "$body"`). File run: 6 of 10
   green; red were newline/two lines, control bytes, suffix, BSD.
3. Display rule (`_verdict_has_control`, `LC_ALL=C` + `[[:cntrl:]]`, wire form
   shown on a control byte): `verdicts-readonly-path.bats` 10 of 10 green.
4. `verdicts-locks.bats` "verdict_config_lock matches the settings.json.lock
   suffix on the decoded path": `verdict_config_lock` reads the decoded value.
   5 of 5 green.
5. Full suite: 2 failures in the existing `tests/verdicts.bats`, fixed as
   listed below; then 388 passed, 0 failed.

## Existing tests rewritten (listed per the dispatch)

Both fed the old raw `path=/r/a b&c\1/x` and expected it verbatim. The probe now
prints `%q`, so the stdin line is `/r/a\ b\&c\\1/x` and the expected verdict text
is still the decoded path, unchanged. A `wire` variable was added; assertions
unchanged.

- `tests/verdicts.bats` "readonly-path writable verdict text matches
  readonly-path.md"
- `tests/verdicts.bats` "readonly-path readonly verdict text matches
  readonly-path.md"

## Decoder on bash 5.2.37 and 3.2.0

The shipped `lib/verdicts.sh` was sourced and `_verdict_path_read` run on each
wire under both bashes, each with `LC_ALL=C.UTF-8` and `LC_ALL=C`. The decoded
bytes (`od -c`), the shown bytes and the return status were identical in all
four runs, for every case:

| Wire | rc | Decoded | Shown |
|---|---|---|---|
| `/a:~root/b\ c` | 0 | `/a:~root/b c` | same |
| `/a:\~root/b\ c` (bash 5.2 `%q` form) | 0 | `/a:~root/b c` | same |
| `$'/x/caf\303\251/f'` | 0 | `/x/caf` + bytes 303 251 + `/f` | same |
| `$'/x/a\nb/f'` | 0 | `/x/a` LF `b/f` | wire form |
| `$'/x/it\'s/f'` (the `\'` step) | 0 | `/x/it's/f` | same |
| `$'/x/a\\b'` | 0 | `/x/a\b` | same |
| `$'/x/\Eb'` | 0 | `/x/` ESC `b` | wire form |
| `$'/x/\\\'\''` | 0 | `/x/\''` | same |
| `/x/\$\(touch\ S\)` | 0 | `/x/$(touch S)`, nothing run | same |
| `$'a'b` (malformed) | 1 | empty | empty |
| `$'a\'` (malformed) | 1 | empty | empty |

Also on both bashes, `verdict_config_lock mask` with
`path=/a:~root/.claude/settings.json.lock` and with the `é` `$'` form gave the
`update-config` act, and `path=$'a'b` gave the flag-worded re-run. The `\'`
substitution works on 3.2.0 with `bq="\\'"` and `q="'"` held in variables and
`${body//"$bq"/"$q"}`.

## Test runs

- Full suite `scripts/run-bats.sh tests/`: 388 passed, 0 failed.
- `just precommit` (unsandboxed, foreground): exit 0, "precommit passed:
  plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links,
  python compile, tests". No warnings printed.
- `just lint` does not exist in this repo's Justfile (`error: Justfile does not
  contain recipe lint`); shellcheck runs inside precommit and `shellcheck
  lib/verdicts.sh` is clean.

## Notes

- Comments in `lib/verdicts.sh` that state the old contract (the
  `verdict_readonly_path` header: "joined by plain expansion ... bytes intact",
  "path= stdin line") were left for Item 7.7, as scoped.
- `lib/verdicts.sh` is 316 lines.
- A backslash-form wire ending in a lone `\` decodes to the text before it (read
  without `-r` takes the line continuation); `%q` never prints that.
- Control-byte test runs under `LC_ALL=C` so a UTF-8 locale does not widen
  `[:cntrl:]` to the C1 range, which is valid text in a path.
