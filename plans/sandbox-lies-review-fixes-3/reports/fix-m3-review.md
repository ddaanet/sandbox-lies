# Review of fix M3 (commit 9a50c64)

Verdict: no defects. Nothing changed besides this report.

## Mutation proof (re-run, not trusted from the report)

Mutant: in `handle_file` of scripts/check-line-limits.sh, the arm
`plans/* | plugin-dev/*) ;;` replaced (exact, once-occurring string) by an
arm exempting only `.sh`, `.bash`, `.bats`, `.py` under `plans/` and
`plugin-dev/`.

1. Landed: `command grep -c 'plans/\*\.sh'` printed 1.
2. Suite: 7 passed, 1 failed. The one failure is case 7, "plans/ and
   plugin-dev/ are out of the awk, TOML, JSON and justfile cap", on its own
   assertion (line 156). Message named all ten paths: plans/ and plugin-dev/
   each with x.awk, x.toml, x.json, justfile, sub/justfile. Four types, two
   roots, nothing else failed (the older plans/ and plugin-dev/ script cases
   stay green, as they should under this mutant).
3. Restored by the swapped replacement; `command grep -c` printed 0;
   `git diff` on scripts/ empty; suite 8 passed, 0 failed.

## Cannot pass for another reason

Hand run on a scratch repo with 401-line tracked x.awk, x.toml, x.json,
justfile and sub/justfile at the root: all five reported
`oversized-file ... 401 lines > 400`, exit 1. The same names under plans/
produce no report. So the fixtures really are over cap and tracked, and only
the root exclusion silences them. Each fixture root holds one tracked file,
so no other file can account for output. The case checks status, stdout and
stderr per file and collects every failure before asserting.

## Size

tests/check-line-limits-types.bats is 174 lines, well under 400.
