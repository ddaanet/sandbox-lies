# Item 2.3 slice 2 — RED

Mode: RED. Nothing committed. `hooks/` and `lib/` are byte-identical to HEAD
(`git diff --name-only -- hooks lib` is empty). Only `tests/hook.bats` changed.

## Tests added

Both named exactly as the slice specifies, plus one extra case, all in
`tests/hook.bats` (inserted before `hooks.json names both events`):

1. **`porcelain on stdout fires untracked`** — `fire-masks-porcelain.txt` in
   `tool_response.stdout` via `post_payload "$text"` (stderr defaults empty).
   Asserts status 0, `hookSpecificOutput.hookEventName` equals `PostToolUse`,
   and `additionalContext` contains `reading the sandbox, not the tree` (the
   closing clause of `verdict_phantom_untracked` in `lib/verdicts.sh`).

2. **`listing on stderr fires`** — the same fixture text in
   `tool_response.stderr` via `post_payload "" "$text"` (stdout empty). Same
   assertions. Paired with test 1: same helper, same event, only the field
   holding the text differs, so a hook keyed to one field only fails one of
   the pair.

3. **`rebuild inserts a newline between stdout and stderr`** (added; not
   named by the slice). `stdout='?? .bashrc'` (no trailing newline of its
   own) and `stderr='?? .gitconfig'` (test review: trailing newline dropped) — two distinct masked names, one per
   field, meeting `match_phantom_untracked`'s threshold-2 only if the hook's
   rebuild inserts a newline between the fields. A raw concatenation merges
   them into one line (`?? .bashrc?? .gitconfig`) that matches the
   line-anchored pattern zero times, so a hook that joins the two fields
   without a separator goes quiet instead of firing. Asserts status 0 and
   the same context substring. The literals sit inside quoted shell
   assignments, not alone on a source line, so `tests/docs.bats` stays quiet
   over this file (confirmed below).

## Discrimination reasoning (per the dispatch's checklist)

- A hook reading `tool_response.stdout` alone: passes test 1, fails test 2
  (stdout is empty there).
- A hook reading `tool_response.stderr` alone: fails test 1 (stderr is empty
  there, by `post_payload`'s default), passes test 2. Explicit per-field
  emptiness (not just "the other field is unused") is what the pairing
  buys — noted in each test's comment.
- A hook that concatenates the two fields with no separator: fails test 3
  only, since tests 1 and 2 each carry the fixture text in exactly one
  field with the other empty, so a missing separator does not change their
  count (still 19 distinct masked names, well over
  the threshold either way). Test 3 is what isolates the newline
  requirement.

## Genuine red

`scripts/run-bats.sh tests/hook.bats`: 3 passed, 3 failed — all three new
cases fail, each on its own assertion, not a crash:

```
not ok 3 porcelain on stdout fires untracked
#   `[ "$(printf '%s' "$output" | jq -r '.hookSpecificOutput.hookEventName')" \' failed
not ok 4 listing on stderr fires
#   `[ "$(printf '%s' "$output" | jq -r '.hookSpecificOutput.hookEventName')" \' failed
not ok 5 rebuild inserts a newline between stdout and stderr
#   `| grep -qF 'reading the sandbox, not the tree'' failed
```

All three fail because `hooks/annotate.sh` only builds `text` on
`PostToolUseFailure` today (its `case "$event"` has one arm) — a `PostToolUse`
payload always falls through to `[ -n "$text" ] || exit 0`, so `$output` is
empty and every downstream `jq`/`grep` assertion fails on its own check
rather than on a missing command or a parse error. The three preexisting
tests (`gitadd failure payload yields one verdict`, `quiet fixture yields
nothing`, `hooks.json names both events`) still pass unchanged.

`scripts/run-bats.sh tests/docs.bats`: 1 passed, 0 failed (self-quiet holds
over the edited `tests/hook.bats`).

## Untouched

`hooks/annotate.sh`, `hooks/hooks.json`, `lib/verdicts.sh`, `lib/matchers.sh`
byte-identical to HEAD. Untracked zero-byte/char-device dotfiles at the repo
root are sandbox masks from this session, not real files — left alone.
