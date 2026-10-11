# Minor batch A, RED (findings 4, 7, 8)

All three findings still hold at HEAD (hand-run on bash 5.2 and 3.2.0):

- 4: `printf '\n' | bash -c 'set -e; . lib/verdicts.sh; verdict_config_lock mask'`
  prints nothing, exit 1.
- 7: on `/tmp/claude/bash32/bash` (3.2.0) under `LC_ALL=C.UTF-8`, an em dash
  has length 1 before and 3 after `_verdict_has_control x`, and after
  `_verdict_path_read /x/y`. Bash 5.2: `1 1` for both. Setting `LC_ALL` in the
  caller and printing it shows no leak: the variable is restored, the C
  locale in the shell is not. The test therefore observes string length.
  `en_US.UTF-8` is not installed here; `C.UTF-8` is.
- 8: `_verdict_path_read` returns 0 for `$''` (raw empty), `$'rel/x'` (raw
  `rel/x`) and `/x\` (raw `/x`).

No source touched, nothing committed. Both files stay under 400 lines
(274 and 356); no new file, so no bsd-stubs load needed (both already load it).
shellcheck clean; `tests/docs.bats` green.

## Tests (all red on unchanged code)

### 4. tests/verdicts-locks.bats, "verdict_config_lock mask under set -e prints its paragraph without a decodable path"

Red: `# stdin [] gave: []` at the paragraph `grep -qF`, i.e. empty output
(the child exited 1 at the bare `_verdict_path_read`). Loops over stdin
`''`, `path=`, `path=relative/x`, `path=$'a'b`, `other=1` and asserts the
paragraph and `reached rc=0`; the first value fails today, the loop covers
the rest for the fixed code.

- State of the world that fails it: errexit caller plus a mask with no
  decodable `path=` line.
- Else that could produce an empty output: the child shell failing to source
  `lib/verdicts.sh` or `VERDICTS` unset. Ruled out by the assertion also
  requiring the paragraph and `reached rc=0` (a sourcing failure would also
  fail it, so the evidence is the hand-run above: exit 1, source loads, other
  cases in the file green with the same `$VERDICTS`).

### 8. tests/verdicts-readonly-path.bats (three cases)

Each runs `_verdict_path_read` in a subshell and asserts
`rc=1 raw=[] shown=[]`.

- `_verdict_path_read reads $'' as no path`: red at the `[ "$out" = ... ]`
  assertion; actual is `rc=0 raw=[] shown=[]`.
- `_verdict_path_read reads a relative $'...' value as no path`: value
  `$'rel/x'`; actual `rc=0 raw=[rel/x]`.
- `_verdict_path_read reads a / value ending in a lone backslash as no path`:
  value `/x\`; actual `rc=0 raw=[/x]`.

State of the world: the decoder accepts these wire values. What else could
make the assertion fail: a sourcing error, which would give `rc=` empty or
an error line; the hand-run above shows the real values `rc=0`, matching the
reason for red.

### 7. tests/verdicts-readonly-path.bats, "the readers leave the caller's locale as it was, on bash 3.2.0"

Red: `# _verdict_has_control x left the length 1 3 (before after)`.

- No bats case on 5.2 can fail for this finding: 5.2 restores the locale on
  return of a `local LC_ALL`, and the variable itself is restored on 3.2.0
  as well (observed). Only a 3.2.0 process shows the leak. So the case runs
  `${BASH32:-/tmp/claude/bash32/bash}` as a subprocess from bats (bats itself
  runs on 5.2) with `LC_ALL` set to `utf8_locale` (helpers/locale), and
  skips when the build is absent. It checks the string length of an em dash
  before and after `_verdict_has_control x` and `_verdict_path_read /x/y`.
- State of the world that fails it: bash 3.2.0 with a UTF-8 locale and a
  function with `local LC_ALL=C`.
- Else that could produce `1 3`: the child starting in a non-UTF-8 locale
  (the first number would then be 3, so `1 3` rules it out); a missing UTF-8
  locale makes `utf8_locale` fail the case rather than pass it.
- On the fixed code (leak removed) the same run must print `1 1`. Hand-run
  commands: `LC_ALL=C.UTF-8 /tmp/claude/bash32/bash -c '. lib/verdicts.sh;
  x="—"; a=${#x}; _verdict_has_control x; echo $a ${#x}'` gives `1 3` today.
  The `LC_ALL=C` run cannot show the leak (it starts in C); the reviewer's
  `1 2` was a different probe string. The test is only a gate where the
  3.2.0 build exists, as the dispatch rules state for 3.2 checks.

## Suite results (unchanged code)

- tests/verdicts-readonly-path.bats: 16 pass, 4 fail (the four above).
- tests/verdicts-locks.bats: 5 pass, 1 fail (the finding 4 case).
