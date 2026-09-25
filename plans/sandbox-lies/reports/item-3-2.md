# Item 3.2 — candidate triage and measurement

2026-09-25. Executes Item 3.2 of `plans/sandbox-lies/runbook.md` for
`readonly-path`, `tmpdir-unset`, `resume-lost`, `zellij-socket` and
`seccomp-init`. Records land in `docs/references/detectors.md` (398 lines
after `just format-docs`).

Outcome:

| candidate | hits | true | precision | decision |
|---|---:|---:|---:|---|
| `readonly-path` | 162 | 157 | 97% if the 5 gated are false | **gated — no `Decision:` line** |
| `tmpdir-unset` | 13 | 13 | 100% | ships |
| `resume-lost` | 2 | 2 | 100% (two-hit base) | ships |
| `zellij-socket` | 0 | 0 | — | stays a candidate (zero true positives) |
| `seccomp-init` | 8 | 8 | 100% | ships |

A hit is a match the detector's flag policy lets fire; the flag is joined from
the paired tool-use input (`dangerouslyDisableSandbox`, absent read as false).

## Method

Layer 1. `plans/2026-09-02-sandbox-detector-replay.py` run unchanged through a
scratch driver (`/tmp/claude/sandbox-lies/replay-candidates.py`) that imports
it and swaps its result matchers for the candidates' bare strings and disables
its command matchers. Corpus: 3,914 JSONL files, 34 projects, 55,877 Bash pairs.

| replay matcher (bare string) | hits |
|---|---:|
| EROFS message anywhere | 487 |
| EBUSY message anywhere | 256 |
| inter-device move text | 60 |
| refusal naming a one-component root path (bare form) | 253 |
| same, quoted form | 123 |
| resume refusal, exact case | 65 |
| resume refusal, case-blind | 243 |
| zellij refusal, exact | 65 |
| zellij refusal, case-blind | 233 |
| seccomp tool name | 241 |
| the `unshare` clause | 234 |

The bare strings are dominated by the store quoting itself (the memory file's
symptom table, its index line, `grep -n`/`cat -n` of either, diffs of it), so
each candidate took a line-shape discriminator.

Layer 2. `tests/corpus-eval.py` extended (prefilter strings for the five, the
flag and the transcript line number carried into the manifest, aggregate split
by flag). `extract` over 3,915 files, 55,896 pairs: 3,765 prefilter survivors.
Arbiter: scratch `/tmp/claude/sandbox-lies/candidates.sh` (not committed),
run over the survivors with `xargs -0 -n 500`; 434 survivors drew a verdict.

## Per candidate

### readonly-path — gated

- Replay: 487 EROFS / 256 EBUSY / 60 inter-device. Sample: live refusals from
  `cp`, `mv`, `rm`, `rmdir`, `mkdir`, `touch`, `tee`, `sed`, `mktemp`, bash's
  redirect (`/bin/bash: line N:`), git `error:`/`fatal:`/`warning:`, uv's
  indented `Caused by:`, Python `OSError`; the rest the store quoting itself.
- Discriminator: a line starting with a tool's own prefix (run free of blanks,
  backticks, pipes and colons, then colon-space) and ending in colon-space plus
  the EROFS or EBUSY message; or Python's line-start exception name ending in
  `Error` with `[Errno 30|16]`, the message and a colon. Why: every live form
  in the sample puts the errno text last after the tool's prefix; every store
  quotation sits mid-line (backticks, table cells, `grep -n` locators, diff
  markers, a wrapped prose line). The Python form added 11 hits the first form
  missed, all 12 of its matches live (`.claude/settings.json` and
  `hooks/hooks.json` among them). Not covered: uv's indented `Caused by:` (a
  leading blank defeats the anchor) — a recall loss, not a precision one.
- Corpus-eval: 162 hits (151 + 11 Python-only), none with the flag set, across
  19 projects, 2026-06-23 to 2026-09-25; 11 from this project's own traffic
  (sandbox probes, scratch writes to `/tmp`). 157 true: sandbox refusals under
  `/tmp`, `~/.cache`, `~/.claude`, `~/.claude/jobs`, sibling repositories'
  inboxes and `plugin-dev/`, harness-mounted `.git/config`, masks under
  `git clean -f`/`rm`, `hooks/` under `sed -i`.
- False positives: 5, none self-reference, none the named residual as written
  ("a genuinely read-only mount"). Recorded under the candidate; escalated
  below. No `Decision:` line, no fixtures, no `expected_for` rows.

### tmpdir-unset — ships

- Replay: 253 bare-form / 123 quoted-form; the store's symptom-table quotation
  of the `$TMPDIR` example is the largest single class, then live `cp`, `ls`,
  bash-redirect refusals on one-component root paths.
- Discriminator: tool prefix at line start (as `readonly-path`), optional
  bash `line N:` locator, a one-component path directly under `/` — bare, or
  in straight or GNU curly quotes after the tool's words — ending in
  colon-space plus the permission-denied or missing-file message. Why: the
  collapse shape is exactly one component under root; the tool prefix drops
  the store's backtick quotation. Permission-denied only would give 9 of the
  13; the missing-file half adds 4 true (`cp` of a backup, `ls` of a worktree,
  `bash` of a script, a `rmdir` loop reading a list).
