# Item 4.3 slice 1 — RED: fire and quiet fixtures (readonly-path), batched
# with Item 4.2's deferred test gaps

2026-09-26. Mode RED. Scope: `readonly-path`'s matcher stub in
`lib/matchers.sh`, `tests/matchers.bats` (the flipped `expected_for` rows and
new cases), `tests/extract-fixtures.py` (one new cut-list entry), one new
fixture. Batched: Item 4.2's three deferred test gaps
(`item-4-2-s1-code-review.md`, "Test gaps the mutation run exposed" a/b/c).
Out of scope: `probe_readonly_path`, slices 2-5, any readonly-path verdict,
memory, docs/.

## SUT stub

`match_readonly_path` added to `lib/matchers.sh`, inert (`cat >/dev/null;
return 1`), wired into `detect()` in catalogue order (before
`match_tmpdir_unset`, matching `docs/references/detectors.md`'s `##
Candidates` ordering: readonly-path, tmpdir-unset, resume-lost,
(zellij-socket — candidate, unshipped), seccomp-init). No probe, no verdict:
out of scope for this slice.

## Fixture cut

New cut-list entry in `tests/extract-fixtures.py`, `fire-tmpdir-unset-bash-bare`
(devddaanet, 2026-09-13, `bash /tmp/claude-1000/../..$TMPDIR/move-strays.sh
2>/dev/null || bash "$TMPDIR/move-strays.sh"` → `Exit code 127` then `bash:
/move-strays.sh: No such file or directory`) — the corpus hit the code review
named for gap (a), cut with `python3 tests/extract-fixtures.py
fire-tmpdir-unset-bash-bare` (62 B). No other new fixture: gaps (b) and (c)
build near-miss text from fragments at run time in the test body (self-quiet),
per the dispatch's instruction — the corpus has no clean hit for either (a
targeted search for a `grep -n`-locator line quoting either diagnostic in full,
ending in nothing but trailing blanks, returned zero hits across all
projects; the two existing quiet fixtures for `resume-lost` and
`seccomp-init` are each already protected by *both* the line-start anchor and
extra trailing content — an ellipsis truncation, a closing backtick — which
is exactly why the code review's own drop-`^`-only mutations stayed green
against them).

## Tests added (`tests/matchers.bats`)

`expected_for`: the three `fire-readonly-path-*` rows flipped from `: ;;` to
`printf 'readonly-path\n' ;;` (the red); the `quiet-readonly-path-index-line`
row unchanged; one new row for `fire-tmpdir-unset-bash-bare` →
`tmpdir-unset`.

New `@test` cases, with the run against the current tree (mode RED, SUT
otherwise untouched):

| test | line | result |
|---|---|---|
| `tmpdir-unset fires on the bare shape directly after the tool prefix` | 19 | ok (behaviour already shipped; proved by mutation below) |
| `tmpdir-unset stays quiet when words before the quote hold a quote` | 23 | ok (already shipped; proved by mutation) |
| `tmpdir-unset stays quiet on a relative path after the prefix` | 24 | ok (already shipped; proved by mutation) |
| `resume-lost stays quiet on the index line quoting the refusal` (pre-existing, unchanged) | 25 | ok |
| `resume-lost stays quiet on a grep -n locator quoting the id whole` | 26 | ok (already shipped; proved by mutation) |
| `seccomp-init stays quiet on a heading quoting the failure` (pre-existing, unchanged) | 27 | ok |
| `seccomp-init stays quiet on a grep -n locator quoting the failure whole` | 28 | ok (already shipped; proved by mutation) |
| `readonly-path fires on a quoted cp refusal under /tmp` | 29 | **not ok** — `fixture fire-readonly-path-cp-tmp: expected [readonly-path] got []` |
| `readonly-path fires on a background task's output file read` | 30 | **not ok** — `fixture fire-readonly-path-task-output: expected [readonly-path] got []` |
| `readonly-path fires on a Python OSError errno 30 refusal` | 31 | **not ok** — `fixture fire-readonly-path-python-errno: expected [readonly-path] got []` |
| `readonly-path stays quiet on the memory index line naming the message` | 32 | ok (trivially true against the inert stub; not vacuous in the sense the standing rule targets — the stub asserts absence of a feature that does not exist yet, the same shape as the existing `no probe without a verdict` / `hook silent without a verdict` cases elsewhere in this suite) |

One pre-existing test also reds as a side effect of the same stub, not a new
test written by this slice:

- `the whole fixture sweep survives BSD grep, sed and mktemp` (line 42 in the
  1-indexed numbering above) — **not ok**, same cause: `fixture
  fire-readonly-path-cp-tmp: expected [readonly-path] got []`. It iterates
  every fixture on disk under `make_bsd_stubs`, so the flipped rows reach it
  too; it goes green with the same GREEN slice that satisfies 29-31.

Full-suite run (`direnv exec . just test`): 165 passed, 4 failed — exactly the
four above (109-111, 122 in the whole-suite numbering), no other file
regressed.

## Mutation proof

Each mutation is an exact-string replace in `lib/matchers.sh`, applied once,
re-run, then reverted with the two strings swapped; each restore was
confirmed by a `grep -c` for the mutated string returning 0 before the
re-run. One mutation per named test; no test file touched.

| # | test | mutation | before → after | red confirmed | restore confirmed |
|---|---|---|---|---|---|
| 1 | `tmpdir-unset fires on the bare shape directly after the tool prefix` (gap a) | make the `line N:` locator mandatory ahead of the bare path, so a plain `tool: /x: …` with no locator can no longer match | `(line [0-9]+: )?/` → `(line [0-9]+: )/` | only test 19 red (17, 18, 20-24 stayed green) | `grep -c '(line \[0-9\]+: )/\['` → 0; suite green |
| 2 | `tmpdir-unset stays quiet when words before the quote hold a quote` (gap b, quote-free-words) | let the words ahead of the opening quote contain a straight quote | `[^']*('\|‘)/` → `.*('\|‘)/` | only test 23 red (17-22, 24 stayed green) | `grep -c "\|\.\*('\|"` → 0; suite green |
| 3 | `tmpdir-unset stays quiet on a relative path after the prefix` (gap b, root slash) | make the bare alternative's root slash optional instead of dropping it outright (a first attempt that deleted the `/` character broke the char class itself and reded tests 17 and 19 too — not isolated, discarded and redone) | `)?/[^/:[:space:]]+` → `)?/?[^/:[:space:]]+` | only test 24 red (17-19, 22, 23 stayed green) | `grep -c ')?/?\['` → 0; suite green |
| 4 | `resume-lost stays quiet on a grep -n locator quoting the id whole` (gap c) | drop the line-start anchor only | `'^No conversation found` → `'No conversation found` | only test 26 red (20, 25, 27, 28 stayed green) | `grep -c "qE 'No conversation found"` → 0; suite green |
| 5 | `seccomp-init stays quiet on a grep -n locator quoting the failure whole` (gap c) | drop the line-start anchor only | `'^apply-seccomp:` → `'apply-seccomp:` | only test 28 red (20, 21, 26, 27 stayed green) | `grep -c "qE 'apply-seccomp"` → 0; suite green |

Mutation 3's discarded first attempt (`(line [0-9]+: )?/[^/:[:space:]]+` →
`(line [0-9]+: )?[^/:[:space:]]+`, deleting the literal `/` instead of making
it optional) is recorded here because it is instructive, not because it was
run against a committed state: it reded tests 17, 19 and 24 together, since
removing the `/` character also excludes `/` from the following character
class, so an absolute path can no longer match at all. The kept mutation
(inserting `?` after the `/`) isolates the root-slash requirement instead.

