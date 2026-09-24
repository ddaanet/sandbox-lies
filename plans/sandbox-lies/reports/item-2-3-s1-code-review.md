# Item 2.3 slice 1 — code review

Scope: `git show HEAD -- hooks lib justfile` (commit `Item 2.3/1 — hook
external contract and phantom verdicts`). Fixes applied in the working tree,
nothing committed.

## Findings

### 1. Major — a detected name with no verdict function emits empty JSON (FR-3)

`out=$("$fn" </dev/null)` did not check its status. `detect` already
prints `git-lock` and `config-lock`, which have no verdict functions yet. On
`fire-lock-add-commit` as a failure payload, the hook printed
`verdict_git_lock: command not found` on stderr and then emitted
`{"hookSpecificOutput":{…,"additionalContext":""},"systemMessage":""}`,
exiting 0. That is a runtime failure with non-empty stdout, and any live
git-lock failure would have produced it. When a lock name and a phantom name
fired together, the context also got a stray empty paragraph and the
`systemMessage` a doubled space.

**Fix:** `out=$("verdict_${name//-/_}" </dev/null) || exit 0`. Any verdict
failure, including a missing function, now exits 0 with empty stdout.
Verified on `fire-lock-add-commit`: no stdout, exit 0. This does not
implement slice 9. Slice 9 skips a verdict-less name so that the other
names still emit, which needs a `declare -F` guard ahead of the call. The
`|| exit 0` stays correct after that guard lands, because it covers a
verdict that exists but fails. Slice 9's two cases stay red against this
code (the mixed case now emits nothing, not the gitadd paragraph).

### 2. Major — here-document writes a temp file on bash < 5.1 (NFR-4)

The name loop was fed by `done <<NAMES … NAMES`. Before 5.1, bash always
spools a here-document through a temp file in `$TMPDIR` (or `/tmp`).
Here-documents started using pipes in 5.1, and only below the pipe-buffer
size. macOS ships bash 3.2, and `bash "…/annotate.sh"` resolves to it
unless Homebrew bash comes first on `PATH`. So on the primary target the
hook wrote a file on every firing call. The Linux box runs 5.2, so no test
here can see it, and slice 8's nonexistent-`TMPDIR` case would not catch it
either: when `TMPDIR` is unusable, bash falls back to `/tmp`.

**Fix:** `done < <(printf '%s\n' "$text" | detect)`. Process substitution
goes through `/dev/fd` on Linux and macOS, so nothing is written. The header
comment records the constraint in one line. `detect`'s own `mktemp` is
unchanged, since slice 8 owns it.

### 3. Minor — unchecked `sed` splits, four forks per verdict

`$(printf '%s\n' "$out" | sed -n '1p')` and the same for line 2 had no
status check. A failing `sed` would have yielded empty parts and the empty
JSON of finding 1. They also cost four processes per verdict on a path
NFR-3 bounds at 100 ms.

**Fix:** parameter expansion on a literal newline (`nl`), which works on bash
3.2 and cannot fail: `para=${out%%"$nl"*}`, `line=${out#*"$nl"}`,
`line=${line%%"$nl"*}`. As a side effect, slice 10's `sed` stub no longer
exercises anything in the hook, so it becomes a smoke run for `grep` (inside
`detect`) alone.

### 4. Minor — the final `jq -n` could fail with a non-zero exit

The last command was `jq -n …`, so its status became the script's status,
which breaks the "exit 0 always" contract.

**Fix:** `json=$(jq -n …) || exit 0; printf '%s\n' "$json"`. A failure now
leaves stdout empty and exits 0.

### 5. Minor — arrays under `set -u` on bash 3.2

`context_parts` and `human_parts` were only expanded behind the length
guard, so they were safe. Bash before 4.4 fails on `"${arr[@]}"` for an
empty array under `set -u`, though, and slice 9's skip would make an empty
array reachable. Because the loop was rewritten for findings 1–3 anyway, the
parts now accumulate as strings: `context="${context:+$context$nl}$para"`,
`human="${human:+$human }$line"`. The joins are unchanged (newline, single
space), and the guard becomes `[ -n "$context" ]`. There are no arrays
left in the hook.