- Corpus-eval: 195 matches, 13 with the flag set. The 13 fire; 13 true, each a
  command naming `$TMPDIR` (Emploi, devddaanet ×6, gitlore, handoff ×2, micro
  ×2, pytest-md). 100%. No pilot traffic. The 182 unflagged matches are silent
  under the policy: sandboxed collapses (the instability clause, skill-mapped)
  and deliberately missing paths in tests.
- False positives: none.
- Fixtures: `fire-tmpdir-unset-redirect` (devddaanet 2026-09-02, bash redirect,
  permission denied), `fire-tmpdir-unset-cp-stat` (micro 2026-07-04, `cp`
  quoted form, missing file), `quiet-tmpdir-unset-deep-path` (micro
  2026-07-22, `ls` missing-file refusal on a deep path, flag set).

### resume-lost — ships

- Replay: 65 exact / 243 case-blind; three at a line start, the rest the store
  (symptom table, index line, the eval-harness paragraph, this repo's own
  `detectors.md`).
- Discriminator: the refusal from the start of its line, then the id (hex and
  hyphens) and only trailing blanks. Why: `claude` prints it with no prefix;
  every quotation is mid-line or truncated.
- Corpus-eval: 3 matches; 1 with the flag set (handoff 2026-08-14, a
  deliberate resume of an all-zero id — silent under the policy, which fires
  only when the flag is false). 2 hits, 2 true, one gitlore session on
  2026-07-17 reproducing the transcript loss (eval runner, then an A/B probe).
  100% on a two-hit base. No pilot traffic.
- False positives: none among hits.
- Fixtures: `fire-resume-lost-two-turn` (gitlore 2026-07-17),
  `quiet-resume-lost-index-line` (handoff 2026-09-20, the memory index line
  naming the refusal mid-line).

### zellij-socket — stays a candidate

