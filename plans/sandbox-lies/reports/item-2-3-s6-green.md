# Item 2.3 slice 6 — GREEN report

Mode: GREEN. Slice 6 (malformed payload): rewrote `hooks/annotate.sh`'s
payload parse as one `jq` call that cannot error on any input, per the
red report and test review's finding 3.

## Step 1 — confirm the slice's tests are red

`scripts/run-bats.sh tests/hook-malformed.bats` against the unmodified
`hooks/annotate.sh`: `0 passed, 2 failed`, matching the test review's final
red run exactly (test 1 leaks `jq`'s parse/index errors to stderr on `not
json`, `42`, `[1]` and the string-`tool_response` case; test 2 leaks the
stub `git-lock` verdict JSON on stdout for the object/array non-string
cases).

## Step 2 — fold the two jq reads into one guarded call

Replaced the event read (`jq -r '.hook_event_name // empty'`) and the
per-event text read (`jq -r '.error // empty'` /
`jq -r '.tool_response.stdout // empty, .tool_response.stderr // empty'`)
with a single call:

```
jq -Rrs '
    fromjson? | select(type == "object") |
    (.hook_event_name // "") as $event |
    select($event != "") |
    $event,
    (if $event == "PostToolUseFailure" then
       (.error | strings)
     elif $event == "PostToolUse" then
       (.tool_response | objects) as $tr |
       ($tr.stdout | strings), ($tr.stderr | strings)
     else empty end)
  '
```

`-Rs` slurps stdin as one raw string, so a non-JSON payload never reaches
jq's own parser (which would otherwise raise before any filter runs, per
`jsonl-reader-type-guard`); `fromjson?` attempts the decode inside the
filter and `?` swallows a failure there. `select(type == "object")` drops a
scalar or array payload the same way — indexing either is fatal, the same
guard the memory file names for a JSONL reader. Every leaf read ends in
`strings`, so a non-string field (a number, an object, an array) is dropped
rather than rendered as text — the "strings-only field reads" the test
review's finding 3 named as what GREEN must do. `(.tool_response |
objects) as $tr` guards the `PostToolUse` branch the same way at one more
level: a string `tool_response` produces zero output for the whole branch,
matching the "tool_response is a string" case.

No `2>/dev/null` anywhere: every path that can fail (bad JSON, wrong type,
non-string leaf) is caught by a guard ahead of the read, so nothing reaches
stderr on the malformed inputs (`no-stderr-suppression`); a real jq failure
(the tool itself missing, or a bug) still surfaces on stderr up to the
final `|| exit 0`, which only swallows the exit status, not the stream.

**Framing.** jq prints the event name on its own line, then the text. Event
names hold no newline — the harness emits only `PostToolUse` or
`PostToolUseFailure` — so bash splits on the first literal newline (the
existing `nl` variable, moved up from its old position before the verdict
loop since it is now needed at the top): `event=${parsed%%"$nl"*}`,
`text=${parsed#*"$nl"}`, guarded by a `case` so a jq output with no newline
in it (the fully-filtered-out cases, and the "event only, no text" cases)
leaves `text=""` instead of misreading `parsed` as the event. The header
comment states this framing and why it is safe, and the "Any parse or
runtime failure exits 0" paragraph was rewritten to describe the new
single-call guard chain instead of the two-arm `case`.

`[ -n "$event" ]` and `[ -n "$text" ]` stay as separate checks after the
split: the first catches the cases jq fully filters out at the top
(`select($event != "")` yields nothing, so `parsed` is empty); the second
catches an event that parsed but whose branch produced no text (textless
object, non-string leaf, wrong-type `tool_response`).

## Step 3 — tests green

`scripts/run-bats.sh tests/hook-malformed.bats`: 2 passed, 0 failed.
`scripts/run-bats.sh tests/`: 82 passed, 0 failed (unchanged suites:
`hook.bats`, `verdicts.bats`, all others).

`shellcheck hooks/annotate.sh` and `bash -n hooks/annotate.sh`: both clean.

## Step 4 — quiet-path timing

Mean of 20 runs of `bash hooks/annotate.sh` on a `quiet-clean-status`
`PostToolUse` payload, built the same way the tests build it
(`jq '.tool_response.stdout = $o | .tool_response.stderr = $e'` over
`tests/fixtures/payload-post.json`, `$o` the fixture text, `$e` empty),
fed on stdin:

| path | before (HEAD) | after (this slice) |
|---|---|---|
| `quiet-clean-status` as a `PostToolUse` payload | 58 ms | 53 ms |

Measured by stashing only `hooks/annotate.sh` (`git stash push --keep-index
-- hooks/annotate.sh`) for the "before" run, then `git stash pop` to
restore this slice's change; `scripts/run-bats.sh tests/` (82 passed) and
`git diff --stat hooks/` were re-checked after the pop to confirm the
restore landed the slice's change and nothing else. The improvement matches
slice 2's review estimate (about 6 ms per call for folding the two jq reads
into one) inside this box's noise; the quiet path is still dominated by
`detect` itself (`mktemp`, five matchers), unchanged by this slice.

## Step 5 — precommit

`just precommit`: `precommit passed: plugin.json, hooks.json, shellcheck,
bash -n, rumdl, line limits, links, tests`.

## Scope

Only `hooks/annotate.sh`'s payload parse changed. No change to
`lib/matchers.sh`, `lib/verdicts.sh`, `hooks/hooks.json`, or any test file
beyond what RED and test review already landed. Slices 7–10 (the 2 KB cap,
`detect` without `mktemp`, verdict-less names, BSD), memory retirement and
Item 2.4 were not touched.
