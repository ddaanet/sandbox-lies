# Review: Phase 4 checkpoint (lock verdicts, shipped candidates, readonly-path matcher and probe, retirement)

**Scope**: `git diff e4cc0d3..HEAD` over the 23 files the dispatch lists (Items
4.1, 4.2, 4.3 and the Phase 4 retirement with its status flips), plus the two
extra items my human partner approved. The `memory` gitlink and anything under
`memory/` are out of scope and were only read to check the retirement. **Date**:
2026-09-26 **Mode**: review + fix (nothing staged, nothing committed)

## Summary

Phase 4 meets its runbook contracts. The hook runs `probe_<name>` only for a
name that has a verdict, with the flag and `cwd` as the interface says. All ten
lock name/outcome pairs and the three candidate verdicts match their doc source
word for word. `tmpdir-unset`, `resume-lost` and `seccomp-init` are gated by the
hook as their flag policies say. `readonly-path` fires, stays silent through the
hook, and its probe meets the `writable|readonly|nopath` contract. The retired
memory sections, the description, the symptom table and both index lines agree
with each other.

No finding was critical. There was one major gap in the tests: the
`hook silent without a verdict` case passed vacuously when nothing fired. The
minor findings were stale comments, one stderr redirect, and an omission from
the hook reference node. All are fixed. Both extra items are applied: the
tmpdir-unset verdict text changed in all three of its places together, and the
docs now carry the mask-free `/tmp` write evidence.

**Overall Assessment**: Ready

## Verification performed

- `cd /Users/david/code/sandbox-lies && direnv exec . just precommit`, run in
  the foreground after all fixes. Result: `bats: 181 passed, 0 failed`, then
  `precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests`.
- Ran the four touched suites directly (`hook-candidates`, `verdicts`,
  `probes-readonly`, `matchers`): 60 of 60 ok.
- Mutation check on the strengthened `hook silent without a verdict` case. I
  replaced `declare -F "$fn" >/dev/null || continue` in `hooks/annotate.sh` with
  `: MUTATED-GATE` (grep counted 1) and ran the case. It went red at
  `[ -z "$output" ]`. I restored the line by the reverse replace; grep counted 0
  and `git diff hooks/annotate.sh` was empty.
- Compared each verdict's text against its source by hand: `lib/verdicts.sh`
  against `docs/references/lock-detectors.md` (git-lock and config-lock, all
  five outcomes and their human lines) and against `detectors.md` (the three
  candidates). All identical after the item-2 change.
- Checked the retirement in `memory/ddaanet/sandbox-effects.md`. The index.lock
  and config.lock section, cost 1, the `--resume` mechanism and the
  sandbox-setup section are gone. The skill-mapped residue is still there. Both
  index lines match the new description. No edit was made under `memory/`.
- Checked line counts: `docs/design.md` 396, `docs/references/detectors.md` 308,
  `docs/references/lock-detectors.md` 146, `docs/references/hook.md` 33,
  `docs/changelog.md` 129. No file is over its cap, so no split was needed.

## Issues Found

### Critical Issues

None.

### Major Issues

1. **`hook silent without a verdict` passed vacuously when nothing fired**
   - Location: `tests/hook-candidates.bats` (the case, ~line 92)
   - Problem: the empty output and the missing probe call were the only
     assertions. Two regressions would have left the case green:
     - `detect` stops naming `readonly-path` on the fixture. Then the silence
       comes from nothing firing, not from the verdict gate.
     - `stub_probe` stops overriding the probe. Then `$PROBE_CALLED` could never
       exist, so the absence proves nothing.

     This is a bare-negative shape.
   - Fix: two additions.
     - An in-test guard, before the run: the copied `lib/matchers.sh` on the
       text must print exactly `readonly-path` with status 0.
     - A positive over the same payload, after the run: define a stub
       `verdict_readonly_path` and the stub probe must be called. The two runs
       differ only in the guard's trigger.

     The mutation above shows the case now goes red when the gate is removed.
   - **Status**: FIXED

### Minor Issues

1. **Stale RED-phase comment in `tests/matchers.bats`**
   - Location: `tests/matchers.bats:228-233` (detector E block)
   - Note: the comment still said `match_readonly_path` was an inert stub and
     that the fire fixtures stay red until GREEN. That is false now.
   - Fix: replaced with the standing fact. The quiet fixture is quieted by more
     than the anchor, and `tests/matchers-edges.bats` pins the line-start anchor
     alone.
   - **Status**: FIXED

2. **Leftover slice note in `expected_for`**
   - Location: `tests/matchers.bats:56`
   - Note: the comment read `Item 4.3 slice 1's matcher (this is its red)`.
   - Fix: now reads `# readonly-path, built by Item 4.3.`
   - **Status**: FIXED

