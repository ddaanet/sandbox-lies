# Item 1.1 review — promote the pilot into lib/ and tests/

Reviewed: HEAD commit `♻️ Item 1.1 — promote the pilot into lib/ and tests/`
against runbook Item 1.1, the Cross-cutting rules, outline Phase 1 and the
design's status legend.

## Verdict

Item 1.1 meets its Done criterion. I found no critical or major issues. I
applied three minor fixes, which are uncommitted in the tree:
`tests/matchers.bats` and `tests/corpus-eval.py`.

## Verification

- `scripts/run-bats.sh tests/matchers.bats`: 26 passed, 0 failed. The TAP log
  has no `# skip` line, so the two live-store cases run against
  `memory/ddaanet/sandbox-effects.md` and do not skip. I re-ran it after the
  fixes: still 26/0, 0 skips, and 0 `BW02` warnings.
- `bash lib/matchers.sh` over `lib/matchers.sh`, `tests/matchers.bats` and
  `tests/corpus-eval.py`: prints nothing and exits 1 for all three.
- `shellcheck lib/matchers.sh tests/matchers.bats`: clean.
- I ran `detect` over every tracked regular file outside `tests/fixtures/`.
  Only the three exemptions that Item 1.3 names fire:
  `plans/2026-09-02-sandbox-detector-hits.jsonl`,
  `plans/2026-09-02-sandbox-detector-replay.py` and
  `plans/2026-09-03-sandbox-matcher-corpus-eval.md`. The docs.bats sweep will
  start green.
- I checked that the fragment split works:
  - The bats string built from the two fragments matches all five
    `fire-lock-*` fixtures under `grep -F`, so the live-store negative
    assertion can actually fail.
  - I copied `lib/`, `tests/` and the store into a scratch tree and appended
    the whole follow-on sentence to the store. Both live-store cases went red
    ("fault applied" was checked before the run). This also shows the new
    `$BATS_TEST_DIRNAME/../memory/...` path resolves.
  - The matcher side is covered by the five `fire-lock-*` fixtures, which
    still produce `git-lock`.
- The renames were done with `git mv` and history is kept: `git show -M`
  reports matchers.sh 95%, matchers.bats 96%, corpus-eval.py 96%,
  extract-fixtures.py 99%, and 19 fixtures at 100%. `lib/matchers.sh` keeps
  mode 100755. `plans/sandbox-detector-pilot/` no longer exists.
- The `SPEC` names in `tests/extract-fixtures.py` match the 19 files in
  `tests/fixtures/` one for one. `OUT` resolves relative to the script, so
  the cutter writes into `tests/fixtures/` unchanged.
- The design header's `Status:` clause names `lib/matchers.sh` and adds no
  line. `BRIEF.md` is untouched.

## Status flips against the legend

The legend says `Done`: implemented and pinned by a test or a gate that
re-checks it.

- **FR-2 Done.** Both pins exist: `lib/matchers.sh` and `tests/matchers.bats`,
  which asserts the full verdict set. Honest.
- **FR-8 Done.** The pin is the script, and the fixture set matches its
  `SPEC` exactly. Item 3.2 extends the cutter but does not reopen the
  requirement. Honest, within what the design names as the pin.
- **NFR-2 Done.** `tests/helpers/bsd-stubs.bash` exists, the one bats file
  loads it, and the stubbed sweep case passes. Later items add suites under
  the same rule. Honest for the current tree.
- **FR-11 Partial.** The named pin, `tests/docs.bats`, does not exist yet, and
  the status line says so. Honest.
- **NFR-1 Partial.** The harness is promoted, but re-measurement comes in
  Items 3.2, 4.2 and 4.3. Honest.

Caveat, not a defect: nothing re-runs the suite on each commit until Item 1.2
wires `just test` into `precommit`. The legend's "a test" clause is met, and
the runbook puts these flips in this item.

## Fixes applied

1. **Minor: `tests/corpus-eval.py` referred to a file by a stale bare name.**
   The docstring's "same pairing as `2026-09-02-sandbox-detector-replay.py`"
   used a name relative to `plans/`. From `tests/` it no longer resolved, so I
   changed it to `plans/2026-09-02-sandbox-detector-replay.py`. I also
   reflowed the first docstring paragraph, which the shorter path had left
   with a ragged short line.
2. **Minor: in `tests/matchers.bats`, `PILOT` named a directory that no
   longer exists.** The variable now holds the repository root, not the pilot
   directory. I renamed it to `ROOT` in its three uses. No other file refers to
   it. The runbook and outline mention "the `PILOT` variable" only as the
   thing to repoint. I left the two live-store paths in the literal form the
   runbook specifies.
3. **Minor: `tests/matchers.bats` produced BW02 warnings.** These predate this
   item. The four `run !` assertions each printed BW02 ("Using flags on `run`
   requires at least BATS_VERSION=1.5.0") into the TAP log. I added
   `bats_require_minimum_version 1.5.0` with a one-line comment. The warnings
   are gone and the case count is unchanged at 26.

## Not flagged (scope OUT or by design)

- The comments in `lib/matchers.sh` and `tests/matchers.bats` still describe
  "the detector pilot". This matches the design `Status:` line, which still
  calls it pilot code. Item 8.2's `## Now` update is where that wording turns
  over.
- `plans/sandbox-lies/runbook.md` and `outline.md` still name the old pilot
  paths as plan text. These are frozen plans, not live pointers.
