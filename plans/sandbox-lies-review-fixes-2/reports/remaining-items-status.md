# Remaining items status

Status of `.claude/handoff-todo.md` against the repository at HEAD `0958a63`.
Format: item | before | after | evidence. Only `.claude/handoff-todo.md` was
edited; nothing staged, committed, stashed or reset by this pass (the Write
hook itself reported staging the todo file with `git add -f`).

## Open decisions

- Scratch transcripts in `~/.claude/projects/-tmp-claude-resume-probe-A/` and
  `-B/` | open | open (default delete kept) | per instruction: undecided;
  outside the repo, not listed or touched.
- FR-5 list omits `tests/hook-resume.bats` | open | closed, removed |
  `docs/design.md:98-107` now carries the `resume-lost` carve-out and names
  `tests/hook-resume.bats`; commit `0958a63` landed m-9 (`deliverable-review-fixes.md`
  §m-9; design.md is 399/400 after moving D-15/D-16 arguments to references).
  The "deferred to save a line" reason is gone.
- `references/excluded-commands.md` keep or drop | open | open (default keep) |
  per instruction; the file was edited in `0958a63` (m-19, m-21) but the
  provenance question is untouched.
- Publishing the plugin (no remote) | open | closed, removed | per instruction;
  `git remote -v` shows `origin git@github.com:ddaanet/sandbox-lies.git`.
  `git ls-remote origin` prints nothing: nothing pushed.
- Held `/gitlore:push` | open | closed, removed; recorded as ordering under
  Remaining | per instruction; memory's `live` branch is at
  `54285829c67f` on `ddaanet/sandbox-lies-memory` (`git ls-remote`), which is
  also the head of `memory/` (`5428582 Update MEMORY.md for ddaanet tier
  merge`). `.gitmodules` url repointed and staged (`M  .gitmodules`), not
  committed.
- Comment on anthropics/claude-code#96225 | open | dropped | per instruction.

## Remaining

- SessionStart notice about `sandbox.excludedCommands` lacking `git:*` etc. |
  open | closed, removed | source: my human partner says it is fixed in
  `prohibitions` 0.3.0. Unverified by me (installed plugin not inspected;
  `~/.claude` untouched).
- Publishing order | (new) | added | gitlore push, then repo push, then release,
  each a prerequisite for the next. Note for that step: `.gitmodules` is staged,
  not committed.
- Rejected `plans/sandbox-lies-review-fixes/reports/deliverable-review-build-only-range.md`
  | (new) | pending, user must run the `rm` | file still present, untracked
  (`ls -la`: 9852 bytes, Oct 7); `git status` lists it `??`. The todo carries
  the verbatim absolute-path `rm`.
- Probe `path=` newline encoding | open | open, annotated | guards stand:
  `lib/probes.sh:12` ("path= is left out when the resolved path holds a
  newline"), `lib/probes-readonly.sh:37-57`, `docs/references/readonly-path.md:51`.
  The second review's carried list also says both guards stand.
- m-1 quadratic tokenizer | open | open, annotated | `word="$word$ch"` appends
  per character in `lib/probes-readonly-command.sh`, bounded by `max=16384`;
  confirmed open by `plans/sandbox-lies-review-fixes/reports/deliverable-review-code.md`
  §Known carry-forward. Timing not re-measured; bash 3.2 unverified.
- m-7 line-cap gate coverage | open | open, annotated |
  `scripts/check-line-limits.sh` `handle_file` arms: `.sh .bash .bats .py` and
  markdown only. Tracked uncovered files: `scripts/lib/strip-code.awk` (68
  lines), `.gitlore/bin/claude` (38), `plugin.json` (18), `hooks.json` (39);
  none is near a cap.
- m-8 corpus-eval idempotency | open | open, annotated | `tests/corpus-eval.py`:
  no clearing of `survivors/` (no rmtree/unlink), the documented loop appends
  `>>DIR/verdicts.tsv`, `aggregate` indexes `manifest[f]` directly, and the
  prefilter comment still says "strictly broader than any matcher". The second
  review lists the comment under "Carried, not counted"
  (`plans/sandbox-lies-review-fixes-2/reports/deliverable-review.md`).
- m-9 extract-fixtures robustness | open | open, annotated |
  `tests/extract-fixtures.py:160` `e.get("timestamp", "")[:10]` crashes on a
  null; `:165` `(b.get("input") or {}).get(...)` crashes on a non-dict input.
  The all-projects `pick()` branch: not re-examined, unverified beyond the
  reviews. Listed again as carried by the second review.
- Tests m-6, suite on macOS | open | open, annotated | `stat -c` in
  `tests/probes.bats:302` and `tests/helpers/probes.bash:101`; `C.UTF-8` in
  `tests/probes.bats:54-70` and `tests/hook-cap.bats:45`. BSD-stub cases cover
  the code under test; a run on a real Mac is unverified (`docs/design.md:51`
  says the macOS sandbox is unverified).
- Carry-forward: readonly-path `nopath` shapes | open | open, annotated |
  `docs/design.md:21-23` still lists `tee:`, sed's temp file and git's
  `could not write config file` as "worth a form"; no lib code names any of the
  five shapes (grep over `lib/`).
- Carry-forward: partial-checkout relative-path from a subdirectory | open |
  open, annotated | documented as a residual at `readonly-path.md:43`;
  `_probe_readonly_resolve` (`lib/probes-readonly.sh:86-92`) joins onto the
  payload `cwd`, no nearest-`.git` resolution (only the lock probes do,
  `hook.md:98-101`).
- Carry-forward: phantom "project root" wording | open | open, annotated |
  `lib/verdicts.sh:16,22` still say "the project root";
  `docs/references/hook.md:103-105` records the persisted-`cd` exception.
- Carry-forward: Item 8.2 remainder | open | open, annotated |
  `memory/ddaanet/sandbox-effects.md` exists and `memory/MEMORY.md:7` indexes
  it; `docs/design.md:152-161` (FR-10 "Partial") and
  `docs/references/detectors.md:311-314` still defer the audit to Item 8.2;
  `tests/docs.bats` has no `sandbox-effects` case; `tests/matchers.bats:285`
  still reads the live memory file.

## Not in the todo (build-finish.md §Carry-forward), noted only

- Line caps: `detectors.md` is now 353 lines (was 399); `design.md` is 399 of 400
  (the move-out the carry-forward asked for happened for D-15/D-16 in
  `0958a63`, and the next addition to design.md still needs another).
- Not listed in the todo and left out: `tmpdir-unset` unobserved since CC
  2.1.270, the edify build-skill TDD-audit proposals, the m7 cwd probe, the
  4.1/7-4.1/9 suite-count discrepancy. Status unchecked; say so if they should
  be tracked.
- `docs/design.md:20` "Next: publish the plugin; then publish the memory tier,
  held until the plugin installs" is stale against the new ordering (gitlore
  push first). Not edited (out of scope).

## `.claude/handoff-task.md`

Not edited. Its Current task section is stale: it describes the deliverable
review of `plans/sandbox-lies-review-fixes-2` as still to run, but
`reports/deliverable-review.md` exists (0 Critical, 0 Major, 22 Minor) and all
22 Minors are fixed in `0958a63`.
