# Item 2.3 slice 8 — RED

Scope: five tests pinning NFR-4 (`detect` and the hook write nothing, no
temp dir) and two of slice 6/7's code-review findings. `hooks/` and `lib/`
are byte-identical to HEAD; only test files changed.

## Tests added

| test | file | line | red today? |
|---|---|---|---|
| `detect needs no temp dir` | `tests/matchers.bats` | 260 | yes, genuine |
| `hook needs no temp dir` | `tests/hook.bats` | 282 | yes, genuine |
| `NUL in the text stays quiet on stderr` | `tests/hook-malformed.bats` | 114 | no — proven by mutation |
| `event name is one of two literals` | `tests/hook-malformed.bats` | 130 | no — proven by mutation |
| `all paragraphs dropped keeps the human line` | `tests/hook-cap.bats` | 184 | no — proven by mutation |

## Genuine reds

### `detect needs no temp dir`

`detect` in `lib/matchers.sh` still buffers through `mktemp
"${TMPDIR:-/tmp}/sbx-detect.XXXXXX" || return 2`. With `TMPDIR` pointed at a
directory that does not exist, `mktemp` fails outright (confirmed by probe:
`mktemp: failed to create file via template … No such file or directory`,
exit 1) — the template's trailing X's randomise only the leaf name, not a
missing parent, so there is no silent fallback to `/tmp`. `detect` then
`return`s 2 before printing anything.

```
not ok 27 detect needs no temp dir
# (in test file tests/matchers.bats, line 268)
#   `[ "$status" -eq 0 ]' failed
```

### `hook needs no temp dir`

The hook's `names=$(printf '%s\n' "$text" | detect) || exit 0` swallows
`detect`'s exit 2 and exits quietly. The test computes slice 1's expected
stdout in the same run (no `TMPDIR` override), asserts it non-empty, then
re-runs the identical payload with `TMPDIR` pointed at a nonexistent
directory and asserts the same stdout — a plain "did the temp dir end up
empty" check would pass against today's code regardless, since the mktemp
buffer removes itself once `detect` returns.

```
not ok 38 hook needs no temp dir
# (in test file tests/hook.bats, line 304)
#   `[ "$output" = "$expected" ]' failed
```

(Broken-TMPDIR run's stdout is empty; the mktemp error instead reaches the
hook's own stderr, captured separately by `run --separate-stderr` and not
compared here.)

## Mutation proofs

The other three tests pin behaviour slice 6 and slice 7's code reviews
already shipped (`item-2-3-s6-code-review.md` F1/F2,
`item-2-3-s7-code-review.md` finding 1), so they pass against HEAD today.
Each was proven by one exact-string mutation, reverted by the inverse
replacement; `git diff --quiet hooks lib` confirmed clean both before each
mutation and after each restore.

### `NUL in the text stays quiet on stderr` (F1)

Mutation: removed the NUL-strip pipeline stage from the jq program in
`hooks/annotate.sh`:

```
    else empty end |
    split("\u0000") | join("")
  ') || exit 0
```
→
```
    else empty end
  ') || exit 0
```

Result: `1 failed` —

```
not ok 1 NUL in the text stays quiet on stderr
# NUL then firing text: positive did not fire: status 0, stderr
#   [.../hooks/annotate.sh: line 41: warning: command substitution:
#    ignored null byte in input]
```

Restored by the inverse replacement; `git diff --quiet hooks lib` exits 0;
test passes again.

### `event name is one of two literals` (F2)

Mutation: relaxed the two exact-equality tests on `$event` to a
type-guarded prefix match, in effect re-allowing a non-literal event line:

```
    .hook_event_name as $event |
    if $event == "PostToolUseFailure" then
      $event, (.error | strings)
    elif $event == "PostToolUse" then
      $event,
      (.tool_response | objects | (.stdout | strings), (.stderr | strings))
    else empty end |
```
→
```
    .hook_event_name as $event |
    if ($event | type == "string") and ($event | startswith("PostToolUseFailure")) then
      $event, (.error | strings)
    elif ($event | type == "string") and ($event | startswith("PostToolUse")) then
      $event,
      (.tool_response | objects | (.stdout | strings), (.stderr | strings))
    else empty end |
```

Result: `1 failed` — the newline-then-firing-text case fired (full
`phantom-untracked` verdict JSON on stdout instead of empty):

```
not ok 1 event name is one of two literals
# newline then firing text: stdout [{ "hookSpecificOutput": { ... } ...
```

Restored by the inverse replacement; `git diff --quiet hooks lib` exits 0;
test passes again.

### `all paragraphs dropped keeps the human line` (s7 finding 1)

Mutation: restored the old all-context guard, dropping the human-line
channel from the check:

```
[ -n "$context$human" ] || exit 0
```
→
```
[ -n "$context" ] || exit 0
```

Result: `1 failed` — with `context` empty, the old guard exits before
printing anything, so `systemMessage` never reaches `$stub_human`:

```
not ok 1 all paragraphs dropped keeps the human line
# (in test file tests/hook-cap.bats, line 211)
#   `[ "$sys" = "$stub_human" ]' failed
```

Restored by the inverse replacement; `git diff --quiet hooks lib` exits 0;
test passes again.

## Verification

- `git diff --quiet hooks lib` exits 0 (checked after every mutation restore
  and once more at the end): `hooks/` and `lib/` are byte-identical to HEAD.
- `shellcheck tests/*.bats hooks/*.sh lib/*.sh`: clean.
- `bash -n` over every tracked `hooks/*.sh` and `lib/*.sh`: clean.
- `scripts/run-bats.sh tests/matchers.bats tests/hook.bats
  tests/hook-malformed.bats tests/hook-cap.bats tests/docs.bats`:
  47 passed, 2 failed — exactly `detect needs no temp dir` and
  `hook needs no temp dir`.
- `scripts/run-bats.sh tests/` (full suite): 89 passed, 2 failed — same two,
  nothing else regressed.
- Line counts after the additions, all under the 400-line cap:
  `tests/matchers.bats` 270, `tests/hook.bats` 341,
  `tests/hook-malformed.bats` 147, `tests/hook-cap.bats` 212.
- `git status --porcelain` on `hooks/`, `lib/`, `tests/`,
  `plans/sandbox-lies/`: only the four test files and this report are
  modified/added; untracked zero-byte/char-device dotfiles at the repo root
  are sandbox masks, not repo state.

## Files changed

- `tests/matchers.bats` — `detect needs no temp dir`
- `tests/hook.bats` — `hook needs no temp dir`
- `tests/hook-malformed.bats` — `NUL in the text stays quiet on stderr`,
  `event name is one of two literals`
- `tests/hook-cap.bats` — `all paragraphs dropped keeps the human line`
- `plans/sandbox-lies/reports/item-2-3-s8-red.md` (this report)

## Scope

Out: slices 9–10, the implementation (removing `detect`'s `mktemp` buffer),
memory retirement, Item 2.4. Nothing under `hooks/` or `lib/` was committed
or left modified.
