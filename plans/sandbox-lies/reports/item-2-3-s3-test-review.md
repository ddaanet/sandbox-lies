# Item 2.3 slice 3 — test review

Scope: the two RED tests (`both listing verdicts share one paragraph` in
`tests/hook.bats`, `verdict text matches detectors.md` in
`tests/verdicts.bats`) and `item-2-3-s3-red.md`. Nothing committed. `hooks/`
and `lib/` byte-identical to HEAD at the end (`git diff --quiet hooks lib`
exits 0; every mutation below was restored by the inverse exact-string swap,
uniqueness-checked, and checked with `git diff --quiet <file>` straight
after).

## Mechanical check

The RED report's run reproduces: `both listing verdicts share one paragraph`
fails on the `additionalContext` equality, not on setup; `verdict text
matches detectors.md` passes (10 passed, 1 failed).

## Transcription check

Checked by script, not by eye. Each `**Verdict.**` paragraph was pulled from
`docs/references/detectors.md`, the hard-wrap joined with single spaces and
split on ` · `, then compared with the literals in the test:

| row | line 1 | line 2 |
|---|---|---|
| phantom-chardev | identical | identical once the code-span backticks are stripped |
| phantom-untracked | chardev paragraph + space + addition; addition identical apart from `a`→`A` | identical once the backticks are stripped |
| phantom-gitadd | identical, inner backticks kept | identical once the backticks are stripped |

The only non-ASCII characters are the three U+2014 em dashes in the human
lines. They match the doc byte for byte. The `·` separator is left out. The
backticks around each human line are markdown code-span delimiters, and the
test drops them correctly. The one reading the test adds is the capital `A`
at the start of the untracked addition. The doc writes `with: a cleanliness
check…`, and the test turns that into a sentence of its own after the
chardev paragraph. `lib/verdicts.sh` reads it the same way. It is a
reasonable reading, and the test's comment already says the untracked
paragraph is composed rather than transcribed. No transcription defects.

There is one limit, and it is by design (the slice says "held in the test").
The test pins `lib/verdicts.sh` to a snapshot of the doc and never reads the
doc itself. If `detectors.md` later changes, this test stays green until
someone re-transcribes.

## Mutation reproductions, `verdict text matches detectors.md`

Each mutation differs from the RED author's three. Each was run alone with
`--filter`, and each turned the test red on the assertion for the line it
mutated:

| # | mutation in `lib/verdicts.sh` | red at |
|---|---|---|
| M1 | chardev line 1: trailing space after `real tree.` | `:97` `line1 = chardev_para` |
| M2 | chardev line 2: `in listing` → `in the listing` | `:98` line2 |
| M3 | untracked line 1: `as dirty` → `as unclean` | `:102` composed line1 |
| M4 | untracked line 1: double space where the two paragraphs join | `:102` composed line1 |
| M7 | untracked line 2: `as untracked` → `as untracked files` | `:103` line2 |
| M5 | gitadd line 1: backticks around `git add` removed | `:108` line1 |
| M6 | gitadd line 2: trailing `.` added | `:109` line2 |

M3 and M4 also confirm the joint claim from the dispatch. The shared test
compares against the live `verdict_phantom_untracked` from the copy, so it
cannot see a wrong untracked text. This test catches one, including a
break at the join inside the composed paragraph.

## Findings and fixes (`tests/hook.bats`)

1. **Missing positive half. Fixed: new test `chardev listing alone keeps its
   own paragraph`.** The payload is `fire-masks-chardev-explicit` alone.
   `additionalContext` must equal line 1 of `verdict_phantom_chardev`, and
   `systemMessage` its line 2. This is the pair to the shared case: the same
   fixture without the porcelain trigger. It goes in this slice because W1
   below is a plausible way for this slice's GREEN to go wrong, and with it
   applied **every suite** (`scripts/run-bats.sh tests/`: 76 passed, 1
   failed) stays green except this new test. Slice 4's "non-empty" would
   catch W1 eventually, but only one slice later. The test passes against
   HEAD, which is expected for a positive control. Its evidence is the W1
   red below.

