# Review: Item 8.0 slice 3 — the probe reports the facts (code review)

**Scope**: the implementation in commit 896a212 — `lib/probes-readonly-facts.sh`
(new) and `lib/probes-readonly.sh`. Checked against `docs/references/detectors.md`
§readonly-path Probe (the key table and the paragraph after it) and
`docs/design.md` NFR-2, NFR-3, NFR-4, D-1 and D-17. Tests were out of scope and
were not edited.
**Date**: 2026-09-27T13:20+02:00
**Mode**: review + fix

## Summary

The committed probe gets the fact table's happy paths right, but four of the
brief's hard checks failed:

- **Unbounded cost.** Cost grew with the square of the command length, and
  there were two git forks per modified file. Either one could hit the 10 s hook
  timeout, which drops the verdict.
- **The probe could write.** `git diff` rewrites `.git/index` even under
  `GIT_OPTIONAL_LOCKS=0`.
- **stderr on common repo states.** A tag pointing at a tree or blob, a broken
  gitlink, an unborn HEAD.
- **bash 3.2 abort.** `git pull`, which has no arguments, stops the probe on bash
  3.2 under `set -u`.

All of these are fixed. The scan moved into a new file to keep both files under
the line cap. `just precommit` exits 0.

**Overall Assessment**: Ready. One action for whoever commits: the new file
`lib/probes-readonly-command.sh` is untracked. The precommit gate lists files with
`git ls-files`, so it has not shellchecked, `bash -n`-checked or line-counted that
file. I ran those checks by hand and it passes: 234 lines. Stage it by name.

## Issues Found

### Critical Issues

1. **Tokenizer cost grew with the square of the command length (NFR-3)**
   - Location: `lib/probes-readonly-facts.sh` `_readonly_tokenize` (commit
     version), which was called twice, from `_readonly_readfile_arg` and
     `_readonly_merge_segment`.
   - Problem: the loop read one character at a time with `${cmd:$i:1}`, and bash
     rescans the string on every call. Measured under a UTF-8 locale:
     - 10 KB: 1.5 s per scan.
     - 40 KB: 21 s per scan, and there were two scans.

     A heredoc-writing command of that size that is refused by a read-only mount
     timed out the hook, so no verdict was given.
   - Fix: characters are now read from a pipe with `read -r -d '' -n 1`, which
     is linear. The command is tokenized once into an array that both readers
     share. The scan stops:
     - at 16384 characters, dropping the cut word;
     - at the end of a line holding `<<`, because a heredoc's body is not
       commands.

     Measured after the fix: 16 KB on one line 0.86 s, 200 KB on one line 1.0 s,
     a 200 KB heredoc 0.06 s.
   - **Status**: FIXED

2. **Unbounded git work for large lists of modified files (NFR-3)**
   - Location: `_readonly_print_matches` (commit version).
   - Problem: for each modified file it ran `cat-file -e` and a
     `cat-file blob | cmp` pipeline. A partial checkout of a large branch leaves
     thousands of modified files. At about 3 ms per fork, that is tens of seconds.
   - Fix: `_readonly_repo_facts` now uses four git processes whatever the file
     count:
     - `cat-file --batch-check` for HEAD and all candidates;
     - `diff-index -z` for the modified list with HEAD's blob ids;
     - `hash-object --no-filters --stdin-paths` for the working tree;
     - one `ls-tree -r -z` over the listed names at the target, paired with the
       list in one merge pass in byte order.

     Past 1000 modified files, no `target=` is printed, so the verdict falls
     back to its generic "restore them from HEAD" clause. I tried a per-name
     `cat-file` lookup and measured 0.4 ms each in a 3000-entry directory,
     because it re-reads the directory every time; that is why the code uses
     `ls-tree`. Measured after the fix:
     - 1000 matching files in a 20000-entry directory: 0.74 s.
     - 3000 modified files (over the cap): 0.35 s.
   - **Status**: FIXED