### 6. Minor — plan-state text in shipped comments

The `annotate.sh` header had a paragraph starting "Slice 1 (Item 2.3)" that
included "lands in a later slice" and "Probe calls join in Item 4.1".
`verdicts.sh` had "Item 4.1 adds the lock verdicts". Its first line also
claimed a `probes` stage the script does not have.

**Fix:** both headers now describe the script as it is: "payload -> text ->
detect -> verdicts -> one JSON object", and "a PostToolUse payload
contributes none". Design ids (FR-3, D-13, NFR-4) stay, because
`docs/design.md` is the repo's living doc. Slices 2 and 4.1 will need to
edit these lines when they change the behaviour.

### 7. Minor, flagged, not fixed — `systemMessage` joiner

With several verdicts, the human lines join with a single space:
`phantom dotfiles — sandbox masks in listing phantom dotfiles — masks listed
as untracked`. That reads as one run-on clause, and FR-6 and D-7 describe
`systemMessage` as one lowercase clause per verdict. Design §Flow only says
the lines "concatenate". Slice 3 removes the phantom pair case, but
`git-lock` and `phantom-gitadd` can fire together once Item 4.1 lands. This
review recommends `; ` as the joiner. It is a design choice, so it is left
to the lead or my human partner. Slice 7 asserts only that both lines are
present, so either joiner passes it.

### 8. Minor, flagged — the untracked paragraph opens with "character-device entries"

`verdict_phantom_untracked` is the chardev paragraph followed by the added
sentence. That is the literal expansion of detectors.md's "As
`phantom-chardev`, with: …", and slice 3 relies on it. On a `git status`
porcelain result there are no visible character-device entries, only `??`
names, so the paragraph's subject names something the agent cannot find in
that listing. This is a detectors.md wording question, not a code defect.
It is flagged here and the text was not changed.

### 9. Note — stderr on exit-0 paths

hook-authoring §output-channels: stderr is ignored on exit 0. It goes to the
debug log only and is shown to neither the user nor the agent. The
unsuppressed stderr on the failure paths therefore costs nothing visible
and helps debugging under `--debug`, which matches no-stderr-suppression.
Slice 6 does assert empty stderr for `not json`, `42`, `[1]`, `{}` and a
string `tool_response`. The current `jq -r '.hook_event_name // empty'`
prints a parse error on `not json` and "Cannot index number" on `42`
(verified). Slice 6 will therefore have to replace the two jq reads with a
raw read that parses quietly, such as `jq -R 'fromjson? |
select(type == "object") | …'`, rather than add a guard beside them. The
same slice could fold the two jq calls (event, then text) into one. That is
a refactor and is flagged, not done.

Also noted: hook-authoring calls a bare `|| exit 0` a "dishonest error
path" and prefers `systemMessage` + exit 0. FR-3 deliberately picks silent
exit, so this is not a finding.

### Checked, no finding

- **Failure-path enumeration** (after the fixes, under `set -u`, no
  `set -e`). Each path exits 0 with empty stdout; stderr is noted per path.
  - jq missing: the first `jq` substitution returns 127 and `|| exit 0`
    fires; stderr shows `jq: command not found`.
  - jq parse error or wrong type: jq exits 2 or 5 and `|| exit 0` fires;
    stderr carries jq's message.
  - lib missing: in non-POSIX bash, `.` returns 1 without exiting the
    shell, then `|| exit 0` fires; stderr carries "No such file". Both libs
    end in function definitions, so a successful source returns 0.
  - `detect` exits 2: nothing is printed, the loop runs zero times, and
    `[ -n "$context" ] || exit 0` exits; stderr carries mktemp's message.
  - Verdict function missing or failing: `|| exit 0`, per finding 1.
  - sed failure: the path no longer exists (finding 3).
  - printf failure: the final `printf` is the one remaining unchecked
    write. If stdout is closed, nothing reaches the harness anyway.
