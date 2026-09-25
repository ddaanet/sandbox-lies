# Item 4.2 slices 1-2 — GREEN

**Status: implementation complete and locally green; NOT committed.** An
unrelated pre-existing failure in `tests/hook-locks.bats` (Item 4.1's suite,
outside this batch) blocks `just test`/`just precommit`, and the standing rule
is that no commit ever leaves the suite red. Diagnosis and evidence below,
under "Blocker". Everything else in this report describes finished,
independently-verified work, ready to commit once that blocker is resolved.

Batched dispatch: slice 1 (`fire and quiet fixtures`) and slice 2 (`<detector>
flag policy`) for the three shipping rows `tmpdir-unset`, `resume-lost`,
`seccomp-init`, against the RED batch in `tests/matchers.bats`,
`tests/verdicts.bats`, `tests/hook-candidates.bats` (already reviewed:
`item-4-2-s1-red.md`, `item-4-2-s1-test-review.md`). `zellij-socket` and
`readonly-path` untouched, as scoped.

## Implementation, one file at a time

**`lib/matchers.sh`** — wired the three candidates into `detect()` in
catalogue order (after `phantom-gitadd`), then grew each matcher from its
`detectors.md` `## Candidates` description:

- `match_tmpdir_unset`: tool prefix (run free of blanks/backticks/pipes/colons,
  then `: `), optional bash `line N: `, then a one-component root path (bare or
  quoted, straight or GNU curly) ending in `: ` plus the permission-denied or
  missing-file message.
- `match_resume_lost`: `^No conversation found with session ID: [0-9a-fA-F-]+`
  anchored at line start, trailing blanks only.
- `match_seccomp_init`: `^apply-seccomp: unshare\(CLONE_NEWUSER\): Invalid
  argument` alone on its line.

Ran `bats tests/matchers.bats`: all 36 tests passed on this first cut,
including the BSD-stub sweep (test 33) and the three new quiet-fixture pins
added by the test review.

**`lib/verdicts.sh`** — transcribed the three `Verdict.` paragraphs and human
lines from `detectors.md` verbatim (matching what `tests/verdicts.bats`
already pinned). Ran `bats tests/verdicts.bats`: all 8 tests passed.

**`hooks/annotate.sh`** — added the row's flag policy as one `case` clause
(FR-5: gating in the hook, never the matcher), sitting beside the existing
phantom-chardev suppression:

```sh
case "$name:$flag" in
  tmpdir-unset:false | resume-lost:true | seccomp-init:true) continue ;;
esac
```

Ran `bats tests/hook-candidates.bats`: all 4 tests passed (the fires-with
halves were already green from the matcher/verdict work above; this step
turned the three silent halves green).

## A bug found and fixed while growing `match_tmpdir_unset`

The first cut of the bare-path alternative had no boundary requirement before
its leading `/`, so it accepted the **last segment of any path**, however deep
or relative, wherever that segment happened to be followed by
`: <message>` — e.g. `ssh_askpass: exec(/usr/X11R6/bin/ssh-askpass): No such
file or directory` (a multi-component path) and
`cp: agent-core/templates/CLAUDE.template.md: No such file or directory` (a
relative path, no leading `/` at all) both matched. This surfaced during the
NFR-1 corpus re-run below (625 raw hits against a recorded 195), not against
the fixture suite — the fixture suite's own quiet case only pins one specific
near-miss shape (a deeper *quoted* path) and doesn't exercise this one. Fixed
by requiring a blank immediately before the bare alternative's leading `/`:

```sh
# before
grep -qE "^[^\`|:[:space:]]+: (line [0-9]+: )?.*(/[^/'\"[:space:]]+|...): ..."
# after
grep -qE "^[^\`|:[:space:]]+: (line [0-9]+: )?.*([[:space:]]/[^/'\"[:space:]]+|...): ..."
```