`git diff lib/matchers.sh` after all five mutation/restore cycles shows only
the two intended hunks (the `detect()` wiring line and the new
`match_readonly_path` stub) — confirmed by inspection, matching the diff
recorded above.

## Commands run

| command | result |
|---|---|
| `python3 tests/extract-fixtures.py fire-tmpdir-unset-bash-bare` | pass, 62 B cut |
| `bash lib/matchers.sh < tests/fixtures/fire-tmpdir-unset-bash-bare.txt` | `tmpdir-unset`, status 0 |
| prototype runs of all four fragment-built near-miss texts against the unmutated matcher | all quiet (status 1, no output) |
| `direnv exec . bats tests/matchers.bats` (final) | 1..45, 4 not ok (29-31, 42), 41 ok |
| `direnv exec . just test` (full suite) | 165 passed, 4 failed (109-111, 122) |
| `git status --porcelain -- lib/ tests/` | `M lib/matchers.sh`, `M tests/extract-fixtures.py`, `M tests/matchers.bats`, `?? tests/fixtures/fire-tmpdir-unset-bash-bare.txt` |

## Changes

- `lib/matchers.sh` — `match_readonly_path` stub (inert), wired into
  `detect()` in catalogue order.
- `tests/extract-fixtures.py` — one new cut-list entry,
  `fire-tmpdir-unset-bash-bare`.
- `tests/fixtures/fire-tmpdir-unset-bash-bare.txt` — new fixture.
- `tests/matchers.bats` — three `expected_for` rows flipped (the red), one
  new row for the cut fixture; nine new `@test` cases (one fire + one quiet
  for gap a's shape is one test since the shape is a fire fixture only; two
  quiet cases for gap b; two quiet cases for gap c; three fire + one quiet
  case for `readonly-path`).

No commit: RED leaves the tests and this report uncommitted for the slice's
GREEN commit to carry.