2. **The fixture precondition was a hand check. Fixed: now asserted in the
   test.** The RED author checked by hand that the joint text fires both
   matchers, and recorded that only in a comment. If the chardev matcher
   stopped firing on this text, the hook would emit only the untracked
   verdict, and the test would pass against today's two-paragraph hook
   without ever testing the merge. The test now pipes the text through
   `match_phantom_chardev` and `match_phantom_untracked` from the copied
   `lib/matchers.sh` before invoking the hook. It asks the matchers and not
   `detect` on purpose: a GREEN that merges inside `detect` has the same
   observable behaviour and must not trip the precondition (see W5).
   Checked: changing the chardev matcher's `c` mode anchor to `C` turns the
   test red on the precondition line (`:154`), not on an assertion that
   would otherwise have passed. Restored.

3. **The two listings were spliced together rather than concatenated.
   Fixed.** `text="${chardev}${porcelain}"` joins the chardev fixture's last
   line, which has no trailing newline (`…/.vscode`), onto the porcelain
   fixture's first line (`?? .bash_profile`). Real output from one call
   running both commands never looks like that. The text is now
   `printf '%s\n%s'`. Both matchers still fire, and the test is still red
   on the same assertion.

4. **The expected values were not guarded against empty. Fixed in both
   hook tests.** Both expectations come from the live verdict function. If
   that verdict printed nothing, a hook that went quiet would match `""` =
   `""`, because `jq -r` on empty stdout prints nothing. The text test and
   `verdicts under 400 chars` already cover this together. The added
   `[ -n "$expected_ctx" ]` / `[ -n "$expected_sys" ]` make each hook test
   stand on its own.

No findings on `tests/verdicts.bats`.

## Wrong-implementation hunt, shared paragraph

Each variant was applied to `hooks/annotate.sh` (or `lib/matchers.sh` for
W5) in place and run against the `listing` tests, then restored:

| variant | shared test | chardev-alone test |
|---|---|---|
| C: correct candidate, skip `phantom-chardev` when `detect` also prints `phantom-untracked` | green | green |
| W1: drop `phantom-chardev` always | green | **red** `:135` context |
| W2: untracked paragraph, both human lines | **red** `:174` systemMessage | green |
| W5: merge inside `detect` (chardev printed only when untracked does not match) | green | green (same observable, allowed) |
| HEAD (both verdicts called) | **red** `:172` context | green |

C shows the shared test can pass: it is not red for a reason no
implementation could satisfy. The other variants from the dispatch:

- **Untracked paragraph with chardev's human line.** `systemMessage` must
  equal untracked's line 2 exactly, so this is caught the same way as W2.
- **Substring de-duplication.** The outcome depends on order. `detect`
  prints chardev before untracked, so "skip a paragraph already contained
  in the context" keeps both paragraphs and the context assertion goes red.
  "Replace an earlier paragraph that the new one contains" produces the
  correct output, which is acceptable.
- **Keep the first paragraph only.** The result is chardev's paragraph, so
  the context assertion goes red.
- **Keep the last paragraph only.** This passes slice 3. It is out of this
  slice's scope; slice 7's "holds the untracked paragraph" is where it
  would show up.

Not pinned, and deliberately left unpinned here: the separator between
human lines in `systemMessage` when several verdicts fire. The design says
only that the lines concatenate, and asserting a separator would lock in a
choice nobody has made.

## Final runs

- `scripts/run-bats.sh tests/hook.bats tests/verdicts.bats`: 11 passed, 1
  failed. The one failure is `not ok 7 both listing verdicts share one
  paragraph`, at `tests/hook.bats:172`, the `additionalContext` equality. It
  got past the precondition and the non-empty guards first. It is red for
  the reason the item names: HEAD calls both verdicts and joins two
  paragraphs.
- `scripts/run-bats.sh tests/docs.bats`: 1 passed, 0 failed.
- `shellcheck tests/hook.bats tests/verdicts.bats`: clean.
- `git diff --quiet hooks lib`: exits 0.

For the GREEN dispatch: the slice now has three tests. The new one,
`chardev listing alone keeps its own paragraph`, is already green and must
stay green.
