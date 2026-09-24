# Item 2.3 slice 9 — test review

Scope: `a name with no verdict contributes nothing`
(`tests/hook-verdicts.bats`), and `detect sees past a NUL` and
`detect on closed stdin` (`tests/matchers.bats`), plus the RED report. All
mutations were made in place as exact string replacements (each old string
confirmed unique before the swap) and restored by the inverse replacement.
After each restore, `git diff --quiet hooks lib` passed. Nothing committed.

## Findings

### 1. Major, fixed: the stderr red was hidden inside a jq parse error (`hook-verdicts.bats`)

`run_hook` used plain `run`, which merges stderr into `$output`. The RED
report says variant 1 failed because "jq chokes on empty `$output`". That is
wrong: `$output` held `annotate.sh: line 67: verdict_no_such_detector:
command not found`, and jq choked on that text. The report's hand
reproduction (`output=[]`) had split the streams, which the test does not
do. As a result:

- The test did pin empty stderr, but only by accident: with a stderr line
  prefixed, the stdout JSON no longer parsed. The failure named a jq
  parse error, not the leak.
- An implementation that does `|| continue` on the verdict call would
  swallow a genuine verdict failure and still leak `command not found`. It
  would red only through that same jq accident.

hook-malformed.bats and hook.bats:291 pin empty stderr on purpose.

**Fix.** Each variant now runs under `run --separate-stderr` and asserts
empty stderr as a check of its own.

### 2. Minor, fixed: sequential variants only surface the first red

The mechanical check found each variant can red on its own. See the
mutation table below: variant 2 reds alone under break-on-missing and under
skip-and-drop-next, and variant 3 reds alone under a missing empty-output
guard. In the sequential form, though, a later variant was reached only
when every earlier one passed. A red run named one variant, never all the
broken ones.

**Fix.** Restructured to collect-then-assert, following the
`tests/hook-malformed.bats` pattern:

- `check_emits` checks status 0, empty stderr, `additionalContext` and
  `systemMessage`.
- `check_quiet` checks status 0, empty stdout and empty stderr.
- `assert_no_failures` is the single assertion, and it prints every miss.

### 3. Major, fixed: F3's unbound-variable spam was unpinned (`detect on closed stdin`)

Mutation: `local text='' status` → `local text status`. This brings back
F3's first bullet. On closed stdin it produces the `0: Bad file descriptor`
line plus five `text: unbound variable` lines, exits 1 and prints nothing
on stdout. Before the fix, the whole six-suite run was 51 passed, 0 failed,
so the mutation survived: the test asserted only status and stdout.

**Fix.** Added `[ "${#stderr_lines[@]}" -eq 1 ]`, with a justified
`SC2154` disable because bats sets that array. This pins "reports once on
stderr". It also rules out a silenced version, which `no-stderr-suppression`
forbids anyway. The test comment now names both halves of F3.

### 4. Minor, fixed: the closed-stdin comment named the wrong mechanism

The comment said fd 0 was left "pointing at a pipe this harness keeps open
elsewhere". I probed it with a throwaway SUT under bats that reports fd 0
state using only builtins: `{ : 9<&0; }`, then `readlink /proc/$$/fd/0`.
There is no command substitution, since one would take a free fd 0.
Results:

