# Fix 5 GREEN — linear `_verdict_path_read`

## Design

`lib/verdicts.sh`, the `$'...'` branch. The per-escape loop re-sliced the
remaining body (`body=${body#"$lit"}`, `${body:4}`) each time: quadratic, and
far worse on bash 3.2.0 in a UTF-8 locale where every slice is a multibyte
scan. Now:

- `local LC_ALL=C IFS=\\`, so splitting and indexing count bytes (the wire
  form is ASCII-escaped bytes; the decode is byte-exact either way).
- Body split once: `read -r -a parts < <(printf '%s\n' "${body}x")` (process
  substitution as before, nothing on disk). The `x` sentinel stops `read`
  dropping a trailing empty field; stripped at the end.
- `parts[0]` is literal. Each later field is the text after one backslash: an
  empty field is a `\\` pair (emit a backslash; the next field is plain
  text); otherwise `^[0-7]{3}` is an octal escape decoded as `%b "\0NNN"`
  (per-escape, so the digit-after-control-byte correctness is kept), else
  the first char is `'`, `"` or one of `abEefnrtv` (fail otherwise); the rest
  of the field is literal.
- `oct` regex lost its leading backslash (fields start after it). `printf -v`
  was already in use (bash 3.1+); no 4.x features.

## Differential (`/tmp/claude/fix5/roundtrip.sh`, 5580 cases)

| bash | locale | mismatches |
|---|---|---|
| 5.2.37 | default | 0 |
| 5.2.37 | C.UTF-8 | 0 |
| 3.2.0 | default | 0 |
| 3.2.0 | C.UTF-8 | 0 |

## Timings (`/tmp/claude/fix5/time32.sh`, 3873-byte CJK path)

| bash | LC_ALL | before | after |
|---|---|---|---|
| 3.2.0 | C | 3.7 s | 0.38 s |
| 3.2.0 | C.UTF-8 | 31.9 s | 0.42 s |
| 5.2.37 | C | 1.7 s | 0.26 s |
| 5.2.37 | C.UTF-8 | 3.9 s | 0.27 s |

## Suites (one at a time, foreground)

verdicts-locks 5, verdicts-readonly-path 14 (the RED ratio test now green),
verdicts-readonly 14, verdicts 11: all passed.

## Mutation proof (kill-check of the differential)

Mutation: `rest=${part:3}` to `rest=${part:2}` (octal escape keeps a digit of
its field). Landed (`command grep -c` = 1). Round trip on bash 5.2 default
locale: 3998 of 5580 mismatches. Restored by the swapped replacement
(`command grep -c` = 0); round trip 0 mismatches again.

## Other

`docs/changelog.md`: new 2026-10-11 section, linear decode and timing.
`docs/design.md` untouched.

## Precommit

First run failed shellcheck (unused `lit`, SC2141 on the backslash IFS); removed
`lit`, added a disable with reason. Second run exit 0: plugin.json, hooks.json,
shellcheck, bash -n, rumdl, line limits, links, python compile, bats (417
passed, 0 failed).