- Replay: 65 exact / 233 case-blind, every one a quotation of the store (or,
  for this session's own triage, a replay excerpt).
- Discriminator measured: the refusal at a line start. No live instance exists
  to select from.
- Corpus-eval: 0 hits; case-blind unanchored, 67, all quotations. Zero true
  positives — recorded as such; `Decision: stays a candidate`.

### seccomp-init — ships

- Replay: 241 tool-name / 234 `unshare`-clause; live instances are the whole
  result, the rest table cells, a section heading and inline code.
- Discriminator: the failure alone on its line from its start (trailing
  blanks allowed). Why: live, it is the entire output, after the exit-code
  line or alone.
- Corpus-eval: 8 hits, 8 true, none flagged, all 2026-08-14 (edify ×4,
  handoff ×3, gitlore ×1; `sed`, `grep`, `git show`, `pytest`, a loop). 100%.
  No pilot traffic.
- Fixtures: `fire-seccomp-init-sed` (edify 2026-08-14),
  `quiet-seccomp-init-heading` (gitlore 2026-09-01, `grep -n "^## "` of the
  memory file listing its section heading).

Every new fixture was checked: `lib/matchers.sh` prints nothing on each, the
scratch arbiter fires its own detector on each `fire-*` and nothing on each
`quiet-*`. All seven rows sit in `expected_for` expecting no verdict.

## Gated false positives — `readonly-path`

Five hits are neither self-reference (D-10) nor the named residual. Each below:
transcript (under `~/.claude/projects/`), JSONL line, context, proposed
classification. Context lines are indented here so this file stays quiet.

1. `-Users-david-code-gitlore/0e8cfc79-d01e-41bf-89d2-c98c48bdaf13.jsonl:1051`,
   2026-07-23, command `tail -40 <session tasks dir>/b1owvqmbh.output`:

   ```text
     /bin/bash: line 1: /Users/david/.claude/jobs/0e8cfc79/tmp/precommit.log: Read-only file system
     /bin/bash: line 1: /Users/david/.claude/jobs/0e8cfc79/tmp/precommit.log: Read-only file system
   ```

2. `-Users-david-code-gitlore/a9bf3102-9e37-4a28-86a7-939d19b02f31/subagents/agent-aitem-1-1-s1-green-2c3c5a1028421824.jsonl:69`,
   2026-09-07, command `cat "<other session tasks dir>/bo7z9uyq2.output" 2>&1 | tail -100`:

   ```text
     /bin/bash: line 1: /tmp/gitlore-precommit-item11s1.log: Read-only file system

     [exited with code 1]
   ```

3. `-Users-david-code-gitlore/70469e22-dd01-4be3-b832-c6acebed9e1e/subagents/agent-aitem-1-3-s2-green-6271ca992e8ef280.jsonl:183`,
   2026-09-10, command `cat <other session tasks dir>/bss1dzd8y.output`:

   ```text
     /bin/bash: line 1: /tmp/amb1.out: Read-only file system
     tail: cannot open '/tmp/amb1.out' for reading: No such file or directory
   ```

   Proposed for 1–3: **true positive**. The text is a background Bash task's
   own result — bash refusing that task's redirect under the sandbox — and a
   read of the task output file is how that result reaches the model. The
   diagnosis is right; the verdict's "re-run the whole call" would target the
   read rather than the backgrounded command. Alternative: a new named
   residual, "a background task's output read back".

4. `-Users-david-code-gitlore/f525585e-baa9-47aa-87ee-1f6e5be1dfa5/subagents/agent-akilled-take-repro-08c2e50907018dac.jsonl:247`,
   2026-09-19, command `cat "$TMPDIR/debug/out.log"`:

   ```text
     error: could not lock config file /Users/david/.gitconfig: Read-only file system
     pin=eb2cf81… live=6806d84… head=eb2cf81…
     === take #1 (killed) ===
   ```

   Proposed: same class as 1–3 — a log of this agent's own earlier sandboxed
   run (a nested `claude -p` whose hook tried to write the user git config),
   read back. True positive on the diagnosis, or the same new residual.

5. `-Users-david-code-gitlore/fca55784-0b9d-4ea8-b978-10c70f459188/subagents/agent-a40c07f35c6405b98.jsonl:122`,
   2026-09-14, a `python3` heredoc splicing a bats file, then running it:

   ```text
     /bin/bash: line 131: gitlore_relay_write: command not found
     cat: '': No such file or directory
     mkdir: cannot create directory ‘/gitlore-relay-s1-a2-1700000000-2-sync’: Read-only file system
   ```

   Proposed: **the named residual in substance** — the path sits directly
   under `/`, from an empty variable, and is not writable outside the sandbox
   either, so the probe prints `readonly` and the verdict says "not a sandbox
   effect". The entry's residual reads "a genuinely read-only mount"; widening
   it to "a path not writable outside the sandbox either" would cover this.

If all five are accepted as proposed, `readonly-path` ships at 162 hits,
157 true + 4 true-on-diagnosis (or 5 residual-classified), and needs its
`Decision: ships` line, a `fire-readonly-path-*`/`quiet-readonly-path-*` pair
cut, and two `expected_for` rows before Item 4.3.

## Pilot traffic this session adds

This session printed survivor texts raw while triaging (`head` of the five
gated survivors, `cut` of the fire candidates), so the next re-measurement
(Items 4.2 and 4.3 re-run this pass) will find D-10 self-reference hits from
the sandbox-lies project dated 2026-09-25: one call carrying the `resume-lost`
and `seccomp-init` shapes, one carrying several `readonly-path` shapes. The
`tmpdir-unset` shape printed there ran unflagged and stays silent.

## design.md status lines

Not edited (400/400). Owed, in my reading:

- NFR-1: `Partial (harness promoted)` → `Partial (harness promoted; candidates
  measured 2026-09-25, Item 3.2)`.
- FR-7: stays `Planned` until Items 4.2/4.3 ship code; its "five candidates"
  count will need `zellij-socket` noted as staying a candidate when it flips.
- FR-8: stays `Done` — the new fixtures are reproducible from the script
  (`python3 tests/extract-fixtures.py <names>`).

## Changes

- `docs/references/detectors.md` — Candidates intro gains the measurement
  line; each candidate's `Matcher.` paragraph states its discriminator;
  `Corpus.` paragraphs; `Decision:` lines for four; `readonly-path`'s five
  unclassified false positives listed, no decision.
- `tests/corpus-eval.py` — prefilter strings for the five candidates; the
  flag joined from the tool-use input and the JSONL line number in the
  manifest; aggregate prints the flagged count per verdict and each hit's
  transcript line.
- `tests/extract-fixtures.py` — seven cut-list entries; optional fixture
  names on the command line so new fixtures are cut without re-picking the
  committed ones (entries with no day or a size preference can drift as the
  corpus grows).
- `tests/fixtures/` — the seven fixtures above.
- `tests/matchers.bats` — seven `expected_for` rows, no verdict.

## Commands run

| command | result |
|---|---|
| `python3 /tmp/claude/sandbox-lies/replay-candidates.py` (layer-1 replay) | pass |
| `python3 tests/corpus-eval.py extract --outdir /tmp/claude/sandbox-lies/eval` | pass, 3,765 survivors |
| `find … -print0 \| xargs -0 -n 500 bash /tmp/claude/sandbox-lies/candidates.sh` | pass, 434 with a verdict |
| `python3 tests/corpus-eval.py aggregate --outdir /tmp/claude/sandbox-lies/eval` | pass |
| `python3 tests/extract-fixtures.py <seven names>` | pass, 7 cut |
| `bash lib/matchers.sh` and the scratch arbiter over each new fixture and each changed file | pass (fixtures as expected; changed files quiet under both) |
| `just format-docs` | pass |
| `just precommit` | pass: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests (131 bats) |

Runs were sequential, foreground, with `free -m` at 1.3–1.4 GB available
before each.
