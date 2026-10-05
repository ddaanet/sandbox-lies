# Outline — sandbox-lies review fixes

Fixes for `plans/sandbox-lies/reports/deliverable-review.md`: all six Majors,
the mechanical doc, comment and test Minors, and code Minors m-2 and m-3. Scope
and the Major 1 and Major 2 mechanisms were fixed by my human partner at
dispatch; this outline records them and adds the decisions the executor would
otherwise have to make. Classification: `classification.md` (Moderate,
Production).

## Provenance

- **Derived from:** `plans/sandbox-lies/reports/deliverable-review.md`,
  superseding `plans/sandbox-lies/outline.md`
- **Base:** `52e6dd82b831a1cc2b7b516d4c248df6fb1ebc8c` — copied verbatim from
  the superseded outline. The review itself ran over `e873bf4..HEAD`
  (`.git/build-baseline`); a reviewer of this job should do the same.

## Scope

**IN**

- Majors 1–6.
- Minors: "Stale comments and help text" (4); "Docs against code or behaviour"
  except "Unchosen host" (13); "Tests" m-1 to m-5; code m-2 and m-3.
- The split of `docs/references/detectors.md` §readonly-path into its own node,
  and a move-out from `docs/design.md`: both files sit at their 400-line cap
  (399 and 395) and this job adds to both; `build-finish.md` §Carry-forward
  already names these as the next additions' remedy.

**OUT** (carried forward)

- m-1 quadratic tokenizer; m-7 line-cap gate coverage; m-8
  `tests/corpus-eval.py` idempotency; m-9 `tests/extract-fixtures.py`
  robustness; "Unchosen host" (the publishing host is a separate decision).
- Tests m-6, the Linux-only suite: making the suite run on a Mac (`stat -c`,
  `C.UTF-8`) is portability work across helpers and stubs, not a mechanical test
  fix.
- Everything in `plans/sandbox-lies/reports/build-finish.md` §Carry-forward,
  including the `path=` partial-checkout resolution and the m7 cwd probe.
- `.bin/claude`: not edited by this job. A saved patch is re-applied by the main
  session after the build; Item 2.6 adds a test against the shim, so that patch
  must keep `tests/shim.bats` green.

## Decisions

- **D1 — Major 1 rule (taken by my human partner).** CC's documented rule: an
  `excludedCommands` entry applies only when it covers every command in the
  call. A `cd` anywhere, a subshell, a command substitution, a redirection other
  than a descriptor duplication, or a command name from a variable keeps the
  call sandboxed. Current syntax is `git *`; `git:*` is legacy. The decoy
  escalation (`false && git status; <payload>`) is dropped. The re-probe is a
  single covered command writing outside the allowlist, e.g.
  `git init -q /tmp/<name>`. The skill keeps the every-command rule as the
  mechanism CC documents, and records that it was not observed: on Linux, with
  `git:*` configured, `git init -q /tmp/sl-exclprobe-288` ran sandboxed
  (read-only file system; 2026-10-03, CC 2.1.288); after a full CC restart with
  `"git *"` in `sandbox.excludedCommands`, `git init -q /tmp/sl-exclprobe-289`
  ran sandboxed the same way (2026-10-04, CC 2.1.289). Exclusions are observed
  not honoured under either syntax.
  - **Revised by my human partner, 2026-10-05, at the Item 5.1 gate.** On CC
    2.1.289 an `excludedCommands` entry is honoured for a call whose every
    command it covers. The exception is git with an absolute, `~`-led or
    `..`-bearing path argument (`git init`, `git clone`, `git worktree
    add/move`, `git bundle create`, among others; `git config --file /tmp/...`
    was also observed sandboxed), which stays sandboxed. Evidence:
    `reports/item-5-1.md` probes 2–4 — a covered `find -fprint /tmp/...` ran
    unsandboxed, a bare covered `git status --porcelain` showed no masks,
    `true && git status --porcelain` showed 20 — and the main session
    re-confirmed the bare `git status` case. The 2.288 and 2.289
    `git init -q /tmp/...` probes above are confounded by that absolute-path
    rule. The re-probe becomes a bare covered `git status` from the project root
    that shows no masks. Every "where honoured" / "not honoured" qualifier in the
    skill and references follows this, as listed in `reports/item-5-1.md` §What
    depends on the answer, and so does Item 5.2's `lock-detectors.md` text. This
    supersedes the "not honoured" sentence and the single-writer re-probe above.
