# Item 2.2 slice 2 — RED

SUT: `scripts/check-links.sh` still scans only `docs/*.md` (slice 1's
scope); `scripts/lib/tracked.sh`'s `markdown_in_scope` (shared with Item
2.1, not yet called by `check-links.sh`) already has the full scope table.

Suite: `tests/check-links.bats`, two new tests appended after slice 1's,
each fixture root a `git init` temp repo under `$BATS_TEST_TMPDIR` with its
files `git add`ed.

Fixture discrimination:

- `broken links in scope are reported`: one broken link each in `README.md`
  (root), `docs/a.md`, `skills/x/SKILL.md` and `skills/x/references/n.md` —
  one file per scope arm (root, `docs/`, `skills/` itself, `skills/` nested
  deeper). All four share the same `missing.md` target, resolved relative to
  each file's own directory, so a correct implementation reports all four
  and an implementation still scoped to `docs/*.md` reports only one.
- `markdown out of scope is ignored`: broken links in `plans/x.md`,
  `plugin-dev/x.md`, `lib/x.md`, `.claude/skills/y/SKILL.md` (skills/
  nested under a dot-directory, not at the root — mirrors Item 2.1's
  `markdown elsewhere is out of scope`), and an **untracked** `docs/u.md`.
  None of these match `docs/*.md`, and the untracked file is never in `git
  ls-files`, so the current SUT already reports none of them — this test
  is expected to pass now and is pinned by mutation instead of a genuine
  red.

## Run

`scripts/run-bats.sh tests/check-links.bats`, foreground:

```
not ok 3 broken links in scope are reported
# (in test file tests/check-links.bats, line 92)
#   `[ "$output" = "broken-link: README.md -> missing.md' failed

bats: 3 passed, 1 failed
```

`resolving link passes`, `broken link is reported` (slice 1) and `markdown
out of scope is ignored` pass; `broken links in scope are reported` fails
its exact-stdout assertion — the current handler emits nothing for
`README.md`, `skills/x/SKILL.md` or `skills/x/references/n.md`, so `$output`
holds at most the `docs/a.md` line, not all four.

## Mutation proof

`markdown out of scope is ignored` passes against the unmodified SUT, so it
is pinned by mutation instead — one mutation per behaviour it protects, each
reverted immediately after observing the expected failure.

1. **Scope widened to every tracked markdown** — `scripts/check-links.sh`,
   `handle_file`: `docs/*.md)` → `*.md)`. Reran the suite:
   `markdown out of scope is ignored` failed (`status` 1, not 0 — the
   `plans/`, `plugin-dev/`, `lib/` and `.claude/skills/` links all get
   checked and reported broken), `broken links in scope are reported` now
   passed (the widened case also covers the three previously-missed files).
   Reverted the one-line change; `git diff --quiet scripts/check-links.sh`
   confirmed restoration.
2. **Untracked files let into the walk** — `scripts/lib/tracked.sh`,
   `walk_tracked_files`: `git ls-files -z` → `git ls-files -z --cached
   --others --exclude-standard`. Reran the suite: `markdown out of scope is
   ignored` failed (`status` 1 — untracked `docs/u.md` is now walked and
   reported, on top of the already-broadened case from mutation 1 having
   been reverted first so this run isolates the untracked behaviour;
   `broken links in scope are reported` still failed, unaffected by this
   mutation). Reverted the one-line change; `git diff --quiet
   scripts/lib/tracked.sh` confirmed restoration.

Final state: `git diff --quiet scripts/` — clean, `scripts/` byte-identical
to HEAD.

## Checks run

- `git diff --quiet scripts/` after both mutations reverted — clean.
- `scripts/run-bats.sh tests/check-links.bats` — 3 passed, 1 failed (the
  genuine red), final state above.

## Left in the tree (uncommitted, per dispatch)

- `tests/check-links.bats` (this slice's two tests, appended after slice 1's)
- this report
- `scripts/` unchanged from HEAD
