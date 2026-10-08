# Deliverable review — Layer 1, CODE partition (review-fixes-2)

## Scope and method

Range `52e6dd82b831a1cc2b7b516d4c248df6fb1ebc8c..HEAD`, current tree. The
closest reading went to this job's changes, `git diff 1718c03..HEAD`. In this
partition they touch `hooks/annotate.sh`, `lib/probes.sh`, `lib/verdicts.sh`,
`lib/probes-readonly-command.sh`, `justfile` and `tests/corpus-eval.py`.

Read whole: `hooks/annotate.sh`, `hooks/check-jq.sh`, `hooks/hooks.json`, the
six `lib/*.sh` files, `scripts/check-line-limits.sh`, `scripts/check-links.sh`,
`scripts/run-bats.sh`, `scripts/lib/tracked.sh`, `scripts/lib/strip-code.awk`,
`tests/corpus-eval.py` (lines 1-120) and `tests/extract-fixtures.py` (lines
140-237), plus the `justfile` recipes.

Baselines: the outline (Q1-Q6, D-a to D-d, Items 1.1, 2.1, 4.1-4.3), the
previous `deliverable-review.md` and `deliverable-review-code.md`,
`docs/design.md` (FR-4, NFR-4, D-8) and `docs/references/detectors.md`
§resume-lost and `readonly-path.md`.

No test process was run (no `bats`, `run-bats.sh` or `just`). Every probe
below is a hand run of one function or of the hook on a crafted input, with
scratch under `/tmp/claude/dr2-code/`.

## Critical

None.

## Major

None.

## Minor

**m-1. `lib/probes.sh:57-67`: an absent or unreadable `<root>/projects` reads
`lost`, so the probe states a verdict about a tree it could not search.**

