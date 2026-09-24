# Item 2.2 slice 3: GREEN

Scope: `scripts/check-links.sh`'s `check_links_in`. Tests are the four in
`tests/check-links.bats` (slice 3) rebuilt by the test review; no further
test edits made here.

## Order worked

1. Read the red report and test review, then the current
   `tests/check-links.bats` and `scripts/check-links.sh` to confirm both red
   tests still fail as the reports describe (`scripts/run-bats.sh
   tests/check-links.bats`: 6 passed, 2 failed, same two names and
   assertions as `item-2-2-s3-red.md`).
2. Added the skip and strip logic to `check_links_in`'s per-link loop, in
   `scripts/check-links.sh`:
   - A `case "$target"` skip, `continue`d (not `return`/`break`, per the
     test review's finding 1) for `http://*`, `https://*`, `mailto:*` (an
     explicit scheme list) and a separate `'#'*` arm for a pure anchor.
   - A `check_target="${target%%#*}"` used only for the existence test; the
     printed line keeps `target` as written, so `c.md#part` still reports
     with its anchor per the test review's finding 3.
   - Declared `check_target` in the function's `local` line alongside the
     existing locals.
3. Ran the two previously-red tests individually
   (`scripts/run-bats.sh tests/check-links.bats -f "urls and anchors
   ignored"` and `-f "link with an anchor checks only the file part"`):
   both pass on the first attempt, no further iteration needed.
4. Ran the full suite, `just precommit`, and the real-tree run, in that
   order (below).

## Scheme test: explicit list, not RFC 3986

Chose the explicit-list shape (`http://* | https://* | mailto:*`) over an
RFC 3986 scheme match: a `case` glob cannot express "letter, then
alnum+-.+, then a colon before any slash" without `[[ =~ ]]`, whose quoting
differs across bash versions (`shell-gotchas`). Recorded in the script as a
comment alongside the residual: a target using a scheme outside this list
(`ftp:`, `tel:`, `data:`, …) is checked as a literal path and reported
broken — loud, not silent, matching the test review's finding 4 on the
guard test's satisfiability (S2 in its mutation table exercises this same
shape).

## Runs

Full suite:

```
$ scripts/run-bats.sh tests/
bats: 51 passed, 0 failed
```

Precommit:

```
$ just precommit
scripts/run-bats.sh tests/
bats: 51 passed, 0 failed
precommit passed: plugin.json, shellcheck, bash -n, rumdl, line limits, tests
```

Real tree:

```
$ scripts/check-links.sh
$ echo $?
0
```

No broken links in the repo's own tracked markdown scope; nothing to
record as a residual finding here.

## Files changed

- `scripts/check-links.sh` — skip and anchor-strip logic in
  `check_links_in`, plus the `check_target` local.
- `tests/check-links.bats` — unchanged from the test review's rebuilt
  fixtures (already staged before this report).
- `plans/sandbox-lies/reports/item-2-2-s3-red.md`,
  `plans/sandbox-lies/reports/item-2-2-s3-test-review.md` — carried into
  this commit per the dispatch's staging list.