- **D2 — Major 2 mechanism (taken).** A README §Install prerequisite note and a
  `SessionStart` hook that speaks only when `jq` is not on `PATH`: a
  `systemMessage` for the user and `additionalContext` for the agent, both
  saying the annotations are off this session until `jq` is installed. It builds
  its JSON with `printf` from fixed text (no `jq`, by construction), writes
  nothing, exits 0 always. Wording per `craft:directive-writing`; lead the
  `systemMessage` with a style reset (`hook-output-channels`).
- **D3 — m-3 name form (approved at proof, 2026-10-04).** `match=` lines carry
  the absolute path, `<repo>/<name>`, where `<repo>` is the repository root the
  probe already resolved. Alternatives: cwd-relative names (cannot express a
  sibling-worktree repo, the recorded reproduction's case); `:/<name>` pathspec
  magic (silently acts on the cwd's repository when that is not the refused
  path's — a wrong act). An absolute path is right from any directory of that
  repository and fails loudly from any other.
- **D4 — m-2 operand rule (approved at proof, 2026-10-04).** A `readfile=`
  candidate must be an input-file operand: a word opening with `-` never is (an
  option, or `--opt=value`); for `grep`, `sed` and `awk` the first non-option
  operand is the pattern or program unless an `-e`/`-f` family option came
  earlier in the segment, and the word after a separate `-e`/`-f` is that
  option's argument; `uniq` with a second operand writes it, so that segment is
  a writer (no `readfile=`, as `sort -o`). Other options' separate arguments
  (`-n 5`, `-d ,`) stay a documented residual.
- **D5 — Mutation verification for pin-only items.** A test written against
  unchanged code cannot show a red the usual way; each Phase 2 assertion is
  instead shown red under the fault the review names (or one the item states),
  applied to a scratch copy or to the hook's per-test copy, never committed. The
  report records each fault and the failing test name.

## Phase 1: make room (type: general)

- Item 1.1: `docs/references/detectors.md` → new
  `docs/references/readonly-path.md` — move §readonly-path whole into its own
  node, leave a stub in `detectors.md` as `lock-detectors.md`'s two entries do,
  and repoint every inbound link (`scripts/check-links.sh` finds them).
  Requirements: line cap (FR-11 gate).

## Phase 2: pin current behaviour (type: general, verified per D5)

- Item 2.1: `tests/hook*.bats` — FR-3 runtime-failure path (Major 3): a stubbed
  probe that prints `writable` then exits non-zero, a verdict that prints text
  then exits non-zero after a probe, and a probe-less verdict that exits
  non-zero each leave the hook silent with exit 0. Fault: each of
  `hooks/annotate.sh`'s three `|| exit 0` after a probe or verdict turned to
  `|| true`. Requirements: FR-3.
- Item 2.2: `tests/hook.bats`, `tests/probes-readonly*.bats` — NFR-4 writes
  nothing on the probe path (Major 4): the "hook needs no temp dir" shape re-run
  on a payload whose detector has a real probe (readonly-path and git-lock), and
  the same `mktemp` spy plus nonexistent `TMPDIR` around `probe_readonly_path`
  directly. Fault: a `mktemp` call in the hook's probe branch, and one in
  `_readonly_print_facts`. Requirements: NFR-4.
- Item 2.3: `tests/matchers-edges.bats` — fire cases built from fragments (Major
  5): `tmpdir-unset` with GNU curly quotes around the path, and
  `phantom-untracked` on tab-indented long-format names with a trailing slash.
  Fault: the curly quotes dropped from the alternation; the whitespace
  alternative dropped from the `phantom-untracked` pattern. Requirements: FR-7.
- Item 2.4: `tests/probes-readonly-pins.bats` — the unpinned fact-table members
  (Major 6): `merge=1` for `switch`, `rebase`, `cherry-pick`; `target=` after
  `switch`; `*.out` and `*.err` as `readfile=` names; `sort -o`, `--output`,
  `awk -i`, `--include` each suppressing `readfile=`. Fault: the subcommand case
  cut to `merge | pull | checkout`; the extensions and exclusions removed.
  Requirements: FR-4.
- Item 2.5: `tests/hook*.bats` — flag pairing (Tests m-1): every `fire-*`
  fixture reaches the hook with the flag absent and with it `true`, asserting
  each detector's flag policy; one case feeds a non-boolean flag (the string
  `"true"`) and asserts it reads as false. Fault: the flag policy `case` in
  `annotate.sh` emptied; `== true` loosened to a truthiness test. Requirements:
  FR-5.
- Item 2.6: `tests/helpers/bsd-stubs.bash`, `tests/shim.bats` — a `paste` stub
  refusing `-s` with no file operand, as BSD paste does, and a shim case re-run
  with it on `PATH` (Tests m-3). Fault: the `-` operand removed from a scratch
  copy of `.bin/claude`, never the tracked file. Requirements: D-16.
- Item 2.7: `tests/check-line-limits.bats`, `tests/check-links*.bats` — the
  exit-2 paths (Tests m-2): `scripts/lib/tracked.sh` when `git ls-files` fails,
  and `check-line-limits.sh` on an unreadable file, each asserting status 2 and
  its stderr line. Fault: `|| true` after the `ls-files`; the read guard
  removed. Requirements: FR-11.
- Item 2.8: suites that run git — host config isolation (Tests m-4):
  `GIT_CONFIG_NOSYSTEM=1` and a test-owned `GIT_CONFIG_GLOBAL` (identity set,
  `commit.gpgsign=false`) in a helper those suites load; the real-probe cases
  that assume no repository above `$BATS_TEST_TMPDIR` call the existing
  `assert_no_git_above`. Verified by running the suites with a host
  `GIT_CONFIG_GLOBAL` that sets `commit.gpgsign=true`. Requirements: NFR-2.
- Item 2.9: `tests/probes-config.bats` — positive assertions where `:96-101` and
  `:131-151` assert only what the outcome is not (Tests m-5). Fault: the outcome
  swapped for another non-excluded token. Requirements: FR-4.

## Phase 3: behaviour changes (type: tdd)

- Item 3.1: `lib/probes-readonly-command.sh` `_readonly_readfile_arg` — D4's
  operand rule (m-2). Requirements: FR-4. Depends on: Item 2.4, Item 1.1.
  - Slices:
    1. Through `probe_readonly_path` on a `writable` refusal: a command
       `grep --include=*.log pat build.log` yields `readfile=build.log`, and
       `grep -r --include=*.log pat .` yields no `readfile=` line.
    2. Pattern and program operands: `grep x.log y.out` yields `readfile=y.out`;
       `sed s/a/b/ in.log` yields `readfile=in.log` while
       `sed -e s/a/b/x.log in.out` yields `readfile=in.out`;
       `awk -f prog.log in.err` yields `readfile=in.err`.
    3. `uniq in.txt out.log` yields no `readfile=` line; `uniq in.log` yields
       `readfile=in.log`.
  - Docs: `docs/references/readonly-path.md` Probe facts table, the `readfile=`
    row and its residuals.
- Item 3.2: `lib/probes-readonly-facts.sh` — D3's absolute `match=` names (m-3).
  Requirements: FR-4. Depends on: Item 1.1.
  - Slices:
    1. Through the hook with the payload `cwd` a subdirectory of the scratch
       repo and a file at the merge target modified in the worktree: the
       `additionalContext` restore clause names `` `<repo>/<file>` `` and the
       probe's `match=` line is `match=<repo>/<file>`; existing `match=`
       assertions updated to the absolute form.
  - Docs: `readonly-path.md` Probe facts table, the `match=` row.
- Item 3.3: new `hooks/check-jq.sh`, `hooks/hooks.json` — D2's `SessionStart`
  check (Major 2). Requirements: NFR-2, D-12. Depends on: none.
  - Slices:
    1. Through the command string `hooks.json` registers under `SessionStart`,
       run with `CLAUDE_PLUGIN_ROOT` set and a `PATH` holding no `jq`: stdout is
       one JSON object (checked with the test's own `jq`) whose `systemMessage`
       names `jq` and the annotations being off, and whose `hookSpecificOutput`
       has `hookEventName` `SessionStart` and an `additionalContext` naming
       `jq`; exit 0; stderr empty. Re-run with `make_bsd_stubs` on `PATH`.
    2. With `jq` on `PATH`: no output, exit 0.
  - Interfaces:
    - `hooks/check-jq.sh` — stdin ignored; stdout empty or one JSON object; exit
      0 always; writes nothing.
  - Docs: `docs/references/hook.md` registration; `docs/design.md` D-12.

## Phase 4: prose (type: general)

- Item 4.1: `skills/sandbox-lies/SKILL.md` and `references/` — Major 1 per D1,
  with the skill-side Minors. Requirements: FR-9.
  - `SKILL.md` §Tell (`:18-21`), §Writing an `excludedCommands` entry
    (`:34-52`), §Leaving the sandbox (`:56-60`), §Keeping the working directory
    (`:71-84`): the D1 rule and syntax; no decoy; re-probe with a single covered
    writer; re-rank the cwd list now that a `cd` forfeits an exclusion as a
    subshell does; "keeps a `cd` between calls" holds in the main session only
    (a subagent's cwd resets per call); strict mode named as
    `sandbox.allowUnsandboxedCommands: false`, shown in `/sandbox` as Strict
    sandbox mode.
  - `references/excluded-commands.md` (`:1-13`, `:29-64`, `:93-110`): retitle
    from whole-call semantics; the D1 rule replaces "one matching segment
    unsandboxes the whole call"; the 2.281 probe recorded as confounded (its
    uncovered `touch` keeps it sandboxed either way) beside D1's 2.288 and 2.289
    observations; "settings reload live" kept as observed earlier, with no
    version recorded.
  - `references/escapes-and-costs.md`: `:3-6`, `:10-15` (strict-mode key),
    `:19-28` (the `git:*` baseline), `:41-44` (the auto-mode exceptions the
    sandboxing doc lists: per-command allowed domains, server-side review of
    sandboxed commands), `:51-55` (one batching rule, matching the hub; drop the
    "no generation" claim), `:76`.
  - `references/masks-and-gates.md` `:15-24` and `:44-55`: main-session
    qualifier; cwd ranking; exclusion wording.
- Item 4.2: docs — Major 1 and Major 2 doc halves and the doc Minors.
  Requirements: FR-7, FR-8, FR-9, NFR-1, NFR-2, NFR-4. Depends on: Items 3.1,
  3.2, 3.3, 4.1.
  - `docs/references/lock-detectors.md` `:88-100`, `:145-153`: the probe shape
    per D1; the recorded runs restated as confounded where they are.
  - `docs/references/detectors.md`: `:18-20` names as open whether the payload
    `cwd` follows a persisted top-level `cd`, and that the lock probes resolve
    against it; the Candidates intro credits the shipped matchers'
    re-measurement (`item-4-2-s1-code-review.md`, `item-4-3-s1-green.md`) rather
    than a scratch shell matcher; `phantom-untracked`'s 41 and 57 each name
    their corpus (from the `plans/2026-09-0*` evaluation files), or say the
    source is not established; `:381`, `:396` exclusion wording.
  - `docs/references/readonly-path.md`: `mv`'s `to` names the target only in the
    inter-device form.
  - `docs/design.md`: NFR-4's read scope (the refused path's repository, and
    paths from the error text); a platform statement (symptoms and figures
    recorded on Linux; macOS unverified); D-3's hook count; NFR-4 before NFR-5;
    FR-8's "reproducible from the script" qualified (25 of 34 byte for byte at
    review time, two undated entries pick other calls, seven not found); `:130`,
    `:271`, `:341`, `:379` exclusion wording; D-12 names the `SessionStart`
    check. Move D-8's argument to a `docs/references/` node if the file passes
    400 lines after `just format-docs`.
  - `README.md`: §Install names `jq` as a prerequisite and says the hook stays
    silent without it, the `SessionStart` check saying so; the platform
    statement; `:59` exclusion wording.
  - `CLAUDE.md:11`: the three pilot files are exempted from the sweep, not
    scanned.
  - `docs/changelog.md`: one entry for this job's user-visible changes.
- Item 4.3: comments and help text (stale group). Requirements: none (hygiene).
  - `lib/matchers.sh:2` header; `:90-92` drop the `CLAUDE_PROJECT_DIR` claim and
    name the `/dev` listing false positive as the accepted residual;
    `lib/probes.sh:3-6` the probe contract with `tool_input.command` as `$3`;
    `justfile` `precommit` so `just --list` shows a full sentence.

## Execution notes

- Every commit passes `just precommit`; docs edits run `just format-docs` first.
  No live file may fire a detector (`tests/docs.bats`): describe a diagnostic,
  build test text from fragments.
- Every new bats file loads `helpers/bsd-stubs`; suites exercising shell code
  keep one case under `make_bsd_stubs`.
- Fixtures: no new `fire-*`/`quiet-*` file by hand; run-time text in
  `*-edges.bats` and the pin suites only.
- Model: Item 4.1 is an opus dispatch (agentic prose); the rest sonnet unless an
  executor escalates.
