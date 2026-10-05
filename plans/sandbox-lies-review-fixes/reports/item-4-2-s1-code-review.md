# Review: Item 4.2 slice 1 — code review (GREEN `✨ Item 4.2/1 — match= names are absolute`)

**Scope**: The GREEN change to `lib/probes-readonly-facts.sh` (the merge pass's
`match=${repo}/${files[$i]}` and the `_readonly_repo_facts` header), plus the
authorised new test in `tests/probes-readonly-members.bats` for the newline
finding. Out of scope: `docs/references/readonly-path.md`, Item 4.3, Phase 5.
**Date**: 2026-10-05. **Mode**: review + fix.

## Summary

The GREEN change follows D3 and is one line. The security finding is real. The
new `$repo` prefix skipped the newline guard that file names already have. I
wrote a failing test for it first, then fixed it. Review also turned up a minor
issue: a cwd with a trailing slash gave `match=<repo>//<name>`. I fixed that
too. A pre-existing issue of the same class is reported at the end. It is in
`path=`, emitted from `lib/probes-readonly.sh`, which is outside the IN scope.
`just precommit` exits 0: 300 bats tests passed, 0 failed.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

1. **A newline in the repository root forges fact lines through `match=`**
   - Location: `lib/probes-readonly-facts.sh`, the `_readonly_repo_facts` merge
     pass. GREEN changed the line to `out="${out}match=${repo}/${files[$i]}"`.
   - Problem: `$repo` comes from `_readonly_git_dir`. It starts from the refused
     path, or from the cwd under nopath. Nothing checked it for a newline. If
     the root's name holds one, each `match=` line splits in two. The text after
     the newline then reaches `verdict_readonly_path` as its own key line. The
     verified output is shown below. With the root `<tmp>/r⏎readfile=x`, the
     probe printed three forged `readfile=` lines, and the last one,
     `readfile=x/e f`, set the verdict's act. A refused path comes off a single
     line of the text, so it cannot carry a newline. Only the cwd can: the
     payload cwd joined onto a relative refused path, the payload cwd under
     nopath, or `$PWD` as the fallback.
   - Fix: `_readonly_repo_facts` now returns 0 straight after `shift` when
     `$repo` matches `*$'\n'*`. Its comment gives the same reason as the
     file-name guard. The header comment now says "nothing when no candidate
     resolves or <repo> holds a newline". Returning before `target=` is
     deliberate. A `target=` with no `match=` lines would suppress the verdict's
     generic `partial=1` restore clause, because that clause is an `elif` on an
     empty target.
   - **Status**: FIXED (test first; see the section below)

### Minor Issues

1. **A trailing slash on the start directory doubled the slash in `match=`**
   - Location: `lib/probes-readonly-facts.sh`, `_readonly_git_dir`.
   - Problem: the first `[ -e "$dir/.git" ]` check succeeds on `<repo>/` itself,
     so the function printed the root with its trailing slash. Under nopath with
     payload cwd `<repo>/`, the probe printed `match=<tmp>/g//a`, verified by
     hand before the fix. It still resolves, but it is not the `<repo>/<name>`
     form D3 specifies, and the verdict shows it to the agent.
   - Fix: trailing slashes are stripped before the walk, with `/` restored when
     the result is empty. This is the loop `probe_readonly_path` already uses on
     `target`. The function comment now says the root it prints never ends in
     `/`, except `/` itself. Verified by hand: cwd `<repo>/`, `<repo>//` and
     `<repo>` each give `match=<tmp>/g/a`. Called on `/` and on `///`, the
     function still terminates with rc 1. No test pins this, because the
     dispatch authorised one test only (see Recommendations).
   - **Status**: FIXED

## Newline test: red, then green

The case is `tests/probes-readonly-members.bats`, "a repository root holding a
newline gives no target= or match=" (lines 85–113; the file is 222 lines). It
uses two scratch repos. `good` is `$BATS_TEST_TMPDIR/r readfile=x`, with a
blank. `bad` is `$BATS_TEST_TMPDIR/r⏎readfile=x`, with a newline where `good`
has the blank. Each is driven under nopath: fixture text with its quoted path
removed, cwd set to the repo, `git merge feat`. `good`'s output must equal the
whole list `nopath`, `merge=1`, `target=feat`, `match=$good/a`, `match=$good/b`,
`match=$good/e f`. That is the paired positive, so the case cannot pass on empty
output. `bad`'s output must equal exactly `nopath⏎merge=1`, which rules out
every forged line at once. Nopath is required here. A relative refused path
would have the probe's own `path=` line forge `readfile=` too (pre-existing; see
Recommendations), and an absolute refused path cannot carry the newline at all.

**Red** (SUT at HEAD, the test only):

