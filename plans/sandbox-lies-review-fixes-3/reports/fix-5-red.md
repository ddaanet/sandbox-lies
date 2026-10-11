# Fix 5 RED — `_verdict_path_read` quadratic decode

Nothing committed. Test added to `tests/verdicts-readonly-path.bats` (now
~278 lines; it also loads `helpers/locale`). No `make_bsd_stubs` re-run:
`lib/verdicts.sh` calls no stubbed tool.

## Test

`_verdict_path_read time grows no faster than linearly in the escape count`.
Builds a CJK path of 300 and of 1200 characters (900 and 3600 octal escapes),
encodes each with the production `_probe_path_line`
(`lib/probes-readonly.sh`), asserts the decode equals the original at both
sizes, then times a fresh `bash -c` that sources `lib/verdicts.sh` and runs
`_verdict_path_read`: least of three runs per size, clock is python3
`time.perf_counter` (bash 3.2 has no EPOCHREALTIME, BSD date no `%N`), under
the UTF-8 locale `utf8_locale` finds. Asserts t(4N)/t(N) < 9.

## Red

Fails on its ratio assertion (not an error), twice in a row:
`t(N)=0.2773 s t(4N)=3.3372 s ratio=12.03`, then
`t(N)=0.2687 s t(4N)=3.4582 s ratio=12.87`. Test runtime on red about 11 s.

- State of the world that fails it: a decoder whose cost per escape grows
  with the remaining body (the `body=${body#"$lit"}` / `${body:4}` rewrite of
  the whole string per escape), so total time is quadratic in escapes.
- What else could fail it: a loaded box inflating the 4N timing (mitigated by
  min of 3; bound 9 sits mid-way between 4 and 16, observed 12-13 so a
  quadratic is clear of it); decoded-value mismatch (separately asserted,
  passed on unchanged code); a missing python3 (errors, not an assertion).
  A GREEN decoder that is linear gives about 4 or less (start-up cost pulls
  the ratio down). A slower-than-linear but sub-quadratic fix (ratio under 9)
  passes by design.

## Before timings (`/tmp/claude/fix5/time32.sh`, 3873-byte CJK path)

Output saved in `/tmp/claude/fix5/before.txt`. Wall time includes building
the path and encoding it (small).

| bash | LC_ALL | real |
|---|---|---|
| bash32 (3.2.0) | C | 3.7 s |
| bash32 (3.2.0) | C.UTF-8 | 31.9 s |
| system 5.2.37 | C | 1.7 s |
| system 5.2.37 | C.UTF-8 | 3.9 s |

(Under C the script triples the character target so the path is still 3873
bytes.) Matches finding 5 (31.8 s and 4.2 s).

## Differential baseline (`/tmp/claude/fix5/roundtrip.sh`)

Round trip through `_probe_path_line` and `_verdict_path_read`: bytes 1-255
before each of 16 following characters, a newline set, and 1500 random byte
strings (seeded), 5580 cases. Reports `MISMATCH wire=...` lines, exit 1 on
any. Baseline 0 mismatches on each of: bash 5.2.37 default locale, bash 5.2.37
C.UTF-8, bash 3.2.0 default locale, bash 3.2.0 C.UTF-8
(`/tmp/claude/fix5/roundtrip-before.txt`).

## Scripts

- `/tmp/claude/fix5/time32.sh [cjk-chars]`
- `/tmp/claude/fix5/roundtrip.sh` (run with `bash` or
  `/tmp/claude/bash32/bash`, `LC_ALL=C.UTF-8` optional)
