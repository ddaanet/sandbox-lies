# Item 2.2 slice 2 — code review

Scope: `git show HEAD -- scripts/check-links.sh` (the switch to
`markdown_in_scope`, the header), and `scripts/lib/tracked.sh` read whole,
since it has had no code review of its own. The review also covered the
`source` line both gate scripts share. Nothing is committed.

## Verdict

The slice's own change is correct. `handle_file` uses the `if` form, the
header now points at the shared scope, and every test passes. The helper had
one dead arm with a wrong comment and contract gaps. Four defects surfaced
around it: a shellcheck directive that passed only from the repo root, a
bare-name invocation that exited 1, a missing helper that exited 1, and
duplicated reports mid-merge. All of them are fixed. One contract question is
left open (finding 8).

## Findings

1. **Minor — dead `plans/* | plugin-dev/*` arm in `markdown_in_scope`, with
   the wrong reason. Deleted.** For markdown, the anchored `docs/` and
   `skills/` arms and the `*/*.md) return 1` skip already send `plans/x.md`
   and `plugin-dev/x.md` to false. For anything else, `*) return 1` does. So
   the arm is dead for every input. Its comment said an unanchored `*.md`
   would match `plans/x.md`, which misses that `*/*.md` comes first. I chose
   to delete it rather than keep it as a guard because the predicate is an
   allowlist. A denylist arm inside it suggests the allowlist needs help,
   and it does not. The contract comment now says so: false for markdown in
   any other directory, those two included. It also keeps the one real
   ordering constraint, `*/*.md` before `*.md`.
   `check-line-limits.sh` keeps its own `plans/* | plugin-dev/*) ;;` arm,
   which scripts need. I reworded its comment. The old "needs no help from
   `markdown_in_scope`, which excludes them itself" read as if the
   predicate had an exclusion arm. The new wording says the arm must come
   before the script arm, and that markdown there is already outside
   `markdown_in_scope`.
2. **Minor — `# shellcheck source=scripts/lib/tracked.sh` resolves against
   shellcheck's CWD. Fixed.** Run from `scripts/` or from `/tmp`, with all
   three files as input, shellcheck printed SC1091 "Not following" on both
   scripts and exited 1. Precommit passed only because `just` runs from the
   repo root. Now both scripts use `# shellcheck source-path=SCRIPTDIR
   source=lib/tracked.sh`. With the helper as input and with `-x`,
   shellcheck exits 0 from the repo root, from `scripts/` and from `/tmp`.
   To confirm the directive really is followed, I pointed it at a missing
   file, and SC1091 came back. Residual: `shellcheck scripts/check-links.sh`
   alone, without `-x`, still prints SC1091 info and exits 1, from any CWD.
   That is shellcheck's default `external-sources=false`, not the path. A
   single-file shellcheck-on-edit hook would hit it (see the refactor flag).
3. **Minor — a bare-name invocation exited 1. Fixed.** `bash check-links.sh`
   from `scripts/` sets `BASH_SOURCE[0]` to `check-links.sh`, and `%/*`
   leaves a slash-less value whole. The script then sourced
   `check-links.sh/lib/tracked.sh`, and both scripts exited 1 with "Not a
   directory". That exit status reads as a broken link or an overage. Both
   scripts now pick the directory in a `case` with a slash-less arm. This
   follows the file's own parameter-expansion idiom, not `$(dirname …)`.
   After the fix, `bash check-links.sh <root>` from `scripts/` reports the
   fixture's broken link and exits 1.
4. **Minor — a failed `source` exited 1. Fixed.** In bash mode, `source` of
   a missing file returns 1 and `set -e` exits with that status, which
   collides with the gate's "found something" code. Both scripts now use
   `source … || exit 2`. With a copy of the script run where no `lib/`
   exists, it printed "No such file or directory" and exited 2.
5. **Minor — mid-merge, the walk listed an unmerged path three times.
   Fixed.** `git ls-files` lists an unmerged path once per stage. In a fixture
   with a real content conflict in `docs/a.md` (git 2.47.3), the file was
   walked three times. `check-links.sh` printed 9 lines for 3 links. The
   exit status was right, but the report was noise. `walk_tracked_files` now
   skips a path equal to the previous one; the stages come out one after
   another because `ls-files` sorts by path. The same fixture now prints 3
   lines. I did not use `--deduplicate`: git before 2.31 refuses it, and
   that would turn a cosmetic problem into exit 2 on older Xcode git.
6. **Minor — the helper's contract comments were incomplete. Fixed.**
   - `walk_tracked_files` did not say that its handler must return 0. The
     handler runs under the caller's `set -e`, so a non-zero return ends
     the run with that status. That is the W10 trap the slice's GREEN
     avoided, and it was documented only at the call site. It is now in the
     `$3` contract.
   - The helper did not say that its `EXIT` trap replaces any trap the
     caller set, or which failures exit 2 (`mktemp`, `git ls-files`). Both
     are now stated.
   - `parse_root`'s "$2, $3: the caller's own "$@"" read as a fixed pair. It
     now reads "$2…: the caller's own "$@", at most ROOT; more exits 2".
