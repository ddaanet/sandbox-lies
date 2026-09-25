# Item 4.1 slice 9 — test review

**Scope**: the uncommitted `tests/hook-cap.bats` changes (joiner update to
`; ` in four existing cases, new case `cap skips and continues`), plus the
RED report `item-4-1-s9-red.md`. SUT (`hooks/annotate.sh`, `lib/`) is
read-only here and is byte-identical to HEAD at the end of the review.
**Mode**: review + fix

## Summary

The RED is sound. All five changed or new cases fail on their
`systemMessage` assertion, and none errors. The new case pins paragraph
order, the absence of paragraph two, the newline separator in the context
and the `; ` separator in `systemMessage`, all by exact equality. The
joiner sweep is complete, which I confirmed by grep and by a full-suite run
under a GREEN-shaped joiner. I applied three fixes to the test file:

- The new case now asserts that its probe stubs were reached.
- A duplicated run-and-extract block is factored into `cap_hook`.
- The file header now matches the new case.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

1. **The new case never proves its probe stubs ran**
   - Location: `tests/hook-cap.bats`, `cap skips and continues`, the probe
     stubs.
   - Problem: the verdict stubs ignore the outcome they receive. So if the
     hook never reached `probe_git_lock` or `probe_config_lock` (a misnamed
     stub, or a hook that reached the real probe), the case would still pass.
     The real probe would then stat the fixture's absolute lock path on the
     host, which the standing rule forbids. `hook-locks.bats` guards this
     same gap with the `$PROBE_CALLED` sentinel of `stub_probe`, for the
     reason its comment gives.
   - Fix: each probe stub now touches
     `$BATS_TEST_TMPDIR/probe-<name>-called`, and the case asserts both
     files exist after the run. `stub_probe` is defined in `hook-locks.bats`
     rather than in a shared helper, so reusing it would mean moving it into
     `tests/helpers/hook.bash`, which is outside this review's file scope. I
     inlined the same sentinel shape instead.
   - Proof: a mutation in `hooks/annotate.sh` changed
     `if declare -F "$probe_fn" >/dev/null; then` to
     `if false && declare -F "$probe_fn" >/dev/null; then`. The case then
     went red on `[ -f "$BATS_TEST_TMPDIR/probe-git_lock-called" ]`. I
     restored the file with the inverse replacement, and
     `git diff --quiet -- hooks lib` succeeds.
   - **Status**: FIXED

### Minor Issues

1. **Duplicated run-and-extract block**
   - Location: `cap skips and continues` repeated `cap_run`'s tail: the
     payload, `run`, the status check and the `x`-sentinel `ctx`/`sys`
     extraction.
   - Note: I split that tail into a new helper, `cap_hook <text>`. `cap_run`
     now calls it, and so does the new case. `all paragraphs dropped keeps
     the human line` now uses it too. That case already carried the same
     copy, and once the new case stopped assigning `ctx`/`sys` itself,
     shellcheck reported SC2030/SC2031 on that copy. It is now clean.
   - **Status**: FIXED

2. **The file header comment was stale**
   - Location: `tests/hook-cap.bats` lines 7-12.
   - Note: the header said every case runs the porcelain+gitadd text, and
     its list of ruled-out caps did not include stopping at the first
     overflow. It now says this applies to the two-paragraph cases, adds
     that the three-paragraph case uses the lock verdicts, and adds
     "stopping at the first overflow" to the list.
   - **Status**: FIXED

## Check 1: mechanical

`direnv exec . scripts/run-bats.sh tests/hook-cap.bats`, in the foreground,
after the fixes:

```
not ok 1 paragraph past 2 KB is dropped, human line kept          line 121: [ "$sys" = "$untracked_human; $stub_human" ]
not ok 2 a paragraph bringing the context to exactly 2 KB is kept line 142: [ "$sys" = "$untracked_human; $stub_human" ]
not ok 3 the paragraph that crosses 2 KB is dropped, not the largest line 163: [ "$sys" = "$stub_human; $gitadd_human" ]
not ok 4 the 2 KB cap counts bytes, not characters               line 189: [ "$sys" = "$untracked_human; $stub_human" ]
ok 5 all paragraphs dropped keeps the human line                  (unchanged: one human line)
not ok 6 cap skips and continues                                  line 257: [ "$sys" = "$human_a; $human_b; $human_c" ]
bats: 1 passed, 5 failed
```

Every changed or new case fails on an assertion, and every one fails on its
joiner. None errors and none passes. In case 6 the new probe-sentinel
assertions pass before the red line, so the red is still the joiner.

Full suite: `direnv exec . scripts/run-bats.sh tests/` gives 143 passed and
5 failed. The failures are the same five, and `docs.bats` is green.

### Mutation proof (a different mutation from the RED report's)

The RED report mutated `continue` to `break`, which also loses the later
human lines. I used a latch instead. It keeps collecting human lines but
drops every paragraph after the first overflow, so it separates the
context's skip-and-continue from the `systemMessage` side.

- In `hooks/annotate.sh`, `[ "$candidate_bytes" -gt 2048 ] && continue`
  (`command grep -cF` gives 1) became
  `[ "$candidate_bytes" -gt 2048 ] && capped=1; [ -n "${capped-}" ] && continue`.
- With the latch in place, case 6 went red on
  `[ "$ctx" = "$para_a"$'\n'"$para_c" ]` (line 258 of the file as it stood
  then). That is the context assertion, one line before the joiner red.
