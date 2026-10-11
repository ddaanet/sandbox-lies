# Fix 5 code review (da7db9d)

Verdict: one defect found and fixed; everything else holds.

## Defect fixed

`read -r -a parts < <(printf '%s\n' "${body}x")` read one line only. The wire
grammar admits a literal newline inside the quoted body (`.` in the pattern
matches it; `%q` never writes one, so it is a forged wire). The old decoder
returned the whole body; the new one decoded only the first line and, with
`parts` empty, aborted on `${parts[0]}` under `set -u` ("unbound variable"),
which kills the hook's shell. Production wires come from line-by-line reads,
so the path is unreachable from a real probe, but it was an output change and
a crash. Fix: `read -r -d '' -a parts < <(printf '%sx' "$body") || :` (end of
input status ignored), comment extended.

Regression test added to `tests/verdicts-readonly-path.bats` ("keeps a literal
newline inside the quoted body"). State that fails it: a one-line read of the
body. Mutation (read without `-d ''`, newline-separated sentinel) gave
`not ok` on the assertion with `gave: rc=0 raw=/x/a`; restored by swapping the
strings back, `command grep` found no `nx`, suite 15 passed.

## Checks

1. Linear: the ratio test passes (suite green); `/tmp/claude/fix5/time32.sh`,
   3873-byte CJK path, decode ok everywhere: bash 3.2.0 C 0.37 s, C.UTF-8
   0.43 s; bash 5.2 C 0.26 s, C.UTF-8 0.28 s (was 31.9 s on 3.2.0 C.UTF-8).
2. Output unchanged: `/tmp/claude/fix5/roundtrip.sh` 5580 cases, 0 mismatches
   on 5.2 and 3.2.0 under C and C.UTF-8. Own differential against
   `git show da7db9d^:lib/verdicts.sh`: 16466 wires (every pair of 46 tokens:
   `\c \x41 \8 \9 \0 \1 \12 \123 \1234 \0123 \777 \400 \\ \' \" \e \E \a \n \t
   \v \f \b \r é \U0001 $' \$ "\ " \<newline> \x \1a \\\ \? \` `, plain
   text, space, tab, newline, é, quote; `\001` prefix cases; 20000 random
   strings of up to 7 tokens; empty, truncated, trailing-backslash, `$''`,
   unterminated forms). rc, raw and shown compared on bash 5.2 and 3.2.0 under
   default locale, C.UTF-8 and C: 0 differences in all six runs (2587 accepted,
   13879 rejected), after the fix above (before it, the newline wires differed).
3. No execution: `$(...)`, backticks, `\$(...)` in the body decode to literal
   text; no marker file created, on 5.2 and 3.2.0. Escapes reach `printf %b`
   only as a fixed `\0NNN` or one of `\a \b \E \e \f \n \r \t \v`.
4. bash 3.2.0: all of the above ran on `/tmp/claude/bash32/bash`. `local
   LC_ALL=C IFS=\\` is declared before use and `_verdict_has_control` is
   unaffected by the lingering `IFS`. Comments match the code; no stale text
   on the removed substitution. Changelog entry accurate (31.9 s matches the
   red/green reports) and wrapped.
