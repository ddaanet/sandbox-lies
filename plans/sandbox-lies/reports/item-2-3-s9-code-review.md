# Item 2.3 slice 9 — code review

Scope: `git show HEAD -- hooks/annotate.sh` (commit `Item 2.3/9 — a name
with no verdict contributes nothing`). Because this slice is the last to
change the hook's logic, the whole script was also read as a finished
artifact against the Item 2.3 Interfaces. Fixes are applied in the working
tree. Nothing is committed.

## Verdict on the slice's change

The guard is correct. `declare -F` is a bash 3.2 builtin, so it adds no
fork. It is silent when the function is missing, and its `>/dev/null`
redirects stdout, not stderr. The name is prefixed with `verdict_`, so a
stray detector name cannot be read as an option. With the guard in place,
the call's `|| exit 0` covers only a verdict that exists and fails, which is
the split that finding 1 of `item-2-3-s1-code-review.md` asked for.

The fix also changes live behaviour today. `detect` already prints
`git-lock` and `config-lock`, and neither has a verdict yet. Before this
slice, a lock name firing together with a phantom name blanked the whole
output. It now emits the phantom verdict.

**Mutation run (once):** `declare -F "verdict_${name//-/_}" >/dev/null ||
continue` → `… || break`. `scripts/run-bats.sh tests/hook-verdicts.bats
tests/hook.bats` went red with 12 passed and 1 failed. The failure is `a name
with no verdict contributes nothing`, and only its `verdict-less name first`
variant failed (`additionalContext []`, `systemMessage []`). That is the
variant the test's comment says exists to rule out an early stop. Restored by
the inverse replacement; `git diff --quiet hooks lib` passed before the
fixes were applied.

## Findings

### 1. Minor, fixed — plan-state text in a shipped comment

The new comment ended with `(Item 2.3 slice 9)`. A shipped script should
describe itself, not the plan that produced it, and slice 1's review had
already removed this kind of text (its finding 6). The comment now says
what the guard does and why the call keeps its own `|| exit 0`: that exit
is for a verdict that exists and fails. That second point is the one fact
about the guard a reader cannot see from the code. After the fix,
`command grep -nE 'Item [0-9]|[Ss]lice' hooks/*.sh lib/*.sh` finds nothing.

### 2. Minor, fixed — the function name was computed twice

The guard and the call each spelled out `"verdict_${name//-/_}"`. Both now
use a local variable, `fn="verdict_${name//-/_}"`, so the reader can see
that the checked function and the called function are the same.

### 3. Minor, fixed — the header overstated the success-payload text

The header said the text is "tool_response.stdout, a newline, and
tool_response.stderr". That holds only when both fields are strings. The
jq program emits each field separately behind `strings`. So when stdout is
missing or not a string, the text is stderr alone, with no leading newline,
and the reverse holds too. The header now reads "whichever of
tool_response.stdout and tool_response.stderr are strings, joined by a
newline", which matches the code and design FR-3's "stdout then stderr".
The jq paragraph had a related problem: "the event, then the text, one per
line" suggested one text line, but a text part can span several lines. It
now says each text part ends in a newline and that this is the join.

### 4. Note, not fixed — a verdict that breaks its two-line contract

If a `verdict_<name>` printed a single line, `line=${out#*"$nl"}` would
leave the whole paragraph in `line`, and the paragraph would appear in
`systemMessage`. If it printed nothing, the result would be an empty
paragraph plus a stray space. The Interfaces contract ("stdout line 1 agent
paragraph, line 2 human line") rules both out, and `verdicts.bats` already
asserts that every `verdict_*` function prints exactly two non-empty lines.
A runtime guard would duplicate a check the suite already enforces, so this
is recorded and not fixed.

### 5. Note, not fixed — a stdout write failure breaks "exit 0 always"

The final `printf '%s\n' "$json"` sets the script's exit status. If stdout
is closed, the script exits 1, or dies from SIGPIPE, while printing a
`write error`. The harness always reads the hook's stdout, and no output
reaches anyone in that case whatever the status. Adding `|| exit 0` would
be cosmetic, so this is recorded and not fixed.

### Checked, no finding

- **Header against the code.** The pipeline line, the registration (checked
  against `hooks/hooks.json`: both events, matcher `Bash`), FR-3's silent
  exit on every failure path (source, jq, detect, a failing verdict, the
  final jq), the one-jq-call and NUL paragraph, and NFR-4's no-here-document
  rule (the loop reads from process substitution) all match the code.
- **Interfaces.** Stdout is empty or a single object whose `hookEventName`
  echoes the event. That event is set only on the path that reaches the
  output, so `set -u` is safe. Verdicts are called with stdin from
  `/dev/null` and no argument, which matches phantom verdicts taking no
  outcome.
- **Comment density.** Every comment block states a reason the code cannot
  show: the chardev/untracked flag policy, the byte count under `LC_ALL=C`,
  the empty-context-with-human-line case, and the header's jq and NFR-4
  reasoning. None of them just narrates the code. Nothing was cut.

## Outside scope — reported, not changed

- **`tests/hook-verdicts.bats` header, lines 8–11, is stale since GREEN.**
  It says "today a missing verdict function makes the whole hook exit 0
  silently…". That was true of the RED tree and is false now. Its lines
  3–6 also cite plan state (`Item 2.3 paragraph`, `Item 2.3 slice 9`). The
  test-only convention for this may differ, but the "today" sentence is
  wrong whatever convention applies.
- **The `lib/matchers.sh` header is pilot-era.** It says "Candidate
  sandbox-symptom matchers for the detector pilot", and it points at
  `plans/2026-09-02-sandbox-detector-replay-results.md` and "layer 1". This
  is shipped plugin code, so it should describe itself. It belongs to
  whichever item next touches `lib/matchers.sh`, or to slice 10.

## Refactor flag

None. No fix needed a module split or a new abstraction.

## Test gaps

None for this slice. `hook-verdicts.bats` pins the name after a missing
verdict (the mutation above), the name before it, the missing name alone,
and empty stderr, which catches the `command not found` leak. No case
covers a verdict that exists but fails (non-zero exit, so the whole hook
goes quiet). The Item 2.3 slices do not name that behaviour, and it is the
FR-3 default, so this is a possible addition and not a gap.

## Verification

- `scripts/run-bats.sh tests/`: 94 passed, 0 failed.
- `direnv exec . just precommit`: `precommit passed: plugin.json,
  hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests`.

## Files changed

- `hooks/annotate.sh`: the guard's comment was rewritten (finding 1), the
  function name was hoisted into `fn` (finding 2), and two header sentences
  were corrected (finding 3).
- `plans/sandbox-lies/reports/item-2-3-s9-code-review.md`: this report.
