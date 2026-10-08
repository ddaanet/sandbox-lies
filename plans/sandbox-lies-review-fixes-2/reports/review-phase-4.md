# Review: Phase 4 — code comments and the gate (d8a8591)

**Scope**: the d8a8591 hunks in `hooks/annotate.sh`, `justfile`,
`lib/probes.sh`, `tests/corpus-eval.py`, against outline Items 4.1–4.3
(m-9, m-10, m-12, m-13). Baseline 72e34d7.
**Date**: 2026-10-07T23:49Z
**Mode**: review + fix

**Counts**: critical 0 · major 0 · minor 1 (DEFERRED to the concurrent
`review-code-tests.md` hunk) · fixes applied 0.

## Summary

The four hunks do what the outline asks, and every comment they add was
checked against the code it describes: the probe key-line list matches what
`lib/probes.sh` and `lib/probes-readonly.sh` print, the stderr sentence
names real pass-through sites, each prefilter string's candidate matches the
matcher or `detectors.md` entry it names, and the `compile()` substitution
for the outline's `py_compile` is justified by a verified claim. The compile
step and the renamed `lint_paths()` both produce a genuine red under mutation.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

None.

### Minor Issues

1. **Stderr pass-through example list omits the `wc` redirect residual**
   - Location: `hooks/annotate.sh:12-15`
   - Note: the sentence names `stat` and the holder tool as the probe
     failures whose stderr passes through. `lib/probes.sh:181-186` documents a
     third: a lock vanishing between `[ -f ]` and `wc -c <"$path"` prints the
     shell's redirect error. The list reads as examples, so the sentence is not
     false, and the other reviewer's uncommitted hunk is already extending it
     (adding `probe_resume_lost`'s `sed`).
   - **Status**: DEFERRED — the hunk is under concurrent edit by
     `reports/review-code-tests.md`'s reviewer, and the dispatch says to leave
     it alone. Suggested wording for that reviewer, if wanted: append
     "or the `wc` redirect on a lock that vanished" to the list.

## Fixes Applied

None. The working tree holds only the pre-existing uncommitted changes of the
other reviewers (`git diff --stat`: README.md, docs/references/detectors.md,
hooks/annotate.sh, lib/probes-readonly-command.sh, skills/**, tests/helpers/
verdicts.bash, tests/probes-resume.bats); none of the files mutated below
appears in it, and `grep -rn SEEDED_SC2086 tests/` finds nothing.

## Requirements Validation

| Requirement | Status | Evidence |
| --- | --- | --- |
| m-10 (Item 4.1) stderr sentence scoped to the parse | Satisfied | `hooks/annotate.sh:11-12` "the parse writes nothing to stderr"; probes named as the exception. `lib/probes.sh:176` (`printf '%s\n' "$mtime" >&2`) and `:328` (holder `err` to stderr) are the named sites. |
| m-10 (Item 4.1) key lines per probe in `lib/probes.sh` header | Satisfied | `lib/probes.sh:7-13`. Lock probes: `pid=` (`:148`), `bytes=` (`:197`), `age=` (`:206`), `path=` (`:115,117,130,148,173,209`). `probe_readonly_path`: `path=` under writable/readonly only (`lib/probes-readonly.sh:80`, nopath at `:57` prints none), facts `readfile=/merge=/partial=/target=/match=` under writable and nopath (`lib/probes-readonly.sh:6-8`). `probe_resume_lost`: no key lines; outcomes `found` (`:47` default), `unknown` (`:58`), `lost` (`:66`). |
| m-9 (Item 4.2) `tracked()` renamed, both scopes stated | Satisfied | `justfile:17-20` comment names tracked plus untracked-unignored and contrasts `scripts/lib/tracked.sh`'s tracked-only `walk_tracked_files` (`git ls-files -z` with no `--others`, `tracked.sh:65`). `lint_paths` at `:23`, call sites `:34`, `:36`; `rg tracked\(` finds no stale call. |
| m-12 (Item 4.2) Python compile step ahead of `tests` | Satisfied | `justfile:40-46`, before `report tests just test` at `:47`. Red under mutation (table below). |
| Outline deviation: `compile()` instead of `py_compile` | Verified | In a scratch dir, `PYTHONDONTWRITEBYTECODE=1 python3 -m py_compile t.py` exited 0 and wrote `__pycache__/t.cpython-314.pyc` (Python 3.14.3): `py_compile` takes the cache path from `importlib.util.cache_from_source` and ignores the env var. The `compile()` one-liner left the dir holding only `t.py`, and `find tests -name __pycache__ -o -name '*.pyc'` is empty after running the real step. A `# -*- coding: latin-1 -*-` cookie in a `str` source compiles cleanly under Python 3, so decoding as UTF-8 before `compile()` loses nothing for these two files. |
| m-13 (Item 4.3) each prefilter string names its candidate | Satisfied | `tests/corpus-eval.py:54-65`. Checked: `File exists` → `match_git_lock` (`lib/matchers.sh:67`) and `match_config_lock` (`:84`); `could not lock config file` → `:84`; `can only add regular files` → `match_phantom_gitadd` (`:134`); `crw-` → `match_phantom_chardev` (`:96`); `Read-only file system`, `Device or resource busy` → `match_readonly_path` (`:147-148`); `Permission denied`, `No such file or directory` → `match_tmpdir_unset` (`:181`); `No conversation found` → `match_resume_lost` (`:190`); `apply-seccomp` → `match_seccomp_init` (`:197`); `MASKED` → `match_phantom_untracked` (`:114`); `no active session` → `detectors.md:259-263` §zellij-socket, "no-active-session refusal at a line start", no shipped matcher. |

**Gaps:** none.

## Mutation proof

Commands run from the repo root in the foreground; mutations by exact
single-occurrence string replacement, restored by the swapped replacement,
proven with `command grep`.

| Behaviour | Mutation | Red or survived |
| --- | --- | --- |
| `python compile` step reds on a syntax error in `tests/corpus-eval.py` | `def result_is_error(entry, block):` → colon dropped (grep: `68:def result_is_error(entry, block)`) | **Red**: exit 1, `File "tests/corpus-eval.py", line 68 … SyntaxError: expected ':'`. Restored: grep 0 hits for the mutation, 1 for the original; step exit 0. |
| `python compile` step reds on a syntax error in `tests/extract-fixtures.py` | `def main():` → `def main()` (grep: `205:def main()`) | **Red**: exit 1, `File "tests/extract-fixtures.py", line 205 … SyntaxError: expected ':'`. Restored: grep 0/1; step exit 0. |
| The step's file list covers every Python tool | List inspection: the step names `tests/extract-fixtures.py tests/corpus-eval.py`. `git ls-files --cached --others --exclude-standard -- '*.py'` returns those two plus `plans/2026-09-02-sandbox-detector-replay.py`. | Both tools are in the list (each redded above). The `plans/` file is outside it, so a mutation there would survive — by design: it is a dated pilot artifact, not one of "the two Python tools" the comment names, and `plans/**` is out of this gate's scope. |
| `lint_paths()` still feeds shellcheck its full list | Ran the function body verbatim (identical bytes to the baseline `tracked()` body, `git show 72e34d7:justfile`): 57 paths for `'*.sh' '*.bash' '*.bats'`, 18 for `'*.sh'`; baseline `shellcheck "${files[@]}"` exit 0. Then seeded `echo $SEEDED_SC2086` as line 2 of `tests/helpers/spy.bash`, a `.bash` file only the first `lint_paths` call lists. | **Red**: `shellcheck "${files[@]}"` exit 1, `In tests/helpers/spy.bash line 2: … SC2086`. Restored: grep 0 hits; `shellcheck tests/helpers/spy.bash` exit 0; `git diff --stat -- tests/helpers/spy.bash` empty. |
| The step writes nothing | Control: `py_compile` under `PYTHONDONTWRITEBYTECODE=1` wrote `__pycache__/t.cpython-314.pyc`. | `compile()` run left no `__pycache__` or `*.pyc` under `tests/` or the scratch dir. |

**Wrong-reason checks** (what else could have produced each red):

- Compile reds: a missing `python3` (exit 127, no traceback), a wrong path
  (`FileNotFoundError`, shown distinct by running the step on
  `tests/nonexistent.py`), or a pre-existing syntax error (ruled out by the
  exit-0 baseline before each mutation). The red seen is a `SyntaxError`
  pointing at the mutated line, so it is the mutation.
- `lint_paths` red: a finding elsewhere in the 57 files (ruled out by the
  exit-0 baseline minutes earlier on the same list), or the file reached via
  another pathspec (`'*.sh'` does not match `.bash`; only the three-pathspec
  call lists it). The red names `tests/helpers/spy.bash line 2`, the seeded
  line.

## Positive Observations

- `justfile:40-42` states why the step exists (no suite runs the tools) and
  why `compile()` over `py_compile`; both claims verified above.
- The `lib/probes.sh` header now distinguishes `probe_readonly_path`'s
  outcome-dependent key lines from the lock probes' and names
  `probe_resume_lost`'s `unknown`, which the previous header's flat
  `(pid=, bytes=, age=, path=)` misdescribed.
- `tests/corpus-eval.py` comments are one candidate per line and the one
  non-matcher string points at its `detectors.md` section.
- `just -n precommit` parses: no brace sequences in the recipe-body comments,
  shared indent intact.

## Recommendations

- If a third Python tool is ever added under `tests/`, the compile step's
  hand-listed pair will not pick it up. `lint_paths '*.py'` would, at the cost
  of compiling `plans/2026-09-02-sandbox-detector-replay.py` too; the current
  explicit list is what the outline specified, so this is a note, not a
  finding.
