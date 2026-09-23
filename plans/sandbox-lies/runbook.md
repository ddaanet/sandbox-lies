# Runbook: sandbox-lies first build

Design: `docs/design.md` (requirements FR-1 to FR-11, NFR-1 to NFR-5,
decisions D-1 to D-16) and `docs/references/detectors.md` (per-detector
mechanism, verdict text, flag policy, translation map). Sequencing and
scope: `plans/sandbox-lies/outline.md`. Recall:
`plans/sandbox-lies/recall-artifact.md`.

Re-sequencing against the outline: its six phases become eight so each live
reproduction precedes the verdict it proves (FR-4) and each retirement rides
the commit that ships its translation (D-11). Outline Phase 1 → Phase 1;
outline Phases 2–3 → Phases 2–4; outline Phase 4 → Phases 3–6; outline
Phase 5 → Phase 7; outline Phase 6 → Phase 8. The outline's first Phase 1
bullet (commit the staged tier mount) is already done: `.gitmodules`,
`memory` and `.envrc` are tracked on the checked-out branch.

Cross-cutting, bounded:

- **Design status.** Each item that pins a requirement flips that
  requirement's status line in `docs/design.md` from `Planned` to `Done`
  (or `Partial`) in its own commit; Item 8.2 updates the `## Now` section.
- **Retirement.** Memory sections leave `memory/ddaanet/sandbox-effects.md`
  in Items 2.3, 4.1, 4.2–4.5, 6.1 and 7.1; Item 8.2 deletes the file. Each
  retiring item also removes the retired symptoms from the file's
  frontmatter `description`, its symptom table, and the index line in both
  `memory/MEMORY.md` and `memory/ddaanet/MEMORY.md`. Memory is committed
  only through the parent commit; never commit inside `memory/`.
- **Self-quiet.** From Item 1.3 on, `tests/docs.bats` fails any commit that
  adds a whole diagnostic with its follow-on to a tracked file; verdict and
  skill text describe strings rather than quote them.
- **Verification standard** (outline): before a tdd phase closes, each new
  assertion class is turned red by one deliberate fault that asserts it
  applied before the run.
- **Out of scope:** everything under the outline's Scope OUT, including
  releasing and the `.gitmodules` url fix.

## Requirements mapping

| Requirement | Phase | Items | Notes |
|---|---|---|---|
| FR-1 | 2 | 2.3 | hooks.json on both events; emitted key set asserted |
| FR-2 | 1 | 1.1 | promoted matchers and suite |
| FR-3 | 2 | 2.3 | payload → text → detect → JSON |
| FR-4 | 2, 3, 4, 5, 6 | 2.4, 3.1, 4.1, 4.6, 5.1, 6.1 | probe, live proof, then wiring |
| FR-5 | 2, 4, 6 | 2.3, 4.1–4.5, 6.1 | per-detector flag policy in the hook |
| FR-6 | 2, 4, 6 | 2.3, 4.1–4.5, 6.1 | verdict text, 2 KB cap |
| FR-7 | 3, 4, 6 | 3.2, 4.2–4.6, 6.1 | candidates under D-15 |
| FR-8 | 1, 3 | 1.1, 3.2 | fixture cutter promoted and extended |
| FR-9 | 7 | 7.1 | the skill |
| FR-10 | 2, 4, 6, 7, 8 | 2.3, 4.1–4.5, 6.1, 7.1, 8.2 | per-section retirement, then file deletion |
| FR-11 | 1, 8 | 1.1, 1.3, 8.2 | literal split, docs guard, retired-path guard |
| NFR-1 | 1, 3 | 1.1, 3.2 | corpus harness under `tests/` |
| NFR-2 | 1, 2 | 1.1, 2.4 | BSD stubs; `stat` stub added |
| NFR-3 | 2 | 2.3 | quiet path empty; wall time recorded |
| NFR-4 | 2 | 2.3 | hook holds text in memory, writes nothing |
| NFR-5 | 1, 2 | 1.2, 2.1, 2.2 | formatter, line caps, links |
| D-16 | 8 | 8.1 | dogfood shim |

## Phase 1: Promote the pilot (type: general)

