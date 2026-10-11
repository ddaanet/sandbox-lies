# Review of fix M2 (commit 2d103a8)

Verdict: sound. No defect found; no fix made.

## Mutation proof (re-run, flush at line 44 of `lib/probes-readonly-command.sh`)

Each mutation was one exact replacement of a string occurring once, with its
landing proved by `command grep`. Each was restored by the swapped replacement
and proved (grep count 0, line 44 reads the original).

1. Pending run dropped (`|| { run=''; }`): suite 14 cases, only
   `not ok 14` (the new case), on `[ "${#tokens[1]}" -eq 601 ]`. Cases 1 to 13
   green.
2. Pending run emitted twice (`$run$run`): only case 14 red, same assertion
   (length 601 fails).
3. Pending run truncated (`${run:1}`): only case 14 red, same assertion.

Final state: `tests/probes-readonly-globs.bats` 14 passed; `git diff` empty;
`git status --short` shows only the untracked `inbox/`.

## Checks on the case

- The word is 600 characters; the pending run joins at 256 and again at 512, so
  two flushes are crossed.
- Content is the numbers 00001 to 00120 in five digits: every position is
  distinguishable, so a same-length reorder or swap fails the exact-equality
  assertion (`"w$word"`). The length assertion catches the three mutants above
  first.
- Test file is 210 lines (cap 400). The suite loads `helpers/bsd-stubs`; no
  stubbed tool is called by the code under test, as the fix report states.