- **Verdict text.** Byte-compared against detectors.md, with wrapped lines
  joined:
  - chardev: paragraph and human line equal.
  - gitadd: paragraph and human line equal.
  - untracked: human line equal; the paragraph equals the chardev paragraph
    plus the capitalised added sentence.
  - The chardev human line `phantom dotfiles — sandbox masks in listing` is
    exact, with a U+2014 em-dash, lowercase, and no instruction.
  - All three paragraphs are under 400 characters, and the only `delete`
    is the sanctioned phrase.
- **hooks.json.** Uses the plugin wrapper format (`{"hooks": {…}}`), with
  `PostToolUse` and `PostToolUseFailure` only (FR-1: no `PreToolUse`),
  matcher `Bash`, type `command`, and timeout 10 (NFR-3). The command is
  `bash "${CLAUDE_PLUGIN_ROOT}/hooks/annotate.sh"`, quoted against a spaced
  plugin root. The optional `description` is absent, which is acceptable.
- **Lib sourcing.** Libs are sourced from `$(cd "$(dirname
  "${BASH_SOURCE[0]}")" && pwd)/../lib`, with `CDPATH=''` and `--`, never
  via `CLAUDE_PLUGIN_ROOT`, as the item paragraph requires.
- **Held text.** The text lives in `payload`, `text` and `context`, with
  no file writes by the hook itself after finding 2.
- **bash 3.2.** `${name//-/_}`, `$(…)`, `< <(…)`, `${var:+…}` and
  `${var%%"$nl"*}` all exist in 3.2. No `mapfile`, `declare -A`,
  `${,,}` or `$'…'` remains.
- **Whitespace.** Every expansion is quoted, and `IFS= read -r` is used on
  the name loop. Detector names are fixed tokens.
- **justfile.** `report hooks.json jq empty hooks/hooks.json` sits beside
  the plugin.json parse, and the gate recap lists `hooks.json`.
- **Later-slice paths.** The hook ignores the flag, which is what slice 4
  expects. The chardev and untracked paragraphs are both emitted (slice 3
  replaces this), and `PostToolUse` yields no text (slice 2 adds it). None
  of these does something a later slice must undo beyond the jq reads in
  finding 9.

## Mutation run (the one permitted)

Mutation: in `lib/verdicts.sh`, delete ` Leave them out of every add, delete
and report.` from `verdict_phantom_chardev` only (the first occurrence).
Result: `scripts/run-bats.sh tests/hook.bats tests/verdicts.bats` reported
6 passed, 0 failed, so the tests stayed green. The mutation was inverted,
and `git diff --quiet hooks lib` confirmed the restore before any fix was
applied.

## Test gaps

- **Verdict text is not pinned to detectors.md.** The mutation above
  survives. No case asserts the chardev or untracked paragraph, or any human
  line except gitadd's. A dropped sentence, a changed act or a typo passes
  as long as it stays under 400 characters, stays quiet and avoids
  "remove". Suggested case for `verdicts.bats`: per row, assert line 1 and
  line 2 against expected strings held in the test. The source doc
  deliberately holds the untracked paragraph only by reference, so parsing
  detectors.md would be brittle.
- **Verdict-less name** (finding 1). Only slice 9 covers it. Until then a
  git-lock fixture through the hook is unpinned. Slice 5's quiet sweep does
  not touch `fire-lock-*`.
- **No test runs the hook under bash < 5.1**, so finding 2 is pinned by
  review only. That matches NFR-4's own "pinned by: review; no test".

## Refactor flag

- Folding the two `jq` payload reads into one call, best done inside slice
  6's parse rewrite (finding 9). This needs no module split.

## Files changed

- `hooks/annotate.sh`: header comment; name loop fed by process
  substitution; verdict call `|| exit 0`; line splits by parameter
  expansion; string accumulation in place of arrays; final `jq` captured
  and printed.
- `lib/verdicts.sh`: header comment, plan-state clause dropped.

## Verification

- `scripts/run-bats.sh tests/`: 71 passed, 0 failed.
- `direnv exec . just precommit`: exit 0, printing `precommit passed:
  plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links,
  tests`.
- By hand: the gitadd payload gives the same object as before, and
  `fire-lock-add-commit` now gives empty stdout with exit 0.
