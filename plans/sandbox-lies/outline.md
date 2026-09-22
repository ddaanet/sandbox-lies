# Outline: sandbox-lies first build

## Provenance

- **Derived from:** none — first plan in this repository. `BRIEF.md` is the
  requirements source; `plans/brief-sandbox-detector-pilot.md` is inherited
  evidence, not a superseded plan.
- **Base:** `52e6dd82b831a1cc2b7b516d4c248df6fb1ebc8c`

The design itself is `docs/design.md` (living) with mechanism in
`docs/references/detectors.md`. This outline is the plan for the first build
and carries only what the design does not: sequencing, scope of this job,
the design amendments the build depends on, and the open questions.

## Approach

Promote the pilot into the plugin layout, wrap the matchers in one hook
script registered on `PostToolUse` and `PostToolUseFailure` (matcher `Bash`)
that emits one JSON, add the probes, add the five candidate detectors behind
a corpus replay, write the `sandbox-lies` skill, retiring each memory
section in the commit that lands its translation (D-11), then dogfood. Decisions D-1 to D-14 in `docs/design.md` are settled; this
outline does not restate them. Where the build found a gap in the design,
the amendment is listed below and lands in `docs/design.md` or
`detectors.md` before the phase it gates.

## Design amendments

All eight were applied to `docs/design.md` and `detectors.md` on 2026-09-22
(A-1 as D-13, A-4's `unknown` outcome as D-14). They stay listed here as the
record of what the review changed; the phases' tests assert the design's
text, not this outline.

- **A-1 · Failed calls fire `PostToolUseFailure`, not `PostToolUse`**
  (gates Phase 2). In the CC 2.1.280 bundle a Bash call with a non-zero exit
  throws, and the tool-failure path dispatches `PostToolUseFailure` with the
  result text in an `error` string; `PostToolUse` (with `tool_response`) runs
  only on success. Nearly every detector's symptom is a failing command, so a
  `PostToolUse`-only hook sees just the piped cases. FR-1, FR-3, D-3 and the
  Architecture name one event; they become one script on two events. Each
  call fires exactly one of the two, so composition and D-3 still hold.
- **A-2 · FR-11's scope is red today** (gates Phase 2). Five tracked files
  fire `git-lock` now: `matchers.sh` and `matchers.bats` (their grep literals
  carry git's follow-on sentence whole), and three frozen pilot artefacts in
  `plans/` (the layer-1 replay script, its hits JSONL, the layer-2 report).
  Proposed: the promoted sources build each literal from two fragments so
  the bytes on disk never hold the whole sentence; the dated `plans/`
  evidence is exempted by name in `tests/docs.bats`, and FR-11/D-10 record
  that exemption as the second residual beside fixture reads (Q8).
- **A-3 · Probe output shape** (gates Phase 3). The design says a probe
  returns one outcome token, but the verdicts interpolate values (pid, byte
  count, age, path, percentages). Proposed contract: a probe reads the
  result text on stdin, takes the flag as `$1`, prints the outcome token on
  its first line and `key=value` lines after it; `verdict_<name>` reads both.
- **A-4 · Lock outcomes** (gates Phase 3). Three additions to the git-lock
  table: a lock path that stats as a character device is `mask`
  (Architecture's reopen-if, not yet in the table); no holder tool available
  is a distinct `unknown` outcome whose verdict carries no removal
  instruction; and the `mask` verdict gains the repeat-failure clause `gone`
  already has (an identical failure after the unsandboxed retry is the
  hook-env leak), because an `excludedCommands`-unsandboxed call carries flag
  false and lands in `mask` (D-8, L-2).
- **A-5 · Flag policy per detector** (gates Phase 2). FR-5 pairs every
  fixture with both flag values, but `detectors.md` defines the flag-true
  outcome only for `git-lock` and a few candidates. Each shipped detector
  needs its flag-true behaviour (same verdict, reworded, or silent) stated
  before `tests/hook.bats` can assert it. The gating lives in the hook or
  the verdict, never the matcher (FR-2 reads text only).
- **A-6 · FR-10's reference check** (gates Phase 6). "Fails if the file is
  still referenced from this repo" fails on `docs/design.md` itself, the
  changelog, `BRIEF.md` and `plans/`, which name the file historically. The
  check covers live pointers only: `hooks/`, `lib/`, `skills/`, `tests/`
  outside `tests/fixtures/`, `CLAUDE.md`, `README.md`.
- **A-7 · Candidate matchers need a shape discriminator** (gates Phase 4).
  `detectors.md` gives each candidate as a bare substring. Once built, a
  bare substring fires on `detectors.md`, the skill and this repo's own
  traffic (FR-11, NFR-1). Each candidate gets an anchor the replay selects
  (line start, the tool's own prefix, or a follow-on), and the candidate
  entries in `detectors.md` describe the strings rather than quote them,
  as its Conventions paragraph already requires.
- **A-8 · The hook buffers in memory** (gates Phase 2). `detect` buffers
  through `mktemp` under `${TMPDIR:-/tmp}`; hooks run outside the sandbox,
  where `$TMPDIR` is unset, so that is `/tmp` — and when `/tmp` is full the
  `mktemp` fails and `tmp-full` goes silent exactly when it should fire. The
  hook holds the text in a shell variable. NFR-4 then reads "writes
  nothing".

## Phases

### Phase 1 — promote the pilot (general)

- Finish repo init first: commit the staged tier mount (`.gitmodules`,
  `memory`, `.envrc`) and confirm `just --list` compiles.
- Move `plans/sandbox-detector-pilot/matchers.sh` → `lib/matchers.sh`,
  `matchers.bats` → `tests/matchers.bats`, `fixtures/` → `tests/fixtures/`,
  `extract-fixtures.py` → `tests/extract-fixtures.py`. Update the bats
  `load` path, the `PILOT` variables and the live-memory path in the two
  cases that read it. Split the grep literals per A-2.
- Promote the layer-2 harness
  `plans/2026-09-03-sandbox-matcher-corpus-eval.py` →
  `tests/corpus-eval.py`, pointing at `lib/matchers.sh` (NFR-1 pins "the
  replay harness under `tests/`"). The layer-1 replay script and the reports
  stay in `plans/` as frozen evidence.
- `scripts/check-line-limits.sh` (400 lines for `.md`, `.sh`, `.bats`,
  `.py`; 200 for `SKILL.md`; ported from edify's, without the allowlist) and
  `scripts/check-links.sh` (every relative markdown link resolves).
- `justfile`: `test` runs `scripts/run-bats.sh tests/`; `precommit` adds
  `shellcheck`, `bash -n`, the two check scripts and `just test`. The
  `jq empty hooks/hooks.json` check joins in Phase 2, when the file exists.
- Delete the promoted files from `plans/`.
- Gate: 26 pass, 0 skip, under BSD stubs. Read the skip count from the TAP
  log — `run-bats.sh` counts a skip as passed.

### Phase 2 — the hook (tdd)

- Record the live payloads first: in a scratch directory (a `claude -p`
  runs the `SessionStart` hooks of the repo it starts in), an unsandboxed
  nested `claude -p --settings <scratch>` whose hook dumps stdin on both
  events; one succeeding and one failing Bash call. Save as
  `tests/fixtures/payload-post.json` and `tests/fixtures/payload-failure.json`,
  and confirm the field names, the text each carries against a fixture's
  shape, and whether the flag is absent or `false` when unset.
- `hooks/hooks.json`: `PostToolUse` and `PostToolUseFailure`, matcher
  `Bash`, both `bash "${CLAUDE_PLUGIN_ROOT}/hooks/annotate.sh"`, timeout 10
  (A-1).
- `hooks/annotate.sh`: read the payload with `jq`, guarded with
  `select(type == "object")`; the text is `error` on a failure payload and
  stdout, newline, stderr from `tool_response` on a success payload; an
  absent flag is false; hold the text in memory (A-8); run `detect`; for
  each verdict run `probe_<name>` when defined, then `verdict_<name>`; build
  `{"hookSpecificOutput":{"hookEventName":<event>,"additionalContext":…},
  "systemMessage":…}` with `jq -n --arg`. Any parse or runtime failure exits
  0 with no output: a hook that dies is a feature that silently stops.
- `lib/verdicts.sh`: one function per verdict and outcome, text from
  `docs/references/detectors.md`; no verdict instructs a removal (D-7).
- Retire (D-11): delete the phantom-dotfile listing and `git add -A`
  paragraphs from `memory/ddaanet/sandbox-effects.md` in the commit that
  ships their verdicts; the porcelain-gate and `## Context` paragraphs stay
  for Phases 5 and 6.
- `tests/hook.bats`: every fixture through the whole hook, wrapped in the
  payload shape its exit status implies, both flag values, expectations from
  the A-5 policy; probe functions stubbed so a fixture's absolute paths never
  reach the host filesystem. The git-lock and config-lock cases join in
  Phase 3 with their outcomes. Asserts: the JSON carries only
  `hookSpecificOutput.additionalContext` and `systemMessage` (FR-1); quiet
  fixtures yield empty stdout; a malformed or non-object payload yields exit
  0 and empty stdout; `additionalContext` under 2 KB. Record the hook's wall
  time on a quiet fixture (the per-call cost NFR-3 does not bound), not
  gated.
- `tests/verdicts.bats`: each paragraph under 400 chars; `detect` over the
  concatenated verdict texts is silent.
- `tests/docs.bats`: `detect` over every tracked regular file outside
  `tests/fixtures/`, minus the named A-2 exemptions, is silent (FR-11).
  `precommit` gains `jq empty hooks/hooks.json`.

### Phase 3 — lock probes (tdd)

- `lib/probes.sh`: `probe_git_lock`, `probe_config_lock`, to the A-3
  contract. The lock path comes from the error text; git prints it absolute,
  and a relative one resolves against the payload `cwd` (the repository the
  call ran in, per `detectors.md`). `CLAUDE_PROJECT_DIR` anchors only the
  `phantom-*` verdicts (Architecture, Scope anchor).
- Holder check: `lsof -t`, else `fuser`; neither present → `unknown` (A-4).
  `lsof` is absent on the Linux dev box today; `fuser` is present. Size and
  age without GNU-only `stat -c` (BSD `stat` differs; NFR-2).
- `tests/probes.bats` over synthetic trees in `$BATS_TEST_TMPDIR`: absent
  (both flags), present-unheld, present-held (a background `sleep` holding
  the fd), a character device at the lock path (point the probe at
  `/dev/null`), and no holder tool on `PATH`.
- Live reproductions (manual, recorded in `detectors.md` under each
  detector): a sandboxed `git add && git commit` in a repo with a staging
  pre-commit hook → `mask`; a hand-made orphan lock → `orphan`; the same
  lock with a holder → `held`; a sandboxed `git config` write → config-lock
  `mask`. Under the `git:*` exclusion a top-level git call runs unsandboxed,
  so each sandboxed reproduction nests the git call (`sh -c`, a recipe).
- Retire (D-11): delete the `.git/index.lock` section from the memory file
  in the commit that ships the lock verdicts.

### Phase 4 — candidate detectors (tdd, per detector)

- Triage each candidate string with the layer-1 replay
  (`plans/2026-09-02-sandbox-detector-replay.py`): count, sample, pick the
  shape discriminator (A-7).
- Measure the shipping figure with `tests/corpus-eval.py`, the shell matcher
  as arbiter: extend its prefilter with the candidate's string and join the
  flag from the paired tool-use input, since the flag-gated candidates
  cannot be measured on text alone. Record hit count, precision, date and
  pilot-traffic note in `detectors.md` (FR-7, NFR-1).
- Ship rule (D-15): at least one true positive, and every false positive
  classified as self-reference (D-10) or as a named residual recorded in
  `detectors.md`. A candidate with zero true positives is recorded as such
  and stays a candidate.
- Cut fixtures with `tests/extract-fixtures.py` (extend its cut list); add
  the matcher, the `fire-*`/`quiet-*` cases, the flag policy (A-5), the
  verdict.
- `readonly-path` carries its probe, built only if it ships (live: a
  sandboxed write into a sibling worktree → `writable`).
- Retire (D-11): each shipped candidate deletes its memory section in the
  same commit; a candidate that stays a candidate leaves its section in
  place. The `/tmp` section is deleted untranslated (rejected alternative).

### Phase 5 — the skill (general, agentic prose)

- `skills/sandbox-lies/SKILL.md` (under 200 lines; detail in
  `references/` beside it): the baseline exclusions and their
  reach; `excludedCommands` semantics; `dangerouslyDisableSandbox` and
  strict mode; the read-only-inspection default (call the escape directly
  for a read, without asking); `$TMPDIR` scoping, including its instability
  across sandboxed calls; classifier and compounds; recipes that must run
  entirely unsandboxed (`release`, `evals`, a `claude` inside a recipe);
  cleanliness gates and the masks; `ps` namespace; recovering a merge
  interrupted by a read-only path; the `!`-expansion facts. Error strings are
  described, not quoted (FR-11). Third person description naming the
  authoring moments as triggers.
- `README.md`, `LICENSE`, `CLAUDE.md` body (import line stays last).
- Retire (D-11): delete every skill-mapped section from the memory file in
  the commit that ships the skill (translation map in `detectors.md`).

### Phase 6 — dogfood shim and final deletion (general)

- `.bin/claude` shim and `PATH_add .bin` in `.envrc`, handoff style (D-16);
  `direnv allow`; a session started here loads the in-tree plugin.
- When the memory file holds only the `## Context` paragraph: amend the
  phantom-dotfile bullet in `memory/ddaanet/shared-claude.md` with the
  `!`-path clause (Q4), delete the file and both index lines
  (`memory/ddaanet/MEMORY.md`, `memory/MEMORY.md`), rewrite the six inbound
  `[[sandbox-effects]]` links (`cc-bash-background-no-duration-cap`,
  `cc-worktree-bash-guard`, `classifier-denied-self-config`,
  `codex-review-of-design-docs`, `git-add-untracked-deletion`,
  `bang-shell-shared-cwd`) — all in one parent commit; let the gate carry the
  memory, then publish the tier (`/gitlore:push`).
- `tests/matchers.bats`: delete the two cases that read the live memory file
  once it is gone; `quiet-memory-file-read` stays.
- `tests/docs.bats` extended: no live pointer references the retired path
  (A-6).

## Verification standard

The brief's line holds for every suite this build adds, not only the
pilot's: before a tdd phase closes, each new assertion class is turned red
by one deliberate fault (in a matcher, a probe, a verdict, the hook or a
fixture), and each fault asserts it applied before the run. `shellcheck`
stays in `precommit` for the `! grep` assertions bats treats as inert
(SC2314). A green suite that has never been fault-injected closes no phase.

## Scope

**IN:**

- Repo init completion (commit of the staged tier mount).
- Promotion of the pilot suite, fixtures, fixture cutter and layer-2 harness
  (Phase 1).
- The hook on both events, `lib/verdicts.sh`, and the hook, verdict and docs
  suites (Phase 2).
- The two lock probes with their live reproductions (Phase 3).
- Replay, measurement and — under D-15 — the five candidates, with the
  readonly-path probe (Phase 4).
- The `sandbox-lies` skill, `README.md`, `LICENSE`, `CLAUDE.md` (Phase 5).
- Per-section retirement in Phases 2–5; the dogfood shim and the final
  deletion with index lines, inbound links and the `shared-claude.md` bullet
  (Phase 6).
- The line-cap and link-check gates (Phase 1).
- The design amendments A-1 to A-8 in `docs/design.md` and `detectors.md`.

**OUT:**

- Editing `craft`, `prohibitions`, `edify` (their gates are theirs to fix
  from the skill's guidance).
- A `PreToolUse` hook of any kind; `PostToolBatch`; prompt-based hooks.
- Suppressing this repo's own fixture reads (D-10).
- The `!`-expansion path (L-1) beyond the `shared-claude.md` bullet, and
  the items under "Not detectors" in `detectors.md` beyond the skill.
- Re-measuring `phantom-gitadd` once this repo's traffic leaves the corpus
  (the brief's open item; a later pass).
- Releasing (`just release`, a separate step after Phase 6). The relative
  submodule url in `.gitmodules` blocks `/plugin install` and must be fixed
  there (see Risks).

## Resolved questions (2026-09-22)

1. Skill named `sandbox-lies`, in this plugin (D-9).
2. No verdict instructs a removal, conditional or not (D-7).
3. Retirement is immediate per section, in the commit that lands the
   translation (D-11); no wait for dogfooding or release.
4. The existing `shared-claude.md` phantom-dotfile bullet is amended with
   the `!`-path clause, not duplicated.
5. Ship rule as proposed (D-15); a precision floor rejected as noise on
   small bases.
6. `tmp-full` dropped: not reproducible, and a small tmpfs fills on its own;
   not a sandbox effect.
7. Dogfood through a `.bin/claude` shim activated by `.envrc` (D-16).
8. The dated `plans/` evidence is exempt from FR-11 by name.

## Risks

- **Result text shape.** The `error` string and `tool_response` fields may
  not reproduce the text the fixtures were cut from (the `Exit code` line,
  stdout/stderr ordering, a truncation marker). The bundle also shows the
  harness appending its own sandbox-violation annotation to a sandboxed
  failure's output, which changes the text the matchers see and may overlap
  the readonly-path verdict. The live-payload recording opens Phase 2 for
  that reason.
- **Holder check absent.** `lsof` is missing on the Linux dev box; `fuser`
  is the fallback, and `unknown` covers neither (A-4). Degrading to
  `orphan` would hand a held lock a removal instruction.
- **FR-11 red on day one** until A-2 lands; five tracked files fire today.
- **Plugin install blocked** by the relative submodule url until release
  fixes `.gitmodules`; dogfood goes through the shim (D-16).
- **Knowledge gap on retirement** for ddaanet repos without the plugin,
  until it is released and installed there (D-11's accepted tradeoff).
- Candidate strings may have zero corpus hits; that is a result, not a
  failure.
