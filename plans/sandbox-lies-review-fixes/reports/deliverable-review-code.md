# Deliverable review — Layer 1, CODE partition

Range `52e6dd82b831a1cc2b7b516d4c248df6fb1ebc8c..HEAD`, current tree. Every
file in the partition is new in the range, so each was read whole.

## Checks run

- Read in full: `hooks/annotate.sh`, `hooks/check-jq.sh`, `hooks/hooks.json`,
  `lib/{matchers,probes,probes-readonly,probes-readonly-command,probes-readonly-facts,verdicts}.sh`,
  `scripts/{check-line-limits,check-links,run-bats}.sh`,
  `scripts/lib/{tracked.sh,strip-code.awk}`, `tests/extract-fixtures.py`,
  `tests/corpus-eval.py`, the `justfile` `precommit` recipe.
- Against: outline D1–D5, runbook Items 4.1–4.3 and 5.3–5.5,
  `docs/design.md` FR-1 to FR-6, NFR-2 to NFR-4, D-12 and D-17, and
  `docs/references/{hook,lock-detectors,readonly-path}.md`.
- `shellcheck` on every hook, lib and script `.sh`: clean.
- D4: sourced `lib/probes.sh` and ran `_readonly_tokenize` +
  `_readonly_readfile_arg` on 60 commands: every runbook slice example, every
  example in `readonly-path.md`'s operand-rule residual list (all 16 print what
  the doc says), and the three m-2 shapes.
- D3: scratch repo at `<tmp>/my repo` (blank in the root) with a subdirectory
  `sub`. `probe_readonly_path` with cwd `<repo>/sub/`, and with a relative
  refused path, printed `match=<tmp>/my repo/a` and `match=<tmp>/my repo/e f`.
  Through `hooks/annotate.sh` with `TMPDIR` unset, the restore clause named
  both absolute paths in backticks, and stderr was empty.
- 5.4 / 5.5 newline guards: twin directory `<tmp>/r⏎age=99999⏎x` holding a
  3-byte `.git/index.lock`. `probe_git_lock` printed `orphan`, `bytes=3` and a
  single `age=` line, with no `path=`. `probe_config_lock` printed `mask`
  alone. `probe_readonly_path` (relative path, command `cat x.log`) printed
  `nopath` and `readfile=x.log`. All six `path=` print sites in
  `_probe_lock_at` read the single guard (`lib/probes.sh:59-61`).
- Key-line forging, by reading: every value a probe prints is either guarded
  against newlines (`path=`, `readfile=`, `match=` file and root) or cannot
  hold one (`pid=` and `bytes=` are digits; `target=` excludes `[[:space:]]`).
- check-jq: run with `env -i PATH=/nonexistent` and stdin `{}`. Exit 0, empty
  stderr, exactly one JSON value (`jq -s length` gives 1). The output holds the
  escape as the six characters `\u001b`, not a raw ESC byte, and has
  `hookEventName` `SessionStart`. With `jq` on `PATH`: 0 bytes.
- NFR-4: grep of the hook path for here-documents, here-strings, `mktemp`,
  `TMPDIR` and file redirections. None outside comments and `/dev/null`.
  Process substitution only.
- Stderr claim: hook run on a git-lock payload with a stub `lsof` that writes
  to stderr (finding m-1).
- `python3 -m py_compile` on both Python tools: both compile. The `__pycache__`
  it created was removed.
- Not run: a bash 3.2 binary (none on this box). Portability was checked by
  reading: `${a[@]+…}` guards, `[[ … == *$'\n'* ]]`, `read -n 1 -d ''`,
  `printf -v`, `+=`, BSD `stat -f` before GNU `-c`, and BSD `sed` labels as
  separate `-e`. No bats run, per the brief.

## Prior finding status

- **code m-2 (`readfile=` takes non-input words): fixed.**
  `lib/probes-readonly-command.sh:122-242`. The three m-2 shapes now behave:
  - `grep -r --include=*.log pat .` prints no line, and
    `grep --include=*.log pat build.log` gives `build.log`;
  - `uniq in.txt out.log` prints no line;
  - `sed s/a/b/x.log in.out` gives `in.out`.

  The D4 rule matches the spec. A leading `-` is never an operand (except a word
  holding `<`, which is consistent with the `<` target rule). The first operand
  of grep, sed and awk is the pattern unless an `-e`/`-f` came earlier, and the
  word after a separate `-e`/`-f` is that option's argument. The pattern role
  resets at each segment (`:148`). Each residual documented in
  `readonly-path.md:90-121` reproduces exactly.
- **code m-3 (`match=` top-relative but printed bare): fixed.**
  `lib/probes-readonly-facts.sh:258` prints `match=${repo}/${files[$i]}`. The
  root comes from `_readonly_git_dir` (`:102-122`), absolute and stripped of
  trailing slashes. A root holding a newline gives nothing (`:160-162`).
  Verified end to end through the hook from a subdirectory cwd.
- **Stale comment `lib/matchers.sh:2`: fixed** (`:2-3`).
- **Stale comment on `CLAUDE_PROJECT_DIR` and `/dev`: fixed**
  (`lib/matchers.sh:91-94`). `detectors.md:70` names the residual as the
  comment says.
- **`lib/probes.sh` probe contract `$3`: fixed** (`:3-8`).
- **`just --list` precommit fragment: fixed** (`justfile:6`, a `[doc(...)]`
  attribute). `just --list` shows "Checks that run before every commit."
