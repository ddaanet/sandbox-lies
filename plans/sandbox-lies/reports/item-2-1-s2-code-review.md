# Item 2.1 slice 2: code review

Scope: the slice-2 change to `scripts/check-line-limits.sh` in
`Item 2.1/2`. That change is one `skills/*/SKILL.md) check_cap "$file" 200`
case arm and the header Scope comment. I judged it against Item 2.1's final
scope as the runbook states it and against NFR-5 in `docs/design.md`. I also
compared it with the port source (edify `scripts/check_line_limits.sh`), the
recall-artifact memories and `shell-gotchas`. The later-slice scope is out
(other `skills/` markdown, root markdown, scripts, `plans/` and `plugin-dev/`
exclusions, precommit wiring). The test file is out of scope too, and its gap
is only reported below.

## Findings

1. **The header comment was narrower than the pattern (minor).** It read
   "each skill's SKILL.md, cap 200". A `case` `*` crosses `/`, so
   `skills/*/SKILL.md` also caps a nested `skills/a/b/SKILL.md`, which is not
   a skill hub. That breadth is harmless and matches the port. The port caps
   by `basename = SKILL.md` anywhere in its markdown scope, so matching at any
   depth is the ported semantics and not an accident. The comment should say
   so, rather than imply the pattern stops at one level. **Fix:** the comment
   now reads "a SKILL.md at any depth under skills/, cap 200 (a `case` `*`
   crosses `/`)". The code is unchanged.

### Checked and sound

- **The pattern fits the repo layout.** The plugin's one skill is
  `skills/sandbox-lies/SKILL.md` (design.md; runbook Item 7.1), and its nodes
  live under `skills/sandbox-lies/references/`. A `case` pattern matches the
  whole path, so the arm is anchored at `skills/`. Because of that,
  `plugin-dev/…/SKILL.md`, `.claude/skills/…/SKILL.md` and `plans/…` do not
  match. `git ls-files -z` emits paths relative to ROOT with no `./`, so the
  anchor holds. A bare `skills/SKILL.md` does not match. It falls through, to
  the later 400 arm once that exists. It is not a skill that Claude Code
  loads, so the 200 cap has no reason to apply to it. The match is
  case-sensitive, and that is correct because Claude Code requires the exact
  name `SKILL.md`. Nothing is tracked under `skills/` yet, and the gate exits
  0 on the real tree.
- **Arm order leaves room for the later `skills/*.md` → 400 arm.** The
  SKILL.md arm comes last, so appending the broader arm after it shadows
  nothing, because `case` takes the first match. Inserting the broader arm
  *above* it, for example to group the 400-cap arms, would shadow it. Two
  things already catch that. First, `SKILL.md capped at 200` goes red on
  status (the test review's probe C). Second, shellcheck SC2221/SC2222 flags
  the shadowed arm, and precommit runs shellcheck. I added no order comment:
  it would presuppose the later slice's arm, and two gates already enforce the
  order.
- **The cap and comparison** go through the shared `check_cap` with `-gt`,
  so 200 lines passes and 201 fails. NFR-5's "under 200" reads that way
  throughout: slice 1 already treats 400 as clean under "under 400", and the
  Interfaces `> <cap>` format agrees.
- **Other checks.** The SKILL.md arm cannot shadow the existing `docs/*.md`
  arm, or be shadowed by it, because their prefixes are disjoint. The arm
  adds no new tools, expansions or bash-3.2 concerns. Default shellcheck is
  clean.

### Observation (not fixed; outside the item's stated scope)

- The port also caps a `SKILL.md` under `docs/` at 200. Here the `docs/*.md`
  arm matches first and applies 400. NFR-5's "(a `SKILL.md` under 200)" is
  worded generically. Its purpose is the hub's per-invocation cost, and
  nothing under `docs/` is loaded as a skill, so the divergence seems
  intended. It is recorded here in case it was not.

## Mutant run (once)

I made an exact replacement of `    skills/*/SKILL.md) check_cap` with
`    *SKILL.md) check_cap`, which removes the `skills/` anchor. I then ran
`scripts/run-bats.sh tests/check-line-limits.bats`.

**Result: the tests did not go red** (`bats: 3 passed, 0 failed`). I restored
the file with the inverse replacement. After the restore,
`grep -c -F '    *SKILL.md) check_cap'` returns 0,
`grep -c -F '    skills/*/SKILL.md) check_cap'` returns 1, and
`git diff --quiet` passed, so the file was byte-identical to HEAD before the
comment fix.

## Test gap (report only; test file out of scope)

- **Nothing pins the `skills/` anchor of the SKILL.md cap.** The fixture's
  only SKILL.md sits under `skills/`, so `*SKILL.md`, `*/SKILL.md` and
  `skills/*/SKILL.md` are indistinguishable. No planned slice (1–6) adds a
  SKILL.md outside `skills/`. An unanchored arm would cap vendored
  `plugin-dev/…/SKILL.md` files at 200, and `.claude/skills/…/SKILL.md` too.
  Whether that reddens precommit then depends on the plugin-dev exclusion arm
  coming first. **Suggested test:** a 201-line
  `.claude/skills/y/SKILL.md` tracked beside the existing fixture, which the
  exact single-line output then requires to stay clean. The test review's
  earlier gap still stands as well: no slice asserts that a 401-line
  non-SKILL `skills/` node is reported.

## Verification

- `scripts/run-bats.sh tests/` (foreground): `bats: 30 passed, 0 failed`.
- `direnv exec . just precommit` (foreground): `precommit passed:
  plugin.json, shellcheck, bash -n, rumdl, tests`.
- `scripts/check-line-limits.sh` on the real tree: exit 0.

## Files changed

- `scripts/check-line-limits.sh` (header comment only)

## Refactor flag

None.
