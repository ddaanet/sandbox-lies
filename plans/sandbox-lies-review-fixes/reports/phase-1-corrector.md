# Review: Phase 1 (Item 1.1) — readonly-path split out of detectors.md

**Scope**: `git diff a7ff5e5043ea6b7b973b264b13ee974bbf7a1787 HEAD` (Item 1.1),
plus a whole-tree sweep for citations of the readonly-path entry outside
`plans/` and `memory/`

**Date**: 2026-10-04

**Mode**: review + fix

## Summary

The move is clean. The moved section is byte-identical to the old
`### readonly-path` section once its heading is promoted to `##`; the only
difference is a dropped trailing blank line (verified by extracting the section
from `a7ff5e5` and diffing it). The new node's opening paragraph and the stub
follow the `lock-detectors.md` pattern. The anchor `#readonly-path` resolves, and
the item's listed prose citations are repointed. The whole-tree sweep found one
punctuation slip, two omissions in the "what is here" lists, and four citations
of the readonly-path entry that the item's list missed. All are fixed.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

None.

### Minor Issues

1. **Missing comma in hook.md's node list**
   - Location: `docs/references/hook.md:7`
   - Note: "[detectors.md](detectors.md) [lock-detectors.md](…) and
     [readonly-path.md](…)" had lost the comma when the list grew from two
     items to three.
   - **Status**: FIXED

2. **Stub and node intro left out the live reproductions**
   - Location: `docs/references/detectors.md:137-138` (stub),
     `docs/references/readonly-path.md:3-4` (opening paragraph)
   - Note: the moved entry has two live reproductions (2026-09-26 `writable`,
     2026-09-27 `partial=1`). Neither "what is here" list named them, although
     the git-lock and config-lock stubs and `lock-detectors.md`'s intro name
     theirs.
   - **Status**: FIXED. "live reproductions" added to both lists. These are new
     sentences, not moved text.

3. **tmpdir-unset matcher cites readonly-path's prefix definition, which no
   longer lives in detectors.md**
   - Location: `docs/references/detectors.md:145`
   - Note: "a tool's own prefix (as `readonly-path`)" points the reader at a
     definition that is now in a different file, and the stub only paraphrases
     it.
   - **Status**: FIXED. The name is now a link to
     `readonly-path.md#readonly-path` and the paragraph is reflowed. No wording
     changed.

4. **`hooks/annotate.sh` flag-policy comment cites only detectors.md, although
   it covers readonly-path**
   - Location: `hooks/annotate.sh:90-92`
   - Note: the item report puts this line among the "citations of other
     detectors". The comment names readonly-path's flag policy, which now lives
     in `readonly-path.md`.
   - **Status**: FIXED. The comment now reads "The candidate flag policies in
     detectors.md and readonly-path.md (FR-5): …".

5. **`tests/corpus-eval.py` prefilter comment cites only detectors.md for the
   candidates' discriminators**
   - Location: `tests/corpus-eval.py:49-51`
   - Note: `PREFILTER_SUBSTRINGS` carries readonly-path's EROFS and EBUSY
     strings, and readonly-path's discriminator is now in `readonly-path.md`.
     This file was not on the item's list.
   - **Status**: FIXED. The comment now names both nodes.

6. **`tests/extract-fixtures.py` candidates-block header cites only
   detectors.md**
   - Location: `tests/extract-fixtures.py:82-84`
   - Note: the "candidates shipping under D-15" block runs through every
     `fire-readonly-path-*` entry and `quiet-readonly-path-index-line`, with no
     intervening header, so its "discriminator in detectors.md" covers
     readonly-path. The item report also lists this line among the "other
     detectors".
   - **Status**: FIXED. The header now names `readonly-path.md` for
     readonly-path.

## Fixes Applied

- `docs/references/hook.md:7` — added the comma between the first two node
  links.
- `docs/references/detectors.md:137-138` — the stub list now includes "live
  reproductions".
- `docs/references/detectors.md:145-151` — linked `readonly-path` to the new
  node and reflowed the paragraph.
- `docs/references/readonly-path.md:3-9` — the intro list now includes "live
  reproductions" (reflowed by `just format-docs`).
- `hooks/annotate.sh:90-93` — the flag-policy comment cites both nodes.
- `tests/corpus-eval.py:49-51` — the prefilter comment cites both nodes.
- `tests/extract-fixtures.py:82-84` — the candidates-block header cites
  `readonly-path.md` for readonly-path.

`just format-docs` was re-run until it was idempotent. `just precommit` exited
0: `precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests`
(bats: 251 passed, 0 failed). Line counts: `detectors.md` 271,
`readonly-path.md` 148, `hook.md` 67.

## Citation sweep classification

`rg -n 'detectors\.md' .`, excluding `plans/` and `memory/`. Hits not covered
above:

- Repointed by the item and verified correct: every hit in `lib/matchers.sh`,
  `lib/probes-readonly*.sh`, `lib/verdicts.sh:8-11, 147, 224`,
  `tests/verdicts.bats:101-141`, `tests/verdicts-readonly.bats`,
  `tests/probes-readonly-facts.bats`, `tests/helpers/verdicts.bash` and
  `tests/extract-fixtures.py:130`.
- Correctly left on detectors.md, because the content cited is still there:
  - `lib/verdicts.sh:242` (tmpdir-unset, resume-lost and seccomp-init verdicts)
  - `hooks/annotate.sh:84` (phantom-chardev)
  - `tests/verdicts.bats:45-46` (phantom verdicts), `:77-78` (the other three
    candidates) and `:157` (phantom-chardev)
  - `tests/matchers.bats:46` (the other three candidates; readonly-path has its
    own comment below it)
  - `tests/hook.bats:248` (Conventions)
- Catalogue-level, and still correct through the stub:
  - `docs/design.md:12, 116, 142, 215`
  - `README.md:54`

  These name detectors.md as the per-detector catalogue, as they did after the
  lock-detectors split left them untouched. The catalogue still lists all ten
  detectors, readonly-path among them as a stub, so every reader is routed
  correctly. `docs/design.md` is at 395 lines, and Item 4.2 owns its rewrites.
- `docs/changelog.md` — historical entries. Left alone.
- `skills/` — no citation of detectors.md or of the readonly-path entry.

## Requirements Validation

| Requirement | Status | Evidence |
|---|---|---|
| NFR-5 / line cap (FR-11 gate) | Satisfied | `detectors.md` 399 → 271; new node 148; line-limits check passes |
| Moved text unchanged | Satisfied | section diff against `a7ff5e5` empty bar the trailing blank line |
| Stub shaped like the lock stubs | Satisfied | "Replaces …", one-sentence gist, "Matcher, probe, … :" link line |
| "Read before" sentences name the new node | Satisfied | `detectors.md:6-9`, `hook.md:7-8` |
| Prose citations repointed | Satisfied (after fixes 4-6) | sweep above |
| Links and anchors resolve | Satisfied | `scripts/check-links.sh` inside precommit |

**Gaps:** none.

## Positive Observations

- The moved body was carried over intact, including the heading promotion that
  the `#readonly-path` anchor needs.
- `lib/verdicts.sh`'s header extends the existing lock-detectors exception
  instead of adding a second sentence form.
- `lib/matchers.sh` updates the heading level in its pointer (`## readonly-path`)
  as well as the file name.

## Recommendations

None for Phase 1. Items 3.1, 3.2 and 4.2 edit `readonly-path.md` next. At 148
lines it has room for them.