- I restored the file with the inverse exact-string replacement.
  `command grep -cF capped hooks/annotate.sh` gives 0, the original string
  counts 1, and `git diff --quiet -- hooks lib` succeeds, so the file is
  byte-identical to HEAD.

(A first attempt used plain `grep`, which counted 0 because the Bash tool's
`grep` is ugrep, so the mutation was never applied. I discarded that run and
redid it with `command grep`.)

## Check 2: completeness of the joiner sweep

The grep found 16 `systemMessage` lines outside `hook-cap.bats`. They are in
`hook.bats` (5), `hook-locks.bats` (8) and `hook-verdicts.bats` (3). None
are in `hook-malformed.bats`, `verdicts.bats`, `docs.bats`, the helpers or
the `.py` files. Each one asserts one of two things:

- a single literal human line, or
- the line-2 output of one verdict (`hook.bats` chardev/shared-paragraph,
  `hook-verdicts.bats` `check_emits`, the `hook-locks.bats` sweep over
  single-verdict fixtures).

None asserts a join of two or more lines.

I also checked this empirically. With the GREEN-shaped joiner applied
temporarily (`human="${human:+$human }$line"` changed to
`human="${human:+$human; }$line"`), `hook-cap.bats` gave 6/6 ok and the
full `tests/` run gave **148 passed, 0 failed**. I then restored by inverse
replacement and `git diff --quiet -- hooks lib` succeeds. No other suite
needed an update, and the tests go green for the intended reason.

## Check 3: wrong-reason hunting (`cap skips and continues`)

- **Order.** Both assertions are exact equalities in a fixed order:
  `ctx = para_a\npara_c` and `sys = human_a; human_b; human_c`. A swap
  anywhere reds.
- **Absence of paragraph two.** Exact equality leaves no room for
  `SLICE9-B…` anywhere in the context.
- **Exact separators.** The context separator is a single `\n` and the
  `systemMessage` separator is `; `. The `x` sentinel keeps a trailing
  newline from being lost, so a trailing or leading `; `, a doubled
  separator, or `;\n` all fail. A join that also puts `; ` into the context
  fails the context equality.
- **Parallel values.** The three human lines differ (first/second/third) and
  so do the three paragraph markers. The sizes 100, 2000 and 100 are
  distinct where it matters: B is the only one that overflows.
- **Other caps it rules out:**
  - A per-paragraph cap keeps B (2000 < 2048), so the context would hold
    all three and the case reds.
  - A running total that also counts dropped paragraphs gives C
    100+2000+100+2 > 2048, so C is dropped and the case reds.
  - A cap that stops at the first overflow reds, shown by both the RED
    report's mutation and mine.
  - Dropping the largest paragraph would pass this case, but it is ruled
    out by `the paragraph that crosses 2 KB is dropped, not the largest`.
    The header lists each case's share.
- **Fixture reachability.** I ran `detect` directly on the concatenated
  text: it prints exactly `git-lock`, `config-lock`, `phantom-gitadd`, rc 0.
  The case also checks each matcher fires before stubbing, so no paragraph
  can be missing because a matcher never fired.
- **Probe reach.** Fixed above (Major 1).

## Check 4: self-quiet

`detect` run over `tests/hook-cap.bats` prints nothing (rc 1). The new case
builds its diagnostic text only by reading fixtures with `cat`, and its
stub text (`SLICE9-*`, `stub — …`) matches no detector. `tests/docs.bats`
is green in the full run.

## Fixes Applied

- `tests/hook-cap.bats` header (lines 7-13): the scope sentence now covers
  the three-paragraph case, and "stopping at the first overflow" is added
  to the list of ruled-out caps.
- `tests/hook-cap.bats`, new helper `cap_hook <text>`: the failure payload,
  run, status check and exact `ctx`/`sys` extraction. `cap_run` now calls
  it.
- `tests/hook-cap.bats`, `all paragraphs dropped keeps the human line`: now
  uses `cap_hook`, and the unused `payload` local is removed.
- `tests/hook-cap.bats`, `cap skips and continues`:
  - the probe stubs now touch sentinels, which the case asserts after the
    run;
  - the case uses `cap_hook`;
  - the unused `payload` local is removed.

## Checks passed

- `shellcheck tests/hook-cap.bats`: clean.
- `wc -l tests/hook-cap.bats`: 258 lines, under the 400-line cap.
- `direnv exec . scripts/run-bats.sh tests/hook-cap.bats`: 1 passed and 5
  failed, the intended reds, each on its joiner assertion.
- `direnv exec . scripts/run-bats.sh tests/`: 143 passed and 5 failed (the
  same five), with `docs.bats` green.
- Mutations: the latch reds case 6 on the context assertion, and the
  skipped probe reds case 6 on the probe sentinel. Each was restored by
  inverse replacement, and `git diff --quiet -- hooks lib` succeeds.
- Joiner preview: 148 passed and 0 failed across `tests/`, restored
  afterwards.
- `git status --porcelain -- hooks lib tests plans`: only
  `tests/hook-cap.bats` is modified, plus the untracked slice reports.
  Nothing is committed.

## Positive Observations

- The RED report's arithmetic (2101 dropped, 201 kept) and its suite
  accounting (147 + 1, minus 4 flipped) both check out against the runs.
- The case checks the matchers directly before stubbing, and the verdict
  stubs have fixed sizes and ignore the outcome. That keeps the case about
  the cap and not about the verdict text.
