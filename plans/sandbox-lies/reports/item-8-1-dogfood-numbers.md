# Item 8.1 dogfood numbers — tmpdir-unset and readonly-path/nopath

## Method

All commands ran from `/Users/david/code/sandbox-lies`, reading
`~/.claude/projects` with the sandbox disabled, in the foreground.

1. Copied `tests/corpus-eval.py` to a scratch copy at
   `/tmp/claude-1000/item81/corpus-eval-ext.py` (repo copy untouched) and
   added one field to the manifest write: `"version": e.get("version", "")`,
   read off the same transcript entry (`e`) that carries the tool result —
   confirmed present on every entry sampled (`e["version"]`, e.g. `2.1.263`,
   `2.1.272`), so no join-back to the transcript line was needed.
2. `python3 /tmp/claude-1000/item81/corpus-eval-ext.py extract --outdir
   /tmp/claude-1000/item81/out`, sandbox disabled. Denominators:
   `jsonl_files=4055`, `projects_total=34`, `bash_tool_use=58729`,
   `bash_tool_result=58716`, `prefilter_survivors=4306`,
   `unparsable_lines=0`.
3. Ran the shell loop from the script's own docstring over the 4306
   survivor files against `lib/matchers.sh` (repo copy, unmodified),
   producing `verdicts.tsv` with 1130 survivor files carrying at least one
   verdict.
4. `aggregate` (scratch copy) for the overview table; per-verdict subsets
   pulled from `manifest.jsonl` + `verdicts.tsv` with ad hoc `python3 -`
   scripts (not written to the repo).
5. For question 2, sourced the repo's own `lib/probes.sh` (which sources
   `lib/probes-readonly.sh`) and ran `probe_readonly_path false / ''` on
   each of the 195 `readonly-path` survivor files, taking only the first
   line of output. Per the task's own instruction, cwd fell back to `/`
   (the manifest carries no per-call cwd) and command was passed empty;
   neither affects the `nopath` vs. path-extracted split, since that split
   is decided by `_readonly_path_line` + `_probe_readonly_path_from_line`
   before any cwd-based resolution or command-based fact printing runs.
6. `nopath` matching lines were re-extracted with `_readonly_path_line`
   (the same discriminator the matcher and probe share) rather than
   re-quoting the whole survivor text.

Self-pollution note: this session's own project directory is
`-Users-david-code-sandbox-lies` (135 survivor files total across all
verdicts). Both answers below are given with and without it.

## Question 1 — does tmpdir-unset ever fire on current CC (2.1.283)?

No. `tmpdir-unset`'s flag policy (`docs/references/detectors.md`,
`hooks/annotate.sh`) is "fires only when the flag is true, silent
otherwise" — that is the sense of "fire" used here. The corpus (4306
survivors) has 100 survivor entries recorded at version 2.1.283, and none
of them carry a `tmpdir-unset` match at all, flagged or not.

Raw matcher hits (`match_tmpdir_unset`, before the flag gate): 201 total,
of which 13 have `dangerouslyDisableSandbox: true` (the ones that actually
fire the hook) and 188 have it false (silent per policy). None of the 13
firing hits come from this session's own project
(`-Users-david-code-sandbox-lies` contributes 15 of the 201 raw matches,
all flag-false) — so the "with self" and "without self" counts for actual
fires are identical: 13 and 13.

Firing hits (`flag=true`) by version and month (identical with/without
self-project, since self contributed none):

| version | month | fires |
|---|---|---|
| 2.1.201 | 2026-07 | 1 |
| 2.1.204 | 2026-07 | 1 |
| 2.1.209 | 2026-07 | 1 |
| 2.1.210 | 2026-07 | 1 |
| 2.1.211 | 2026-07 | 1 |
| 2.1.216 | 2026-07 | 1 |
| 2.1.217 | 2026-07 | 1 |
| 2.1.231 | 2026-08 | 1 |
| 2.1.252 | 2026-09 | 1 |
| 2.1.258 | 2026-09 | 1 |
| 2.1.268 | 2026-09 | 1 |
| 2.1.270 | 2026-09 | 2 |