3. **`git diff --name-only HEAD` rewrote `.git/index` (NFR-4)**
   - Location: `_readonly_print_matches` (commit version), the process
     substitution feeding its loop.
   - Problem: I reproduced this on git 2.47.3. A tracked file that is
     stat-dirty but has unchanged content makes porcelain `git diff` refresh
     the index and write it back, despite `GIT_OPTIONAL_LOCKS=0`. The index
     mtime moved from 946681200 to 1790507787. The slice's test did not catch
     this because its fixture has no stat-dirty file with unchanged content
     (`d` is never touched). Porcelain `git diff` also reads the content of such
     files through clean filters, and an LFS clean filter stores objects. I did
     not reproduce the LFS part: git-lfs is not on this box.
   - Fix: `diff-index` (plumbing, no refresh) with `-c core.fsmonitor=false`,
     plus `hash-object --no-filters` with no `-w`. A stat-dirty file with
     unchanged content is dropped because its working-tree id equals HEAD's.
     Re-verified: the index mtime is unchanged and no `index.lock` is left.
   - **Status**: FIXED

### Major Issues

1. **Empty arrays abort the probe on bash 3.2 under `set -u` (NFR-2)**
   - Location: `"${cands[@]}"` in `_readonly_print_facts` and
     `_readonly_merge_segment`, and `"${out[@]}"` in `_readonly_tokenize`.
   - Problem: bash before 4.4 treats an empty array as unbound. A `git pull`
     segment (no words after the subcommand), or an empty command, printed
     "unbound variable" and exited the probe's subshell. `hooks/annotate.sh`'s
     `|| exit 0` then dropped the verdict on macOS. The suite runs bash 5, so it
     cannot see this.
   - Fix: every array that can be empty now expands as `${a[@]+"${a[@]}"}` or
     behind a count check, the same pattern `lib/verdicts.sh` uses. The file
     header states the rule. I could not run bash 3.2 here, so this fix is
     correct by construction but not executed.
   - **Status**: FIXED

2. **A ref pointing at a tree or blob printed to stderr**
   - Location: `_readonly_resolve_target` (commit version).
   - Problem: `rev-parse --verify --quiet X^{commit}` still prints
     `error: X^{commit}: expected commit type…` for a tree or blob. I verified
     this for tree and blob tags and for a raw tree id.
   - Fix: candidates are resolved with `X^{}` and `%(objecttype)`. A tree or
     blob answers with its type rather than an error.
   - **Status**: FIXED

3. **Repository states that git cannot open printed to stderr**
   - Location: `_readonly_resolve_target` and `_readonly_print_matches` (commit
     versions).
   - Problem: verified cases:
     - a `.git` file pointing at a missing gitdir: `fatal: not a git repository`;
     - an empty `.git` directory: fatal;
     - an unborn HEAD with another branch present: `diff … HEAD` fatal.

     Dubious ownership and a corrupt index take the same path.
   - Fix: one `cat-file` asks about `HEAD^{}` first. An unborn HEAD answers
     `missing`, and so gives no `target=`. Each git call discards stderr, with
     the reason written inline, as the `no-stderr-suppression` memory asks:
     every such failure means "no fact", and the probe's stderr has no reader.
     Each call's own output is checked instead:
     - `diff-index` and `ls-tree` must end in an empty-record sentinel;
     - the `hash-object` line count must equal the file count.
   - **Status**: FIXED

4. **An unquoted newline did not separate commands**
   - Location: `_readonly_tokenize` (commit version).
   - Problem: a newline went into the word and was then split by the reader
     loop, so it separated words but not list segments. Two effects:
     - `git fetch` then `git merge feat` on the next line gave no `merge=1`;
     - `cat build.log` then `rm -rf x` gave `readfile=build.log`, although
       `rm` is not a reader.
   - Fix: an unquoted newline now separates segments. Treating newlines as
     separators would have turned heredoc bodies into commands: a body line
     reading `git merge feat` would give a false `merge=1`, and its verdict
     would tell the agent to restore files from HEAD. So the scan stops at the
     end of a line holding `<<`, and a stopped scan gives no `readfile=`. I
     verified both sides. The cost is that a merge after a heredoc is missed,
     and the doc now says so.
   - **Status**: FIXED

