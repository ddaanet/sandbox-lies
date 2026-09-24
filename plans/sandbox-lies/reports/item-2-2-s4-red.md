# Item 2.2 slice 4: RED

Scope: `tests/check-links.bats` only. `scripts/` untouched, byte-identical to
HEAD (verified below). Not committed.

## Test added

- **`link inside a code span or fence ignored`** — the runbook's quoted
  slice-4 name, pinned as a single test since every fixture line pins the
  same contract (code is not a link) from a different angle. One
  `docs/a.md`:

  ```
  `[a](span-missing.md)`
  `code` [b](after-span-missing.md)
  ```
  [c](fence-missing.md)
  ```
  [d](after-fence-missing.md)
  ~~~
  [e](tilde-missing.md)
  ~~~
  [z](sentinel-missing.md)
  ```

  - `span-missing.md` sits inside an inline code span — ignored.
  - `after-span-missing.md` sits on the *same line* as that span but outside
    its backticks — reported. Discriminates an implementation that drops
    every line containing a backtick instead of just the spanned text.
  - `fence-missing.md` sits inside a ``` fence — ignored.
  - `after-fence-missing.md` sits on the first line past the closing ``` —
    reported. Discriminates an implementation that never leaves "fence mode"
    once entered.
  - `tilde-missing.md` sits inside a `~~~` fence — ignored, repeating the
    fenced case with the other CommonMark fence marker.
  - `sentinel-missing.md` is last — reported. Discriminates an early
    return/break in place of continue, which would drop it along with the
    fenced lines ahead of it.

  Expects status 1 and exactly three lines, in file order: the two "reported"
  decoys above and the sentinel.

  Deliberately left out (noted per dispatch, not covered by this fixture):
  indented (4-space) code blocks, fences nested inside a list item,
  double-backtick spans (`` `` ` `` ``), and an unclosed fence.

## Run: full suite, unmodified SUT

```
$ scripts/run-bats.sh tests/check-links.bats
not ok 9 link inside a code span or fence ignored
#   `[ "$output" = "broken-link: docs/a.md -> after-span-missing.md' failed
bats: 8 passed, 1 failed
```

Full log:

```
1..9
ok 1 resolving link passes
ok 2 broken link is reported
ok 3 broken links in scope are reported
ok 4 markdown out of scope is ignored
ok 5 urls and anchors ignored
ok 6 colon or double slash in a relative target is not mistaken for a URL
ok 7 link with an anchor checks only the file part
ok 8 link text does not cut the target
not ok 9 link inside a code span or fence ignored
# (in test file tests/check-links.bats, line 255)
#   `[ "$output" = "broken-link: docs/a.md -> after-span-missing.md' failed
```

Reds genuinely: `check_links_in` (`scripts/check-links.sh`) has no code-span
or fence awareness today — a single `grep -aoE` over the whole file matches
every `](target)` regardless of context, so it reports all six missing
targets (span, after-span, fence, after-fence, tilde, sentinel), not just the
three the fixture expects. The failure is a string mismatch on `$output`
(more lines than expected), not a missing command or an execution error —
the same "fails on its own assertion" shape as slice 3's reds, not an
absence.

## Verification

- `shellcheck tests/check-links.bats`: clean (added
  `# shellcheck disable=SC2016` on the fixture's `printf`, justified inline —
  the two backtick-bearing lines are literal fixture data, not command
  substitution).
- `git status --porcelain --untracked-files=no`: ` M tests/check-links.bats`
  only.
- `git diff --quiet scripts/ && echo "scripts/ byte-identical to HEAD"` →
  printed, confirming `scripts/` is untouched.

## Files changed

- `tests/check-links.bats` (uncommitted). `scripts/` unchanged.
