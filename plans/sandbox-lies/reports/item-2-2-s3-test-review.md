# Item 2.2 slice 3: test review

Scope: the four new tests in `tests/check-links.bats` and
`item-2-2-s3-red.md`. Fixes are in `tests/check-links.bats` (uncommitted).
`scripts/` is byte-identical to HEAD, checked at the end.

## Mechanical check

The RED run reproduces: `urls and anchors ignored` fails on `[ "$status" -eq 0 ]`
and `link with an anchor checks only the file part` fails on its output
assertion. Both fail on an assertion, not on an error.

## Findings

1. **Major: `urls and anchors ignored` passes when a skip stops the scan of
   the file.** Every line in the fixture is a non-file target, and the test
   expects empty output. A skip written with `return` or `break` where
   `continue` belongs drops every later link in the file, yet still produces
   status 0 and empty output. Reproduced with the mutation
   `case "$target" in *://* | mailto:* | '#'*) return ;; esac` after the
   target cut: the test stayed green and only the anchor test went red.
   **Fix:** a broken `[x](missing.md)` sentinel now follows the four
   non-file links. The test asserts status 1, the exact output
   `broken-link: docs/a.md -> missing.md` and empty stderr. The runbook
   says these targets "yield status 0". The test now shows that they yield
   no line, and the sentinel's line makes the status 1. Revert this if the
   runbook's literal status 0 must hold. That would leave the `return`
   hole open.

2. **Major: the extra guard test ruled out a correct implementation.** Its
   fixture `note:missing.md` has a colon in the first path segment. Per
   RFC 3986 §4.2 that is an absolute URI with scheme `note`, not a relative
   reference. A relative path shaped like that must be written
   `./note:missing.md`. A GREEN that skips any RFC 3986 scheme
   (`^[A-Za-z][A-Za-z0-9+.-]*:`) is a legitimate reading of the slice. Run
   against the old fixture, that GREEN went red on this test. The fixture
   also could not catch the plausible wrong glob `[a-z]*:*` (starts with a
   letter, contains a colon anywhere), because a correct scheme test skips
   `note:` too. So the test forced a scheme allowlist on the GREEN, which
   the slice never decides.
   **Fix:** the target is now `sub/a:missing.md`, a colon after a `/`. No
   scheme reading can claim it. The comment says why a first-segment colon
   is deliberately not used. `sub//missing.md` is unchanged.

3. **No change: the "target as written" report (`c.md#part`).** The
   Interfaces give `broken-link: <file> -> <target>`, and slice 1 prints the
   link's target with no normalization. Printing `c.md#part` rather than the
   stripped `c.md` fits that, and a reader can grep the linking file for the
   printed string. The slice's "checks `b.md` only" is about what gets
   checked, not what gets printed. The test is the first to pin the printed
   form, so keeping `#part` is a deliberate choice rather than something the
   slice forces. Kept.

4. **No change: wrong-reason questions from the brief.**
   - A skip for `https://` alone: `http://` and `mailto:` still report
     lines, so the test fails.
   - A skip of every target containing `#`: the anchor test fails, because
     `c.md#part` goes silent.
   - `${target##*#}`, which keeps the anchor in place of the file part:
     reports `b.md#part` as well, so the anchor test fails.
   - An empty remainder from `#section` after stripping: it resolves to the
     linking file's directory, which exists. Explicitly skipping `#…` gives
     the same result. Both are correct under the slice, and the fixture
     does not need to separate them. The satisfiability run below shows the
     strip form passing.

## Mutation reproductions

Each mutation was applied in place as an exact string replacement and
restored by the inverse replacement.

| # | Mutation of `scripts/check-links.sh` | Fixture | Result |
|---|---|---|---|
| A | regex `\[[^]]*\]\([^)]*\)`, cut `${link#*](}`: bracket half only, a different mutation from RED's | — | `link text…` red on `[ "$status" -eq 1 ]` (`[a [b] c](missing.md)` unmatched) |
| B | regex `\([^)]*\)`, cut `${link#(}`: paren half only | — | `link text…` red on output (extra `-> b` line) |
| C1 | `case … *:* \| '#'*) continue` | old | guard red. `urls…` **green**, which is why the guard is needed |
| C2 | `case … *//* \| mailto:* \| '#'*) continue` | old | guard red |
| C3 | `[[ =~ ^([A-Za-z][A-Za-z0-9+.-]*:\|#) ]] && continue` (correct RFC 3986 skip) | old | guard **red on a correct implementation**: finding 2 |
| R | `case … *://* \| mailto:* \| '#'*) return` | old | `urls…` **green**: finding 1 |
| R | same | new | `urls…` red on `[ "$status" -eq 1 ]` |
| G1 | `case … [a-z]*:* \| '#'*) continue` | new | guard red on output |
| G2 | `case … *:* \| '#'*) continue` | new | guard red on output |
| G3 | `case … *//* \| mailto:* \| '#'*) continue` | new | guard red on output |
| S1 | RFC 3986 scheme skip and check `${target%%#*}` | new | 8/8 green |
| S2 | `http://*\|https://*\|mailto:*` skip and check `${target%%#*}` | new | 8/8 green |

S1 and S2 show that the rebuilt tests accept both correct shapes of GREEN.
The guard (`colon or double slash…`) is now proven by mutation (G1–G3)
rather than resting on a green run nobody watched fail.

## Final red run (unmodified SUT)

```
$ scripts/run-bats.sh tests/check-links.bats
not ok 5 urls and anchors ignored
#   `[ "$output" = "broken-link: docs/a.md -> missing.md" ]' failed
not ok 7 link with an anchor checks only the file part
#   `[ "$output" = "broken-link: docs/a.md -> c.md#part" ]' failed
bats: 6 passed, 2 failed
```

Both fail on an assertion. `urls…` now fails on its output line, because
the current SUT reports all four non-file targets in addition to the
sentinel.

## Verification

- `git diff --quiet scripts/` exits 0, and `grep -c MUTATION
  scripts/check-links.sh` returns 0.
- `shellcheck tests/check-links.bats` is clean.
- `git status --porcelain -- scripts/ tests/` shows ` M tests/check-links.bats`
  only.