```text
1..1
not ok 1 a repository root holding a newline gives no target= or match=
# (in test file tests/probes-readonly-members.bats, line 110)
#   `[ "$output" = $'nopath\nmerge=1' ]' failed
```

Line 110 is the final assertion. The `good` half passed. The probe's actual
`bad` output (`cat -A`, tmpdir shown as `<tmp>`):

```text
nopath$
merge=1$
target=feat$
match=<tmp>/r$
readfile=x/a$
match=<tmp>/r$
readfile=x/b$
match=<tmp>/r$
readfile=x/e f$
```

**Green** (after the fix): `bats tests/probes-readonly-members.bats` gave `ok 1`
through `ok 10`, including
`ok 4 a repository root holding a newline gives no target= or match=`.

**Mutation (once, in place, restored by inverse replacement)**: I widened the
guard from `*$'\n'*` to `*[[:space:]]*`, the over-broad variant. The case went
red at line 104, `[ "$output" = "$expected" ]`, which is the `good` half. The
paired positive is what catches a guard that also drops roots containing a
blank. After the inverse replacement, `git diff` on the lib file shows only the
intended fix.

## Other fact lines (dispatch check 3)

- `match=`: the file part was already guarded at the `*$'\n'*) continue` line.
  The repo part is now guarded too.
- `target=`: the candidate filter skips `*[[:space:]]*`, which includes a
  newline. Safe.
- `readfile=`: `_readonly_readfile_arg` passes over a candidate holding a
  newline (`lib/probes-readonly-command.sh`, comment at l.136). Safe.
- `merge=1` and `partial=1` are constants.
- `path=`: **unguarded, and pre-existing.** See Recommendations 1.

## Other checks

- **Is `$repo` always absolute?** Yes. `_readonly_git_dir` joins a relative
  start onto `$PWD`. `_probe_readonly_resolve` has already joined a relative
  refused path onto the cwd, or onto `$PWD` when the cwd is relative or empty. A
  `..`-bearing start gives an absolute but non-canonical root such as
  `<x>/sub/..`. The kernel resolves both the `.git` test and the later
  `<repo>/<name>` read the same way, so they agree. If `sub` is a symlink, both
  follow its target's parent. A non-existent component makes the `-e` test fail
  and the walk moves past it. A trailing slash is fixed (Minor 1). `/` as root
  still yields `//<name>`. That form is legal on Linux and macOS, and a
  repository at `/` is out of practical reach, so it stays a residual.
- **Verdict with a space-bearing absolute name**: `verdict_readonly_path` reads
  each line with `IFS= read -r` and stores `${line#match=}` whole.
  `_readonly_match_list` puts each name in backticks by plain expansion. Blanks
  pass through byte-exact, as they did for the bare `e f`. The new
  `tests/hook-writes.bats` needle (``…, `<repo>/e f` from HEAD``) pins this end
  to end. A backtick in a root closes the code span early, the documented
  behaviour already applied to `path=`.
- **Stderr/`2>/dev/null`**: the GREEN change adds none.

## Fixes Applied

- `lib/probes-readonly-facts.sh` `_readonly_repo_facts`: the newline guard on
  `$repo` with its comment, and the header comment clause "or <repo> holds a
  newline".
- `lib/probes-readonly-facts.sh` `_readonly_git_dir`: trailing slashes are
  stripped before the walk, and the comment is updated to match. The file is 265
  lines.
- `tests/probes-readonly-members.bats`: the new newline case.
- `shellcheck -x` is clean on both files. `just precommit` exits 0, with
  plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links and
  tests all passing (bats 300 passed, 0 failed). Nothing is staged.

## Requirements Validation

| Requirement | Status | Evidence |
| --- | --- | --- |
| FR-4 / D3 (`match=` is `<repo>/<name>`) | Satisfied | merge-pass line; members.bats "match= names are absolute…"; hook-writes.bats restore clause |

## Positive Observations

- The change is one line at the site the runbook names, and it reuses the `repo`
  argument rather than recomputing the root.
- The header comment states why names are absolute (the clause reads from any
  cwd).

## Recommendations

1. **`path=` forges key lines from a newline-bearing cwd** (pre-existing,
   `lib/probes-readonly.sh`, outside IN). A relative refused path is joined onto
   the payload cwd by `_probe_readonly_resolve`. The probe then prints
   `path=$path` unguarded. Verified: cwd `<tmp>/r⏎readfile=x` with refused path
   `a` gives `writable`, `path=<tmp>/r`, `readfile=x/a`, `merge=1`, and the
   verdict reads
   `` `<tmp>/r` is writable … Re-run the command that wrote `x/a`. `` The new
   repo guard already keeps `match=` out of this output. The fix has to choose
   what the probe reports for a path it cannot print: `nopath`, or an outcome
   with no `path=` line. That choice changes the A-3 contract, so it belongs to
   my human partner or a later item.
2. **Pin Minor 1**: add a case with cwd `<repo>/` under nopath that asserts
   `match=<repo>/a` exactly. I did not write it, because the dispatch authorised
   only the newline test.

END OF REPORT
