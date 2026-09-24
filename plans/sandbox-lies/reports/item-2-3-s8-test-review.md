# Item 2.3 slice 8 — test review

Scope: the five slice 8 tests and the RED report
(`item-2-3-s8-red.md`). `hooks/` and `lib/` are byte-identical to HEAD. I
checked this with `git diff --quiet hooks lib` before and after every
mutation. Nothing is committed.

## Verdict

The RED phase holds. Both temp-dir tests fail on an assertion. The other
three tests red under mutations of my own, each different from the RED
report's. I found three wrong-reason gaps, all fixed in the tests:

- F1 is major.
- F2 is major.
- F3 is minor.

F4 and F5 are notes. They record residuals and need no code change.

## Findings

### F1 — Major, fixed: a GREEN that keeps `mktemp` with a fallback directory passed both temp-dir tests

The item says `detect` stops using `mktemp`, and NFR-4 says it writes
nothing. The tests broke only `TMPDIR`. A buffer like this one passed both
tests:

```
buf=$(mktemp "${TMPDIR:-/tmp}/…" 2>/dev/null || mktemp /tmp/…)
```

That buffer still writes a temp file. I confirmed the gap by mutation. The
fallback went to `/tmp/claude-1000`, which stands in for `/tmp`, because this
sandbox mounts `/tmp` read-only. That mount would also red an unsandboxed
`/tmp` fallback here, but only here. Result against the pre-fix tests:
`2 passed, 0 failed`.

Fix: a new helper, `tests/helpers/spy.bash`. It defines
`make_spy <dir> <log> <tool>…`, which works like `make_bsd_stubs`. It
installs a PATH stub that appends its name and arguments to a log, then
execs the real tool. Both tests now put a `mktemp` spy first on `PATH`,
alongside the broken `TMPDIR`, and assert `[ ! -e "$calls" ]`. Because the
spy execs the real tool, a fallback GREEN gets past the status and output
assertions. It then reds on the spy assertion, which is the one it violates.
Behaviour, not a grep of the source.

I chose a spy over a grep of `lib/matchers.sh` for `mktemp`. The spy also
catches `mktemp` reached through any helper, and it does not fire on a
comment that mentions the word.

### F2 — Major, fixed: `event name is one of two literals` had no paired positive, and its object case could not red

- **No positive.** Both cases were `check_quiet`, so a hook that exits 0 on
  everything passed. Mutation D (`[ -n "$text" ] || exit 0` → `exit 0`)
  leaves the old test green by construction, and now reds on the new
  positive.
- **The object case was vacuous.** It was `{embedded: <porcelain>}` over the
  fixture's quiet stdout. `jq -r` pretty-prints an object with its string
  JSON-escaped, so the embedded newlines never become lines. The phantom
  matchers are line-anchored, so the case stayed quiet whatever the hook did
  with a non-literal event. Mutation B2 below accepts any non-null event and
  prints it through `tostring`. Against the pre-fix test it redded only the
  newline case, and the object case passed.

Fix: add `check_fires "literal event, firing stdout"`, with porcelain in
`tool_response.stdout` under the literal `PostToolUse`. The object case is
now that same payload with only the event changed, to
`{name: "PostToolUse"}`. Only the event check keeps it quiet. The newline
case keeps a quiet stdout, so its firing text is reachable only through a
split at the event's newline. The comment explains the choice.

### F3 — Minor, fixed: `hook needs no temp dir` left the broken run's stderr unchecked

At HEAD the broken run's `mktemp` error reached the hook's stderr. That
breaks FR-3's "no output", and nothing asserted it. Fix: both runs now use
plain `run`, which merges stderr into `$output`. `expected` must parse as one
JSON document (`jq -e .`), so the equality with the broken run also pins an
empty stderr. I did not add a separate `[ -z "$stderr" ]` check. Reading
`$stderr` in this file triggers SC2030/SC2031 against a `local stderr` in
another test, and the merged form needs no suppression. At HEAD the test now
reds on `[ "$output" = "$expected" ]`, because the merged output carries the
`mktemp` error.

### F4 — Note: the NUL test reds only under bash 4.4 or later