3. **`hook-candidates.bats` header named only Item 4.2**
   - Location: `tests/hook-candidates.bats:2-5`
   - Note: the file also holds Item 4.3's `readonly-path` silence case.
   - Fix: the header now names both.
   - **Status**: FIXED

4. **Plan state in production code**
   - Location: `lib/probes.sh:47-48`
   - Note: the comment said
     `(Item 4.3's Interfaces block; no verdict ships yet, Item 6.1)`. That goes
     stale at Item 6.1, and it is the only plan-item reference in `lib/` or
     `hooks/`.
   - Fix: the comment now states the contract instead: line 1 is `writable`,
     `readonly` or `nopath`, then `path=` when a path was extracted.
   - **Status**: FIXED

5. **Blanket `2>/dev/null` in a teardown**
   - Location: `tests/probes-readonly.bats:26` (`teardown`)
   - Note: `chmod 755 "$RO_DIR" 2>/dev/null || :` hid any failure to restore the
     mode, which would leave bats a tree it cannot clean
     (`no-stderr-suppression`).
   - Fix: now `[ -z "$RO_DIR" ] || chmod 755 "$RO_DIR"`. A failed restore is
     visible and fails the case.
   - **Status**: FIXED

6. **Hook reference node left out two steps of the call sequence**
   - Location: `docs/references/hook.md` Flow paragraph
   - Note: the node that governs changes to `annotate.sh`'s call sequence did
     not say two things the tests pin:
     - A name its flag policy silences, or with no `verdict_<name>`, is skipped
       before any probe runs.
     - Human lines join with `; `.
   - Fix: one sentence and one clause added to the Flow paragraph.
   - **Status**: FIXED

7. **`## Now` in `docs/design.md` is stale**
   - Location: `docs/design.md:16-25`
   - Note: "Next: corpus replay for the five candidate detectors" was done in
     Phase 3, and Phase 4 shipped the candidates.
   - **Status**: DEFERRED. Runbook cross-cutting rule: Item 8.2 updates the
     `## Now` section. Phase 8 is in Scope OUT.

## Extra items

### 1. Item 3.1 sandbox evidence

`command grep` over `docs/` found two places that argued from masks:

- `docs/references/lock-detectors.md`, `Live reproduction owed: mask`.
- The config-lock `mask` reproduction in the same file, which said the
  delegate-session and main-session git calls failed "despite `git:*`" with the
  mask hit as the only evidence.

No other sentence in `docs/` claims a mask exists only inside the sandbox. The
statements in `hook.md` and `changelog.md` that masks are visible to unsandboxed
readers already hold in the one-directional sense.

- Owed-`mask` paragraph: removed two sentences. One said every config-lock write
  "hit a mask that exists only inside the sandbox". The other recorded a
  `test -c` of the mask in the same `sh -c` string. The conclusion now stands on
  the mask-free test: on CC 2.1.283 the `git:*` exclusion is not honoured. In
  the main session on 2026-09-26, `git --version && touch /tmp/sbx-probe-git`
  failed with the read-only-filesystem error, and the same `touch` with the
  sandbox disabled succeeded. A write to `/tmp/<name>` fails that way only
  inside the sandbox. A mask proves nothing about the call that sees it.
- Config-lock reproduction: the observations stay (same error, key unwritten,
  delegate and main session). The "despite `git:*`" claim now points at the
  `/tmp` write test "not on the mask they hit".
- The diagnostic is described rather than quoted, so the file stays self-quiet.

### 2. `tmpdir-unset` caveat and verdict

- Caveat added to the `tmpdir-unset` entry of `docs/references/detectors.md`.
  **Caveat (2026-09-26).** On CC 2.1.283 an unsandboxed call's `$TMPDIR` read
  `/tmp`, not unset, so the collapse may not occur unsandboxed on current CC;
  the 13 hits predate that observation. The verdict states only what the flagged
  call shows.
- The verdict changed in three places together, which stay identical:
  - `detectors.md`, the source text
  - `lib/verdicts.sh` `verdict_tmpdir_unset`
  - `tests/verdicts.bats`, the verbatim transcription

  The two `systemMessage` assertions in `tests/hook-candidates.bats` changed
  with them.

Old paragraph:

```text
`$TMPDIR` is unset outside the sandbox, so the path collapsed to `/`. Use the literal scratch path `/tmp/claude/<job>` (create it with `mkdir -p`) in this and every unsandboxed or delegated command.
```

New paragraph:

```text
`$TMPDIR` expanded empty in this unsandboxed call, so the path collapsed to `/`. Use the literal scratch path `/tmp/claude/<job>` (create it with `mkdir -p`) in this and every unsandboxed or delegated command.
```

