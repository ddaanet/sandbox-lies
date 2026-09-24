# Item 2.2 slice 3: RED

Scope: `tests/check-links.bats` only. `scripts/` untouched, byte-identical to
HEAD (verified below). Not committed.

## Tests added

- **`urls and anchors ignored`** — one file linking `http://…`, `https://…`,
  `mailto:…` and `#section`; none of these resolve as a literal path. Expects
  status 0, empty stdout, empty stderr.
- **`colon or double slash in a relative target is not mistaken for a URL`** —
  a guard against an over-broad scheme test, not named in the runbook slice
  text but cheap: `note:missing.md` (a colon, but not a registered scheme) and
  `sub//missing.md` (a double slash with no scheme prefix). Both are broken
  and neither is a URL; expects both reported. This test does not red against
  the current SUT — every target is still checked as a literal path, so both
  are already reported broken for the right reason. Its purpose is to catch a
  slice-3 GREEN implementation whose scheme test is "contains `:`" or
  "contains `//`" rather than an anchored scheme match.
- **`link with an anchor checks only the file part`** — its own test, split
  out from the URL/anchor test because it pins a different contract (the file
  part of an anchored link, not scheme detection). One file links `b.md#part`
  (`b.md` exists) and `c.md#part` (`c.md` missing). Discriminates a script
  that checks the whole `b.md#part` string literally (would wrongly report
  the first line) from one that drops every link holding a `#` (would wrongly
  stay silent on the second). The report shows the target as written,
  `c.md#part`, matching the existing broken-link lines' convention.
- **`link text does not cut the target`** — slice 1's code-review finding
  (`plans/sandbox-lies/reports/item-2-2-s1-code-review.md`, finding 2), now
  pinned by a test. One file links `[a (b)](x.md)` (`x.md` exists) and
  `[a [b] c](missing.md)` (missing). Combining both in one file means a
  regression that cuts the target at the link text's own `(`, or hides the
  bracketed link behind an unmatched `]`, changes the single expected output
  line rather than just toggling a status.

## Run: full suite, unmodified SUT

```
$ scripts/run-bats.sh tests/check-links.bats
not ok 5 urls and anchors ignored
#   `[ "$status" -eq 0 ]' failed
not ok 7 link with an anchor checks only the file part
#   `[ "$output" = "broken-link: docs/a.md -> c.md#part" ]' failed
bats: 6 passed, 2 failed
```

`urls and anchors ignored` and `link with an anchor checks only the file
part` red genuinely: the SUT checks every target as a path relative to the
linking file's directory, with no scheme or anchor handling, so
`http://example.org/x` etc. and `c.md#part` (and `b.md#part`) are each
checked as literal paths that do not exist and reported broken — the exact
behaviour slice 3 must change.

`colon or double slash…` and `link text does not cut the target` pass already
(the former as a forward guard described above; the latter is slice 1's
already-shipped fix).

## Mutation proof — `link text does not cut the target`

Reverted `scripts/check-links.sh`'s extraction to its pre-fix-2 shape (slice
1's code review, finding 2): the link regex back to
`\[[^]]*\]\([^)]*\)` (text half restored) and the target cut to
`${link#*(}` (first `(` instead of `](`).

```
$ scripts/run-bats.sh tests/check-links.bats -f "link text does not cut the target"
not ok 1 link text does not cut the target
#   `[ "$output" = "broken-link: docs/a.md -> missing.md" ]' failed
bats: 0 passed, 1 failed
```

Restored by inverting both edits, then:

```
$ git diff --quiet scripts/ && echo "scripts/ byte-identical to HEAD"
scripts/ byte-identical to HEAD
```

## Verification

- `shellcheck tests/check-links.bats`: clean.
- `git status --porcelain -- scripts/ tests/`: ` M tests/check-links.bats`
  only.

## Files changed

- `tests/check-links.bats` (uncommitted). `scripts/` unchanged.