- Item 1.1: `plans/sandbox-detector-pilot/` → `lib/`, `tests/` — move
  `matchers.sh` to `lib/matchers.sh`, `matchers.bats` to
  `tests/matchers.bats`, `fixtures/` to `tests/fixtures/`,
  `extract-fixtures.py` to `tests/extract-fixtures.py`, and
  `plans/2026-09-03-sandbox-matcher-corpus-eval.py` to
  `tests/corpus-eval.py`, all with `git mv`. In `tests/matchers.bats`: the
  `PILOT` variable and `MATCHERS`/`FIXTURES` point at `lib/matchers.sh` and
  `tests/fixtures`; `load` becomes `helpers/bsd-stubs`; the store path in
  the two live-memory cases becomes `$BATS_TEST_DIRNAME/../memory/ddaanet/
  sandbox-effects.md`. Update the usage docstrings of
  `tests/extract-fixtures.py` and `tests/corpus-eval.py` to the new paths
  (the cutter's output directory is already relative to its own location).
  Split the git-lock grep literals in `lib/matchers.sh`
  (`match_git_lock`) and in `tests/matchers.bats` (every case whose body
  holds git's follow-on sentence whole) so each literal is built from two
  shell fragments and no file on disk holds the sentence (A-2). Delete
  `plans/sandbox-detector-pilot/README.md` with the directory: its content
  is superseded by `docs/design.md` FR-2/FR-8 and the directory no longer
  exists. Done when `scripts/run-bats.sh tests/matchers.bats` reports 26
  passed, 0 failed, and the TAP log holds no `# skip` line (the wrapper
  counts a skip as a pass), and `bash lib/matchers.sh` over each of the two
  promoted source files prints nothing. Requirements: FR-2, FR-8, FR-11,
  NFR-1, NFR-2.
  Interfaces:
  - `lib/matchers.sh` — sourced: defines `match_<name>` and `detect`;
    executed: runs `detect` on stdin
  - `detect` — stdin: result text; stdout: one detector name per firing
    matcher, catalogue order, one per line; exit 0 when any fired, 1 when
    none, 2 on a buffering failure
  - `tests/fixtures/<fire|quiet>-<topic>-<case>.txt` — one verbatim tool
    result per file

- Item 1.2: `pyproject.toml`, `.envrc`, `.rumdl.toml`, `justfile` — the
  formatter and the gate. `pyproject.toml` is a non-package project with a
  `dev` dependency group holding `rumdl`; `.envrc` exports
  `VIRTUAL_ENV=$PWD/.venv` and prepends its `bin` to `PATH` (keep
  `source_up_if_exists` first and `PATH_add .gitlore/bin`); `.venv/` joins
  `.gitignore`. `uv sync` runs once unsandboxed to materialise the venv —
  never `uv run` or `uvx` in a recipe. `.rumdl.toml` ports
  `/Users/david/code/edify/.rumdl.toml` with scope `skills/**/*.md`,
  `docs/**/*.md` and `/*.md` (root-anchored), no `exclude`, its comment
  rewritten for this repo. `justfile` gains `format-docs` (`rumdl fmt -q
  --no-cache`), `test` (`scripts/run-bats.sh tests/`), and `precommit`
  becomes: plugin.json parse, `shellcheck` over every tracked `*.sh` and
  `*.bats`, `bash -n` over every tracked `*.sh`, `rumdl fmt --check -q
  --no-cache`, then `just test`, each through a `report` helper that
  accumulates the check's name and prints the passed list on success
  (quiet-gate recap). Run `just format-docs` once and commit the reflow of
  `docs/` and root markdown in this item. Done when `just precommit` exits 0
  printing its check list, and fails with a diff when a paragraph in
  `docs/design.md` is hand-rewrapped at 60 columns. Requirements: NFR-5.
  Depends on: Item 1.1

- Item 1.3: `tests/docs.bats` — FR-11 guard. One case per tracked regular
  file (`git ls-files -z`, skipping gitlinks and symlinks) outside
  `tests/fixtures/`, minus three exemptions named by exact path:
  `plans/2026-09-02-sandbox-detector-replay.py`,
  `plans/2026-09-02-sandbox-detector-hits.jsonl`,
  `plans/2026-09-03-sandbox-matcher-corpus-eval.md`. Each file is piped
  through `lib/matchers.sh`; the case fails naming the file and the verdicts
  printed. A single aggregate case is acceptable if its failure message
  lists every firing file. Record the exemption list in `docs/design.md`
  FR-11 by path. Fault injection: append a whole git-lock diagnostic with
  its follow-on to a scratch tracked copy, assert the case goes red, revert.
  Requirements: FR-11. Depends on: Item 1.1
  Interfaces:
  - `tests/docs.bats` — exemption list as one bash array of exact
    repo-relative paths; Item 8.2 adds its retired-path case to this file

- Item 1.4: `tests/fixtures/payload-post.json`,
  `tests/fixtures/payload-failure.json`, `docs/references/detectors.md` —
  record the live payloads. In a scratch directory under `/tmp/claude/`
  (outside any repo, so no repo `SessionStart` hook runs), write a settings
  file registering one command hook on `PostToolUse` and one on
  `PostToolUseFailure`, matcher `Bash`, each appending its stdin to a file
  in that directory. Run one unsandboxed nested `claude -p --settings
  <file>` that issues one succeeding and one failing Bash call. Save the two
  payloads as the fixtures with the session-specific ids and paths replaced
  by stable placeholders. In `detectors.md` Conventions, record: the field
  names that carry the text on each event, the order of exit-code line,
  stderr and stdout in `error`, whether `dangerouslyDisableSandbox` is
  absent or `false` when unset, and whether a sandboxed failure carries the
  harness's sandbox-violation annotation (L-5). If the recorded shape
  contradicts D-13, stop and escalate: D-13's reopen-if fires.
  Requirements: FR-3, FR-5.
  Interfaces:
  - `tests/fixtures/payload-failure.json` — one `PostToolUseFailure`
    payload object; the text field (`error` per D-13) and
    `tool_input.dangerouslyDisableSandbox` are the fields tests overwrite
  - `tests/fixtures/payload-post.json` — one `PostToolUse` payload object;
    `tool_response.stdout` and `tool_response.stderr` are overwritten

## Phase 2: Gate scripts, hook, lock probes (type: tdd)

- Item 2.1: `scripts/check-line-limits.sh` — line caps, ported from
  `/Users/david/code/edify/scripts/check_line_limits.sh` without the
  allowlist. Scope: tracked `*.sh`, `*.bats`, `*.py` outside `plans/` and
  `plugin-dev/`, and markdown under `skills/`, `docs/` and the root. Wired
  into `precommit` after the rumdl check. Requirements: NFR-5.
  Slices:
  1. External contract: `clean tree exits 0 silently` — asserts status 0
     and empty stdout on a temp root holding a 10-line `docs/a.md`;
     `oversized markdown is reported` — asserts status 1 and stdout exactly
     `oversized-file: docs/a.md 401 lines > 400` for a 401-line file.
  2. SKILL.md cap: `SKILL.md capped at 200` — asserts
     `oversized-file: skills/x/SKILL.md 201 lines > 200` and status 1.
  3. Scripts in scope: `oversized script is reported` — a 401-line
     `lib/x.sh` yields the `> 400` line; `plans/ is out of scope` — a
     401-line `plans/x.md` yields status 0.
  4. Whitespace: `path with a space` — a 401-line `docs/a b.md` is reported
     with its full path.

- Item 2.2: `scripts/check-links.sh` — every relative markdown link in the
  same markdown scope as Item 2.1 resolves to an existing path. Wired into
  `precommit`. Requirements: NFR-5.
  Slices:
  1. External contract: `resolving link passes` — asserts status 0 and
     empty stdout for `docs/a.md` linking `(b.md)` beside an existing
     `docs/b.md`; `broken link is reported` — asserts status 1 and stdout
     `broken-link: docs/a.md -> missing.md`.
  2. Non-file targets: `urls and anchors ignored` — links to `https://…`,
     `mailto:` and `#section` yield status 0; a link `b.md#part` checks
     `b.md` only.
  3. Code is not a link: `link inside a code span or fence ignored` — a
     broken target inside backticks or a fenced block yields status 0.

- Item 2.3: `hooks/hooks.json`, `hooks/annotate.sh`, `lib/verdicts.sh`,
  `tests/hook.bats`, `tests/verdicts.bats` — the hook with the three
  phantom verdicts. `hooks.json` registers `bash
  "${CLAUDE_PLUGIN_ROOT}/hooks/annotate.sh"` on `PostToolUse` and
  `PostToolUseFailure`, matcher `Bash`, timeout 10; `precommit` gains `jq
  empty hooks/hooks.json`. `annotate.sh` parses with `jq` guarded by
  `select(type == "object")`, rebuilds the text (`error` on failure; stdout,
  newline, stderr from `tool_response` on success), holds it in a shell
  variable (A-8: no `mktemp`, no file writes), sources `lib/*.sh`, runs
  `detect`, calls `probe_<name>` when defined and `verdict_<name>` when
  defined (a verdict name with no verdict function contributes nothing),
  and emits one object with `jq -n --arg`. Any failure exits 0 with empty
  stdout. `hook.bats` runs a copy of `hooks/` and `lib/` under
  `$BATS_TEST_TMPDIR` so stubs can be appended to the copied lib files; it
  builds each payload from the Item 1.4 fixtures with `jq`, the fixture text
  placed in `error` for a failure and in `tool_response.stdout` for a
  success. Verdict text for `phantom-chardev`, `phantom-untracked`,
  `phantom-gitadd` from `detectors.md`. Same commit: delete the
  phantom-dotfile masks/who-sees-them, `git add -A` and
  visible-unsandboxed paragraphs, and the `/tmp reads full` section
  (untranslated, design rejected alternatives), from the memory file; the
  porcelain-gate and `## Context` paragraphs stay. Record the hook's wall
  time on `quiet-clean-status` in `docs/changelog.md` (not gated).
  `detect` in `lib/matchers.sh` stops using `mktemp`: it holds the text in
  a shell variable and feeds each matcher with `printf '%s\n'` (NFR-4).
  Requirements: FR-1, FR-3, FR-5, FR-6, FR-10, NFR-3, NFR-4.
  Depends on: Item 1.1, Item 1.3, Item 1.4
  Interfaces:
  - `hooks/annotate.sh` — stdin: hook payload; stdout: empty, or one
    object `{"hookSpecificOutput":{"hookEventName":string,
    "additionalContext":string},"systemMessage":string}`; exit 0 always
  - `verdict_<name>` — as Item 4.1's interface; phantom verdicts take no
    outcome
  - `tests/verdicts.bats` — a `name outcome` row table, one row per
    verdict and outcome (`-` for none), extended by Items 4.1–4.5 and 6.1
  - `tests/hook.bats` — helpers `failure_payload <text> [flag]` and
    `post_payload <stdout> [stderr] [flag]` printing a payload; `stub_lib
    <file> <body>` appending to the copied lib file; reused by later items
  Slices:
  1. External contract: `gitadd failure payload yields one verdict` —
     `fire-masks-gitadd-refused` as a `PostToolUseFailure` payload: status
     0; stdout parses; top-level keys exactly `hookSpecificOutput` and
     `systemMessage`; `hookSpecificOutput` keys exactly `hookEventName`
     (value `PostToolUseFailure`) and `additionalContext`; context contains
     `Stage explicit paths`; `systemMessage` equals `git add — refused a
     sandbox mask`. `quiet fixture yields nothing` — `quiet-clean-status` as
     a `PostToolUse` payload: status 0, stdout empty.
     `verdicts under 400 chars` (`verdicts.bats`) — every row of a
     name/outcome table yields a first line under 400 characters and a
     non-empty second line; `verdict text is quiet` — `detect` over all
     rows' text concatenated prints nothing; `no removal instruction` — no
     row's text matches `rm `, `remove`, `delete` case-insensitively (D-7).
  2. Success text rebuild: `porcelain on stdout fires untracked` —
     `fire-masks-porcelain` in `tool_response.stdout`, event
     `PostToolUse`: `hookEventName` is `PostToolUse` and context contains
     `reading the sandbox, not the tree`; `listing on stderr fires` — the
     same text in `tool_response.stderr` gives the same context.
  3. Shared phantom paragraph: `both listing verdicts share one paragraph`
     — a payload whose text concatenates `fire-masks-chardev-explicit` and
     `fire-masks-porcelain`: context holds the `phantom-untracked` paragraph
     once and the `phantom-chardev` paragraph not at all; `systemMessage`
     equals the `phantom-untracked` human line alone.
  4. Flag policy: `phantom verdicts ignore the flag` — each phantom fire
     fixture with `dangerouslyDisableSandbox` absent, `false` and `true`
     yields byte-identical stdout.
  5. Quiet set: `every quiet fixture is silent` — each `quiet-*` fixture in
     both payload shapes yields empty stdout.
  6. Malformed payload: `non-json, scalar, array and textless object` —
     inputs `not json`, `42`, `[1]`, `{}` and an object whose
     `tool_response` is a string each yield status 0, empty stdout, empty
     stderr.
  7. Context cap: `paragraph past 2 KB is dropped, human line kept` — with
     a stub `verdict_phantom_gitadd` appended to the copied `verdicts.sh`
     printing a 1900-character paragraph, a payload firing it with
     `phantom-untracked`: `additionalContext` is under 2048 bytes, holds
     the untracked paragraph, lacks the stub's; `systemMessage` holds both
     human lines.
  8. Writes nothing: `detect needs no temp dir` (`matchers.bats`) — with
     `TMPDIR` set to a nonexistent directory, `detect` over `fire-lock-add-commit` prints `git-lock`
     and exits 0; `hook writes no file` (`hook.bats`) — a fire payload run
     with `TMPDIR` pointing at an empty directory leaves it empty.

- Item 2.4: `lib/probes.sh`, `tests/probes.bats`,
  `tests/helpers/bsd-stubs.bash` — `probe_git_lock` and `probe_config_lock`
  to the A-3 contract, not yet called by any verdict. Path from the error
  text; a relative path resolves against `$2`. Holder check `lsof -t`, else
  `fuser`, else `unknown`. Size via `wc -c`, mtime via BSD `stat -f %m`
  when it succeeds, else GNU `stat -c %Y`; add a `stat` stub to
  `bsd-stubs.bash` that refuses `-c` as BSD does, and load it in
  `probes.bats`. No `2>/dev/null` on the probe's own tool calls: guard the
  expected absence first. Requirements: FR-4, NFR-2.
  Depends on: Item 1.1
  Interfaces:
  - `probe_git_lock <flag:true|false> <cwd>` — stdin: result text; stdout
    line 1 one of `mask|gone|held|orphan|unknown`, then `key=value` lines
    (`pid=`, `bytes=`, `age=`, `path=`); exit 0
  - `probe_config_lock <flag> <cwd>` — same contract on `.git/config.lock`
  Slices:
  1. External contract: `absent lock, sandboxed, is mask` — error text
     naming `$BATS_TEST_TMPDIR/r/.git/index.lock` (absent), flag `false`:
     line 1 `mask`, a `path=` line naming that path.
  2. `absent lock, unsandboxed, is gone` — same text, flag `true`: `gone`.
  3. `present unheld lock is orphan` — the lock written with 7 bytes, flag
     `false`: `orphan`, `bytes=7`, an `age=` integer ≥ 0.
  4. `held lock names the holder` — a background `sleep 30` holding the
     lock open on an fd: `held`, `pid=` equal to that job's pid; the job is
     killed in teardown.
  5. `character device is mask` — error text naming `/dev/null` as the
     lock, flag `false` and `true`: `mask` both times.
  6. `no holder tool is unknown` — `PATH` set to a directory holding only
     the tools the probe needs, without `lsof` and `fuser`: `unknown`,
     `bytes=7`.
  7. `relative path resolves against cwd` — text naming `.git/index.lock`,
     `$2` the repo dir holding a present lock: `orphan`, `path=` absolute.
  8. `config-lock reads its own error` — config-lock error text (shaped as
     `fire-configlock-remote-add`) with an absent lock, flag `false`:
     `mask`; with a present lock: `orphan`.

## Phase 3: Evidence (type: general)

- Item 3.1: `docs/references/detectors.md` — live reproductions for the
  lock probes, recorded under `git-lock` and `config-lock` in place of the
  "Live reproduction owed" lines, each with the date, the command shape and
  the probe's printed output. In a scratch repo under `/tmp/claude/` with a
  pre-commit hook that stages a file: a sandboxed `sh -c 'git add f && git
  commit -m x'` produces the lock error; `probe_git_lock false <repo>` run
  unsandboxed on that text prints `mask`. A hand-made lock prints `orphan`;
  the same lock held by a background process prints `held`. A sandboxed
  `sh -c 'git config x.y z'` produces the config-lock error;
  `probe_config_lock false <repo>` prints `mask`. A probe that prints
  anything else stops the phase: record the output and escalate.
  Requirements: FR-4. Depends on: Item 2.4
  Interfaces:
  - `detectors.md` `git-lock` and `config-lock` entries — a `Live
    reproduction (YYYY-MM-DD)` paragraph per outcome proved; its presence
    gates Item 4.1

- Item 3.2: `docs/references/detectors.md`, `tests/extract-fixtures.py`,
  `tests/corpus-eval.py`, `tests/fixtures/` — candidate triage and
  measurement for `readonly-path`, `tmpdir-unset`, `resume-lost`,
  `zellij-socket`, `seccomp-init`. Per candidate: replay with
  `plans/2026-09-02-sandbox-detector-replay.py` (count, sample); pick the
  shape discriminator the sample supports (line start, the tool's own
  prefix, or a follow-on; A-7); extend `tests/corpus-eval.py`'s prefilter
  with the candidate's string and join the flag from the paired tool-use
  input; run it with a shell matcher implementing the discriminator as
  arbiter. Record under the candidate: discriminator (described, not
  quoted), hit count, precision, date, pilot-traffic note, each false
  positive's class, and the D-15 decision — `ships` or `stays a candidate`.
  For each shipping candidate, extend `tests/extract-fixtures.py`'s cut list
  and cut at least one `fire-<detector>-*` and one `quiet-<detector>-*`
  fixture. A candidate with zero true positives is recorded as such.
  Requirements: FR-7, FR-8, NFR-1. Depends on: Item 1.1
  Interfaces:
  - `detectors.md` candidate entry — a `Decision: ships` or `Decision:
    stays a candidate` line, read by Items 4.2–4.6
  - `detectors.md` candidate entry — the discriminator stated precisely
    enough to implement as `match_<name>` (anchor, the tool prefix, the
    required substrings described)
  - `tests/fixtures/fire-<detector>-<case>.txt`,
    `tests/fixtures/quiet-<detector>-<case>.txt` — at least one each per
    shipping candidate

## Phase 4: Lock verdicts and shipped candidates (type: tdd)

Items 4.2–4.6 run only for a candidate Item 3.2 records as `ships`. A
candidate recorded `stays a candidate` closes its item with no code change
and leaves its memory section in place; `/build` reports it as skipped.

- Item 4.1: `lib/verdicts.sh`, `tests/hook.bats`, `tests/verdicts.bats` —
  `git-lock` and `config-lock` verdicts for all five outcomes, text from
  `detectors.md`; the hook passes the flag and the payload `cwd` to the
  probe. Same commit: delete the `.git/index.lock` section, including its
  `.git/config.lock` paragraph, from the memory file. Requirements: FR-4,
  FR-5, FR-6, FR-10. Depends on: Item 2.3, Item 2.4, Item 3.1
  Interfaces:
  - `verdict_<name> [outcome]` — stdin: the probe's `key=value` lines
    (empty when no probe); stdout line 1 agent paragraph, line 2 human
    line; exit 0. `<name>` is the detector name with `-` as `_`.
  Slices:
  1. External contract: `mask outcome through the hook` —
     `fire-lock-add-commit` as a failure payload with a stub
     `probe_git_lock` printing `mask`: context contains `Re-run the same
     command with` and `GIT_INDEX_FILE`; `systemMessage` equals
     `index.lock — sandbox mask, no file exists`. Verdict table rows added
     for all ten name/outcome pairs.
  2. `held interpolates the pid` — stub prints `held` and `pid=4242`:
     context contains `pid 4242`; human line `index.lock — held by pid
     4242`.
  3. `orphan and unknown interpolate size and age` — stub prints `bytes=7`,
     `age=12`: context contains `7 bytes` and `age 12s`; `unknown` context
     contains `no holder check is available`.
  4. `probe receives flag and cwd` — a stub recording its arguments to a
     file under `$BATS_TEST_TMPDIR`: payload with the flag `true` and `cwd`
     `/x` records `true /x`; flag absent records `false /x`.
  5. `config-lock mask names config.lock and update-config` —
     `fire-configlock-remote-add`, stub `mask`: context contains
     `config.lock` and `update-config`.
  6. `piped lock failure on a success payload` — `fire-lock-piped-tail` in
     `tool_response.stdout`, event `PostToolUse`: git-lock verdict present
     (D-4).

- Item 4.2: `lib/matchers.sh`, `lib/verdicts.sh`, `tests/matchers.bats`,
  `tests/hook.bats` — `tmpdir-unset`. Matcher from Item 3.2's
  discriminator; verdict from `detectors.md`; flag policy: fires only when
  the flag is `true`. Same commit: delete cost 1 of `Leaving the sandbox`
  except the instability clause (skill-mapped). Requirements: FR-5, FR-7,
  FR-10. Depends on: Item 3.2, Item 4.1
  Slices:
  1. `fire and quiet fixtures` (`matchers.bats`) — the cut `fire-tmpdir-*`
     yields exactly `tmpdir-unset`; the cut `quiet-tmpdir-*` yields nothing.
  2. `fires only unsandboxed` (`hook.bats`) — the fire fixture with the
     flag `true` yields context containing `/tmp/claude/`; flag absent
     yields empty stdout.

- Item 4.3: same targets — `resume-lost`; flag policy: fires only when the
  flag is `false`. Same commit: delete the `--resume` section except the
  eval-harness consequence (skill-mapped). Requirements: FR-5, FR-7, FR-10.
  Depends on: Item 3.2, Item 4.1
  Slices:
  1. `fire and quiet fixtures` — as Item 4.2 slice 1 for `resume-lost`.
  2. `fires only sandboxed` — flag absent: context contains `one
     unsandboxed call`; flag `true`: empty stdout.

- Item 4.4: same targets — `zellij-socket`; flag policy: fires only when
  the flag is `false`. Same commit: delete the zellij section.
  Requirements: FR-5, FR-7, FR-10. Depends on: Item 3.2, Item 4.1
  Slices:
  1. `fire and quiet fixtures` — as Item 4.2 slice 1 for `zellij-socket`.
  2. `fires only sandboxed` — flag absent: context contains `socket is
     outside the sandbox`; flag `true`: empty stdout.

- Item 4.5: same targets — `seccomp-init`; flag policy: silent when the
  flag is `true`. Same commit: delete the sandbox-setup section.
  Requirements: FR-5, FR-7, FR-10. Depends on: Item 3.2, Item 4.1
  Slices:
  1. `fire and quiet fixtures` — as Item 4.2 slice 1 for `seccomp-init`.
  2. `silent unsandboxed` — flag absent: context contains `Retry the
     identical command once`; flag `true`: empty stdout.

- Item 4.6: `lib/matchers.sh`, `lib/probes.sh`, `tests/matchers.bats`,
  `tests/probes.bats` — `readonly-path` matcher and probe, no verdict yet,
  so the hook stays silent on it (Item 2.3's no-verdict rule).
  Requirements: FR-4, FR-7. Depends on: Item 2.4, Item 3.2
  Interfaces:
  - `probe_readonly_path <flag> <cwd>` — stdin: result text; stdout line 1
    one of `writable|readonly|nopath`, then `path=` when extracted; exit 0
  Slices:
  1. `fire and quiet fixtures` — as Item 4.2 slice 1 for `readonly-path`.
  2. `writable path` — text naming a file under `$BATS_TEST_TMPDIR`:
     `writable`, `path=` that file.
  3. `absent file checks its parent` — text naming a missing file in a
     writable dir: `writable`; in a `chmod 555` dir: `readonly`.
  4. `no quoted path` — text with no quoted path: `nopath`, no `path=`
     line.

## Phase 5: readonly-path live proof (type: general)

- Item 5.1: `docs/references/detectors.md` — runs only if `readonly-path`
  ships. Create a sibling worktree of a scratch repo under `/tmp/claude/`;
  a sandboxed write into it produces the read-only error;
  `probe_readonly_path false <cwd>` run unsandboxed on that text prints
  `writable`. Record date, command shape and output under `readonly-path`.
  Any other output stops the phase and escalates. Requirements: FR-4.
  Depends on: Item 4.6
  Interfaces:
  - `detectors.md` `readonly-path` entry — a `Live reproduction
    (YYYY-MM-DD)` paragraph; its presence gates Item 6.1

## Phase 6: readonly-path verdict (type: tdd)

- Item 6.1: `lib/verdicts.sh`, `tests/hook.bats`, `tests/verdicts.bats` —
  runs only if `readonly-path` ships. Three verdicts from `detectors.md`;
  flag policy: silent when the flag is `true`. Same commit: delete the
  harness-mounted-config-paths and sibling-worktree sections and cost 3 of
  `Leaving the sandbox` except its skill-mapped remainder. Requirements:
  FR-4, FR-5, FR-6, FR-7, FR-10. Depends on: Item 5.1
  Slices:
  1. External contract: `writable outcome through the hook` — the fire
     fixture, stub probe printing `writable` and `path=/r/x`: context
     contains `/r/x is writable outside the sandbox` and the
     compare-before-retry clause; human line `read-only — sandbox
     allowlist, writable outside`. Verdict rows added for all three
     outcomes.
  2. `readonly and nopath` — stub `readonly`: context contains `not a
     sandbox effect`; stub `nopath`: the writable paragraph with no path.
  3. `silent unsandboxed` — flag `true`: empty stdout, and the stub probe
     records no call.

## Phase 7: The skill and repository prose (type: general)

- Item 7.1: `skills/sandbox-lies/SKILL.md`,
  `skills/sandbox-lies/references/` — the symptom-less knowledge, every
  row the `detectors.md` translation map sends to `skill`, including the
  remainders left by Items 4.2, 4.3 and 6.1 (or the whole sections, for a
  candidate that stayed a candidate). `SKILL.md` under 200 lines, third
  person `description` naming the authoring moments (writing an exclusion,
  a recipe, a cleanliness gate, a subagent directive with a scratch path);
  detail in `references/`. Error strings described, not quoted. Before
  commit, grep the skill for requirement and decision ids (FR, NFR, D-n)
  and for `/Users/` and `~/code/`: none ship. Same commit: delete every
  skill-mapped section and paragraph from the memory file. Done when
  `tests/docs.bats` and `precommit` are green and the memory file holds
  only its `## Context` paragraph plus sections of candidates that stayed
  candidates. Requirements: FR-9, FR-10, FR-11. Depends on: Item 4.1
  Interfaces:
  - `skills/sandbox-lies/SKILL.md` — the skill `sandbox-lies:sandbox-lies`;
    the name Items 7.2 and 8.2 point readers at
  - `memory/ddaanet/sandbox-effects.md` — post-state: frontmatter,
    `## Context` paragraph, and any stayed-candidate sections only

- Item 7.2: `README.md`, `LICENSE`, `CLAUDE.md` — README: what the plugin
  does, install, the detector list pointing at `detectors.md`, the skill;
  LICENSE: MIT, holder David Allouche, 2026; `CLAUDE.md`: a body for
  agents working here (precommit, the self-quiet rule, fixtures come from
  the cutter), the `@memory/ddaanet/shared-claude.md` import line kept
  last. Requirements: FR-9, FR-11. Depends on: Item 7.1

## Phase 8: Dogfood and final deletion (type: general)

- Item 8.1: `.bin/claude`, `.envrc` — the D-16 shim: prepends
  `--plugin-dir <this checkout>` and execs the next `claude` on `PATH` with
  `.bin` stripped from `PATH`; `.envrc` adds `PATH_add .bin` last. After
  `direnv allow`, a `claude -p` started here lists the `sandbox-lies`
  skill and a sandboxed call reproducing a phantom listing gets the
  verdict. Requirements: D-16, FR-1.

- Item 8.2: `memory/ddaanet/sandbox-effects.md`, `memory/MEMORY.md`,
  `memory/ddaanet/MEMORY.md`, `memory/ddaanet/shared-claude.md`, six
  inbound-link files, `tests/matchers.bats`, `tests/docs.bats`,
  `docs/design.md` — runs when the memory file holds only `## Context`
  (candidates that stayed candidates keep it alive; then this item is
  deferred and reported). Audit the translation map row by row against the
  file's git history and record the audit in `detectors.md`. In one parent
  commit: amend the phantom-dotfile bullet in `shared-claude.md` with the
  `!`-expansion clause and repoint its `sandbox-effects` reference to the
  `sandbox-lies` skill; delete the memory file and both index lines;
  rewrite the `[[sandbox-effects]]` link in
  `cc-bash-background-no-duration-cap`, `cc-worktree-bash-guard`,
  `classifier-denied-self-config`, `codex-review-of-design-docs`,
  `git-add-untracked-deletion`, `bang-shell-shared-cwd` to name the skill;
  delete the two `tests/matchers.bats` cases that read the live file (keep
  `quiet-memory-file-read`); add a `tests/docs.bats` case that fails when a
  tracked file under `hooks/`, `lib/`, `skills/`, `tests/` outside
  `tests/fixtures/`, `CLAUDE.md` or `README.md` names
  `sandbox-effects.md` (A-6), fault-injected once; update `## Now` in
  `docs/design.md`. Then publish the tier with `/gitlore:push`.
  Requirements: FR-10, FR-11. Depends on: Item 1.3, Item 7.1
