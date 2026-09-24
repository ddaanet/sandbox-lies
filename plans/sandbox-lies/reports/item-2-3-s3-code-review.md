# Item 2.3 slice 3 — code review

Scope: `git show HEAD -- hooks/annotate.sh` (commit `Item 2.3/3 — one
paragraph when both listing detectors fire`), read with the whole script.
Fixes applied in the working tree; nothing committed.

## Verdict

The slice is correct. The shared paragraph is emitted when both listing
detectors fire, chardev alone keeps its paragraph, and any other name that
fires alongside them (checked: chardev, porcelain and gitadd together) still
emits. No critical or major findings. Two minor fixes, one comment fix, one
test gap that slice 7 closes as specified.

## Findings

### 1. Minor, fixed — detect's status was captured and then ignored

`names=$(printf '%s\n' "$text" | detect)` has no status check. Under `set -u`
without `set -e`, both non-zero exits continue:

- **Exit 1 (nothing fired)**, the quiet path. `names` is empty, so
  `printf '%s\n' ""` feeds one empty line to `grep` (a fork, finding 2) and
  to the loop, which skips it by `[ -n "$name" ] || continue`. `context`
  stays empty and `[ -n "$context" ] || exit 0` exits. Correct, but the
  path that runs after every Bash call (NFR-3) pays a `grep` fork and a
  process substitution to learn what the exit status already said.
- **Exit 2 (buffer failure, until slice 8)**. `detect` returns before
  printing anything, so `names` is empty and the same path exits 0 with
  empty stdout. Probed with `TMPDIR=/nonexistent` on a firing payload:
  mktemp's message on stderr, empty stdout, exit 0. Same outcome as the
  process-substitution form, which could not see the status at all.

So the behaviour was never wrong, and a detect failure was no more silent
than before. The capture made the status visible for the first time, and
the slice did not use it.

**Fix:** `names=$(printf '%s\n' "$text" | detect) || exit 0`, with a one-line
comment saying both non-zero cases are silent. Both are meant to exit 0 with
empty stdout, so they need not be told apart. The line stays correct after
slice 8 drops exit 2. `detect` returns 0 whenever it printed a name, so a
firing result can never be cut short. `[ -n "$name" ] || continue` stays as
a guard against a blank line. `[ -n "$context" ] || exit 0` stays for
slice 9's case where every name lacks a verdict.

### 2. Minor, fixed — the membership test forked `grep`

`printf '%s\n' "$names" | grep -qFx 'phantom-untracked' && untracked_fires=1`
ran on every non-empty `text`, including every quiet one, so it cost one
fork per Bash call. grep's exit 2 (grep missing, or a stub refusing an
option under slice 10's `make_bsd_stubs grep`) read the same as exit 1, so
`untracked_fires` stayed 0 and both paragraphs came back. That is a
degraded result, the pre-slice behaviour, and not a silent one. So this was
not a correctness defect, but it was a failure mode that did not need to
exist.

**Fix:** a `case` on the newline-delimited list, which forks nothing and
cannot fail:
`case "$nl$names$nl" in *"${nl}phantom-untracked$nl"*) continue ;; esac`.
The surrounding newlines anchor it to whole names, just as `-x` did. It
works on bash 3.2 because the quoted parts of a `case` pattern are literal.

Timing (mean of 40 `bash hooks/annotate.sh` runs on this box, two passes):
the quiet `quiet-clean-status` path went from 55–58 ms to 54–57 ms, and the
firing `fire-masks-porcelain` path from 69 ms to 61–78 ms. One fork is
about 1 ms, which is inside the noise here. The fix is about removing a
failure mode and a fork on the hot path, not a measured speed-up. The quiet
path is still dominated by `detect` (mktemp plus five matchers), as the
slice 2 review found.

### 3. Minor, fixed — comment overstated the rule and sat away from the skip

The comment said "only verdict_phantom_untracked runs". Read literally,
that means the other verdicts are suppressed too, when only the chardev one
is. It also sat above a flag computed ten lines before the `continue` that
applies it.

**Fix:** with finding 2, the membership test moves into the loop beside the
skip, and `untracked_fires` is gone. The comment now sits on the `if` and
says what the policy says ("one paragraph when both listing detectors
fire") and why chardev is the one dropped (the untracked paragraph restates
it). On structure: the skip belongs in the loop. Filtering `names` up front
by pattern substitution would depend on `detect` printing chardev before
untracked, with the newline after it. Keeping the test next to the
`continue` makes the policy one unit.

### Checked, no finding

- **Empty name list.** Handled on both paths: by `|| exit 0` now, and before
  the fix by the blank-line `continue` plus the context guard.
- **NFR-4.** `$(…)` is a pipe, and the loop is still fed by process
  substitution rather than a here-string, which spools to a temp file on
  bash < 5.1. The hook itself still writes nothing. `detect`'s `mktemp` is
  slice 8's.
- **bash 3.2 / BSD.** `$(…) || exit 0`, `case` with quoted pattern
  segments, `${name//-/_}`. No arrays, `mapfile` or `<<<`. The hook no
  longer calls `grep` or `sed` itself. Its only external tool calls are
  `jq`, `cat` and `dirname`, and `detect`'s tools inside the lib.
- **Whitespace.** Names are fixed tokens, all expansions are quoted, and
  the loop uses `IFS= read -r`.
- **Three names at once.** Chardev, porcelain and gitadd concatenated into
  one `PostToolUse` stdout give two paragraphs, and `systemMessage` reads
  `phantom dotfiles — masks listed as untracked git add — refused a sandbox
  mask`. So the skip drops chardev only. The single-space joiner is slice
  1's open finding 7, not reopened here.

## Mutation run (the one permitted)

The mutation, applied by exact replacement to the HEAD code: `if [ "$name"
= "phantom-chardev" ]` became `if [ "$name" != "phantom-untracked" ]`. When
untracked fires, this skips every other name, which is the old comment's
literal reading. `scripts/run-bats.sh tests/hook.bats` gave **8 passed, 0
failed**, so the tests did not red. The replacement was inverted, and
`git diff --quiet hooks lib` exited 0 before any fix was applied.

## Test gaps

- **The skip's reach is unpinned (the mutation above).** No current case
  fires untracked together with a third detector. Slice 7 as specified
  (porcelain plus gitadd, `systemMessage` holds both human lines) catches
  it, so nothing needs adding now. If slice 7's stub or payload changes,
  keep a non-listing name firing beside untracked.
- **`|| exit 0` on detect** is pinned only by outcome, which is identical
  either way. That is inherent: the fix changes cost, not output.

## Refactor flag

None new. Slice 1's flag stands: fold the event and text `jq` reads into
one call during slice 6's parse rewrite. It needs no module split.

## Files changed

- `hooks/annotate.sh`: detect's status is checked (`|| exit 0`); the
  `grep -qFx` flag is replaced by a `case` inside the loop; the comment is
  moved and corrected.

## Verification

- `shellcheck hooks/annotate.sh`: clean.
- `scripts/run-bats.sh tests/`: 77 passed, 0 failed.
- `direnv exec . just precommit`: `precommit passed: plugin.json,
  hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests`.
- By hand: the quiet payload gives empty stdout and exit 0; the firing
  payload with `TMPDIR=/nonexistent` gives empty stdout and exit 0; the
  three-name payload is as above.