bash 3.2 drops a NUL from `$(...)` silently, so on macOS stock bash the
mutation cannot red it. I did not add a skip. Under 3.2 the case still
checks a real property: the NUL does not stop the verdict. A skip would
discard that. The comment now says outright that only bash 4.4 and later can
red this case. Before, it said only that the warning is bash 4.4 and later.

### F5 — Note: residuals the temp-dir tests cannot see

A write that never calls `mktemp` is unseen:

- a hard-coded path;
- a here-document or here-string. bash spools those to a temp file before
  5.1, and from 5.1 on when the body is larger than the pipe buffer. bash
  also falls back to `/tmp` by itself when `TMPDIR` is unusable, so a broken
  `TMPDIR` never shows the spool.

On this box's bash 5.2 with a small fixture, the here-document uses a pipe.
The hook's code reviews already ruled here-documents out of `annotate.sh`.
The `detect` test comment now names this residual, and the hook test
comment points to it.

`all paragraphs dropped keeps the human line` is sound. It has no finding.

## Mutation reproductions (my own; each restored by inverse replacement, `git diff --quiet hooks lib` exit 0 after)

| id | file | mutation | test | red on |
|---|---|---|---|---|
| A | `hooks/annotate.sh` | `split("\u0000") \| join("")` → `… join("\u0000")` (no-op strip) | NUL | `check_fires`: stderr carries bash's `ignored null byte` warning |
| B | `hooks/annotate.sh` | `elif $event == "PostToolUse" then` → `elif $event != null then` | event | newline case: stdout non-empty; object case: stderr (`split input … must be strings`) |
| B2 | `hooks/annotate.sh` | as B, and `$event,` → `($event \| tostring),` | event | pre-fix: newline case only (F2). Post-fix: newline and object cases, both on stdout |
| C | `hooks/annotate.sh` | `--arg sys "$human"` → `--arg sys "${context:+$human}"` | all-dropped | `[ "$sys" = "$stub_human" ]` |
| D | `hooks/annotate.sh` | `[ -n "$text" ] \|\| exit 0` → `exit 0` | event (post-fix) | positive did not fire |
| FB | `lib/matchers.sh` | `mktemp` with `2>/dev/null \|\| mktemp <other dir>` fallback | both temp-dir | pre-fix: both passed (F1). Post-fix: both red on `[ ! -e "$calls" ]` |

**Simulated GREEN.** I rewrote `detect` to hold the text in a variable and
feed each matcher with `printf '%s\n'`, as the item specifies. The full
suite ran `91 passed, 0 failed`. The strengthened tests are satisfiable. I
then restored `detect` by inverse replacement and confirmed it clean.

## Final red run (HEAD `hooks/` and `lib/`)

`scripts/run-bats.sh tests/`: 89 passed, 2 failed:

```
not ok 59 hook needs no temp dir
#   `[ "$output" = "$expected" ]' failed
not ok 87 detect needs no temp dir
#   `[ "$status" -eq 0 ]' failed
```

- `scripts/run-bats.sh tests/docs.bats`: 1 passed.
- `shellcheck tests/*.bats tests/helpers/*.bash hooks/*.sh lib/*.sh`: clean.
- `detect` over each new or edited test file: quiet.
- Line counts:

  | file | lines |
  |---|---|
  | `tests/hook.bats` | 349 |
  | `tests/matchers.bats` | 277 |
  | `tests/hook-malformed.bats` | 157 |
  | `tests/hook-cap.bats` | 212 |
  | `tests/helpers/spy.bash` | 24 |

## Files changed by this review

- `tests/helpers/spy.bash` (new): `make_spy`
- `tests/matchers.bats`: loads `helpers/spy`; `detect needs no temp dir`
  gains the `mktemp` spy, and its comment is rewritten with no "today"
  claim and with the residual
- `tests/hook.bats`: loads `helpers/spy`; `hook needs no temp dir` gains
  the spy and the merged-stderr equality
- `tests/hook-malformed.bats`: the event test gains a paired positive and a
  discriminating object case; the NUL comment states the bash 4.4 floor
- `plans/sandbox-lies/reports/item-2-3-s8-test-review.md` (this report)

**For GREEN.** `hook.bats` and `matchers.bats` now load `helpers/spy`, and
`spy.bash` must be committed with them.
