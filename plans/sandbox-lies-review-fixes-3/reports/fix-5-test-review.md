# Fix 5 RED — test review

Verdict: the ratio test is genuine evidence after one fix. Nothing committed;
only `tests/verdicts-readonly-path.bats` edited (280 lines, under 400).

## Checks

- Fails on assertion for a quadratic decoder: yes. Three red runs by me and
  the RED's two: ratio 11.7 to 12.9, always on the final `ratio < 9` line.
- Passes for a linear decoder: yes. Throwaway copy of the tree in my own
  `mktemp -d` (lib/ of the real tree untouched), decode loop replaced by one
  sed pass plus a single `printf -v %b`; the test went green. Copy removed.
- Bound and N: 9 sits between 4 and 16. Quadratic reads 12 (not 16, since
  start-up and the per-escape constant), so 3 clear of the bound; linear
  reads about 4, 2.25x clear. Min of 3 per side means one load spike cannot
  move either. A sustained 2.25x slowdown on only the 4N side across three
  consecutive ~1 s runs is the false-red route; unlikely, accepted. A
  sustained slowdown on the N side only gives a false green, not a false red.
- Wrong reason: python3 start-up is outside the timed region's weight (the
  timer wraps the child `bash` process only; python start-up is before
  `t0`). Bash start-up and sourcing are a few ms against 0.27 s at N. A
  sub-quadratic but super-linear fix (ratio under 9) passes by design.
- Runtime: about 11 s on red; a linear fix runs in about 2 s. Acceptable.
- bash 3.2 / 5.2: the test runs on system bash only (bats does not parse on
  3.2.0); the clock is python3, so no EPOCHREALTIME dependence. The
  subprocess is `bash` from `PATH`, the same as the suite's.
- File length: 280 lines.

## Defect found and fixed

The decoded-value assertions ran in the bats default locale, while the timed
runs use the UTF-8 locale. A decoder wrong or empty only under UTF-8 would
have passed on speed. Both value checks now run under `LC_ALL=$loc`, the
timing locale. Proof: with a throwaway decoder that left the value empty the
test fails at the value assertion (line 269), not on speed; with the
unchanged decoder it is red on the ratio line (12.20). Also added the missing
`SC1091` disable above the second `_probe_path_line` line (shellcheck now
clean).

## Residual notes

- The value checks use `[ ... = same ]` in a command substitution, so a
  failure reports only the line, not the values. Acceptable; the ratio line
  prints its numbers.
- `python3` absent errors instead of asserting; python3 is already a
  precommit dependency.

## Hand-run scripts in `/tmp/claude/fix5/`

- `time32.sh`: adequate for the before/after record on 3.2.0 under both
  locales (it checks the decode and prints wall time). It asserts no bound,
  so the GREEN report must quote the numbers; the bats ratio test is the
  gate on 5.x.
- `roundtrip.sh`: adequate as the differential: every byte 1..255 before 16
  following characters, a newline set and 1500 seeded random strings (5580
  cases), run under four bash and locale combinations with 0 mismatches
  baseline. Gap: no long multi-escape string; the bats value assertions at
  900 and 3600 escapes cover that on 5.x only, and `time32.sh`'s decode check
  covers it on 3.2.0.
