# Phase 1 checkpoint review — promote the pilot

Reviewed: `e873bf4..HEAD` (Items 1.1–1.4) against runbook Phase 1, the
Cross-cutting section, the Requirements mapping, the outline, and the recall
artifact's memory files. Item 1.4 is reviewed in full because it had no
item-level review. The fixes below are uncommitted in the tree:
`docs/design.md`, `docs/references/detectors.md`, `lib/matchers.sh` and
`tests/matchers.bats`.

## Verdict

Phase 1 meets its contract. There are no critical or major findings. Four
minor fixes are applied. Three of them make the docs say only what the Item
1.4 recording actually shows. The fourth corrects a stale comment reference
that Item 1.2 made wrong.

## Item 1.4 — full review

- **Fixtures against raw recordings.** After deleting the five scrubbed
  fields (`session_id`, `transcript_path`, `cwd`, `prompt_id`,
  `tool_use_id`), each fixture is `jq -S`-identical to the first line of
  `/tmp/claude/sandbox-lies-payloads/{post,failure}.jsonl`. The placeholders
  agree with each other: `transcript_path`'s project dir `-tmp-scratch`
  matches `cwd` `/tmp/scratch`, and both events share one session id and one
  prompt id, as in the raw recording. `command grep` finds no `/Users/`, no
  real `toolu_` id, and neither real session id. `jq .` parses both files.
- **Interfaces.** `payload-failure.json` has `error` and no `tool_input` flag,
  so tests have a field to overwrite and can add the flag. `payload-post.json`
  has `tool_response.stdout` and `.stderr`. Both conform.
- **Byte-identical claim (D-13, detectors.md, changelog).** Verified against
  the nested sessions' transcripts. In both runs, the `tool_result` `content`
  of each call equals the payload's `tool_response.stdout` (success) or
  `error` (failure) exactly. The fixtures were cut from that same `content`
  field (`tests/extract-fixtures.py`), so the reopen-if does not fire. The
  transcript's `toolUseResult` string prepends `Error: `, but no fixture reads
  that field.
- **Merged stream, sandboxed and unsandboxed.** Run 1 carries no flag: its
  third call was refused with `Read-only file system`, so that session was
  sandboxed. Run 2 (`r2/`) carries `dangerouslyDisableSandbox: true` on both
  calls. Both runs show stderr merged into stdout and an empty
  `tool_response.stderr`. The claim holds.
- **Flag.** It is absent from `tool_input` when unset (run 1) and `true` when
  set (run 2). The detectors.md record is correct.
- **L-5.** The third call's payload `error` and the model's `tool_result` are
  both `Exit code 1` plus bash's `Read-only file system` line, with no
  annotation. The detectors.md and changelog record is correct.
- **CC version.** Every transcript entry of both runs carries
  `version: 2.1.280`.
- **Escalation reflected.** D-13, the detectors.md Conventions and the
  changelog entry agree. No file in `docs/`, `BRIEF.md` or the root still
  states separate streams or a stderr-then-stdout order in `error`. FR-3's
  "stdout then stderr from `tool_response`" describes how the hook rebuilds
  the text. It matches the Conventions definition and is not a stream-layout
  claim.

## Fixes applied

1. **Minor — detectors.md said the payload carries "the call's `cwd`".** The
   recording cannot show that. No call changed directory, so `cwd` was simply
   the session's working directory. Where it lands after a `cd` inside the
   call is unrecorded. The Conventions now state what was observed and name
   that gap. This matters because Phase 3's relative-lock-path resolution
   leans on `cwd`. The residual is small, since git prints lock paths
   absolute.
2. **Minor — design.md Architecture "Paths" made the same claim** ("the
   directory the call ran in"). That breaks the hub's rule of never claiming
   more than the reference carries. Replaced it with a parenthetical saying
   the post-`cd` value is unrecorded.
3. **Minor — design.md L-5 contradicted the recording.** It stated without
   qualification that the harness appends a sandbox-violation annotation to
   a sandboxed failure. The recorded refused write carried none. Kept the
   general claim, attributed to the bundle reading, and added the recorded
   exception. L-5 still says the recorded payloads bound what matchers see.
   Scope of this change: only the one recorded case (a Linux filesystem write
   refused by the allowlist) is stated as an exception. The general
   annotation claim is not removed, because the recording did not test any
   other violation class, such as a network denial.
4. **Minor — stale `just format-docs` references in `lib/matchers.sh` (the
   config-lock comment) and `tests/matchers.bats` (the live-store follow-on
   case).** The pilot comments credited `just format-docs` with wrapping the
   memory store. Item 1.2 added a `format-docs` recipe to this repo, and its
   `.rumdl.toml` scope excludes `memory/`. The comments now point at a real
   recipe that does not do what they claim. Reworded both to say the store is
   hard-wrapped, and in the bats comment, that this repo's recipe does not
   reach `memory/`.
5. **Minor — FR-8's pin said "the fixture set is reproducible from the
   script".** `tests/fixtures/` now also holds the two recorded payloads,
   which `tests/extract-fixtures.py` does not produce. Narrowed it to the
   `fire-*` and `quiet-*` set.

`rumdl fmt` reflowed the three edited paragraphs. `docs/design.md` is now 395
lines, under Item 2.1's 400-line cap, and `detectors.md` is 318.

## Items 1.1–1.3, cross-item

- **Promotion.** The renames are history-preserving. `lib/matchers.sh` and
  `tests/matchers.bats` build the git-lock follow-on from two fragments. The
  corpus-eval and extract-fixtures docstrings name the new paths.
  `plans/sandbox-detector-pilot/` is gone.
- **Gate.** The `precommit` recipe matches Item 1.2: NUL-delimited file lists,
  a `report` recap, and rumdl `fmt --check` ahead of the tests. `.envrc`,
  `pyproject.toml`, `uv.lock`, `.gitignore` and `.rumdl.toml` conform. The
  run-bats log prefix names this repo.
- **docs.bats.** It skips `tests/fixtures/`, which covers the new `.json`
  payloads. `matchers.bats`' fixture-to-case check globs only `*.txt`, so the
  payloads do not break it.
- **Status lines against the legend.** FR-2, FR-8, FR-11 and NFR-2 are Done,
  and each is pinned by a suite that `just precommit` runs. NFR-1 and NFR-5
  are Partial, with the pending part named. All are honest.

## Verification

- `just precommit` before and after the fixes:
  `precommit passed: plugin.json, shellcheck, bash -n, rumdl, tests`. 27
  passed, 0 failed. The TAP log has no `# skip` line, and all 27 cases are
  `ok`.
- The FR-11 sweep (`tests/docs.bats`) stays green over the edited files.
- The tree has no stray scratch state. Every untracked path is one of the
  sandbox's mask names, and `.venv/` is ignored.

## Not changed, for the lead

- The design header still reads "Status: Planned. Nothing in this document is
  live … pilot code", while four requirements are Done. Item 1.1's review left
  this to Item 8.2's `## Now` update. It is true in the sense that no hook
  runs yet.
- The recording did not cover a large output that the harness truncates or
  persists (the outline's "truncation marker" risk). Whether `tool_response`
  and `error` then carry the full text or the model-visible preview is still
  open. Phase 2 is the natural place to pin it.
- The success-text rebuild (stdout, newline, stderr) ends in a newline that
  the model-visible result lacks. This is harmless to the line-oriented
  matchers.
- Run 2 also shows `dangerouslyDisableSandbox: true` echoed inside
  `tool_response` on `PostToolUse`. The flag's source stays `tool_input`, per
  the Conventions.
