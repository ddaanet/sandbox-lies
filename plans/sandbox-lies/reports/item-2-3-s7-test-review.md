# Item 2.3 slice 7 — test review

Scope: `tests/hook-cap.bats` (untracked, new) and
`plans/sandbox-lies/reports/item-2-3-s7-red.md`. I changed only
`tests/hook-cap.bats`. `hooks/` and `lib/` were mutated in place for probes and
then restored by inverse replacement. `git diff --quiet hooks lib` exits 0 and
`git status --porcelain -- hooks lib` is empty. Nothing is staged or committed.

## Findings

1. **Names (fixed).** The RED names carried a `Context cap: ` prefix. The
   runbook's test is now named exactly `paragraph past 2 KB is dropped, human
   line kept`. The paired case has been renamed for what it does (finding 3).

2. **The paired case missed the boundary (fixed).** The RED's paired case used
   a 100-byte stub, so the total was 470 bytes. It caught "keep the first
   paragraph only" and "drop any paragraph over 400". It could not catch three
   plausible wrong caps:
   - an off-by-one (`-ge 2048` where `-gt 2048` is right);
   - a cap at 2000 bytes, since "2 KB" is ambiguous;
   - any cap threshold between 470 and 2270.

   FR-6 says a paragraph that would push the context **past** 2 KB is dropped.
   A context of exactly 2048 bytes is therefore kept. The case was rebuilt as
   `a paragraph bringing the context to exactly 2 KB is kept`. The stub is
   sized at run time to 2048 − (untracked bytes + 1). The test asserts that
   the context is both paragraphs joined by a newline and that its byte count
   is exactly 2048.

   The runbook's "under 2048 bytes" is an assertion about slice 7's own
   fixture, which is 370 bytes, so it holds under either reading. FR-6's
   "past" is what decides the boundary.

3. **Big paragraph first (added).** In detect's catalogue order,
   phantom-untracked comes before phantom-gitadd. So a big paragraph can
   come first when `verdict_phantom_untracked` is stubbed. FR-6 composes in
   catalogue order and drops the paragraph that *would push* past the cap,
   which is the later one even when it is small.

   Two wrong caps pass every other case: "on overflow, drop the largest" and
   "the running total omits the join newline". The new case `the paragraph
   that crosses 2 KB is dropped, not the largest` stubs untracked to
   2048 − gitadd bytes. The real 110-byte gitadd paragraph then brings the
   total to exactly 2049, or 2048 if the newline is left out. The test
   asserts that the context is the stub alone and that `systemMessage` is the
   stub's human line followed by gitadd's.

4. **Bytes vs characters (added).** The stub and the untracked paragraph are
   both ASCII, so no case could tell a byte count from a character count. A
   cap written with `${#context}` counts characters under a UTF-8 locale,
   which is the production shell's locale, and would pass all the other
   cases. The new case `the 2 KB cap counts bytes, not characters` uses a
   stub of 1600 characters, 400 of them em dashes. The resulting context is
   1970 characters but 2770 bytes.

   The hook runs under a UTF-8 locale chosen by `utf8_locale`. That helper
   tries `C.UTF-8`, then `en_US.UTF-8`, and accepts a locale only if bash
   counts an em dash as one character under it. If no locale qualifies, the
   test fails rather than passing vacuously under a byte locale. Two
   preconditions assert that the fixture really straddles the cap: at most
   2048 by `wc -m`, and over 2048 by `LC_ALL=C wc -c`.

5. **Exact capture (fixed).** `$(jq -r …)` strips trailing newlines, so a
   hook that emitted a context ending in `\n` would compare equal and measure
   one byte short. That matters at the 2048 boundary. `cap_run` now captures
   with `jq -j … && printf x` and then strips the `x`, so both strings are
   exact. The `&&` also means that a jq parse failure fails the test at that
   line.

6. **Unused `load helpers/bsd-stubs` (removed).** Nothing in this file calls
   `make_bsd_stubs`.

7. **Kept as it is.** The runbook-named assertions in the first case stay:
   the byte check `-lt 2048`, the exact equality, the marker absence and
   the `systemMessage` equality. The marker check can never fail on its own,
   because the exact equality implies it. It maps to the runbook's "lacks the
   stub's" clause and costs nothing.

   The match preconditions (both matchers fire on the concatenated text) and
   the non-empty guards on expected values are retained in `cap_run` and in
   each test.

8. **Open, not added: stop-at-first-overflow versus skip-and-continue.** FR-6
   judges each paragraph, which reads as skip-and-continue. Telling that apart
   from `break` needs three paragraphs. In Item 2.3 the phantom verdicts emit
   at most two, because chardev folds into untracked. The only third source is
   a stubbed `verdict_git_lock`, and Item 4.1 rewires the git-lock path
   through a probe, so a test built on that stub now would be coupled to that
   rewiring. Recommend that Item 4.1 add the case once lock verdicts exist.

## Probe table

Each probe replaces the hook's paragraph-append block, or its post-loop
`[ -n "$context" ] || exit 0` line, with the named cap. The probe then runs
`bats tests/hook-cap.bats` and restores the hook by inverse replacement. Tests:
1 is the runbook case, 2 is at-cap kept, 3 is big-first, 4 is bytes-not-chars.
R means red, g means green.

| Cap in `annotate.sh` | 1 | 2 | 3 | 4 |
| --- | --- | --- | --- | --- |
| none (HEAD) | R | g | R | R |
| reference: bytes, `> 2048` dropped, join counted, human kept | g | g | g | g |
| off-by-one: drop at 2048 (`-ge`) | g | R | g | g |
| cap at 2000 bytes | g | R | g | g |
| counts characters (`${#cand}`) | g | g | g | R |
| running total omits join newline | g | g | R | g |
| keep first paragraph only | g | R | g | g |
| drop any paragraph over 400 chars | g | R | R | g |
| reference cap, but human line dropped with its paragraph | R | g | R | R |
| on overflow, drop the largest paragraph | g | g | R | g |
| on overflow, drop the last paragraph | g | g | g | g |
| truncate context to 2048 bytes | R | g | R | R |

Every wrong cap is caught. There is one exception: "on overflow, drop the
last paragraph" survives, and that is correct. With two paragraphs, the last
one is always the one that crosses the cap, so this cap behaves exactly like
FR-6 here. It becomes distinguishable only with three paragraphs (finding 8).

The reference cap turns all four tests green, so none of them asks for more
than FR-6 does.

## Final red run

```
$ scripts/run-bats.sh tests/hook-cap.bats
not ok 1 paragraph past 2 KB is dropped, human line kept
#   `[ "$(byte_count "$ctx")" -lt 2048 ]' failed
not ok 3 the paragraph that crosses 2 KB is dropped, not the largest
#   `[ "$ctx" = "$stub_para" ]' failed
not ok 4 the 2 KB cap counts bytes, not characters
#   `[ "$ctx" = "$untracked_para" ]' failed
bats: 1 passed, 3 failed
```

Test 2 passes today by nature: nothing is dropped yet, so both paragraphs are
already kept. The probe table shows it turning red under four wrong caps.

The GREEN step must turn tests 1, 3 and 4 green.

## Checks passed

- `shellcheck tests/hook-cap.bats`
- `scripts/run-bats.sh tests/docs.bats`: 1 passed, 0 failed
- `scripts/run-bats.sh tests/`: 83 passed, 3 failed. The only failures are
  the three intended reds.
- `scripts/check-line-limits.sh`: `tests/hook-cap.bats` is 181 lines
- `git diff --quiet hooks lib`: exit 0
