# Item 2.1 slice 3: code review

Scope: the slice-3 change to `scripts/check-line-limits.sh` in `Item 2.1/3`.
It adds the `skills/*.md` → 400 arm, a `*/*) ;;` skip arm and the root `*.md`
→ 400 arm, and it rewrites the header Scope comment. I read it against Item
2.1's runbook text and slice list (slice 4 adds `*.sh`/`*.bash`/`*.bats`/`*.py`
outside `plans/` and `plugin-dev/`), the recall-artifact memories,
`shell-gotchas`, the slice-3 RED, test-review and GREEN reports, and the slice 1
and 2 code reviews. Slices 4–7 and the precommit wiring are out of scope. The
test file is out of scope too, and its gaps are only reported below.

## Findings

1. **The `*/*) ;;` skip made every later arm order-dependent, and it failed
   silently (major).** The arm swallows *any* path that contains a `/`, not
   only markdown. An arm placed after it can therefore match root-level files
   only. I probed the case semantics directly: with `*/*) ;;` ahead of
   `*.sh) check_cap`, `lib/x.sh` is skipped and a root `x.sh` is capped.
   Slice 4's planned `lib/x.sh` test would catch a misplaced `*.sh` arm, but
   only that one. Suppose an editor adds `*.sh` above the skip (as the red test
   forces) and then appends `*.bash|*.bats|*.py` below it next to `*.md`, where
   the other "cap 400" arms sit. Slice 4's suite passes, the real-tree gate
   exits 0, and `tests/*.bats` is never counted. Shellcheck does not flag this,
   because `*/*` does not fully shadow `*.py` (a root `x.py` still reaches it),
   so SC2221/SC2222 stay silent.
   **Fix:** I narrowed the skip to `*/*.md) ;;`. It now removes only non-root
   markdown, which is the one job it has, namely keeping the root `*.md` arm
   from crossing `/`. An arm for another file type now behaves the same in any
   position. The only order constraints left are inside the markdown group
   (SKILL.md before `skills/*.md`, the skip before the root arm), and each is
   commented next to its arm. The probe on the new form caps `lib/x.sh` and
   `x.sh` and still skips `plans/x.md` and `notes/d.md`. I considered the
   alternatives. A nested `case` inside a root `*.md` arm costs more lines to
   do the same thing. Matching "no `/`" directly is not possible in a plain
   `case` glob, and extglob is not worth it here. Markdown behaviour is
   unchanged: all six tests pass.
2. **The skip arm's comment was inaccurate (minor).** "tracked or not" is
   wrong, because the loop reads `git ls-files -z`, so an untracked path never
   reaches the `case`. "(docs/skills/ already matched above …)" reads as a
   path `docs/skills/`, not as "docs/ and skills/". **Fix:** I rewrote the
   comment. It now says what the arm excludes (markdown under any other
   directory, with `lib/` and `.claude/skills/` as examples), why it exists
   (a `case` `*` crosses `/`, so the root arm alone would match nested
   markdown), and why it names `.md` (finding 1).
3. **The header Scope comment was imprecise (minor).** The parenthetical
   "(a `case` `*` crosses `/`)" had drifted to the end of the list, so it now
   seemed to explain root-level markdown instead of depth. "A SKILL.md at any
   depth under root-level skills/" also covered a bare `skills/SKILL.md`,
   which the `skills/*/SKILL.md` arm leaves at 400 (slice 2's review:
   intentional, since it is not a skill hub). **Fix:** the comment now states
   once, up front, that paths are root-relative and that `*` crosses `/`.
   It then lists docs/ at any depth → 400, `skills/*/SKILL.md` → 200, other
   `skills/` markdown → 400, and root (no `/`) → 400.

### Checked and sound

- **Arm order inside the markdown group.** `skills/*/SKILL.md` stays above
  `skills/*.md`, and its comment says why. Reversing them trips SC2221 in
  precommit and reddens `SKILL.md capped at 200`. `docs/*.md` and the
  `skills/` arms have disjoint prefixes.
- **Anchoring.** Paths from `git ls-files` are root-relative with no `./`, so
  `skills/…` cannot match `.claude/skills/…` or `plugin-dev/…/skills/…`.
  A root dotfile such as `.x.md` reaches the root arm, because a `case` `*`
  matches a leading dot. That is correct, since it is root markdown.
- **Whitespace, bash 3.2, BSD.** The `case` word is `"$file"`, read
  NUL-delimited. The patterns are intentionally unquoted globs. Comment lines
  between `case` items are POSIX grammar and are accepted by bash 3.2. The
  slice adds no new tools. Shellcheck is clean.
- **Real tree.** The only tracked root markdown is `BRIEF.md` and `CLAUDE.md`,
  both under 400. `scripts/check-line-limits.sh .` exits 0.

### Observation (not fixed; slice 4's concern)

- With the skip narrowed, slice 4's `plans/*|plugin-dev/*) ;;` exclusion still
  has to come *above* its script arm. That ordering is inherent to the "outside
  X" scope, and shellcheck will not flag it either. The slice's `plans/ is out
  of scope` test uses a 401-line `plans/x.md`, which the markdown skip already
  covers. So the test does not pin the exclusion for scripts (see test gaps).

## Mutant run (once)

This is an exact replacement that deletes the line `    */*.md) ;;`, so the
root `*.md` arm crosses `/`. I then ran `scripts/run-bats.sh
tests/check-line-limits.bats`. **The tests went red:** test 5 failed on its
exact-output assertion (line 109, `notes/deep.md` also flagged) and test 6
failed on `[ "$status" -eq 0 ]` (line 130). I restored the file by inverting
the edit, which reinserts the line before the root arm. Proof of the restore:
`cmp` against a copy taken before the mutation found no difference, and
`grep -c -F '    */*.md) ;;'` returns 1. The narrowed arm is load-bearing and
the suite pins it.

## Test gaps (report only; test file out of scope)

- **Nothing pins markdown directly under `skills/`.** Every skills fixture sits
  in a subdirectory, so a mis-narrowed `skills/*/*.md` arm passes the suite and
  leaves a `skills/README.md` uncapped. The fix is one more 401-line
  `skills/top.md` in `oversized skills node is reported`, with its expected
  line first (`skills/top.md` sorts before `skills/x/`).
- **For slice 4:** a single `lib/x.sh` fixture pins `*.sh` only. To pin every
  script type regardless of arm layout, the fixture should hold one 401-line
  file of each type (`.sh`, `.bash`, `.bats`, `.py`) in a subdirectory. The
  `plans/` and `plugin-dev/` exclusions need a *script* there too (e.g.
  `plans/x.sh`, `plugin-dev/x.sh`), not only `plans/x.md`, which the markdown
  skip already covers.

## Verification

- `scripts/run-bats.sh tests/` (foreground): `bats: 33 passed, 0 failed`.
- `direnv exec . just precommit` (foreground): `precommit passed:
  plugin.json, shellcheck, bash -n, rumdl, tests`.
- `scripts/check-line-limits.sh .` on the real tree: exit 0, no output.

## Files changed

- `scripts/check-line-limits.sh` (the skip arm narrowed to `*/*.md`, and the
  arm comment and header Scope comment rewritten). Nothing is committed.

## Refactor flag

None.
