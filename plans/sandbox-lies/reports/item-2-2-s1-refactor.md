# Item 2.2 slice 1: refactor

Refactor flagged by `item-2-2-s1-code-review.md`'s "Refactor flag": the two
gate scripts duplicated the arity check, the `mktemp` walk list with its
trap and failure paths, the `git ls-files -z` spool, the NUL read loop, and
the symlink/non-regular-file skip — about 30 lines, comments included — and
`check-links.sh`'s slice 2 would have duplicated `check-line-limits.sh`'s
markdown scope table too.

## What moved

New `scripts/lib/tracked.sh`, sourced by both scripts from their own
directory (`${BASH_SOURCE[0]%/*}/lib/tracked.sh`, never an env var):

- `parse_root <prog> "$@"` — the arity check, moved as suggested by the
  flag. Sets `ROOT` directly in the caller's shell rather than through a
  command substitution: `exit 2` inside a `$(...)` only exits the subshell,
  not the calling script (the shell-gotchas exit-status-loss class), so the
  check has to set a variable, not echo one back.
- `walk_tracked_files <prog> <root> <handler>` — the mktemp/trap/`git
  ls-files -z` spool and the NUL read loop, calling `<handler>` once per
  tracked, readable, non-symlink file. The walk-list variable is
  deliberately not `local`: the `EXIT` trap that removes it fires after the
  function has returned, and a `local` would already be unbound by then
  under `set -u` — worth a comment since it looks like an oversight
  otherwise.
- `markdown_in_scope <path>` — Item 2.1's full markdown scope table (docs/
  at any depth, skills/ at any depth, root-level, excluding root-level
  plans/ and plugin-dev/), as a predicate rather than a cap-selecting
  `case`.

`check-line-limits.sh` now dispatches each walked file through `handle_file`
(script extensions and `skills/*/SKILL.md`'s 200 cap kept as explicit case
arms — the predicate carries no cap information — with everything else
falling through to `markdown_in_scope` for the shared 400 cap). Every
comment stating a residual or a reason (the unreadable-file exit-2 rationale,
the SKILL.md-before-markdown ordering, the `awk` NR vs `wc -l` note) moved
with the code it describes; the two copies of the mktemp/walk comment and
the two copies of the symlink/deleted-file comment were merged into one each
in the helper.

`check-links.sh` KEEPS its slice-1 `docs/*.md`-only scope in `handle_file`
— it does not call `markdown_in_scope` yet. That switch is slice 2's GREEN,
per the dispatch constraint. Its slice-progress header note is untouched for
the same reason.

## Shellcheck

The helper is sourced with a computed path
(`${BASH_SOURCE[0]%/*}/lib/tracked.sh`), so shellcheck needs `# shellcheck
source=` to find it. Empirically, `source=` resolves relative to
shellcheck's own working directory when the file is included in the same
invocation — not relative to the checked script's directory as the docs
implied — and `just precommit`'s `shellcheck "${files[@]}"` runs from the
repo root, so the directive reads `# shellcheck source=scripts/lib/tracked.sh`
(confirmed by reproducing precommit's exact invocation in an isolated tree).

`walk_tracked_files` calls `handle_file` indirectly through the `$handler`
variable, which shellcheck's reachability analysis cannot trace: it marked
`handle_file`, and transitively everything only `handle_file` calls
(`check_cap`, `check_links_in`), as SC2317 "unreachable". A `# shellcheck
disable=SC2317` directive placed immediately above each such function
definition suppresses it for that whole function body (verified in
isolation before applying it here) — kept as a per-function directive with
its own reason, not a blanket disable.

## Verification

- `shellcheck scripts/lib/tracked.sh scripts/check-line-limits.sh
  scripts/check-links.sh` and `bash -n` on all three: clean.
- `scripts/run-bats.sh tests/` (foreground): `bats: 45 passed, 0 failed`,
  unchanged from before the refactor.
- `direnv exec . just precommit` (foreground), after staging the new file
  (untracked files are invisible to the gates' `git ls-files` walk, so
  shellcheck's own `git ls-files`-driven file list needed the add too):
  `precommit passed: plugin.json, shellcheck, bash -n, rumdl, line limits,
  tests`, exit 0.
- `scripts/check-line-limits.sh` and `scripts/check-links.sh` on the real
  tree: both exit 0.

## Files changed

- `scripts/lib/tracked.sh` (new, 78 lines) — `markdown_in_scope`,
  `parse_root`, `walk_tracked_files`.
- `scripts/check-line-limits.sh` (71 lines, was 97) — sources the helper;
  arity check, walk, and symlink/deleted-file skip removed; cap dispatch
  moved into `handle_file`.
- `scripts/check-links.sh` (77 lines, was 100) — sources the helper; arity
  check, walk, and symlink/deleted-file skip removed; scope dispatch moved
  into `handle_file`, unchanged (`docs/*.md` only).