7. **Nit — the skip comment gave the wrong reason for symlinks. Fixed.** It
   said reading "either" of three kinds of path would fail. Reading a
   symlink to a regular file succeeds. The real reason is that its target,
   if tracked, is walked on its own. The comment now separates the two
   reasons. Also, `echo "$prog: …"` became `printf '%s: …\n'`, like the
   helper's other diagnostics.
8. **Minor, open (contract question, not applied) — an empty ROOT is taken
   as `.`.** `check-links.sh ""` (for example from an unset `$DIR`) gives
   `${2:-.}` = `.`. `git -C ""` would also mean the current directory. This
   is the "a tree the caller did not ask for" case that `parse_root`'s own
   comment rejects for a second argument. The runbook contract says only
   "default `.`", so exit 2 on an explicit empty ROOT would change the
   external contract. **Default:** add it as an edge input in slice 5, with
   a test, if the orchestrator agrees. Otherwise leave it as is.
9. **Nit — `check-links.sh` `handle_file` comment was imprecise. Fixed.** It
   said "walk_tracked_files's caller runs under errexit". What aborts is the
   helper's call of the handler. It now reads "walk_tracked_files calls its
   handler under `set -e`, so the run would end 1 at the first one".

## Checked and sound (no change)

- **SC2317 scoping.** I deleted every `disable=SC2317` line in a scratch
  copy and reran shellcheck. It flagged exactly `check_links_in` and
  `handle_file` in `check-links.sh`, and `check_cap` and `handle_file` in
  `check-line-limits.sh`. It flagged nothing in `tracked.sh`. Each directive
  sits on the function definition, so its scope is that function. None is
  redundant and none is missing. Each reason is a second comment, as
  shellcheck requires.
- **errexit through the indirection.** `markdown_in_scope` runs only as an
  `if` condition. Both `handle_file`s end in `if`/`case` forms that return 0
  when nothing fires. `check_links_in`'s loop ends in `[ … ] || continue` or
  an else-less `if`, and both return 0. `check_cap` ends in an else-less
  `if`. A deliberate `exit 2` inside a handler still runs the `EXIT` trap.
- **bash 3.2 / BSD.** The code uses `read -r -d ''`, `<<<`, multi-name
  `local`, `${BASH_SOURCE[0]}`, `case` and `[ ]`, all bash 3.2. The helper
  uses no GNU-only flag. `mktemp` has an explicit template, and `git -C`
  and `ls-files -z` are old.
- **Whitespace.** The walk is NUL-delimited with `IFS= read -r`, and every
  expansion is quoted. `case` matches its word literally, so glob
  characters in a path are inert. `$root/$file` stops a leading `-` from
  reaching `[`.

## Mutation run (one, in place)

Mutation, in `walk_tracked_files`: `if [ -L "$root/$file" ] || [ ! -f
"$root/$file" ]; then` → `if [ ! -f "$root/$file" ]; then`. The change was
an exact-string replacement asserted at count 1, then inverted the same way.
Then `scripts/run-bats.sh tests/check-links.bats tests/check-line-limits.bats`,
foreground: **`bats: 20 passed, 0 failed`. The mutant survived, so no test
redded.** `git diff --quiet scripts/` after the restore exited 0. That was
before any fix was applied.

## Test gaps (tests out of scope; reported, not written)

- **Tracked symlink skip — unpinned in both suites** (mutation above). A
  tracked symlink to an oversized file, or to a file with a broken link,
  would expose it. The fixture needs a target the walk does not also reach
  on its own, such as a target outside the tree, or an untracked one.
- **Bare-name invocation and a missing helper** (findings 3 and 4). `cd
  "$REPO/scripts" && bash check-links.sh "$root"` should give the same
  stdout and status. A copy of the script without `lib/` beside it should
  exit 2 with empty stdout.
- **Mid-merge dedup** (finding 5). A fixture with a real content conflict in
  `docs/a.md` holding one broken link should print exactly one line. The
  conflict needs two branches committing different contents, then `git
  merge`.
- **Empty ROOT** (finding 8), if it is adopted.

## Refactor flag

None needing a module split. Two observations, not refactors:

- The 7-line helper-locating block is now identical in both gate scripts.
  It cannot move into the helper, because it is how the helper is found. A
  third gate script would copy it as well.
- A repo `.shellcheckrc` with `external-sources=true` would make a
  single-file shellcheck, such as an on-edit hook, follow the helper. That
  is a new config file, so I did not add it.

## Checks run (after fixes, foreground)

- `scripts/run-bats.sh tests/`: `bats: 47 passed, 0 failed`.
- `direnv exec . just precommit`: `precommit passed: plugin.json,
  shellcheck, bash -n, rumdl, line limits, tests`, exit 0.
- `scripts/check-links.sh`: exit 0, no output.
- `scripts/check-line-limits.sh`: exit 0, no output.
- `shellcheck` on the three scripts from the repo root, `scripts/` and
  `/tmp`, with the helper as input and with `-x`: exit 0 each time.

## Files changed

- `scripts/lib/tracked.sh`: dead arm and its comment removed, contract
  comments completed, mid-merge dedup, symlink-skip comment, `printf`.
- `scripts/check-links.sh`: helper-locating block and shellcheck directive,
  `handle_file` comment.
- `scripts/check-line-limits.sh`: helper-locating block and shellcheck
  directive, `handle_file` comment.