- **Axis:** error signalling, robustness. **Severity:** Minor.
- **What happens:** the probe prints `unknown` only for an empty root or no
  extracted id. When the glob cannot search at all, it gets the same empty
  match as "no transcript": a root that does not exist, an unreadable
  `projects/`, or an unreadable project directory. It prints `lost`, and the
  hook then states the sandbox cause ("`~/.claude/projects` is read-only inside
  the sandbox").
- **Evidence:** in `/tmp/claude/dr2-code/r3`, a config dir holding both
  fixture ids printed `found`. After `chmod 000 projects/-p` it printed `lost`;
  after `chmod 000 projects` it printed `lost`; with `CLAUDE_CONFIG_DIR=<dir>/nonexistent`
  it printed `lost`.
- **Impact:** low. The parent CC writes its own transcript under the same
  root, so the root and `projects/` normally exist and are readable. A relative
  non-empty `CLAUDE_CONFIG_DIR` is the most plausible trigger: the probe
  resolves it against the hook's cwd. D-a defines `lost` only as "some id has no
  transcript".
- **Fix:** a guard can cover two of the three cases. Print `unknown` when
  `[ -d "$root/projects" ] && [ -r … ] && [ -x … ]` fails, which catches a
  missing root and an unreadable `projects/`. An unreadable single project
  directory under a readable `projects/` would still read `lost`, so either
  record that case as a residual or record the whole gap in `detectors.md`
  §resume-lost, next to the `archived/` residual.

**m-2. `hooks/annotate.sh:11-16`: inserting the probe sentence left the next
sentence's "it" pointing at the wrong noun, and left a line unreflowed.**

- **Axis:** clarity (comment). **Severity:** Minor.
- **The text:** "`stat`, holder tool or probe_resume_lost's `sed`, passes its
  own stderr through. `-Rs` takes it as one raw string and `fromjson?`
  decodes it". "It" now reads as the probe's stderr. It meant stdin, as it did
  before the edit (`git diff 1718c03..HEAD -- hooks/annotate.sh`). Line 16,
  "dropping what does not parse;", is a short orphan line in an otherwise
  filled paragraph.
- **The list is also short:** "The probes are the exception" names `stat`, the
  holder tool and the resume `sed`. It leaves out two other stderr paths:
  - the `wc -c` redirect error that `lib/probes.sh:182-183` documents as a
    residual;
  - `detect`'s `tr` read failure, which `lib/matchers.sh:26-29` says reaches
    stderr.
  The second is outside the probes altogether. Item 4.1's requested scope
  (the parse, plus the probes' pass-through) is met, so this is wording only.
- **Fix:** move the probe sentences after the jq description ("…only a string
  field is read as text"). Say "e.g." or add the two paths.

**m-3. `lib/probes.sh:54-55`: the probe keeps its own copy of
`match_resume_lost`'s line shape instead of sharing it.**

- **Axis:** modularity. **Severity:** Minor.
- **The two copies:** the regex
  `^No conversation found with session ID: ([0-9a-fA-F-]+)[[:space:]]*$` is
  written out in `lib/probes.sh:55`, and again (minus the group) in
  `lib/matchers.sh:190`.
- **Why it matters:** readonly-path shares its discriminator through
  `_readonly_path_line` (`lib/matchers.sh:137-149`), explicitly "rather than as
  two copies that could drift apart". If the matcher's id class widens and the
  probe's does not, the probe prints `unknown` and the hook goes silent on a
  refusal it detected.
- **Current state:** the two shapes agree today. A hand run of a CRLF line, a
  `--` id and a two-id mix gave the outcomes they should.
- **Fix:** have `match_resume_lost` and the probe both use one
  `_resume_lost_ids` helper (`LC_ALL=C sed -nE …p`), with the matcher testing
  that its output is non-empty.

**m-4. `lib/probes-readonly-command.sh:237-238`: brace expansion is not part
of the glob/expansion skip.**

- **Axis:** functional completeness (m-11's class). **Severity:** Minor.
- **Evidence:** I sourced `lib/probes.sh` and ran `_readonly_tokenize` +
  `_readonly_readfile_arg` (`/tmp/claude/dr2-code/dr2-rf.sh`):
  - `cat {a,b}.log` gives `readfile={a,b}.log`, so the verdict reads "Re-run
    the command that wrote `{a,b}.log`". That is the same misdirection m-11
    fixed for `*.log`.
  - `cat ~/x.log` gives `~/x.log`. That is harmless: it names the real file.
  - `cat \`pwd\`/x.log` gives the backtick word, a gap the comment at `:138-139`
    states.
- **Docs:** `readonly-path.md:68-70` lists `*`, `?`, `[` and `$`, and `:84-85`
  says "braces" are not parsed. That phrase is about grouping, so brace
  expansion is undocumented either way.
- **Fix:** add `{` to the class (`*[*?[{\$]*`), or name brace expansion in the
  residual list.

**m-5. `tests/corpus-eval.py:47-65`: the Item 4.3 comments are right
string-by-string, but the block comment above them still carries a false
claim.**

- **Axis:** clarity, carried correctness. **Severity:** Minor.
- **The claim:** "strictly broader than any matcher" is still false for
  `crw-` against `match_phantom_chardev`'s `c[rwx-]{9}`. Re-verified: `printf 'cr--r--r-- 1 root root 1, 3 Jan 1 .bashrc\n' | bash lib/matchers.sh`
  prints `phantom-chardev`, and that text has no `crw-`. This is the previous
  review's carried code m-8, not counted again here. Item 4.3 rewrote the lines
  directly below that claim.
- **Every per-string tag is correct** against `lib/matchers.sh` and
  `detectors.md`. `"no active session"` is the `zellij-socket` candidate's,
  which "stays a candidate" (`detectors.md:259-276`).

**m-6. `lib/probes.sh:42-48`: a caller with `noglob` (`set -f`) gets `lost`
for transcripts that exist.**

- **Axis:** robustness, comment accuracy. **Severity:** Minor.
- **The claim:** the comment says the subshell makes the glob safe "whatever
  the caller's shell options", but the body only runs `shopt -u failglob`.
  Under `set -f` the pattern never expands, the literal path fails `[ -f ]`,
  and every id reads as missing.
- **Evidence:** in `/tmp/claude/dr2-code/r3`, which holds both fixture ids,
  `bash -c '. lib/probes.sh; CLAUDE_CONFIG_DIR=… probe_resume_lost' <fixture`
  printed `found`. The same command with `set -f;` prepended printed `lost`.
- **Impact:** none through the hook today. `hooks/annotate.sh` never sets
  `-f`, and the one `set -f` in `lib/` (`probes-readonly-facts.sh:223`) sits
  inside `_readonly_repo_facts`'s own subshell. It matters only to a future
  caller, or a sourced edit, that leaves noglob on.
- **Fix:** `set +f` beside `shopt -u failglob`, with the comment kept true.

## Checked and conforming

- **D-a, `probe_resume_lost`** (`lib/probes.sh:30-69`). The root is
  `${CLAUDE_CONFIG_DIR+set}` (set, even empty) else `${HOME:+$HOME/.claude}`.
  The glob is `"$root"/projects/*/"$id".jsonl` with the root quoted. It counts a
  file only if `[ -f ]` holds. It never opens a transcript (no read, only a
  test) and prints no key lines. It is a subshell with `failglob` unset. Hand
  run in `/tmp/claude/dr2-code/r1` (config dir path holding a space):
  - empty dir gives `lost`; one id gives `lost`; both ids give `found`;
  - `<id>.jsonl` as a directory, a dangling symlink or a FIFO each give `lost`;
  - a caller with `failglob` gets `found` and `lost` correctly, with no abort;
    a caller with `nullglob` gets `lost`; `noglob` is m-6;
  - `CLAUDE_CONFIG_DIR=''` gives `unknown`. The `HOME` fallback without
    `.claude` gives `lost`, and with both ids `found`. `HOME` unset gives
    `unknown`;
  - a CRLF refusal line gives `found`; an id of `--` gives `lost`; a non-hex
    id or no refusal line gives `unknown`; under `set -euo pipefail` the
    outcome is correct and the caller survives.
- **Hostile ids:** the extraction admits only `[0-9a-fA-F-]+`, the matcher's
  class, so no glob or path metacharacter reaches the pattern.
- **D-b, `verdict_resume_lost`** (`lib/verdicts.sh:252-265`). `lost` prints the
  text from before this job unchanged. `found` prints its own paragraph and
  human line. Any other outcome, `-` included, prints nothing. Both texts
  match `detectors.md` §resume-lost verbatim. The `found` text departs from the
  outline's draft, which was a draft to be finalized.
- **Q1, the gate dropped** (`hooks/annotate.sh:95-101`). End to end with
  crafted `PostToolUseFailure` payloads (`/tmp/claude/dr2-code/hk.sh`):
  - flag `true` and flag `false` with an empty config dir each emit the `lost`
    verdict;
  - with both ids present and flag `true`, the hook emits the `found` verdict;
  - with `CLAUDE_CONFIG_DIR=''` (`unknown`) it emits nothing and exits 0;
  - stderr was empty in every case.
- **Item 2.1 / Q4** (`lib/probes-readonly-command.sh:234-243`, comment
  `:136-139`). The test cases below behave as the comment and
  `readonly-path.md:68-73,123-125` say:

  | Command | Result |
  | --- | --- |
  | `grep -l pat *.log` | no line |
  | `cat $OUT.log` | no line |
  | `cat "$OUT".log` | no line |
  | `cat 'lit*.log'` | no line, the documented safe side |
  | `cat a[1].log` | no line |
  | `cat a?.log` | no line |
  | `cat <$F.log` | no line |
  | `cat x\$y.log` | no line |
  | `cat x.log` | `x.log` |
  | `cat *.log x.log` | `x.log` (a skip does not hide a later literal) |
  | `wc -l<x.log` | `x.log` |

- **Item 4.1, probe header** (`lib/probes.sh:2-13`). It is true to the code:
  - the lock probes print pid=, bytes=, age= and path=;
  - `probe_readonly_path` prints path= (none on nopath), then the facts on
    writable and nopath;
  - `probe_resume_lost` prints no key lines and one of three outcomes;
  - `$3` is read by `probe_readonly_path` only.

  The stderr sentence in `annotate.sh` is true as far as it goes: the resume
  `sed` has no stderr redirect.
- **Item 4.2** (`justfile:17-46`). `tracked()` is renamed `lint_paths()` at the
  definition and both call sites (`:34`, `:36`). A whole-tree grep outside
  `plans/` and `dist/` finds no stale `tracked()` or `tracked '`. The comment
  states both scopes against `scripts/lib/tracked.sh`.
- **The python compile step:** the outline's form was
  `PYTHONDONTWRITEBYTECODE=1 python3 -m py_compile`. The job used a
  `compile()` one-liner instead and gave a reason, and that reason holds.
  `PYTHONDONTWRITEBYTECODE=1 python3 -m py_compile ok.py` in scratch still
  wrote `__pycache__/ok.cpython-314.pyc`. The one-liner exits 1 with a
  `SyntaxError` on a bad file, writes nothing, and passes on both tools. The
  step runs ahead of `tests`.
- **Lint:** `shellcheck` on `hooks/*.sh lib/*.sh scripts/*.sh scripts/lib/*.sh`
  is clean, and so is `bash -n` on each. All the files are under their caps
  (`lib/probes.sh` 338 is the largest).
- **`hooks/check-jq.sh`:**
  - under `env -i PATH=/nonexistent` it exits 0 with one JSON value and empty
    stderr;
  - with jq on PATH it prints 0 bytes.
- **Major 1's code path** (`lib/matchers.sh:117-119`):
  - `?? .claude/skills` plus `?? .claude/skills/` counts once (no verdict);
  - a long-format `.bashrc` plus `.claude/skills/` fires;
  - trailing blanks and tabs are tolerated.
- **Carried items still present, not counted:**
  - the previous code m-8 (`crw-` prefilter; see m-5 above);
  - code m-9 in `tests/extract-fixtures.py`: `e.get("timestamp", "")[:10]` at
    `:158` still crashes on a null timestamp, and `(b.get("input") or {})` at
    `:163` on a non-dict input.
- **Unchanged in this job and re-read with no new finding:**
  `scripts/check-line-limits.sh`, `scripts/check-links.sh`,
  `scripts/lib/tracked.sh`, `scripts/lib/strip-code.awk`,
  `scripts/run-bats.sh`, `lib/probes-readonly.sh` and
  `lib/probes-readonly-facts.sh`. Their documented stderr discards, in
  `_readonly_repo_facts` and the BSD `stat -f` probe, each carry a written
  reason.
