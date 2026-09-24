# Item 2.1 slice 1: code review

Scope: `scripts/check-line-limits.sh` as committed in `Item 2.1/1`. I read it
against the runbook's Item 2.1 Interfaces block, NFR-2 and NFR-5, the port
source (edify `scripts/check_line_limits.sh`), the recall-artifact memories and
the `shell-gotchas` skill. The test file is out of scope; its gaps are listed
below.

## Findings

1. **A tracked file deleted from the work tree fails the gate with exit 2
   (major).** `git ls-files` lists index entries, so a path that was `rm`'d but
   not yet staged, or one outside a sparse checkout, reached `wc -l <path`. The
   script then printed `cannot read docs/gone.md` and exited 2. That is a false
   "failure to run" on a file that cannot be oversized, and it would redden
   `precommit` in its most common use, an unstaged deletion before
   `git commit -a`. I reproduced it against the committed version. The same
   path through `wc` also hit a tracked symlink (a dangling one exits 2, and
   one to a regular file counts its target) and a gitlink's directory.
   `memory` is a gitlink in this repo. It matches no slice-1 pattern, but the
   walk lists it. The port's `find -type f` never saw any of these.
   **Fix:** `check_cap` returns early when the path is a symlink or is not a
   regular file (`[ -L ] || [ ! -f ]`), which matches `find -type f` exactly.
   A comment states the residual: a file under an unsearchable directory also
   tests absent, so it is skipped instead of failing the run.
2. **A last line without a terminating newline went uncounted (minor).**
   `wc -l` counts newline characters, so a 401-line file without a trailing
   newline read as 400 and passed. The port recorded this as a known gap.
   Here nothing guarantees a trailing newline: `.rumdl.toml` enables MD013
   only, and shellcheck does not require one. **Fix:** the count is
   `awk 'END { print NR }' <file`, which is POSIX and behaves the same in BSD
   awk. It gives the same count as `wc -l` on terminated files and counts an
   unterminated last line. It also drops the `wc | tr` pipeline, so the
   unreadable-file guard no longer depends on `pipefail`. The comment that
   explained that dependency is rewritten to say why `awk` is used.
3. **Extra arguments were ignored silently (minor).** `check-line-limits.sh .
   x` walked `.` and could exit 0 over a tree the caller did not name. The
   port rejected a second positional with exit 2. **Fix:** an arity check
   exits 2 with `check-line-limits: unexpected extra argument: <arg>` on
   stderr.
4. **`echo` printed arbitrary data (minor).** The overage line and two stderr
   diagnostics interpolated a path or ROOT through `echo`, which breaks the
   skill's rule 5 and the repo idiom (`lib/matchers.sh` uses `printf`).
   **Fix:** all three now use `printf '%s'` format strings. The fixed-literal
   `mktemp` diagnostic keeps `echo`.
5. **The header cited a private absolute path (minor).**
   `/Users/david/code/edify/...` does not resolve for anyone who installs the
   plugin (`extracting-memory-into-skills`). **Fix:** it now reads "edify's
   scripts/check_line_limits.sh". Naming the project is enough to find the
   source.
6. **An inaccurate comment (minor).** The walk-list comment said the file is
   "read back by the caller's own loop", which is wording from the port's
   `walk()` helper. There is no caller here. **Fix:** it now says "read back by
   the loop below".

### Checked and sound

- **Exit-code contract.** A non-git ROOT, a missing ROOT (`git -C` fails), a
  failed `mktemp` and an unreadable file all exit 2 with a diagnostic, and
  git's own message passes through. An overage exits 1 and a clean run exits
  0. `check_cap` runs in the main shell because the loop reads a redirected
  file, not a pipe, so both `EXIT_CODE` and `exit 2` propagate.
- **Stderr discipline.** There is no redirect to `/dev/null`. The shell's
  `Permission denied` for an unreadable file is shown alongside the script's
  own line.
- **Whitespace safety.** The walk uses `-z` with
  `while IFS= read -r -d ''`, and every expansion is quoted. The count reads
  its file by redirection, not as an awk operand, so a name like `a=b.md` is
  not taken as an awk assignment. I probed a 401-line `docs/a b.md` and it
  was reported with its full path.
- **bash 3.2 / BSD.** There are no arrays, `mapfile` or `[[ =~ ]]`. `mktemp`
  gets an explicit trailing-X template. `awk` and `git` are the only external
  tools, and neither is stubbed.
- **Default shellcheck** is clean. `--enable=all` adds only SC2250, SC2292 and
  SC2249 style notes, which the repo does not follow. The masked-status checks
  SC2310 to SC2312 are silent.

## Verification

- **Edge probes** in a `git init` temp root, run as a script (not through the
  Bash tool's shell functions):
  - an unstaged-deleted `docs/gone.md` and a dangling `docs/link.md` symlink
    were skipped;
  - an unterminated 401-line file was reported as `401 lines > 400`;
  - a `chmod 000` file gave exit 2 with `cannot read`;
  - an extra argument gave exit 2;
  - a non-git ROOT gave exit 2 with git's `not a repository` shown.
- **Mutant run (once).** I changed `-gt "$cap"` to `-ge "$cap"` by exact
  replacement and ran `scripts/run-bats.sh tests/check-line-limits.bats`.
  Test 1 went red on `[ "$status" -eq 0 ]` and test 2 passed. After the
  inverse replacement, `command grep -c -- '-ge "$cap"'` returns 0 and the
  count for `-gt "$cap"` is 1.
- **`scripts/run-bats.sh tests/`** (foreground): `bats: 29 passed, 0 failed`.
- **`direnv exec . just precommit`** (foreground): `precommit passed:
  plugin.json, shellcheck, bash -n, rumdl, tests`.
- **`scripts/check-line-limits.sh`** on the real tree: exit 0.

## Test gaps (report only; test file out of scope)

No test covers fixes 1–3. Each can be pinned by a one-fixture case:

- a `git add`ed then `rm`'d 401-line `docs/gone.md`, expecting status 0;
- a 401-line `docs/a.md` written without its final newline, expecting the
  `401 lines > 400` line;
- `"$SCRIPT" "$dir" extra`, expecting status 2.

Slice 3 ("untracked file is out of scope") is the nearest home for the first.
The default-ROOT and exec-bit observations in the test review still stand.

## Files changed

- `scripts/check-line-limits.sh`

## Refactor flag

None.