5. **In-place sed variants gave `readfile=` (the contract says "sed without
   in-place editing")**
   - Location: `_readonly_readfile_arg`.
   - Problem: only `-i*` was rejected. `sed --in-place`, option clusters such
     as `sed -Ei`, and BSD's `sed -I ''` all gave `readfile=`.
   - Fix: all three forms are rejected. `sort -o` and gawk's `-i inplace` also
     write, so they are rejected too, which is the safe direction. The doc now
     names both.
   - **Status**: FIXED

6. **Key lines could be forged through a value holding a newline**
   - Location: `target=` and the new tokenizer's quoted words.
   - Problem: `rev-parse` resolves `HEAD@{1<newline>x}` to a commit (verified).
     Once quoted words keep their newlines, such a candidate would print a
     second, arbitrary line after `target=`. The same applies to a `readfile=`
     name holding a newline.
   - Fix: a candidate holding a blank or newline is skipped (no ref name holds
     one). A `readfile=` name holding a newline is passed over. `match=` already
     skipped such names.
   - **Status**: FIXED

7. **Revision syntax could kill or stall resolution**
   - Location: candidate filter in `_readonly_repo_facts`.
   - Problem: `HEAD@{99}` makes `cat-file --batch-check` die with a fatal error
     on a short reflog (verified), losing every candidate after it. `^{/re}`
     walks the history.
   - Fix: candidates holding `@{`, `^{` or `:`, or starting with `-`, are
     skipped. None of these is a ref name; `:` would also break the `rev:path`
     form.
   - **Status**: FIXED

8. **Infinite loop on a relative start directory**
   - Location: `_readonly_git_dir`.
   - Problem: under `nopath`, the search starts at the raw payload cwd. For a
     relative cwd, `${dir%/*}` never reaches `/`, so the hook spun until its
     timeout.
   - Fix: a relative directory is joined onto `$PWD` first, as
     `_probe_readonly_resolve` does. Verified: `nopath` with cwd `repo` resolves
     `target=feat`.
   - **Status**: FIXED

9. **Scan residuals the doc did not state (D-17: `references/` names the
   residuals beside each fact)**
   - Location: `docs/references/detectors.md` §readonly-path, the Residuals
     sentences.
   - Problem: the doc named only the newline-in-`match=` and cd/assignment
     residuals. It did not name:
     - unparsed `$( )`, backticks, subshells, braces and `$'…'`;
     - the heredoc and length cuts;
     - a quoted `>` blocking `readfile=`;
     - skipped candidate shapes;
     - the 1000-file cap;
     - byte-exact matching before clean filters, and no symlinks.
   - Fix: the Residuals sentences now list them. The paragraph was reformatted
     with rumdl, scoped to that one file.
   - **Status**: FIXED

10. **`target=` was printed before the `match=` lines were computed**
    - Location: `_readonly_print_facts` (commit version).
    - Problem: if the file comparison failed after `target=` was printed, the
      verdict would read `target=` with no `match=` and state "nothing sits at
      the target".
    - Fix: `target=` is printed only after every read has succeeded, and
      directly ahead of its `match=` lines.
    - **Status**: FIXED

### Minor Issues

1. **Backslash escapes were not honoured** — `cat my\ file.log` gave
   `readfile=file.log`. The tokenizer now removes backslashes as the shell
   does, both unquoted and inside double quotes, including line continuation.
   **Status**: FIXED

2. **Comments were not parsed** — `cat build.log # don't` followed by a writer
   on the next line opened a quote that never closed and hid the writer. A `#`
   at the start of a word now runs to the end of the line. **Status**: FIXED

3. **`cat <build.log` gave `readfile=<build.log`** — a leading `<` redirection
   is now stripped from the name. **Status**: FIXED

4. **Symlinks were followed** — `cmp` compared the link target's bytes with the
   link's blob and could read outside the repository. Symlinks are now never a
   match. **Status**: FIXED

5. **Inherited repository environment** — a `GIT_DIR` or `GIT_INDEX_FILE` in
   the hook's own environment (a claude started inside a git hook) would point
   every read at another repository (NFR-4 read scope). The git reads now run
   in a subshell that unsets `git rev-parse --local-env-vars` and exports
   `GIT_OPTIONAL_LOCKS=0` once, which covers every call. **Status**: FIXED

6. **Plan references in shipped comments** — "Item 8.0 slice 3" appeared in the
   headers of both lib files, and plan items rot. Removed. **Status**: FIXED

7. **`docs/design.md` Architecture did not list the new lib files** — added one
   line covering `lib/probes-readonly-*.sh`. **Status**: FIXED

## Fixes Applied

- `lib/probes-readonly-facts.sh`:
  - `_readonly_print_facts` tokenizes once and passes the tokens to both
    readers. It reads the merge segment as NUL-terminated words and delegates to
    `_readonly_repo_facts`.
  - `_readonly_git_dir` handles a relative directory.
  - `_readonly_repo_facts` replaces `_readonly_resolve_target` and
    `_readonly_print_matches`. It runs in a subshell with the repository
    environment unset, uses four batched git reads, caps at 1000 files, guards
    candidates, checks each read's output, and prints `target=` last.
- `lib/probes-readonly-command.sh` (new, untracked; stage it):
  - `_readonly_tokenize` is linear, handles backslashes, comments and newlines,
    stops at a heredoc line, bounds at 16384 characters, and writes to an array.
  - `_readonly_readfile_arg` rejects the in-place and output-option forms,
    strips a leading `<`, and passes over names holding a newline.
  - `_readonly_merge_segment` works on the array and prints NUL-terminated
    words.

  The file header carries the set -u empty-array rule.
- `lib/probes-readonly.sh`: sources the new file and rewords its comments to
  match; plan references removed.
- `docs/references/detectors.md`: Residuals sentences extended.
- `docs/design.md`: Architecture line added.

`hooks/annotate.sh` needs no change. It already passes `"$command"` as the third
argument, and `lib/probes.sh` → `lib/probes-readonly.sh` sources both files.

## Verification

- `just precommit`, run in the foreground: exit 0. Checks passed: plugin.json,
  hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests (227
  passed). Shellcheck and `bash -n` were also run by hand on the untracked file.
- Ad hoc probes against the fixed code, each with exit 0 and empty stderr:
  - multi-line `git fetch` then `git merge feat` gives `target=feat` and
    `match=a`;
  - a heredoc body holding `git merge feat` gives no `merge=1`;
  - `cat build.log` then `rm` on the next line gives no `readfile=`;
  - a tree tag, a broken gitlink, an unborn HEAD and a newline-forging
    candidate give `merge=1` and no `target=`;
  - a detached HEAD resolves;
  - a stat-dirty file with unchanged content leaves the index mtime unchanged
    and is not listed.

  A join over names including `"q`, `st*r`, a tab, a backslash, a blank,
  `a.b`/`a-b`/`a0`/`a/x`, and a path that is a file at HEAD but a directory at
  the target matched every expected name and excluded the edited and
  converted ones.
- **Mutated-SUT run (once).** I changed `[ "${shas[$i]}" = "${tshas[$j]}" ]` to
  `[ "${shas[$i]}" = "${shas[$i]}" ]`, which makes every modified file a match.
  `tests/probes-readonly-facts.bats` redded exactly one test, "target and match
  select files at the resolved ref…", on `run ! grep -qxF 'match=c'`. I restored
  the line by inverting the replacement and checked with grep: original 1,
  mutant 0.

## Requirements Validation

| Requirement | Status | Evidence |
|---|---|---|
| FR-4: `readfile=` for reader pipelines and lists of a command-output file | Satisfied | `_readonly_readfile_arg`; the slice's tests plus the newline and in-place probes |
| FR-4: `merge=1` from a git segment or the partial-checkout text | Satisfied | `_readonly_merge_segment`, `_readonly_partial_checkout_text` |
| FR-4: `target=` and `match=` over the path's repository, else the cwd's | Satisfied | `_readonly_git_dir`, `_readonly_repo_facts` |
| D-1: command shapes wording only | Satisfied | the facts never feed detection or the outcome |
| D-17: residuals named beside each fact | Satisfied | detectors.md Residuals, extended |
| NFR-2: bash 3.2 / BSD | Satisfied (bash 3.2 by construction) | empty-array expansions; the BSD-stub test passes |
| NFR-3: bounded probe cost | Satisfied | the timings above |
| NFR-4: writes nothing | Satisfied | diff-index without refresh, no `-w`, fsmonitor off, index mtime unchanged |

## Recommendations

The tests were out of scope for this review. The next test pass should pin
these as tests:

- a `touch d` in `make_scratch_repo`. It reds the committed `git diff` on the
  index mtime assertion.
- a tree-tag candidate, asserting empty stderr.
- multi-line and heredoc commands.
- `>1000` modified files, asserting no `target=`.
- a relative cwd under `nopath`.
- a time bound on a large command.
