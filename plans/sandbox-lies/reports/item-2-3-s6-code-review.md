# Item 2.3 slice 6 — code review

Scope: `hooks/annotate.sh` as changed by `Item 2.3/6 — malformed payloads
stay silent`, read as a whole script. All fixes are applied in the working
tree. Nothing is committed. `lib/` is byte-identical to HEAD.

## Probe results against the committed hook

Each input was piped into `bash hooks/annotate.sh`, and status, stdout and
stderr were captured. Tools: jq 1.7, bash 5.2.

| input | committed hook | after fixes |
|---|---|---|
| empty stdin | quiet | quiet |
| raw NUL byte in stdin | **stderr**: `line 37: warning: command substitution: ignored null byte` | quiet |
| valid payload, `stdout` holds `\u0000` followed by porcelain text | fires, **stderr**: same warning at line 50 | fires, stderr empty |
| invalid UTF-8 in a string | quiet | quiet |
| `hook_event_name` a number (`5`) | quiet | quiet |
| `hook_event_name` = `"PostToolUse\n" + porcelain text`, no text field | **fires** (`hookEventName` `PostToolUse`) | quiet |
| `hook_event_name` an object or an array | quiet (see F2) | quiet |
| `hook_event_name` `PreToolUse` with `error` and `stdout` set | quiet | quiet |
| 20000-deep `[` nesting (with and without an object wrapper) | quiet | quiet |
| two concatenated objects; `1e1000` as `stdout` | quiet | quiet |

## Findings

### F1 — NUL bytes write a bash warning to stderr (major, fixed)

bash 4.4 and later warn on stderr when `$(...)` drops a NUL byte. The hook
has two such substitutions. The realistic trigger is the second one: a
well-formed payload whose `tool_response.stdout` or `error` holds `\u0000`.
That payload comes from any Bash call that prints NULs, such as
`git ls-files -z` or `find -print0` run bare. `jq -r` then writes a raw NUL
into `parsed=$(...)`. This produces stderr output on a plain successful
call, which breaks FR-3 ("no output"). The same warning comes from
`payload=$(cat)` when the stdin itself holds a raw NUL. bash 3.2 drops the
NUL without a warning, so macOS stock bash is not affected.

Fix: jq reads stdin directly (`parsed=$(jq -Rrs '…')`), so the
`payload=$(cat)` capture and the `printf` pipe go away. The program ends in
`split("\u0000") | join("")`. That drops exactly the bytes bash would have
dropped, but without the warning. `jq -R` handles a raw NUL without error,
and `fromjson?` then rejects it.

### F2 — The event line was not guaranteed to be one line (minor, fixed)

`(.hook_event_name // "") as $event | select($event != "")` emitted any
non-empty value. There were three consequences:

- A number or `true` printed as the event line. The hook exited quietly
  only because no text followed it.
- A string holding a newline split at its first newline. Everything after
  that newline became "text", so detect ran on it and the hook fired with
  `hookEventName` set to the first line. This is the `evnl` row above.
- An object or an array pretty-prints over several lines. Its inner lines
  became "text". The phantom matchers are line-anchored, so they missed it.
  `git-lock` is not anchored and would match once Item 4.1 ships its
  verdict, and the hook would then emit `hookEventName: "{"`.

