# Fix pass summary

Range: `3b48408..845bc12`. Every item: implementer, Sonnet (or Haiku for stage 2)
reviewer that re-ran the mutant; reports under `reports/fix-<id>*.md`.

| Item | Commit | Mutant | Dies now | Reports |
| --- | --- | --- | --- | --- |
| M1 | 595bf60 | gate fix, stderr line before `return 1` | yes | fix-m1, fix-m1-review |
| 12 | 9087e61, 33b98f9 | none (split into `check-line-limits.bats` and `check-line-limits-types.bats`; 3-line comment restored) | n/a | fix-12, fix-12-review |
| M3 | 9a50c64 | 5.2 `handle_file` (script types capped under plans/, plugin-dev/) | yes, all 10 type/root paths | fix-m3, fix-m3-review |
| M2 | 2d103a8 | 4.1 top-of-loop flush drops the pending run | yes | fix-m2, fix-m2-review |
| 5 | da7db9d, 85b2e07 | timing defect, linear decoder | gone | fix-5-red, -test-review, -green, -code-review |
| 6 | e501eb0, f8586ec | timing defect, no copy on `#` and `>&` | gone | fix-6-red, -test-review, -green, -code-review |
| 1.1/3 | 34c5573 | no `path=` when readonly and newline | yes | fix-s2-1-1-3, -review |
| gate `a b f r v` | 31df412 | letters dropped (also each of the five singly) | yes | fix-s2-gate, -review |
| 2.1/1 | d615a24 | walk from cwd parent | yes | fix-s2-2-1-1, -review |
| 6.1/2, 6.1/3 | 37faedb, 8df8cd4 | skipped by verdicts; guard string-only | yes | fix-s2-6-1-2, -6-1-3, fix-s2-6-1-review |
| 6.2/1, 6.2/2 | 9b0ef52, 008f433 | null timestamp; non-dict input | yes | fix-s2-6-2-1, -6-2-2, fix-s2-6-2-review |

No stage-1 change killed a stage-2 mutant, so all seven loops ran.

## bash 3.2.0 timings (before to after)

Finding 5, 3873-byte CJK path `_verdict_path_read`: LC_ALL=C 3.7 s to 0.38 s;
C.UTF-8 31.9 s to 0.42 s (bash 5.2.37: 1.7 to 0.26 s, 3.9 to 0.27 s).

Finding 6, 16384 characters, 3.2.0 C.UTF-8: `a` then `#` 66.7 to 3.7 s; `a#`
33.7 to 3.8 s; `>&` 38.5 to 4.6 s; plain word 3.7 s. 3.2.0 C: 11.4 to 2.2 s,
6.4 to 2.1 s, 6.7 to 2.3 s. The 6001-character letter-then-`#` shape: 9.9 to
1.3 s (C.UTF-8). Round trip of finding 5 and tokenizer differential of
finding 6: 0 mismatches on bash 5.2 and 3.2.0, default locale, C and C.UTF-8.

## Notes

- Finding 5 code review found a regression the GREEN missed (a literal newline in
  the wire body crashed the new decoder under `set -u`); fixed in 85b2e07
  with a regression case.
- Finding 6 header: "no copy grows with the word" was not true; the 256-char
  flush's `word="$word$run"` still copies once per 256 characters (at most 64
  times under the cap). The header states this residual.
- The finding 6 timing test compares dense against plain word at the same size
  (bound 1.9, observed 2.85 to 5.2 on the unchanged code, about 1.0 to 1.2
  fixed): the 16384-character scan cap leaves no 4x-ratio midpoint.
- The 12 split's `mktemp` stub case is a smoke run (the script calls `mktemp`,
  not `wc`); a bare `mktemp` call would not fail it.

## Last `just precommit` (HEAD 845bc12, exit 0)

precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line
limits, links, python compile, tests (426 bats passed, 0 failed).

## Open

Minor findings outside the pins stay open (4, 7 to 11, 13 to 25, 29, 30), as scoped.
Apple bash 3.2.57 and macOS remain unverified.

Finding 7 (a `local LC_ALL=C` not undone on return under bash 3.2.0) now has
two sites: fix 5 added one in `_verdict_path_read`, beside the one in
`_verdict_has_control`. No behaviour changes, since the second function ran
on every successful decode already.

## Checked by the main session at HEAD

`just precommit` exit 0 (426 bats). Hand run on bash 3.2.0 and 5.2.37 under
`C` and `C.UTF-8`: a 3873-byte CJK path decodes to the original in under 1 s,
and a 6001-character letter-then-`#` word tokenizes in 1 s. Timing tests over
four runs: dense-over-plain ratio 0.89 to 1.24 against the bound 1.9; the
decoder's 4N-over-N ratio 3.40 to 4.49 against the bound 9.
