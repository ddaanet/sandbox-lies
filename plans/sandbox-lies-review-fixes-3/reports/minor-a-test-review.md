# Minor batch A, test review (findings 4, 7, 8)

Tests only edited; no source touched, nothing committed. shellcheck clean on
both files.

## Defects found and fixed

- Finding 7 (blocking): the `_verdict_path_read /x/y` probe never reaches the
  `$'...'` arm, so it exercises only `_verdict_has_control`. A fix of that one
  `local LC_ALL=C` would pass the whole case while line 175's
  `local LC_ALL=C IFS=\\ ...` still leaked. Added a third probe, the wire form
  `$'a'`, which reaches both sites. Hand-run on 3.2.0 with a copy of the
  library: fixing only `_verdict_has_control` leaves `1 3` for `$'a'`; fixing
  only line 175 leaves `1 3` for `_verdict_has_control x`; so either
  half-fix stays red. The call is now passed as separate arguments to the
  child (`"$2" "$3"`): inlined into the script text, `$'a'` is expanded by the
  child's parser to `a` and the reader returns at `*)` without reaching the
  arm.
- Finding 8: the legitimate neighbours were not pinned. Added "_verdict_path_read
  still reads an absolute $'...' value and a / value ending in an escaped
  backslash": `$'/x'` reads `/x`, `/x\\` reads `/x\`, `$'/x\\'` reads `/x\`.
  Green on unchanged code (they are existing behaviour); they turn red for a
  fix that rejects every `$'...'` value, any trailing backslash, or an
  absolute `$'...'`.
- Finding 4: added the neighbour at the end of the case: under `set -e`, a
  decodable `path=/r/.claude/settings.json.lock` still prints the
  `update-config` act and `reached rc=0`.

## Checked, no change

- Finding 4 against `|| true`/`|| :` on the bare call: correct fix, passes. A
  fix that swallows the paragraph (early `return`, redirect) fails the
  paragraph `grep -qF`. The `|| true` on the `$(...)` is only so the loop
  reports the failure from its own assertion; the assertion needs the
  paragraph plus `reached rc=0`, so an empty output fails on the first stdin
  (`''`), and the other values cover each undecodable shape.
- Finding 8 red cases each fail on `[ "$out" = 'rc=1 raw=[] shown=[]' ]`
  with `rc=0` actual, and nothing else can give that string: a sourcing error
  would leave `rc=` empty or print an error line.
- 3.2 skip: skips only when `${BASH32:-/tmp/claude/bash32/bash}` is not
  executable, with a message naming the path; a missing UTF-8 locale fails
  (via `utf8_locale`), it does not skip. Comment cites the rebuild recipe.
  The comment explains why no 5.2 case can be red. Honest.

## Result on unchanged code

- tests/verdicts-readonly-path.bats: 17 pass, 4 fail (the three finding 8
  cases and the 3.2.0 locale case, the latter now red on
  `_verdict_has_control x left the length 1 3`). Red set unchanged; the new
  neighbour case is green.
- tests/verdicts-locks.bats: 5 pass, 1 fail (finding 4, `stdin [] gave: []`).

## Residual

The locale case reports only the first failing probe per run (it returns on
the first mismatch); the per-site argument above rests on the hand-run, not on
a test run against half-fixed source.
