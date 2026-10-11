# Minor batch D: findings 10 and 11

## Finding 10: vacuous BSD-stub case in tests/verdicts-readonly-path.bats

Decision: removed the case "decodes the same with the BSD stubs first on
PATH" and its `stubbed_verdict` helper; the suite header now says why.

Reason: CLAUDE.md requires a BSD re-run only for a suite whose code under test
calls a stubbed tool. `lib/verdicts.sh` forks none. A grep for sed, grep,
awk, tr, cut, wc, stat, mktemp, cat, head, tail, date, od, basename, dirname
and git over non-comment code found only `printf` (a builtin). Its `$(...)`
subshells (`_lock_rerun`, `_lock_retry`) run library functions, and the
decoder uses parameter expansion, `printf -v` and `read -a` on builtin
input. The only `sed` in the case was the test's own pipeline stage, outside
the code under test. The suite still loads `helpers/bsd-stubs`.

Coverage lost: none. The case's wires (the blank/ampersand form, the UTF-8 and
quote form, the newline form) are decoded byte-exact by the retained cases
"shows each character %q escapes, byte-exact", "shows a UTF-8 path
byte-exact" and "shows the wire form for a path holding a newline".

## Finding 11: encoded BATS_TEST_TMPDIR literals

Confirmed at HEAD: 13 in tests/probes-readonly.bats, 1 in
tests/probes-config.bats, 4 in tests/probes.bats (two of those already had an
inline guard).

Decision: one helper, `assert_unescaped_dir <dir>`, in
tests/helpers/probes.bash (all three suites already load it): returns 1 and
names the directory unless `LC_ALL=C printf %q` leaves it unchanged. Called
from the `setup` of probes.bats, probes-config.bats and probes-readonly.bats,
so every case in them fails loudly on a hostile TMPDIR. The two inline
guards in probes.bats were redundant and are removed; the comment names the
setup guard instead.

Helper proof: the new case "assert_unescaped_dir fails for a directory name
holding a byte %q escapes" (probes.bats) builds names at run time under
$BATS_TEST_TMPDIR (blank, quote, UTF-8 pair, tab) and requires status 1 plus
the message on stderr for each, and status 0 for a plain name.

Mutation proof (helper made a constant pass): replaced the test line in the
helper with `true && return 0`; grep found the mutation (count 1); the case
went red on its own assertion (`[ "$status" -eq 1 ]`, "name a\ b passed").
Restored by the reverse replacement; grep count 0; case green. Setup proof:
`TMPDIR="/tmp/claude/minor d/t"` ran `absent lock, sandboxed, is mask`, which
failed in `setup` at `assert_unescaped_dir` with the message naming the
directory.

### Assertions removed from tests/probes-config.bats

All three followed `[ "$output" = mask ]` (or `= gone`), a whole-output
equality, so each is implied and cannot fail while that line holds (and if
that line fails, the case is already red). Checked by evaluating every
removed expression with output set to `mask` and to `gone`: all held.

- "each probe reads only its own lock line", last block: first line not
  `orphan`, first line not `held`, zero `path=$index` lines (an output equal
  to `mask` has one line, `mask`).
- "pathless text never names the base", flag-false block: first line not
  `held`, not `orphan`, zero `pid=` lines.
- Same case, flag-true block (`= gone`): the same three.

The `[ -z "$stderr" ]` assertions stay: stderr is not part of `$output`.

## Precommit recap

Suites run one at a time with scripts/run-bats.sh: probes.bats 16 passed,
probes-config.bats 13 passed, probes-readonly.bats 17 passed,
verdicts-readonly-path.bats 20 passed. Line counts: probes.bats 389,
probes-config.bats 314, probes-readonly.bats 388, helpers/probes.bash 292,
verdicts-readonly-path.bats 361. No changelog bullet: tests only.