**Newest version and date with a fire: 2.1.270, 2026-09-13T14:22:34.672Z**
(project `devddaanet`). The other 2.1.270 fire is the same day
(2026-09-13T14:21:13.584Z, same project). Current CC is 2.1.283; the gap
between the newest fire (2.1.270) and current (2.1.283) spans 13 build
versions with zero fires in between, even though the corpus still has raw
(flag-false, silent) `match_tmpdir_unset` hits at every recent version up
to 2.1.281 (12, 9, 17, 3, 9 and 15 raw matches at 2.1.271, 2.1.272,
2.1.274, 2.1.275, 2.1.276 and 2.1.281 respectively, all flag-false). This
is consistent with `detectors.md`'s dated caveat that an unsandboxed
call's `$TMPDIR` read `/tmp` rather than empty as of 2.1.281 — the shape
still appears under the sandbox (deliberately missing paths, or genuine
collapses that stay flag-false and hence silent), but the flag-true
collapse that would make the hook actually speak has not recurred since
2.1.270.

## Question 2 — how often does readonly-path yield nopath?

All 195 `readonly-path` matcher hits in the corpus carry
`dangerouslyDisableSandbox: false` (0 have the flag true, matching
`readonly-path`'s policy of running silently under the sandbox rather than
never occurring flagged — empirically, none of the 195 happened to be
flagged calls). So the flag-false share is the whole set; there is no
flag-true share to compare it against.

| split | nopath | path extracted (writable+readonly) | total | nopath % |
|---|---|---|---|---|
| all hits, flag=false (incl. self) | 11 | 184 | 195 | 5.6% |
| all hits, flag=false, excl. self-project | 10 | 142 | 152 | 6.6% |
| self-project only (`sandbox-lies`) | 1 | 42 | 43 | 2.3% |
| flag=true (any project) | 0 | 0 | 0 | n/a |

Path-extracted here folds together `writable` (0 of 195 today) and
`readonly` (184 of 195) per the task's instruction, since that split
depends on today's filesystem rather than on the question asked.

### nopath lines (matching line, trimmed to 200 chars), grouped by shape

Each line is quoted as a list item, so this report does not itself fire
`readonly-path` when read back (FR-11).

11 `nopath` hits found; 10 shown below (one of the four duplicate
"could not write config file" lines omitted since it is byte-identical
to the three others quoted) — every distinct shape is represented.

**Shape: `tee: <path>: Read-only file system`** (2 of 2 shown)
- `tee: /tmp/release-test-out.txt: Read-only file system`
- `tee: /tmp/collect_before.txt: Read-only file system`

**Shape: `sed: couldn't open temporary file <relative-path>: Read-only file system`** (2 of 2 shown)
- `sed: couldn't open temporary file hooks/sedUWZIXj: Read-only file system`
- `sed: couldn't open temporary file hooks/sed7bAEpG: Read-only file system`

**Shape: `warning: failed to remove <name>: Device or resource busy`** (2 of 2 shown)
- `warning: failed to remove .bash_profile: Device or resource busy`
- `warning: failed to remove .bash_profile: Device or resource busy`

**Shape: `error: could not write config file <path>: Device or resource busy`** (3 of 4 shown; 1 identical duplicate omitted)
- `error: could not write config file .git/config: Device or resource busy`
- `error: could not write config file .git/config: Device or resource busy`
- `error: could not write config file .git/config: Device or resource busy`

**Shape: `cp: cannot create regular file <empty>: Read-only file system`** (1 of 1 shown)
- `cp: cannot create regular file : Read-only file system`

All five shapes are genuine near-misses of the probe's four recognised
unquoted forms (bash's `line N:`, dash's `N: cannot create`, git's
`error: could not lock config file` and `fatal: cannot mkdir`) and of its
quoted-segment rule: `tee` and the `warning: failed to remove` line carry
no quotes and no recognised locator word; `sed`'s temp-file message names
a relative path with no quotes either; `could not write config file`
differs from the one config-lock wording the extractor recognises
(`could not lock config file`) by one word; and the `cp` line has an empty
operand (`cp` printed nothing between "regular file" and the colon), so
there is no path text to extract at all.

## Caveats

- The corpus grows every session (including this one); the two flag
  splits given above (with/without `-Users-david-code-sandbox-lies`) make
  the self-pollution visible rather than eliminating it — other repos'
  sessions studying these same detectors are not excluded.
- `readonly-path`'s `writable`/`readonly` split is a function of today's
  filesystem (whether the named path is still writable outside the
  sandbox right now), not of the corpus; it is reported only as a
  denominator component here, not as a finding.
- Version is read from the transcript entry that carries the Bash tool
  result (`e["version"]`), which is the CC build that *wrote* that line,
  not necessarily the build in use when a resumed/rewritten session was
  first started.
- Scratch artifacts (`corpus-eval-ext.py`, `out/` with `manifest.jsonl`,
  `survivors/`, `verdicts.tsv`, `probe_outcomes.tsv`, `readonly_files.txt`)
  live under `/tmp/claude-1000/item81/` and were not written into the
  repository.
