# Item 1.1 GREEN report — `path=` in `printf %q` form

Mode GREEN, slice group 1-5. Tests were not edited in slices 1-4; slice 5
rewrote existing assertions only (list below).

## Implementation

- `lib/probes-readonly.sh`: new `_probe_path_line <path>`. It prints `path=`
  plus `LC_ALL=C printf -v quoted %q "$1"` (the prefix on the builtin) and a
  newline, and prints nothing for an empty path. `probe_readonly_path` prints
  its outcome, then the helper's line. The newline arm of the `nopath` test is
  gone (`[ -z "$path" ]` remains).
- `lib/probes.sh`: `_probe_lock_at` loses `pathline` and its newline test; the
  five print sites (absent under each flag, character device, held, final
  orphan) call `_probe_path_line "$path"` after the outcome line (and the
  `pid=` line for held). The outcome, `pid=`, `bytes=` and `age=` order is
  unchanged, so the `path=` line stays last for orphan and after the outcome
  for the others.
- `lib/verdicts.sh` unchanged. Old-contract comments in lib are left stale
  (Item 7.7).

## Order the tests were made to pass

The encoder is one helper that every site shares, so it went in as one edit
(the helper and its five call sites plus the two guard removals), not one test
at a time. The tests were then run singly or by file, in this order, each
green on its first run after the edit:

1. `probes.bats` `a relative lock path under a cwd holding a blank prints
   path= in %q form` (slice 1)
2. `probes.bats` `probe_config_lock with no config-lock line prints mask and
   no path=` (slice 1)
3. `probes.bats` `a lock path holding e-acute prints the octal form under a
   UTF-8 locale` (slice 4)
4. `tests/probes-lock-newline.bats`: 7 passed (slice 2)
5. `tests/probes-readonly-members.bats`: 12 passed (slice 3)

## Slice 5: full-suite run, then rewrites

`scripts/run-bats.sh tests/` after the edit: 360 passed, 15 failed. Every
failure was a `path=` assertion on the old raw form. Rewritten to the literal
encoded form (expected literals written out, not produced by `%q`):

`tests/probes-config.bats`
- `config-lock appends .lock to the named file`: `path=...it\'s\ here/main/...`
- `each probe reads only its own lock line`: the bare `path=` assertion for
  the pathless `probe_config_lock` run became `[ "$output" = mask ]` (an empty
  path prints no line).
- `pathless text never names the base`: the same, for `mask` and for `gone`.
  (Two sites in one test.)

`tests/probes-readonly.bats`
- `writable path`, `writable path survives BSD grep and sed`:
  `a\ dir/target`
- `curly-quoted mkdir path is extracted` (two sites),
  `curly and unquoted paths survive BSD grep and sed` (curly site):
  `$'...curly \342\200\224 target'`
- `bash line-N path is extracted`, `dash redirect path is extracted`,
  `git config-lock path is extracted`, `git mkdir path is extracted`,
  `mv target path is extracted, not the source`,
  `straight-quoted touch and ln keep their path` (two sites),
  `curly and unquoted paths survive BSD grep and sed` (bash site): the
  blank-escaped form (`bash\ line\ 3:\ target` and the like)

`tests/probes.bats`
- `non-UTF-8 byte in the path`: `path=$'<tmp>/r\351n/r/.git/index.lock'`
- `quote and space in the lock path`: `<tmp>/it\'s\ here/r/.git/index.lock`

### Temporary, reverted by Item 1.2

None. No hook- or verdict-level test broke: `hooks/annotate.sh` and
`lib/verdicts.sh` are unchanged, and no `hook-*.bats` assertion in the suite
pins a blank-named path. The expectation in the outline for such sites did not
materialise, so nothing is listed here.

## Results

- Whole suite, `scripts/run-bats.sh tests/`, foreground: 375 passed, 0 failed.
- `just precommit` (unsandboxed, foreground): exit 0, "precommit passed:
  plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links,
  python compile, tests". No warnings printed.
