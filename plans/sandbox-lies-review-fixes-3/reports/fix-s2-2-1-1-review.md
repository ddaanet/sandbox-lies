# Review of d615a24 — pin for mutant 2.1/1

Verdict: no defects. No code change.

## Mutation re-run

- Mutant: in `probe_readonly_path` (`lib/probes-readonly.sh` line 57) the walk
  call `_readonly_git_dir "$cwd"` became `_readonly_git_dir "${cwd%/*}"`, one
  occurrence, applied by exact replacement. Landed: `command grep -nF` found it.
- Result: 9 passed, 1 failed. Only `not ok 4 partial-checkout path joins onto a
  linked worktree's top when the cwd is that top` failed, on its own
  assertion `[ "$(path_line)" = "path=$wt/d/f" ]` (line 107). Every other
  case stayed green.
- Restored by the swapped replacement. `command grep -cF` of the mutant text
  prints 0, `git diff --stat -- lib` is empty, the suite is 10 passed, 0 failed.

## Hermeticity

- The file loads `helpers/git-env` (global config is a file under
  `BATS_TEST_TMPDIR`, system config off), so no host `~/.gitconfig`.
- All trees are under `$BATS_TEST_TMPDIR`. The probe reads no `~/.claude`.
- The file loads `helpers/bsd-stubs`; the BSD-tools case of the file is the
  existing one. The code under test here is the walk (shell builtins), and the
  grep/sed pipeline is covered by that case.

## Cannot pass by accident

The outer tree is a real `git init` at `main` with `main/d/f` present, so a
walk from the cwd's parent meets `main/.git` and prints `main/d/f`, which
differs from `main/wt/d/f`; the mutation run shows exactly that failure.
`[ -f "$wt/.git" ]` guards that the worktree top really is a gitfile.

## Variants

- Linked-worktree top: covered, this is the case.
- Submodule-top: structurally identical to the walk (`_readonly_git_dir` tests
  only `-e "$dir/.git"`, and a submodule top holds a `.git` gitfile like a
  linked worktree), so the same mutant would be killed by a submodule layout;
  the case is not specific to the linked worktree and adds nothing a
  submodule fixture would. A plain nested `.git` directory inside an outer
  repo would be killed equally.
- A walk that ignores `.git` and joins on the cwd gives the same path here;
  other cases pin that, as the implementer report states.