Re-ran `tests/matchers.bats` and `tests/hook-candidates.bats` after the fix:
all 40 tests still pass (no fixture depended on the old, looser shape).

## NFR-1: corpus re-run with the shipped matchers as arbiter

Reused Item 3.2's own extraction (`/tmp/claude/sandbox-lies/eval`: 3,765
prefilter survivors over the same 55,896-pair corpus, `manifest.jsonl` from
`tests/corpus-eval.py extract`) rather than re-scanning `~/.claude/projects` a
second time — same survivor set, only the arbiter changes, one replay at a
time, foreground, sequential (~1.3 GB free before each run):

```
for f in survivors/*; do
  v=$(bash lib/matchers.sh <"$f") || true
  [ -n "$v" ] && printf '%s\t%s\n' "$(basename "$f")" "$v" >>verdicts.tsv
done
python3 tests/corpus-eval.py aggregate --outdir /tmp/claude/sandbox-lies/eval
```

Ran it twice: once with the buggy matcher (to discover the bug above), once
after the fix.

| row | detectors.md before | measured now (shipped matcher) | moved? |
|---|---|---|---|
| `tmpdir-unset` | 13 hits, 13 true, 182 unflagged silent | 202 total matches, 16 flagged, 16 true, 186 unflagged silent | **yes — re-recorded** |
| `resume-lost` | 3 total (2 true unflagged + 1 flagged silent) | 3 total, 1 flagged, 2 true unflagged — identical | no |
| `seccomp-init` | 8 hits, 8 true, 0 flagged | 8 hits, 8 true, 0 flagged — identical | no |

`resume-lost` and `seccomp-init` matched their recorded lines exactly
(project breakdowns identical too), so their `Corpus.` paragraphs are
untouched.

`tmpdir-unset` moved. All 16 flagged hits were inspected individually
(command + matched text): each is a `$TMPDIR`-referencing command whose
result names a bare filename directly under `/`
(`ashby-ids.txt`, `screen99.png`, `dirs-sorted.txt`, `live.conf`,
`remote-micro.json`, `cmsg`, `bundle-test`, `restest`, `parent-msg.txt`,
`fg2.sh`, `pane.txt`, `m6probe`, `micro-build`, `verify-wt`, `acprobe`,
`tok.txt`) — 16/16 true, no self-reference (no `sandbox-lies` project among
them). Projects: Emploi ×2, devddaanet ×5, gitlore ×2, handoff ×3, micro ×2,
prohibitions (new vs. the recorded line), pytest-md. The move (13→16 hits,
195→202 total matches) is attributable to the shipped matcher's regex
differing slightly from Item 3.2's scratch arbiter (same reused survivor
set, so not a corpus change) — recorded as such rather than left unexplained.
`docs/references/detectors.md`'s `tmpdir-unset` `## Corpus.` paragraph
re-recorded (count, true/false split, 100%, date 2026-09-25 per the
dispatch), then `just format-docs` re-wrapped it. File is 306 of 400 lines
after the edit.

## Full-batch verification

```
$ direnv exec . bats tests/matchers.bats tests/verdicts.bats tests/hook-candidates.bats
# 36 + 8 + 4 = 48 tests, all ok
$ direnv exec . bats tests/docs.bats
ok 1 no tracked file outside the fixtures fires a detector
$ direnv exec . shellcheck lib/matchers.sh lib/verdicts.sh hooks/annotate.sh \
    tests/hook-candidates.bats tests/matchers.bats tests/verdicts.bats
# clean
$ direnv exec . scripts/check-line-limits.sh
# clean
$ wc -l lib/matchers.sh lib/verdicts.sh hooks/annotate.sh tests/matchers.bats \
    tests/verdicts.bats tests/hook-candidates.bats
171 116 147 373 251 107  (all under 400)
```

## Blocker: `just test` / `just precommit` fail on an unrelated, pre-existing test

