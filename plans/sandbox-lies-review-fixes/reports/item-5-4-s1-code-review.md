# Review: Item 5.4 slice 1, code review

**Scope**: the GREEN in commit 6a6c7b4 ("Item 5.4/1"): `lib/probes-readonly.sh`
`probe_readonly_path` and its header comment, the `nopath` row in
`docs/references/readonly-path.md`, and the sentence it added to
`docs/changelog.md`. Report only: the lock probes in `lib/probes.sh`. The tests
were read but not edited.
**Date**: 2026-10-05
**Mode**: review + fix

## Summary

The fix is correct. `_probe_readonly_resolve` now runs before the no-path check.
That check sends both an empty resolved path and a resolved path holding a
newline to the existing `nopath` branch, so the branch body appears only once.
I found one minor issue and fixed it: the header comment still said `path=` is
printed "when a path was extracted", which the new case contradicts. The lock
probes do have the same defect. I confirmed it by running them on scratch
input; see the section on them below. Under this item that is report only.

**Overall Assessment**: Ready

## Correctness checks

- **The guard tests the resolved path.** Line 55 is
  `[ -z "$path" ] || [[ $path == *$'\n'* ]]`, and it runs after
  `path=$(_probe_readonly_resolve "$path" "$cwd")`. An absolute refused path
  under a cwd holding a newline therefore stays `writable` with its `path=`
  line. The test's middle half pins this.
- **An empty extracted path behaves as before.** `_probe_readonly_resolve`
  prints an empty `<path>` unchanged (its `/* | ''` arm). So the empty case
  takes the same branch, with the same arguments, as before the change.
- **`set -e` callers.** I ran `bash -ec` with the library sourced. Text with no
  matching line gives `nopath`, `readfile=a.out`, and so does a relative `a`
  under a cwd holding a newline. Both exit 0. The resolve call ends in
  `printf`, so the assignment's status is 0. The comment at lines 47-49 is
  still true.
- **Bash 3.2.** `[[ … == *$'\n'* ]]` works in 3.2: `$'…'` is quoted, so the
  newline matches literally. The sibling `_readonly_repo_facts` writes the same
  test as a `case`. Both forms appear in these files (`[[ < ]]` is at
  `probes-readonly-facts.sh:262`), so neither form is a finding.
- **No `2>/dev/null` was added.**
- **The extracted path is always one line.** `_readonly_path_line` is
  `grep -m1`, and the curly-quote block in `_probe_readonly_path_from_line`
  cuts at the newlines it inserts. Only the cwd that gets joined on, or `$PWD`
  for a relative cwd, can bring a newline in. The guard covers both, because
  it tests the joined result.
- **The comment, the doc row and the code agree.** The function body's comment,
  the `nopath` row ("no path extracted, or the resolved path holds a newline")
  and the changelog sentence all describe the code. The header now matches
  too; see Minor 1.

## Other newline routes to output in `probe_readonly_path` / `_readonly_print_facts`

None remain once this fix is in. With a cwd holding a newline:

- `path=` is guarded (this slice).
- `match=` comes from `_readonly_repo_facts`, which returns early when `<repo>`
  holds a newline. It also skips file names holding one.
- `target=` comes only from candidates without blanks, so a newline is ruled
  out (the `*[[:space:]]*` arm).
- `readfile=` comes from the command tokens only. `_readonly_readfile_arg`
  passes over a token holding a newline
  (`probes-readonly-command.sh:136`).
- `merge=1` and `partial=1` are literals.

## Mutated-SUT run (once)

I replaced `[[ $path == *$'\n'* ]]` with `[[ $cwd == *$'\n'* ]]` in place, using
a Python script that requires exactly one occurrence. This is the cwd-keyed
guard the test review called the plausible wrong GREEN. Running `bats -f` on
the slice's case gave `not ok 1`, failing at line 158
(`[ "$output" = "$expected" ]`, the half with the absolute path under the
newline cwd). So the test goes red on this mutant.

To restore, I ran the inverse replacement. `command grep` then shows line 55
back to `$path ==` with no `cwd ==` left, and `git diff --stat` on the file was
empty. `tests/probes-readonly-members.bats` passed all 12 cases. The RED report
had already shown that a run with no guard at all goes red, at line 153.

## Issues Found

### Critical Issues

None.

### Major Issues

None.

### Minor Issues

1. **The header comment contradicted the new case**
   - Location: `lib/probes-readonly.sh:35-43`
   - Note: It read "`nopath` (also when the resolved path holds a newline,
     which is never printed), then `path=` when a path was extracted". A path
     holding a newline *was* extracted, yet gets no `path=` line, so the
     sentence relied on its own parenthesis to undo it. The comment now says
     what the code does. `nopath` is "no path extracted, or the resolved path
     holds a newline, which is never printed", and `path=` is printed "under
     `writable` and `readonly` only". That matches the `readonly-path.md` row
     word for word. I reflowed the paragraph to 80 columns.
   - **Status**: FIXED

## Fixes Applied

- `lib/probes-readonly.sh:35-43`: reworded and reflowed the header comment
  (Minor 1). This is a comment-only change.
- `just precommit` was run in the foreground and exited 0. All 299 bats tests
  passed. plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits,
  links and tests all passed.