The payload comes from the harness, so this is not an attack surface. The
issue is that the header comment claimed the invariant ("event names hold
no newline") as a property of the harness, while the program did not
enforce it.

Fix: `$event` is printed only inside the two `if` branches, where it equals
the literal `PostToolUseFailure` or `PostToolUse`. The `// ""` and the
`select($event != "")` are removed. An unknown or non-string event yields
no output, which is the same observable result as before. The event line
is now always one of two newline-free literals, and `hookEventName` can
echo nothing else.

### F3 — `[ -n "$event" ]` was dead (minor, fixed)

This was already true before F2. Any output with no newline leaves `text`
empty, and any output with a newline starts with a non-empty event. The
guard never decided anything, so it is removed together with
`event="$parsed"`. `event` is set only inside the `case` arm. Under
`set -u` this is safe, because the only reader (`jq -n --arg event`) is
reached only when `text` is non-empty.

### F4 — Header comment (minor, fixed)

- The comment cited the memory slug `(jsonlreadertypeguard)`. That is a
  foreign reference that plugin readers cannot resolve. It is removed, and
  the reason is stated in its place: jq cannot index a scalar or an array
  without a fatal error.
- Accuracy: the comment presented the "no newline in the event" claim as a
  fact about the harness. It now states the enforced mechanism (F2).
  "`select(type == "object")` drops … the same way" was imprecise, and it is
  reworded. The NUL handling (F1) is explained, because otherwise
  `split/join` reads as noise.
- Length: 13 lines are now 8.
- The remaining ids (`FR-3`, `D-13`, `NFR-4`) resolve to `docs/design.md`,
  which ships in the same repo, so they are left as they are.

### F5 — jq version portability (note, no change)

Feature floor, from jq's `NEWS.md` (fetched during this review):

- jq 1.4: `objects`, `strings`, and `split` with a string argument.
- jq 1.5: `fromjson` and `try`/`?`.
- `-R`, `-s`, `-r`, `elif` and `as $x` all predate these.

The program always writes `else empty end`, so it does not depend on 1.7's
optional `else`. **The minimum is jq 1.5.**

jq 1.7 made one behavioural change: "Fix try/catch catches more than it
should". Before 1.7, a `?` also swallowed errors raised later in the
pipeline. That only makes the hook quieter on 1.5 and 1.6. On those
versions the object guard is redundant but still harmless, and the
mutation below would probably not red there.

This review did not check which jq versions macOS or Homebrew ship. Recalled,
and not verified: macOS 15 ships `/usr/bin/jq` 1.7.1, older macOS ships no
jq, and Homebrew installs the current 1.7.x or 1.8.x. Whichever is true, any
jq someone can install today is above the floor, so the minimum has no
practical effect.

### F6 — Other jq failure modes (checked, no finding)

The following are all quiet: an empty stdin (`fromjson?` yields nothing),
invalid UTF-8 (`-R` replaces it with U+FFFD), a nesting depth past jq's
limit, trailing garbage, and a huge number. A huge payload is read into
memory once, where before this fix it was held by both bash and jq. The only
stderr path left is jq being missing or crashing. `|| exit 0` catches the
status of both, but bash's `command not found` message still reaches
stderr. That is outside this slice's contract, so it is noted but not
changed.

### F7 — NFR-3 timing (checked)

Mean of 20 runs, repeated 3 times, on the `quiet-clean-status` `PostToolUse`
payload:

- Committed hook: 47–49 ms.
- After the fixes: 45–49 ms.

The difference is within noise. Removing the `cat` and `printf` fork does
not show up at this resolution. The GREEN report's 58 → 53 ms was measured
under a different load on the same box. Its direction is plausible, but the
5 ms gap is also within noise. Nowhere near the 100 ms bound.

## Mutation run (the one permitted)

I removed `select(type == "object") |` from the jq program with an exact
string replacement, then ran
`scripts/run-bats.sh tests/hook-malformed.bats tests/hook.bats`. The result
was `12 passed, 1 failed`. The test `non-json, scalar, array and textless
object` went red on `scalar` and `array`, each with a jq index error on
stderr.

I restored the line by inverting the replacement. `git diff --quiet lib`
exits 0, and `git diff hooks` shows only the fixes above. The mutant line is
gone.

## Test gaps (reported, test files not touched)

- F1 has no test: no case puts `\u0000` in `tool_response.stdout` or
  `error` and asserts empty stderr alongside a fire. The suite runs bash 5,
  so such a test would red against the committed hook.
- F2 has no test: no case uses a `hook_event_name` that holds a newline
  followed by firing text, or an object event wrapping `git-lock` text with
  the stub verdict.
- The header of `tests/hook-malformed.bats` cites
  `plans/sandbox-lies/reports/…` paths. These resolve inside the repo, but
  they are plan-scoped artefacts, not a stable reference. This is minor, and
  it is left to the test owner.

## Refactor flag

None. The fixes stay inside the one jq program and the split that follows
it.

## Verification

- `shellcheck hooks/annotate.sh` and `bash -n` are clean.
- `scripts/run-bats.sh tests/`: 82 passed, 0 failed.
- `just precommit`: `precommit passed: plugin.json, hooks.json, shellcheck,
  bash -n, rumdl, line limits, links, tests`.

## Files changed

- `hooks/annotate.sh`
- `plans/sandbox-lies/reports/item-2-3-s6-code-review.md` (this report)