```
$ direnv exec . scripts/run-bats.sh tests/
not ok 62 probe reads the result text on stdin
# (in test file tests/hook-locks.bats, line 368)
#   `[ "$(cat "$recorded")" = "$(printf '%s\n%s' "$stdout" "$stderr")" ]' failed

bats: 159 passed, 1 failed
```

This is `tests/hook-locks.bats`'s `probe reads the result text on stdin`
(Item 4.1, git-lock/config-lock; not part of this batch, and `Never edit a
test file` is absolute in GREEN mode regardless).

**Confirmed pre-existing, not a regression from this dispatch:** reverted
`hooks/annotate.sh` to the tracked `HEAD` version (my flag-policy `case`
clause removed) with everything else unchanged, and the same test failed
identically. Restored my edit immediately after (`git diff -- hooks/annotate.sh`
shows only the intended 6-line addition, confirmed via `git diff` right
after restoring).

**Root cause, isolated by copying the failing `@test` block into a scratch
file** (deleted after use, never committed): the test declares
`local stdout stderr payload text` and later does `run_hook "$payload"`.
bats-core's `run()` (`/usr/local/lib/bats-core/test_functions.bash:410`)
unconditionally executes `unset stderr stderr_lines` after a plain (merged,
non-`--separate-stderr`) run — bash's dynamic `local` scoping means that
`unset` reaches into the *caller's* local variable of the same name. The
test's own `$stderr` (holding git's follow-on sentence) is silently wiped to
empty by its own call to `run_hook`, which is why the *first* assertion in
the test — comparing the probe's recorded stdin against
`$stdout`+`\n`+`$stderr` — reds: `$stderr` reads empty at that point even
though the hook's actual behaviour (piping the correct joined text to the
probe) is unaffected. Verified with `echo "$stderr"` before and after
`run_hook` in a scratch copy: populated before, empty after. This is a name
collision with a bats-reserved variable, present in the tracked test file
independent of Item 4.2.

**Why this stops the commit:** `just precommit` → `report tests just test` →
`scripts/run-bats.sh tests/`, so this failure is on the standard gate path.
The phase's standing rule is "the commit leaves the suite green; no commit
ever leaves the suite red" — true here even before this dispatch started (the
failure reproduces against the tracked `HEAD` `hooks/annotate.sh` with no
Item 4.2 changes at all).

**Needs a decision:** fixing `tests/hook-locks.bats` (rename its local
`stderr` to something that doesn't collide, e.g. `stderr_text`) is outside
Item 4.2's scope and edits a test file, which this mode absolutely
prohibits. Options, for the orchestrator: (a) dispatch a small out-of-band
fix to that one local-variable name in `tests/hook-locks.bats` (Item 4.1's
file) before this slice commits; (b) direct me to commit Item 4.2's work
regardless, if the gate is expected to tolerate this known-and-diagnosed
failure some other way; (c) something else. I have made no commit and no
test-file edit pending that decision.

## Requirements coverage (once committed)

| Requirement | Evidence |
|---|---|
| FR-5 (flag policy in the hook, not the matcher) | `hooks/annotate.sh` `case "$name:$flag"`; matchers read text only |
| FR-6/FR-7/FR-10 (verdict text, catalogue wiring, translation) | `lib/verdicts.sh` transcriptions; `detect()` catalogue order |
| NFR-1 (corpus re-measurement before commit) | table above; `tmpdir-unset` `Corpus.` line re-recorded |

## Files touched (uncommitted)

`lib/matchers.sh`, `lib/verdicts.sh`, `hooks/annotate.sh`,
`docs/references/detectors.md` (the one moved `Corpus.` line, re-wrapped by
`just format-docs`), plus the already-uncommitted `tests/matchers.bats`,
`tests/verdicts.bats`, `tests/hook-candidates.bats` (new) from the RED/review
dispatches, and this report. No memory or design.md edit (out of scope, per
the dispatch). No commit made.
