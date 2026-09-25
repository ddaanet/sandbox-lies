# Item 4.1 slice 9 — RED

Slice: `cap skips and continues` — three verdicts in catalogue order where the
second alone would cross 2 KB and the third fits, plus the list revision: the
`systemMessage` joiner changes from a space to `; `.

No SUT stub needed: the SUT (`hooks/annotate.sh`, `lib/verdicts.sh`) already
exists with real behaviour from Items 2.3/2.4/4.1 slices 1-8. This dispatch
touches only `tests/hook-cap.bats`.

## Test changes

`tests/hook-cap.bats`:

1. **Joiner update** (list revision, code-review recommendation adopted as
   the default) — every existing case asserting a `systemMessage` holding two
   human lines, joined today by a space, changed to `; `:
   - `paragraph past 2 KB is dropped, human line kept` (line 113)
   - `a paragraph bringing the context to exactly 2 KB is kept` (line 134)
   - `the paragraph that crosses 2 KB is dropped, not the largest` (line 155)
   - `the 2 KB cap counts bytes, not characters` (line 181)

   Grepped every test file under `tests/` for a `systemMessage` assertion
   joining two or more human lines: `tests/hook-cap.bats` is the only file
   with any (`tests/hook.bats`, `tests/hook-locks.bats`,
   `tests/hook-verdicts.bats` each assert a single human line or an
   already-computed pair's equality, never a literal space join).
   `all paragraphs dropped keeps the human line` (line 211) asserts one human
   line alone and is untouched.

2. **New case** `cap skips and continues` — git-lock, config-lock and
   phantom-gitadd fire together, in catalogue order, on
   `fire-lock-add-commit.txt` + `fire-configlock-remote-add.txt` +
   `fire-masks-gitadd-refused.txt` concatenated (verified directly against
   `lib/matchers.sh`'s `detect`, which prints exactly `git-lock`,
   `config-lock`, `phantom-gitadd` on that text — no chardev/untracked
   spillover). `probe_git_lock` and `probe_config_lock` are stubbed (drain
   stdin, print `mask`) so no fixture path reaches the host filesystem, and
   `verdict_git_lock`/`verdict_config_lock`/`verdict_phantom_gitadd` are
   stubbed to fixed-size paragraphs ignoring the outcome argument they are
   handed: 100 bytes, 2000 bytes, 100 bytes. After verdict 1 (100 bytes),
   verdict 2's candidate is 100+1+2000 = 2101 bytes (over 2048, dropped);
   verdict 3's candidate is still measured against the unchanged context
   (100 bytes), giving 100+1+100 = 201 bytes (kept). Asserts
   `additionalContext` is paragraph 1 + newline + paragraph 3 (paragraph 2
   dropped, skip-and-continue) and `systemMessage` is all three human lines
   joined by `; `.

## Red run

```
$ direnv exec . scripts/run-bats.sh tests/hook-cap.bats
not ok 1 paragraph past 2 KB is dropped, human line kept
# (in test file tests/hook-cap.bats, line 113)
#   `[ "$sys" = "$untracked_human; $stub_human" ]' failed
not ok 2 a paragraph bringing the context to exactly 2 KB is kept
# (in test file tests/hook-cap.bats, line 134)
#   `[ "$sys" = "$untracked_human; $stub_human" ]' failed
not ok 3 the paragraph that crosses 2 KB is dropped, not the largest
# (in test file tests/hook-cap.bats, line 155)
#   `[ "$sys" = "$stub_human; $gitadd_human" ]' failed
not ok 4 the 2 KB cap counts bytes, not characters
# (in test file tests/hook-cap.bats, line 181)
#   `[ "$sys" = "$untracked_human; $stub_human" ]' failed
not ok 6 cap skips and continues
# (in test file tests/hook-cap.bats, line 259)
#   `[ "$sys" = "$human_a; $human_b; $human_c" ]' failed

bats: 1 passed, 5 failed
```

Test 5 (`all paragraphs dropped keeps the human line`, one human line) is
unaffected and stays green.

Each of the five reds fails on its `systemMessage` assertion — the joiner
(space vs `; `), never on `additionalContext`, `status`, an `ImportError`
equivalent or a missing symbol. `cap skips and continues`'s own
`additionalContext` assertion (`[ "$ctx" = "$para_a"$'\n'"$para_c" ]`)
already passes today: the skip-and-continue behaviour it names is already in
`hooks/annotate.sh` (Item 2.3 slice 7), which the mutation proof below
confirms.

Full suite: `direnv exec . scripts/run-bats.sh tests/` — 143 passed, 5 failed,
148 total. Before this dispatch the suite stood at 147 passed, 0 failed
(`item-4-1-s7-green.md`). This dispatch adds 1 test (147 + 1 = 148 total) and
flips 4 pre-existing tests from green to red by the joiner edit
(147 − 4 = 143 still green), leaving 143 passed and 5 failed (4 flipped +
1 new) — matching the run above exactly. No other test regressed.

## Mutation proof

**Test:** `cap skips and continues`. **String pair:** in
`hooks/annotate.sh`, `[ "$candidate_bytes" -gt 2048 ] && continue` ↔
`[ "$candidate_bytes" -gt 2048 ] && break` (the string occurs once in the
file; verified with `grep -n`).

Replacing `continue` with `break` makes the cap loop stop at the first
over-cap paragraph (verdict 2) instead of skipping it and trying verdict 3 —
stop-at-first-overflow instead of skip-and-continue. With the mutation in
place:

```
$ direnv exec . scripts/run-bats.sh tests/hook-cap.bats
...
not ok 6 cap skips and continues
# (in test file tests/hook-cap.bats, line 258)
#   `[ "$ctx" = "$para_a"$'\n'"$para_c" ]' failed
...
bats: 1 passed, 5 failed
```

The test now reds on its `additionalContext` assertion (line 258, one line
earlier than the unmutated run's line 259 `systemMessage` failure) — `break`
exits the loop before verdict 3 ever runs, so `additionalContext` holds
paragraph 1 alone instead of paragraph 1 + paragraph 3, and `systemMessage`
never gains verdict 3's human line either. This confirms the
`additionalContext` assertion is pinned to the skip-and-continue behaviour,
not vacuous.

Restored by the inverse replacement (`break` → `continue`).
`grep -n '&& break' hooks/annotate.sh` — no hit (exit 1).
`git diff --stat -- hooks lib` — empty (byte-identical to HEAD). Re-running
the suite after restore reproduces the original red exactly:

```
$ direnv exec . scripts/run-bats.sh tests/hook-cap.bats
...
not ok 6 cap skips and continues
# (in test file tests/hook-cap.bats, line 259)
#   `[ "$sys" = "$human_a; $human_b; $human_c" ]' failed
...
bats: 1 passed, 5 failed
```

## Checks passed

- `shellcheck tests/hook-cap.bats`: clean
- `wc -l tests/hook-cap.bats`: 260 lines (400-line cap)
- `direnv exec . scripts/run-bats.sh tests/hook-cap.bats`: 1 passed, 5 failed
  (the intended reds)
- `direnv exec . scripts/run-bats.sh tests/`: 143 passed, 5 failed (same five,
  no other regression)
- `git status --porcelain -- hooks lib tests plans/sandbox-lies/reports`:
  only `tests/hook-cap.bats` modified
- `git diff --stat -- hooks lib`: empty
