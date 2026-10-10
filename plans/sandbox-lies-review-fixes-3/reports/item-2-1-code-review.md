# Code review — Items 2.1 + 3.1 (GREEN commit HEAD)

Mode: code review + mutation testing. Scope IN: `git show HEAD -- lib docs`
(`probe_readonly_path`, `_probe_readonly_resolve`, `lib/verdicts.sh` lines 16
and 22, the `detectors.md` phantom paragraph). Nothing committed. No `# MUT`
text remains; `git diff --stat -- lib docs tests` is empty.

Assessment: Ready. No defects found, no edits made. One surviving mutation.

## Review against §B and §C

- Matching line alone: `line` is captured once from `_readonly_path_line`, both
  the path extraction and the partial-checkout gate read it, never `text`.
- Nearest `.git` ancestor, file or directory: `_readonly_git_dir` tests
  `[ -e "$dir/.git" ]`; linked worktree case is test 3.
- No `.git` ancestor: `|| base="$cwd"` keeps today's join. Empty `cwd` leaves
  `base` empty, so `_probe_readonly_resolve` joins onto the probe's `$PWD`, as
  before; the walk is not attempted from `$PWD` (hook always sends a `cwd`;
  noted, not a defect).
- `set -e`: `line=$(...) || line=` and `base=$(...) || base=` are guarded; the
  `if` condition is exempt. Under `bash -c 'set -e; ...'` the real code prints
  `nopath` and exits 0.
- Whitespace: all expansions quoted, `_readonly_git_dir` is quote-safe, no word
  splitting. One matching line holds no newline. No bash 4 features; no GNU-only
  flags added (BSD stubs case passes).
- Comments: the `_probe_readonly_resolve` header no longer claims a walk or
  refusal to walk; `rg` finds no other "never walks" text in lib, hooks, skills
  or docs. `lib/matchers.sh:93,99` "project root" is about corpus provenance,
  unrelated. `docs/references/hook.md` "names the project root, the usual case"
  is Item 7.x (OUT).
- §C: both verdict sentences and the `detectors.md` chardev paragraph agree;
  the untracked paragraph in `detectors.md` inherits by reference.

## Mutation proof

Each mutation by exact replacement of a once-occurring string, landed shown with
`command grep -c`, restored by swapping (two restores needed a longer context
string because the new text occurred twice; same method), restore shown by
`command grep -c` of the mutation text returning 0 and an empty
`git diff --stat -- lib`.

| # | File | Old | New | Suite | Result |
| --- | --- | --- | --- | --- | --- |
| 1 | `lib/probes-readonly.sh` | `base=$(_readonly_git_dir "$cwd") \|\| base="$cwd"` | `base="$cwd"` | resolve | RED: cases 1, 2, 3, 4 |
| 2 | same | `if _readonly_partial_checkout_text "$line"; then` | same with `"$text"` | resolve | RED: case 6 |
| 3 | same | same | `if true; then` | resolve | RED: cases 5, 6 |
| 4 | same | `\|\| base="$cwd"` | `\|\| base="${cwd%/*}"` | resolve | RED: case 7 |
| 5 | same | `_readonly_path_line) \|\| line=` | `_readonly_path_line)` | resolve, probes-readonly, probes-readonly-facts | SURVIVED (7, 17, 15 passed) |
| 6 | same | `path=$(printf '%s\n' "$line" \|` | same with `"$text"` | resolve, probes-readonly | RED: resolve case 6, probes-readonly "quoted path off the matching line is ignored" |
| 7 | `lib/verdicts.sh` | `The character-device entries in this listing are sandbox masks, not` | `... masks over dotfiles in the project root, not` | verdicts | RED: case 3 |
| 8 | same | `The dotfile entries in this listing are sandbox masks, not` | `... masks over dotfiles in the project root, not` | verdicts | RED: cases 3, 4 |

## Survivors

1. The `|| line=` guard in `probe_readonly_path`.
   - File: `lib/probes-readonly.sh`
   - Old string: `_readonly_path_line) || line=`
   - New string: `_readonly_path_line)`
   - Behaviour changed: grep's status 1 on a text with no matching line becomes
     the assignment's status, so a caller running the probe under `set -e`
     aborts silently (verified by hand: `bash -c 'set -e; source lib/probes.sh;
     printf "plain\n" | probe_readonly_path false /tmp x'` exits 1 with no
     output, against `nopath` and exit 0 with the guard). No test runs the probe
     under errexit: bats `run` does not carry `set -e` into the function, and no
     file in `tests/` sets it for the probes.
   - Suggested test shape: in `tests/probes-readonly-resolve.bats` (loads
     `helpers/bsd-stubs`, so it covers BSD tools), `run bash -c 'set -e; source
     "$1"; printf "%s\n" "$2" | probe_readonly_path false "$3" x' _
     "$ROOT/lib/probes.sh" "plain text, no refusal" "$BATS_TEST_TMPDIR"`;
     assert status 0 and first output line `nopath`. Red on the mutation by the
     status assertion (exit 1, empty output). Use a clean text so the matching
     line is absent; keep `$BATS_TEST_TMPDIR` as cwd.

## Fixes applied

None.