## Lock probes: `path=` shares the defect (report only)

**Verdict: yes.** In `probe_git_lock` and `probe_config_lock`, a relative lock
path goes through `_probe_resolve_path`, which joins it onto the payload cwd
(or onto the nearest ancestor holding `.git/`). `_probe_lock_at` then prints
`path=$path` with no guard, at lines 62, 64, 77, 95, 120 and 155. A newline in
the cwd therefore splits that line. A component such as `r⏎age=99999⏎x` puts a
whole key line between the two newlines, and the forged line's value is clean.
The hook delivers such a cwd: `hooks/annotate.sh` decodes it with
`printf '%b'` (line 70) and passes it as `$2` (line 114).

**Evidence.** I ran a scratch script under `$TMPDIR`, sourcing `lib/probes.sh`
and `lib/verdicts.sh`, with flag `false`; `<T>` stands for the scratch
directory. The script was deleted afterwards.

- **`probe_git_lock`**: text holding git's "Unable to create" line for
  `.git/index.lock`, with cwd `<T>/r⏎age=99999⏎x`. That cwd holds a `.git/`
  with a 3-byte `index.lock` in it. Output (`cat -A`):

  ```text
  orphan$
  bytes=3$
  age=0$
  path=<T>/r$
  age=99999$
  x/.git/index.lock$
  ```

  `_verdict_lock_present` keeps the last value it reads for each key, so the
  verdict reads "The lock exists outside the sandbox (3 bytes, age 99999s) and
  no process holds it." The real age, 0, is overwritten. A `pid=` line would be
  forged the same way under `held`, because the real `pid=` line comes before
  `path=` there too. I found that by reading the code and did not run it,
  because it needs a live holder.
- **`probe_config_lock`**: text holding git's "could not lock config file"
  line for `.git/config`, with cwd `<T>/c⏎path=/h/.claude/settings.json.lock⏎y`.
  That cwd is nested directories, since the forged value contains slashes.
  There is no lock, so the outcome is `mask`. Output:

  ```text
  mask$
  path=<T>/c$
  path=/h/.claude/settings.json.lock$
  y/.git/config.lock$
  ```

  `verdict_config_lock` keeps the last `path=` it reads, so the act swaps to
  "Write `.claude/settings.json` through the `update-config` skill" for a
  lock that has nothing to do with settings.json. As a control, the same cwd
  with a blank in place of each newline gave one line,
  `path=<T>/c path=x/.git/config.lock`.
- `probe_git_lock` reads no `path=` under `mask` or `gone`. There a forged line
  is inert unless it is a key the verdict actually reads.

**Not reachable through the text.** A lock path that git prints as absolute and
that holds a newline spans two lines. Neither `_probe_lock_path` nor
`_probe_config_lock_path` matches across lines, so that case already yields an
empty path.

**What a fix has to decide.** The lock outcomes (`mask`, `gone`, `held`,
`orphan`, `unknown`) have no pathless outcome like `nopath`. They can be
decided without printing the path, because `[ -e ]`, `[ -c ]`, the holder
check, `stat` and `wc` all work on the real name with its newline. So the
choice is one of these:

1. Keep the outcome, and leave out `path=` when the path holds a newline. The
   A-3 contract would then allow `path=` to be missing under every lock outcome.
   `verdict_config_lock` already handles an empty `path=` by keeping *Re-run*.
2. Take a pathless route, as readonly-path now does. That means either a new
   outcome token with its own verdict text, or reusing `mask`, which would be a
   wrong diagnosis for a real lock.
3. Escape or encode the newline in `path=`. This changes the value's meaning
   for every consumer.

Option 1 is the smallest change and keeps the diagnosis correct. It still
changes the contract in `lock-detectors.md`, so the choice belongs to my
human partner, like this item's D1-gate decision. Whichever way it goes, the
guard should go in `_probe_lock_at`, which is the one place all six `path=`
prints share. A test would mirror this slice's three-half case, with whole
output compared on both lock probes.

## Requirements Validation

| Requirement | Status | Evidence |
|-------------|--------|----------|
| 5.4: a resolved refused path holding a newline gives `nopath`, never `path=` | Satisfied | `lib/probes-readonly.sh:52-59`; case 6, third half |
| 5.4: the blank twin keeps `writable` and `path=<tmp>/r readfile=x/a` | Satisfied | case 6, first half |
| 5.4 docs: the `nopath` row and the header say the same | Satisfied | `readonly-path.md:51`; header after Minor 1 |
| 5.4: report whether the lock probes share the defect | Satisfied | section above, verified by running them |
| FR-4 (A-3 contract, no forged key line), readonly-path | Satisfied | the routes listed above are all guarded |

## Positive Observations

- The change reuses the existing `nopath` branch rather than copying it. The
  test is on the resolved value, which is the one that actually reaches
  output, so a relative cwd that falls back to `$PWD` is covered too.
- The middle half added at test review stops the cwd-keyed mutant. That mutant
  would have passed the original two-half case.

## Recommendations

1. Open a follow-up item for the lock-probe `path=` guard in `_probe_lock_at`,
   once my human partner has chosen among the options above.