| invocation | SUT fd 0 |
|---|---|
| `run … timeout 5 bash -c 'bash "$1" <&-' _ SUT` (the test's form) | closed |
| `run … timeout 5 bash SUT <&-` (naive form) | open, `pipe:[…]` |
| plain shell `timeout 5 bash SUT <&-` | closed |

The naive form closes fd 0 for `run`, and `run`'s own capture substitution
then takes the freed fd 0 for its pipe. That is F3's mechanism, one level
up. So the inner form really does close the SUT's stdin, and the test
covers the same condition F3 describes. I rewrote the comment to say this.

(A first probe used `{ : <&0; }`. It reported "open" in every case,
because bash treats `n<&n` as a no-op. I discarded it.)

### 5. Minor, fixed: the NUL test did not guard its own fixture

If someone edits the `printf` and the NUL disappears, the test becomes an
ordinary firing case that passes without testing anything. I added
`[ "$(LC_ALL=C tr -cd '\000' < "$input_file" | wc -c)" -eq 1 ]`. I checked
the guard by hand: it counts 1 with the NUL and 0 without. bash `[` accepts
BSD `wc`'s padded count.

### 6. Nit, fixed: `command -v timeout >/dev/null 2>&1`

`command -v` writes nothing to stderr, so `2>&1` was a blanket redirect
with no job to do (`no-stderr-suppression`). I dropped it.

### Checked, no finding

- **Stub scope.** `stub_lib` appends only to `$HOOK_COPY/lib/matchers.sh`.
  The repo's `lib/` is untouched: `git diff --quiet hooks lib` passes after
  each run. A later appended `detect` wins, so the three restubs in turn
  work.
- **Expected text.** It comes from the copy's `verdict_phantom_gitadd`,
  lines 1 and 2, and both are guarded non-empty.
- **Stub liveness.** The payload's own text fires `phantom-gitadd`. If a
  stub failed to replace `detect`, the alone variant would emit it and red.
  A comment now says so.
- **Skip that also drops the next name.** Covered by variant 2 (mutation
  below).
- **NUL placement.** The firing line comes after the NUL:
  `quiet preamble text\n\000error: …`. The firing sentence is built from
  fragments, and running `bash lib/matchers.sh` over both edited files
  still exits 1 (quiet).

## Mutation reproductions

Each row was run against the revised tests.

| subject | mutation (mine) | result |
|---|---|---|
| `annotate.sh` | `declare -F … \|\| break` before the verdict call (fixes only "working name first") | red, only `verdict-less name first` (ctx, sys) |
| `annotate.sh` | `declare -F … \|\| { IFS= read -r name; continue; }` (skips unknown, drops next) | red, only `verdict-less name first` |
| `annotate.sh` | `declare -F … \|\| continue` plus `[ -n "$context$human" ] \|\| exit 0` → `:` | red, only `verdict-less name alone` (stdout holds empty-field JSON) |
| `annotate.sh` | verdict call `\|\| exit 0` → `\|\| continue` (stderr leaks) | red, stderr miss on all three variants |
| `annotate.sh` | `declare -F … \|\| continue` alone (the plausible GREEN) | green: the test does not over-constrain |
| `matchers.sh` | `tr -d '\000'` → `tr '\000' '\001'` then `text=${text%%$'\001'*}` (stops at first NUL) | red `detect sees past a NUL`, `[ "$status" -eq 0 ]` |
| `matchers.sh` | group → `{ text=$(cat <&3); } 3<&0` (bash warns on NUL) | red `detect sees past a NUL`, `[ -z "$stderr" ]` |
| `matchers.sh` | group → `text=$(LC_ALL=C tr -d '\000' </dev/stdin)` (reopens fd 0, which is the substitution's pipe: hang) | red `detect on closed stdin`, `[ "$status" -ne 124 ]` |
| `matchers.sh` | `local text='' status` → `local text status` (F3's original spam) | survived before the fix (51/0); after the fix, red `detect on closed stdin`, `stderr_lines` count |

In every row, only the test named for the mutation went red.

The RED report does prove `detect on closed stdin` by mutation: its table
has `→ text=$(LC_ALL=C tr -d '\000')`, red on `status -ne 124`. The
mutations above are different from the report's.

## Final red run

`scripts/run-bats.sh tests/hook.bats tests/hook-malformed.bats
tests/hook-cap.bats tests/hook-verdicts.bats tests/matchers.bats
tests/docs.bats`: 51 passed, 1 failed. The failure is
`a name with no verdict contributes nothing`, on
`assert_no_failures`:

```
# verdict-less name last: stderr [.../hooks/annotate.sh: line 67: verdict_no_such_detector: command not found]
# verdict-less name last: additionalContext []
# verdict-less name last: systemMessage []
# verdict-less name first: stderr [... command not found]
# verdict-less name first: additionalContext []
# verdict-less name first: systemMessage []
# verdict-less name alone: stderr [... command not found]
```

That is a genuine assertion red, and every variant shows it at once.

- `scripts/run-bats.sh tests/docs.bats`: 1 passed, 0 failed.
- `shellcheck tests/matchers.bats tests/hook-verdicts.bats`: clean.
- Line counts: `tests/hook-verdicts.bats` 101, `tests/matchers.bats` 318.
- `tests/hook-verdicts.bats` loads `helpers/bsd-stubs`.
- `git diff --quiet hooks lib`: passes. `git status --porcelain -- hooks
  lib tests` shows only `M tests/matchers.bats` and
  `?? tests/hook-verdicts.bats`.

## Note for GREEN

Pass condition: all three variants with empty stderr. The minimal fix is a
`declare -F "verdict_${name//-/_}" >/dev/null || continue` guard ahead of
the call, keeping `|| exit 0` for a verdict that exists but fails. That fix
turns the test green with no other change (row 5 above).
