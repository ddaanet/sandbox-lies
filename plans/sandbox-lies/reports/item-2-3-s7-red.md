# Item 2.3 slice 7 — RED

Test added: `tests/hook-cap.bats` (new file — adding to `tests/hook.bats`,
already at 316 lines, risked the 400-line cap; the topic, the context-cap
policy of FR-6, is distinct from the malformed-payload suite in
`tests/hook-malformed.bats`).

## Test

`"Context cap: paragraph past 2 KB is dropped, human line kept"`.

Fixture: `fire-masks-porcelain.txt` concatenated with `fire-masks-gitadd-refused.txt`
(a newline between them) as one `PostToolUseFailure` `error` text. Precondition,
asserted directly (not via `run`, so a miss fails the test at that line):
`match_phantom_untracked` and `match_phantom_gitadd`, from the copied
`lib/matchers.sh`, both fire on that text — so the test cannot pass because
gitadd simply did not fire.

`lib/verdicts.sh` is copied then `stub_lib`-appended with a
`verdict_phantom_gitadd` that prints a 1900-byte ASCII paragraph opening with
the marker `STUBMARKER-GITADD-1900` (unique to the stub, absent from the real
`verdict_phantom_untracked` text) and the human line `stub — gitadd 1900`. The
real `verdict_phantom_untracked` paragraph is 369 bytes (`LC_ALL=C wc -c`, minus
the trailing newline `sed -n '1p'` adds) — well under 2048 alone, but
369 + 1 (join newline) + 1900 = 2270 together, past the cap.

Assertions on the hook's actual output (`additionalContext`, `systemMessage`):

- `additionalContext` is under 2048 bytes (`LC_ALL=C wc -c`, per the plan's note
  that the verdict text holds multibyte em dashes — measuring the whole string
  keeps the count correct even though this particular pair doesn't put an em
  dash near the boundary).
- `additionalContext` equals the untracked paragraph exactly (`[ "$ctx" =
  "$untracked_para" ]`) — holds the untracked paragraph, and holds nothing
  else.
- `additionalContext` does not contain the stub's marker — lacks the stub's
  paragraph, checked by the marker rather than by length alone.
- `systemMessage` equals `"$untracked_human $stub_human"` exactly — holds both
  human lines, in catalogue order, space-joined as `hooks/annotate.sh` already
  joins them.

Paired case, included per the dispatch as cheap: `"Context cap: a paragraph
under the cap is kept, not dropped by position"` — same fixture and precondition,
a 100-byte stub paragraph instead of 1900. Asserts `additionalContext` equals
the untracked paragraph, a newline, then the stub paragraph in full (both kept),
and `systemMessage` again holds both human lines. This one is not itself red
today — nothing drops any paragraph yet, short or long, so it already holds —
but it pins that a future cap keyed on "second paragraph" or "any stubbed
paragraph" rather than on the running byte total would fail it while the first
test above still passed.

A shared `cap_setup <marker> <stub-bytes> <stub-human>` helper builds the fixture,
precondition checks and stub for both cases; `stub_paragraph <marker> <total-bytes>`
builds the exact-length ASCII paragraph (`printf '%*s' "$((total -
${#marker}))" '' | tr ' ' 'x'`, prefixed with the marker).

## Red confirmed

```
$ scripts/run-bats.sh tests/hook-cap.bats
not ok 1 Context cap: paragraph past 2 KB is dropped, human line kept
# (in test file tests/hook-cap.bats, line 63)
#   `[ "$ctx_bytes" -lt 2048 ]' failed
bats: 1 passed, 1 failed
```

Verbose run shows why: today's `hooks/annotate.sh` has no cap, so
`additionalContext` carries both paragraphs (2270 bytes) and `systemMessage`
already joins both human lines correctly — the human-line half of FR-6 was
already true before this slice; only the paragraph-drop half is red.

## Verification

- `shellcheck -s bash tests/hook-cap.bats`: clean (shellcheck does not
  recognize the `bats` shebang; the project's own `justfile` runs it over
  tracked `*.bats` files the same way `shellcheck "${files[@]}"` does, which
  is clean too).
- `bash -n tests/hook-cap.bats`: clean.
- `scripts/run-bats.sh tests/hook.bats tests/hook-malformed.bats
  tests/hook-cap.bats tests/matchers.bats tests/verdicts.bats`: 44 passed, 1
  failed (the new red test only).
- `scripts/run-bats.sh tests/docs.bats`: 1 passed, 0 failed — the new file
  stays quiet under `detect` (FR-11): it names verdict/matcher functions and a
  fixture pair rather than quoting diagnostic text.
- `scripts/run-bats.sh tests/`: 83 passed, 1 failed (the new red test only;
  nothing else regressed).
- `scripts/check-line-limits.sh`: clean. `tests/hook-cap.bats` is 114 lines;
  `tests/hook.bats` is untouched at 316.
- `git status --porcelain -- hooks lib` and `git diff --stat -- hooks lib`:
  both empty — `hooks/` and `lib/` are byte-identical to HEAD. Only
  `tests/hook-cap.bats` is new; nothing staged or committed. The untracked
  dotfiles reported by `git status` (`.bashrc`, `.claude/*`, etc.) are sandbox
  masks, not real files.
