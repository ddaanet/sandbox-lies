# Minor batch E: stale comments

Comments only. `just precommit` exit 0 (446 bats passed).

- 13: `tests/hook-locks-pathless.bats` header said a newline in the lock path
  leaves path= out. False at HEAD: `_probe_lock_at` prints such a path as one
  `$'...'` line (lib/probes.sh, comment above `_probe_lock_at`). A path= line
  is absent when the path is empty (`probe_config_lock` found no config-lock
  line; `_probe_path_line` prints nothing). Header rewritten.
  `tests/hook-locks.bats` `LOCK_PATH_LINE` comment now says the probe prints
  `%q` form and the value is raw because the held/orphan/unknown verdicts
  ignore path=. `tests/helpers/locale.bash` header named three users; five
  files load the helper and call `utf8_locale` (hook-cap, probes,
  probes-lock-newline, probes-readonly-tokenize-time, verdicts-readonly-path).
  Header lists all five.
- 14: `lib/verdicts.sh` `_verdict_path_read` comment above `local re=`
  rewritten to say why the regex is held in a variable (unquoted on the right
  of `=~`; quoted-string reading differs across bash versions) and what it
  admits. Reason for `\"` and `\e` added as a comment at the case arm in
  `_verdict_unescape`; both kept. Checked on bash 5.2.37:
  `printf %q` of ESC, a double quote and a single quote gives `$'\E"\''`, so
  `%q` writes `\E` and `\'` but not `\"` or `\e`; all four are valid in
  `$'...'`. The stated reason holds. The comment says `%q` writes `\E` and a
  bare `"`.
- 15: phrase "design section B/C" removed from `lib/probes-readonly.sh`,
  `tests/probes-readonly-resolve.bats`, `tests/verdicts.bats` (no path
  reference needed; the claims stand on their own words). Grep over tracked
  files: only the review reports under `plans/` still quote the phrase.
- 16: comment above `verdict_readonly_path` now states the exception: a path
  with a control byte shows in its wire form (per `_verdict_path_read`).
- 30: `justfile` compile-step comment now names `tests/corpus-eval.bats` and
  `tests/extract-fixtures.bats` and gives the real reason for the compile
  step. `scripts/check-line-limits.sh` header now says "Any other
  extensionless file" (the `justfile` is capped, case arm at line 71).

No classifier refusals.