Old human line: `$TMPDIR — unset unsandboxed`

New human line: `$TMPDIR — expanded empty, path collapsed to /`

The new text states only what this call shows and keeps the literal-path
directive. It is 208 characters, under FR-6's 400, and the human line is still
one lowercase clause with an em-dash. The `verdict text is quiet` test stays
green.

Other places checked:

- `docs/design.md:4`: names the detector only. Unchanged.
- `docs/design.md:142`: `$TMPDIR`-unset is the retired section's label. Not an
  always-unset claim, so unchanged.
- `docs/design.md:179-183` (NFR-4): said the hook runs "with `$TMPDIR` unset".
  Now reads "where `$TMPDIR` may be unset". This mattered: on macOS the variable
  is normally set.
- Translation-map row in `detectors.md`: changed from "`$TMPDIR` unset and
  unstable" to "`$TMPDIR` collapse and instability".
- `docs/changelog.md`: a new 2026-09-26 entry records both changes.

## UNFIXABLE

None.

## Fixes Applied

- `docs/references/lock-detectors.md`: owed-`mask` paragraph and config-lock
  `mask` reproduction now rest on the `/tmp` write test, not on masks (extra
  item 1).
- `docs/references/detectors.md`: `tmpdir-unset` verdict reworded, dated caveat
  added, translation-map row reworded (extra item 2).
- `lib/verdicts.sh`: `verdict_tmpdir_unset` paragraph and human line (extra item
  2).
- `tests/verdicts.bats`: transcription of the new tmpdir-unset text (extra item
  2).
- `tests/hook-candidates.bats`: new `systemMessage` in both tmpdir-unset cases
  (extra item 2); header (minor 3); detect guard and positive pair in
  `hook silent without a verdict` (major 1).
- `docs/design.md`: NFR-4 wording (extra item 2).
- `docs/changelog.md`: 2026-09-26 entry.
- `docs/references/hook.md`: Flow paragraph (minor 6).
- `lib/probes.sh`: `probe_readonly_path` contract comment (minor 4).
- `tests/matchers.bats`: detector E comment and `expected_for` comment (minor 1,
  2).
- `tests/probes-readonly.bats`: teardown without `2>/dev/null` (minor 5).

## Requirements Validation

| Requirement | Status | Evidence |
|---|---|---|
| FR-3 | Satisfied | `hooks/annotate.sh` probe call; `tests/hook-locks.bats` |
| FR-4 | Partial (as recorded) | lock probes hook-called; `probe_readonly_path` built, `tests/probes-readonly.bats`; live proof Item 5.1 |
| FR-5 | Partial (as recorded) | candidate gating in `annotate.sh`; paired-flag cases in `hook-locks.bats`, `hook-candidates.bats`; readonly-path policy Item 6.1 |
| FR-6 | Partial (as recorded) | verdict text verbatim, under 400, quiet; cap skip-and-continue in `hook-cap.bats`; readonly-path verdicts Item 6.1 |
| FR-7 | Partial (as recorded) | four candidates matched, `zellij-socket` a candidate |
| FR-10 | Partial (as recorded) | lock, cost 1, `--resume`, sandbox-setup sections retired |
| NFR-1 | Satisfied | shipped matchers re-measured; `Corpus.` lines current |

**Gaps:** none within Phase 4 scope.

## Positive Observations

- Every case that fires a lock detector stubs its probe and asserts
  `$PROBE_CALLED`, so no fixture path reaches the host and a stub the hook never
  reached cannot pass.
- The verdict transcriptions come from the docs, not from `lib/verdicts.sh`. The
  row table is checked against the set of defined `verdict_*` functions, so a
  verdict without a row fails.
- `_readonly_path_line` is shared by the matcher and the probe, so their
  discriminators cannot drift apart.

## Files modified

- /Users/david/code/sandbox-lies/docs/changelog.md
- /Users/david/code/sandbox-lies/docs/design.md
- /Users/david/code/sandbox-lies/docs/references/detectors.md
- /Users/david/code/sandbox-lies/docs/references/hook.md
- /Users/david/code/sandbox-lies/docs/references/lock-detectors.md
- /Users/david/code/sandbox-lies/lib/probes.sh
- /Users/david/code/sandbox-lies/lib/verdicts.sh
- /Users/david/code/sandbox-lies/tests/hook-candidates.bats
- /Users/david/code/sandbox-lies/tests/matchers.bats
- /Users/david/code/sandbox-lies/tests/probes-readonly.bats
- /Users/david/code/sandbox-lies/tests/verdicts.bats
- /Users/david/code/sandbox-lies/plans/sandbox-lies/reports/phase-4-corrector.md
  (this report)
