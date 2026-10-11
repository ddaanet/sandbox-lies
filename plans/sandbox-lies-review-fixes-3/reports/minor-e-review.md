# Minor batch E review

Verdict: findings 13, 14, 15, 16 and 30 are closed. Two cosmetic defects
fixed; one residual noted.

## Checks

- Comments only: `git show 904af8a` (outside `plans/`), every added or removed
  line that is not a `#` comment line: none.
- 13 pathless header: `probe_config_lock` leaves `path` empty when no
  config-lock line exists; `_probe_path_line` prints nothing for an empty
  value and `printf %q` for the rest, so a newline path prints as one
  `$'a\nb'` line. Header true. `LOCK_PATH_LINE` comment: the stub value is raw,
  `%q` would escape the blank, `&` and backslash; true.
- 13 locale.bash users: counted `load helpers/locale` and `utf8_locale`
  callers: hook-cap, probes, probes-lock-newline, probes-readonly-tokenize-time,
  verdicts-readonly-path. Five; header lists five.
- 14: the new `_verdict_path_read` comment matches the code (regex in a
  variable, unquoted on the right of `=~`, admits no bare quote and a backslash
  plus any one character). Ran the regex on /bin/bash 5.2.37 and
  /tmp/claude/bash32/bash 3.2.0 under `LC_ALL=C`: identical results (matches
  `$'a\"b\e\''` and `$'a\\'`, rejects `$'a'b'` and `$'ab\'`). Both bashes
  decode `$'\"'` to `"` and `$'\e'` to ESC; `%q` writes `$'\E"\''`, never `\"`
  or `\e` inside `$'...'`. The `_verdict_unescape` comment is true.
- 15: `git grep -nIiE 'design section [BC]'` finds the phrase only in the
  review reports under `plans/`. Residual, not in the finding:
  `tests/probes-readonly-resolve.bats` lines 273 and 293 say "outline section
  B"; that names `plans/sandbox-lies-review-fixes-3/outline.md`, a tracked
  file, so it resolves. Left.
- 16: comment matches `_verdict_path_read` (wire form shown when the decoded
  bytes hold a control byte).
- 30: `tests/corpus-eval.bats` and `tests/extract-fixtures.bats` both exist and
  run the tools they are named for. `check-line-limits.sh` `handle_file` caps
  `justfile` at 400; "Any other extensionless file" is accurate.

## Defects fixed

1. `tests/verdicts.bats` comment before "phantom-untracked opens without
   naming a location": the edit joined two lines into one of 130 characters.
   Rewrapped to three lines under 80.
2. `lib/verdicts.sh`, `verdict_readonly_path` comment: the edit left a ragged
   short line ("nopath has no"). Re-wrapped.

Caps: no touched file near 400 lines; no new line over 80 in the batch's
comments.

No classifier refusals.