- **Major 2, code half: fixed.** `hooks/check-jq.sh` and the `SessionStart`
  entry in `hooks/hooks.json:3-14` conform to D2 and to the Item 4.3
  interface:
  - `command -v jq`;
  - one `printf` of fixed text producing valid JSON;
  - a `\u001b[0m` reset leading `systemMessage`;
  - `additionalContext` under `hookEventName` `SessionStart`;
  - exit 0 on every path, no matcher, a 10 s timeout.
- **Item 5.3's list revision (annotate.sh stderr claim): partly.** The case
  with `jq` absent is now stated. The rewrite also asserts that with `jq`
  present the hook writes nothing to stderr, which is false; see m-1.

## Critical

None.

## Major

None.

## Minor

**m-1 — `hooks/annotate.sh:9-12`: the header says that with `jq` present the
hook writes nothing to stderr. The probes write to stderr by design.**

- **Axes:** conformance (comment versus code), error signaling.
- **Where the code writes to stderr:**
  - `lib/probes.sh:130` passes on a `stat` failure;
  - `lib/probes.sh:264-283` (`_probe_holder_pids`) passes on a holder tool's
    unexpected stderr;
  - `lib/probes.sh:136-137` documents a `wc` redirect error as a residual;
  - `lib/matchers.sh:26-29` says that a failed read in `detect` reaches
    stderr.
- **History:** Item 5.3 rewrote the sentence. The original form, "One jq call
  … cannot error …, so the hook writes nothing to stderr while jq is on PATH",
  was already too broad. The rewrite states the claim unconditionally.
- **Evidence:** I put a stub `lsof` that prints one line to stderr and exits
  1 ahead on `PATH`. I then fed the hook a git-lock failure payload naming an
  existing `<tmp>/repo/.git/index.lock`. The hook exited 0 and the
  `systemMessage` read "index.lock — present, holder unknown". Its stderr
  held the stub's line.
- **Impact:** only on someone maintaining the code. Claude Code ignores stderr
  on exit 0, but the comment invites a future edit to treat any stderr as a
  regression, or to suppress the probes' deliberate pass-through.
- **Fix:** scope the sentence to the parse: the `jq` call itself cannot error,
  and the probes pass on failures they cannot classify.
- **Related nit:** the `lib/probes.sh:6-7` header lists the key lines as
  `pid=, bytes=, age=, path=`. Yet it introduces every `probe_<verdict>`
  function, and `probe_readonly_path`, which it sources, prints `readfile=`,
  `merge=1`, `partial=1`, `target=` and `match=`.

**m-2 — `lib/probes-readonly-command.sh:229-238`: an unquoted glob or
parameter expansion is taken as a literal `readfile=` name, and the residual
list does not name this.**

- **Axes:** functional correctness (edge), conformance to the documented
  residuals.
- **Evidence:** `grep -l pat *.log` gives `readfile=*.log`. The verdict then
  reads "Re-run the command that wrote `*.log`". `cat $OUT.log` would likewise
  give `$OUT.log`.
- **What the docs say:** `readonly-path.md:68` says "`readfile=` honours single
  and double quotes". That reads as shell word semantics. The residual list
  (`:79-83`, `:90-121`) names `$( )`, backticks and `$'…'`, but not globbing
  or `$VAR` expansion.
- **Impact:** low. The act still points at the output's producer, only
  vaguely. Name it as a residual, or skip a candidate holding an unquoted `*`,
  `?`, `[` or `$`.

**m-3 — `justfile:7-41`: the precommit gate does not check the two Python
tools, and no suite runs them.**

- **Axes:** testability, gate coverage.
- **Evidence:** `tests/extract-fixtures.py` and `tests/corpus-eval.py` appear
  in no `report` line. The only `.bats` mentions are a comment
  (`tests/matchers.bats:5`) and a path list (`tests/docs.bats:17`). A syntax
  error in either tool would pass `just precommit`. Both compile today.
- **Fix:** a `python3 -m py_compile` step costs one `report` line. Set
  `PYTHONDONTWRITEBYTECODE=1` so the step writes no `__pycache__`.
- **Related:** this is a different gap from the carried m-7 (the line-cap
  gate's coverage of `.awk` and `.json`).

**m-4 — `tests/corpus-eval.py:61`: the prefilter string `"no active session"`
matches no matcher and states no reason for being there.**

- **Axes:** excess.
- **Evidence:** the string appears nowhere else in `docs/`, `lib/`,
  `skills/` or the bats suites. The comment above it (`:47-51`) ties every
  string to a shipped matcher or a candidate's discriminator, and this string
  belongs to neither.
- **Impact:** harmless to the prefilter's coverage, since a broader prefilter
  only adds survivors. The fix is to drop the string or say which candidate it
  stands for.

## Known carry-forward confirmed (not counted)

- m-1, the quadratic tokenizer: `lib/probes-readonly-command.sh:44` still
  appends one character at a time, bounded at 16384 characters.
- m-7, line-cap coverage: `scripts/check-line-limits.sh:67` still skips
  `.awk`, `.json` and extensionless files.
- m-8, corpus-eval: the run is still not idempotent, and `:47-51` still claims
  the prefilter is broader than every matcher, which `crw-` against
  `cr--r--r--` refutes.
- m-9, extract-fixtures: a null `timestamp` (`:160`) and a non-dict `input`
  (`:165`) still crash it, and the all-projects branch of `pick()` is still
  unreachable.
- Carry list: the newline guards (readonly `nopath`, and the lock probes
  leaving `path=` out) stand in for a `path=` encoding that can carry newlines.
  Both guards work as documented.
- build-finish §Carry-forward: a relative partial-checkout path is still
  joined onto the payload `cwd` rather than the worktree top
  (`lib/probes-readonly.sh:86-105`). `readonly-path.md:42-45` documents this.
