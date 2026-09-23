# Item 1.3 review — `tests/docs.bats` self-quiet guard

Scope: `tests/docs.bats` (new) and the FR-11 paragraph of `docs/design.md`, as
committed in the Item 1.3 commit. Fixes are applied and left uncommitted.

## Verdict

The item meets its contract, with one major fix applied. The sweep covers every
tracked regular file from the repo root, NUL-delimited. It skips gitlinks and
symlinks by index mode, and `tests/fixtures/` and the three exemptions by exact
path. The exemption list is one bash array. The failure message lists each
firing file with its verdicts. FR-11 now lists the exemptions by path in place
of the "dated pilot evidence" wording, and the status reads Done, which matches
the legend: a test re-checks it on every commit.

## Findings

### Major — matcher failure mid-sweep read as quiet (fixed)

`verdicts=$(bash "$MATCHERS" <"$ROOT/$path" || true)` flattened every exit
status into "quiet". `detect` returns 2 when `mktemp` fails. On this box `/tmp`
is a tight shared tmpfs, so that failure is plausible. Any file checked after
`$TMPDIR` filled would pass silently. The executor's up-front positive control
(each exempt file must still fire) only catches a failure that already exists
when the case starts, not one that begins mid-sweep.

Fix: capture the status, and record any status above 1 in the failure list as
`<path>: matchers exited <n>`. The header now reads "files firing a detector or
failing the matchers". Red proven in a scratch clone: a mutated `detect`
returned 2 for one tracked file (`justfile`). The old suite stayed green under
that mutation. The fixed suite failed and named `justfile: matchers exited 2`.
Restoring the matchers turned it green again.

### Minor — FR-11 said "every other tracked file" (fixed)

The sweep skips gitlinks and symlinks, so the pin line now says "every other
tracked regular file". The line stays under 80 columns and `rumdl` is clean.

### Checked and sound, no change

- **Positive control.** It is a real improvement over the letter of the item. It
  turns red if `MATCHERS` breaks (the executor's check, and it follows from the
  code).
- **Git-lock fault red.** Done in a scratch clone (reason below). A git-lock
  diagnostic was built from two fragments at run time and appended to
  `docs/changelog.md`. `lib/matchers.sh` printed `git-lock` on the file before
  the run. The case went red naming `docs/changelog.md: git-lock`.
  `git checkout -- docs/changelog.md` restored green. Repeated against the fixed
  suite with the same result.
- **Whitespace.** The clone sat under a directory with a space in its name
  (`…/has space/repo`), so `ROOT` contained a space. A staged firing file named
  with both a space and a tab was reported as `docs/a b<TAB>tab.md: git-lock`.
  `${meta#*$'\t'}` strips only up to the first tab, which is git's separator.
- **Symlink skip.** A staged symlink pointing at a firing fixture left the case
  green.
- **Gitlink skip.** `memory` is the repo's only gitlink (mode 160000) and is
  skipped. Without the skip, the read would fail on a directory and count as
  quiet, so removing the skip would not produce a false pass on real files.
- **Non-vacuity guards.** `[ -s "$index" ]` and `[ "$checked" -gt 0 ]` catch an
  empty listing.
- **NFR-2.** The file loads `helpers/bsd-stubs` and uses no bash-4 syntax:
  `read -d ''`, `${var//…}` and `$'…'` all exist in bash 3.2.

## Verification

- `just precommit` (venv on PATH):
  `precommit passed: plugin.json, shellcheck, bash -n, rumdl, tests`, 27 bats
  cases passed, both before and after the fixes.
- All fault injections ran in a clone under
  `/tmp/claude/item-1-3-review/has space/`. The clone was removed afterwards, so
  no fault is left anywhere.

## Notes for the lead

- **Concurrent session in the tree.** During the review,
  `docs/references/detectors.md` was modified and
  `tests/fixtures/payload-{post,failure}.json` were untracked. That is Item 1.4
  work I did not touch. For that reason the red was re-proven in a clone instead
  of in the live tree, so a concurrent `just precommit` would not pick up the
  injected fault.
- **Probe slip, repaired.** My first injection targeted `README.md`, which is
  not tracked, so the append created a new untracked 118-byte file holding only
  the injected text. I checked its contents and deleted it. It was never
  committed and never inside the sweep.
- **Out of scope, not fixed (`lib/matchers.sh`, Item 1.1).** `detect` does not
  check `cat >"$buf"`. If the disk fills mid-write, the matchers read a
  truncated buffer and report quiet with status 1, which the new status check
  cannot see.
