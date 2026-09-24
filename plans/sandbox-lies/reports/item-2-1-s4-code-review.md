# Item 2.1 slice 4: code review

Scope: the slice-4 change to `scripts/check-line-limits.sh` in `Item 2.1/4`,
read as a whole with the file. It adds the `plans/* | plugin-dev/*) ;;`
exclusion as the first `case` arm, the `*.sh | *.bash | *.bats | *.py` → 400
arm last, and a script clause in the header Scope comment. I read it against
Item 2.1's runbook text and slice list, the recall-artifact memories,
`shell-gotchas`, the slice-4 RED, test-review and GREEN reports, and the
slice 1–3 code reviews. Slices 5–7, the precommit wiring and Items 2.2–2.4 are
out of scope, and so is the test file.

## Findings

1. **The header Scope comment was stale (minor).** It still said "(grows
   across later slices of this item)". Slice 4 is the last slice that changes
   scope: 5–7 cover whitespace, edge inputs and BSD stubs. So the note was
   already false and would stay in the finished script. **Fix:** I dropped
   the parenthetical and reflowed the paragraph.
2. **The exclusion was described only by its effect on scripts (minor).** The
   header said scripts are capped "except under a root-level `plans/` or
   `plugin-dev/`", and the arm's comment described only how it shadows the
   script arm. The arm actually skips *every* path under those directories,
   and it runs ahead of the markdown arms too. Nothing was described wrongly.
   Markdown under `plans/` is outside the docs/, skills/ and root scope either
   way, and before this slice the `*/*.md` skip handled it. But a reader of
   the finished table should see the arm as a whole-directory exclusion, not
   only as a script carve-out. The phrase "an unadorned `plans/*` only
   matches a path that starts with it" was also vague about what "it" is.
   **Fix:** the header now ends "Nothing under a root-level `plans/` or
   `plugin-dev/`." The arm's comment opens "Root-level plans/ and plugin-dev/
   are out of scope for every file type." It keeps the must-precede
   rationale, and it now reads "`plans/*` matches only a path beginning
   `plans/`".

### Checked and sound

- **Placement.** The exclusion comes first, so it runs ahead of the script
  arm, as it must. `case` takes the first match, and the test review showed
  that moving it after the arm reddens both exclusion tests. Its prefixes do
  not overlap `docs/` or `skills/`, so putting it first costs nothing and
  reads as "exclusions, then inclusions". The script arm's position among
  the markdown arms is free because the skip names `.md`. The skip arm's
  comment already says so.
- **The table as a finished scope.** From top to bottom, it has a
  whole-directory exclusion, then docs/ markdown, then SKILL.md before the
  other skills/ markdown, then the non-root markdown skip, then root
  markdown, then scripts. It matches the runbook's scope sentence exactly.
  Every arm whose order matters has a comment saying why. No arm is dead:
  precommit's shellcheck (SC2221/2222) is clean.
- **Anchoring and the real tree.** Paths from `git ls-files` are
  root-relative with no `./`, so `plans/*` cannot match `tools/plans/…`, and
  a root `plans.sh` is still capped. On the real tree the exclusion matters.
  `plugin-dev/release.sh` has 832 lines, and
  `plans/2026-09-02-sandbox-detector-replay.py` has 358. The largest in-scope
  script is `tests/matchers.bats`, at 256. The only gitlink is `memory`,
  which has no script extension and falls through every arm.
- **bash 3.2, BSD, whitespace.** The slice adds only `case` alternation with
  `|`, which is POSIX. It adds no tools, and the `case` word is still the
  NUL-read `"$file"`.

## Mutant run (once)

I used an exact replacement to remove `.bats` from the script arm:
`*.sh | *.bash | *.bats | *.py) check_cap` became `*.sh | *.bash | *.py)
check_cap`. The test review had covered the exclusion missing `.py`, but not
the arm missing a type. I then ran `scripts/run-bats.sh
tests/check-line-limits.bats`. **The tests went red:** `not ok 7 oversized
script is reported` failed its exact-output assertion (line 160), with 11
passed and 1 failed. I restored the file with the inverse replacement.
Proof of the restore: `git diff --quiet scripts/check-line-limits.sh`
exited 0 both before the mutation and after the restore. The mutation ran
before I made any fix.

## Test gaps (report only)

None new. The test review's residuals still hold: there is no nested
`plans/job/x.sh` fixture, and nothing pins a slashless `plans*`.

## Verification

- `scripts/run-bats.sh tests/` (foreground): `bats: 39 passed, 0 failed`.
- `direnv exec . just precommit` (foreground): `precommit passed:
  plugin.json, shellcheck, bash -n, rumdl, tests`, exit 0.
- `scripts/check-line-limits.sh .` (foreground): exit 0, no output.

## Files changed

- `scripts/check-line-limits.sh`: the comments only (the header Scope
  paragraph and the exclusion arm's comment). No code changed, and nothing
  is committed.

## Refactor flag

None.
