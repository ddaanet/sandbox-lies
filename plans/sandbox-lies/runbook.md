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
  (or `Partial`) in the item's commit; Item 8.2 updates the `## Now` section.
- **"Same commit" in a tdd item** means the item's final slice commit: a
  retirement or status flip rides the slice that completes the item.
- **Retirement.** Memory sections leave `memory/ddaanet/sandbox-effects.md`
  in Items 2.3, 4.1, 4.2, 6.1 and 7.1; Item 8.2 deletes the file. Each
  retiring item also removes the retired symptoms from the file's
  frontmatter `description`, its symptom table, and the index line in both
  `memory/MEMORY.md` and `memory/ddaanet/MEMORY.md`. Memory is committed
  only through the parent commit; never commit inside `memory/`.
- **Self-quiet.** From Item 1.3 on, `tests/docs.bats` fails any commit that
  leaves a tracked file (outside the exemptions) firing a detector; verdict
  and skill text describe strings rather than quote them, and test sources
  build any diagnostic text they need from fragments at run time.
- **Portability.** Every new bats file loads `helpers/bsd-stubs` (NFR-2),
  and each suite exercising shell code (hook, probes, check scripts) has one
  case re-running a representative input with `make_bsd_stubs` on `PATH`.
- **direnv.** Item 1.2 edits `.envrc`, which revokes direnv's approval and
  does not reach this session's already-started shells. `direnv allow` is my
  human partner's trust step; until the session restarts, executors run
  gates as `direnv exec . just precommit`.
- **Verification standard** (outline): before a tdd phase closes, each new
  assertion class is turned red by one deliberate fault that asserts it
  applied before the run.
- **Out of scope:** everything under the outline's Scope OUT, including
  releasing and the `.gitmodules` url fix.

## Requirements mapping

| Requirement | Phase | Items | Notes |
|---|---|---|---|
| FR-1 | 2, 8 | 2.3, 8.1 | hooks.json on both events; emitted key set asserted; dogfood |
| FR-2 | 1 | 1.1 | promoted matchers and suite |
| FR-3 | 1, 2, 4 | 1.4, 2.3, 4.1 | recorded payloads; payload → text → detect → JSON; probe call |
| FR-4 | 2, 3, 4, 5, 6 | 2.4, 3.1, 4.1, 4.3, 5.1, 6.1 | probe, live proof, then wiring |
| FR-5 | 1, 2, 4, 6 | 1.4, 2.3, 4.1, 4.2, 6.1 | flag shape recorded; per-detector flag policy in the hook |
| FR-6 | 2, 4, 6 | 2.3, 4.1, 4.2, 6.1 | verdict text, 2 KB cap |
| FR-7 | 3, 4, 6 | 3.2, 4.2, 4.3, 6.1 | candidates under D-15 |
| FR-8 | 1, 3 | 1.1, 3.2 | fixture cutter promoted and extended |
| FR-9 | 7 | 7.1, 7.2 | the skill; README points at it |
| FR-10 | 2, 4, 6, 7, 8 | 2.3, 4.1, 4.2, 6.1, 7.1, 8.2 | per-section retirement, then file deletion |
| FR-11 | 1, 7, 8 | 1.1, 1.3, 7.1, 7.2, 8.2 | literal split, docs guard, quiet skill and prose, retired-path guard |
| NFR-1 | 1, 3, 4 | 1.1, 3.2, 4.2, 4.3 | corpus harness under `tests/`; shipped matchers re-measured |
| NFR-2 | 1, 2, 4 | 1.1, 2.1–2.4, 4.2/4.3 | BSD stubs; `stat` stub added; one stubbed case per suite |
| NFR-3 | 2 | 2.3 | quiet path empty; quiet and verdict wall times recorded |
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
  exists. In `docs/design.md`, the header `Status:` line's pilot-path clause
  names `lib/matchers.sh` instead, without adding a line. `BRIEF.md` keeps
  its pilot paths: it is the frozen input brief. Done when
  `scripts/run-bats.sh tests/matchers.bats` reports 26 passed, 0 failed,
  and the TAP log holds no `# skip` line (the wrapper counts a skip as a
  pass), and `bash lib/matchers.sh` over each of the two
  promoted source files prints nothing. Requirements: FR-2, FR-8, FR-11,
  NFR-1, NFR-2.
  Interfaces:
  - `lib/matchers.sh` — sourced: defines `match_<name>` and `detect`;
    executed: runs `detect` on stdin
  - `detect` — stdin: result text; stdout: one detector name per firing
    matcher, catalogue order, one per line; exit 0 when any fired, 1 when
    none, 2 on a buffering failure (until Item 2.3 removes the buffer)
  - `tests/fixtures/<fire|quiet>-<topic>-<case>.txt` — one verbatim tool
    result per file

- Item 1.2: `pyproject.toml`, `uv.lock`, `.envrc`, `.gitignore`,
  `.rumdl.toml`, `justfile` — the formatter and the gate. `pyproject.toml`
  is a non-package project with a `dev` dependency group holding `rumdl`;
  `uv.lock` is committed; `.envrc` exports
  `VIRTUAL_ENV=$PWD/.venv` and prepends its `bin` to `PATH` (keep
  `source_up_if_exists` first and `PATH_add .gitlore/bin`); `.venv/` joins
  `.gitignore`. `uv sync` runs once unsandboxed to materialise the venv —
  never `uv run` or `uvx` in a recipe. `.rumdl.toml` ports
  `/Users/david/code/edify/.rumdl.toml` with scope `skills/**/*.md`,
  `docs/**/*.md` and `/*.md` (root-anchored), no `exclude`, its comment
  rewritten for this repo. `justfile` gains `format-docs` (`rumdl fmt -q
  --no-cache`), `test` (`scripts/run-bats.sh tests/`), and `precommit`
  becomes: plugin.json parse, `shellcheck` over every tracked `*.sh`,
  `*.bash` and `*.bats`, `bash -n` over every tracked `*.sh`, `rumdl fmt
  --check -q --no-cache`, then `just test`, each through a `report` helper
  that accumulates the check's name and prints the passed list on success
  (quiet-gate recap). Run `just format-docs` once and commit the reflow of
  `docs/` and root markdown in this item, and record `docs/design.md`'s
  post-reflow line count in the item report (it stands at exactly 400
  before the reflow; Item 2.1 caps it). Done when `direnv exec . just
  precommit` exits 0 printing its check list, and fails with a diff when a
  paragraph in `docs/design.md` is hand-rewrapped at 60 columns.
  Requirements: NFR-5. Depends on: Item 1.1

- Item 1.3: `tests/docs.bats` — FR-11 guard. One aggregate case over every
  tracked regular file (`git ls-files -z` from the repo root, skipping
  gitlinks and symlinks) outside `tests/fixtures/`, minus three exemptions
  named by exact path: `plans/2026-09-02-sandbox-detector-replay.py`,
  `plans/2026-09-02-sandbox-detector-hits.jsonl`,
  `plans/2026-09-03-sandbox-matcher-corpus-eval.md`. Each file is piped
  through `lib/matchers.sh`; the case fails with a message listing every
  firing file and the verdicts it printed. Record the exemption list in
  `docs/design.md` FR-11 by path, replacing the "dated pilot evidence"
  wording rather than adding beside it (the file sits just under Item 2.1's
  400-line cap).
  Fault injection: append a whole git-lock diagnostic, built at run time
  from two fragments, to a tracked file; assert the case goes red naming
  that file; invert the edit. Requirements: FR-11. Depends on: Item 1.1
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
  <file> --allowedTools Bash` that issues three Bash calls: one succeeding
  and printing a line on each of stdout and stderr; one doing the same then
  exiting 3; one sandboxed write outside the sandbox's write allowlist (a
  path directly under `/tmp/`, not `/tmp/claude/` — verified read-only
  sandboxed on 2026-09-23). Save the first two payloads as the fixtures with
  the session-specific ids and paths replaced by stable placeholders. In
  `detectors.md` Conventions, record: the field names that carry the text,
  the event name and the `cwd` on each event, the order of exit-code line,
  stderr and stdout in `error`, whether `dangerouslyDisableSandbox` is
  absent or `false` when unset, and whether the third call's text carries
  the harness's sandbox-violation annotation (L-5). If the recorded shape
  contradicts D-13, stop and escalate: D-13's reopen-if fires.
  Requirements: FR-3, FR-5.
  Interfaces:
  - `tests/fixtures/payload-failure.json` — one `PostToolUseFailure`
    payload object; the text field (`error` per D-13) and
    `tool_input.dangerouslyDisableSandbox` are the fields tests overwrite
  - `tests/fixtures/payload-post.json` — one `PostToolUse` payload object;
    `tool_response.stdout` and `tool_response.stderr` are overwritten

## Phase 2: Gate scripts, hook, lock probes (type: tdd)

- Item 2.1: `scripts/check-line-limits.sh`, `tests/check-line-limits.bats`
  — line caps, ported from
  `/Users/david/code/edify/scripts/check_line_limits.sh` without the
  allowlist, walking `git ls-files -z` instead of `find` (so `.venv/` and
  gitlinks stay out). Scope: tracked `*.sh`, `*.bash`, `*.bats`, `*.py`
  outside `plans/` and `plugin-dev/`, and tracked markdown under `skills/`,
  `docs/` and the root. Wired into `precommit` after the rumdl check; done
  when the gate passes on the real tree. If `docs/design.md` is over its cap
  there, stop and escalate: splitting the living design doc is a design-doc
  decision, not the executor's. Requirements: NFR-2, NFR-5.
  Depends on: Item 1.2
  Interfaces:
  - `scripts/check-line-limits.sh [ROOT]` — ROOT a git work tree, default
    `.`; stdout one `oversized-file: <path>: <n> lines > <cap>` line per
    overage (the port's format); exit 0 clean, 1 on any overage, 2 on a
    failure to run
  Slices (each fixture root a `git init` temp repo with its files added):
  1. External contract: `clean tree exits 0 silently` — asserts status 0
     and empty stdout on a root holding a 10-line `docs/a.md`;
     `oversized markdown is reported` — asserts status 1 and stdout exactly
     `oversized-file: docs/a.md: 401 lines > 400` for a 401-line file.
  2. SKILL.md cap: `SKILL.md capped at 200` — asserts
     `oversized-file: skills/x/SKILL.md: 201 lines > 200` and status 1.
  3. Markdown scope (added by slice 2's reviews): `oversized skills node is
     reported` — a 401-line `skills/x/references/n.md` yields the `> 400`
     line; `oversized root markdown is reported` — a 401-line `README.md`
     yields the `> 400` line; `markdown elsewhere is out of scope` — a
     401-line `lib/x.md` and a 201-line `.claude/skills/y/SKILL.md` yield
     status 0 (the latter pins the SKILL.md cap's `skills/` anchor).
  4. Scripts in scope: `oversized script is reported` — a 401-line
     `lib/x.sh`, `lib/x.bash`, `lib/x.bats` and `lib/x.py` each yield a
     `> 400` line (every type, so no arm layout leaves one uncounted);
     `plans/ is out of scope` — a 401-line `plans/x.md` and `plans/x.sh`
     yield status 0; `plugin-dev/ is out of scope` — a 401-line
     `plugin-dev/x.sh` yields status 0; `markdown directly under skills/`
     — a 401-line `skills/top.md` yields the `> 400` line (slice 3's code
     review; proven by mutation); `untracked file is out of
     scope` — an untracked 401-line `docs/u.md` yields status 0;
     `deleted tracked file is skipped` — a 401-line `docs/gone.md` added,
     then removed from the work tree only, yields status 0 (slice 1's code
     review added the skip; proven by mutation).
  5. Remaining contract and wiring (slices 5–7 merged after slice 4: none
     adds behaviour, so each case is proven by mutation, and the item's
     `precommit` wiring rides this slice's GREEN). Whitespace: `path with
     whitespace` — a 401-line `docs/a b.md`, `docs/a<TAB>b.md` and root
     ` lead.md` are each reported with their full path (renamed and widened
     by the slice's test review: a newline-delimited or `IFS=`-less walk
     passed the space-only fixture). Edge inputs (slice 1's code review): `unterminated last line counts` — 401
     lines with no final newline yields `oversized-file: docs/a.md: 401
     lines > 400` and status 1; `extra argument exits 2` — ROOT then a
     second argument yields status 2 and empty stdout. BSD tools: slice 1's
     401-line fixture with `make_bsd_stubs mktemp` on `PATH` (the one
     stubbed tool the script calls; `grep` and `sed` are not called, so
     stubbing them proves nothing) yields the same stdout and status 1; if
     no mutation the stub refuses can red it, the test is named as the
     portability smoke run it is (cross-cutting Portability rule) and the
     RED report says so.

- Item 2.2: `scripts/check-links.sh`, `tests/check-links.bats` — every
  relative markdown link in the same tracked markdown scope as Item 2.1
  resolves to an existing path, relative to the linking file. Wired into
  `precommit` after the line-limit check. Requirements: NFR-2, NFR-5.
  Depends on: Item 1.2
  Interfaces:
  - `scripts/check-links.sh [ROOT]` — ROOT a git work tree, default `.`;
    stdout one `broken-link: <file> -> <target>` line per broken link;
    exit 0 clean, 1 on any broken link, 2 on a failure to run
  Slices (fixture roots as in Item 2.1):
  1. External contract: `resolving link passes` — asserts status 0 and
     empty stdout for `docs/a.md` linking `(b.md)` beside an existing
     `docs/b.md`; `broken link is reported` — asserts status 1 and stdout
     `broken-link: docs/a.md -> missing.md`.
  2. Scope (added before the slice started, from Item 2.1's reviews: the
     scope is where its gaps were): `broken links in scope are reported` —
     one broken link each in `docs/a.md`, `skills/x/SKILL.md`,
     `skills/x/references/n.md` and root `README.md` yields four lines in
     `git ls-files` order; `markdown out of scope is ignored` — a broken
     link in `plans/x.md`, `plugin-dev/x.md`, `lib/x.md`,
     `.claude/skills/y/SKILL.md` and an untracked `docs/u.md` yields
     status 0.
  3. Non-file targets: `urls and anchors ignored` — links to `https://…`,
     `mailto:` and `#section` yield status 0; a link `b.md#part` checks
     `b.md` only; `link text does not cut the target` (slice 1's code
     review; proven by mutation) — `[a (b)](x.md)` beside an existing
     `x.md` yields status 0, and `[a [b] c](missing.md)` yields its
     `broken-link` line.
  4. Code is not a link: `link inside a code span or fence ignored` — a
     broken target inside backticks or a fenced block yields status 0.
  5. Whitespace and edge inputs (edge cases from slice 1's code review;
     proven by mutation): `linking file with a space` — `docs/a b.md` with
     a broken link yields `broken-link: docs/a b.md -> missing.md`;
     `deleted tracked file is skipped` — a `docs/gone.md` added, then
     removed from the work tree only, yields status 0; `unreadable file
     exits 2` — a mode-000 `docs/a.md` yields status 2 and empty stdout
     (skipped when run as root); `extra argument exits 2` — as Item 2.1's;
     `any URI scheme is skipped` (slice 3's code review replaced a
     three-scheme list with an RFC 3986 match) — `ftp://h/x`, `HTTP://X`
     and `x:y.md` (no such file) ahead of a broken sentinel yield only the
     sentinel's line; `CRLF fence closes` — a CRLF `docs/c.md` with a closed
     fence ahead of a broken sentinel yields the sentinel's line; `code
     span at line start is not a fence` — a line opening with a code span
     ahead of a broken sentinel yields the sentinel's line; `name=value
     ROOT is a path` — a fixture repo under a directory named `x=y`, given
     as a relative ROOT with stdin from `/dev/null`, yields its
     `broken-link` line and status 1 (the last three from slice 4's code
     review).
  6. Shared walk (`scripts/lib/tracked.sh`, pinned through this suite;
     slice 2's code review added each; proven by mutation): `tracked
     symlink is skipped` — a tracked `docs/l.md` symlink to an untracked
     file holding a broken link yields status 0; `bare-name invocation` —
     `cd` into `scripts/` and `bash check-links.sh <root>` yields the same
     stdout and status as slice 1's broken case; `missing helper exits 2` —
     a copy of the script with no `lib/` beside it yields status 2 and
     empty stdout, and so does a copy whose `lib/` holds `tracked.sh` but
     not `strip-code.awk`; `unmerged path walked once` — a real content conflict in
     `docs/a.md` holding one broken link yields exactly one line.
  7. BSD tools: `broken link under BSD stubs` — slice 1's broken-link
     fixture with `make_bsd_stubs grep mktemp` on `PATH` (the stubbed tools
     the script calls; it calls no `sed`) yields the same stdout and exit
     status 1. The item's `precommit` wiring rides this slice's GREEN.
     Open, unverifiable here: a NUL byte under BSD awk (one-true-awk) may
     drop the rest of its line; the macOS dogfood run is where it shows.

- Item 2.3: `hooks/hooks.json`, `hooks/annotate.sh`, `lib/verdicts.sh`,
  `lib/matchers.sh`, `tests/hook.bats`, `tests/helpers/hook.bash`,
  `tests/verdicts.bats` — the hook with the three phantom verdicts.
  `hooks.json` registers `bash "${CLAUDE_PLUGIN_ROOT}/hooks/annotate.sh"`
  on `PostToolUse` and `PostToolUseFailure`, matcher `Bash`, timeout 10;
  `precommit` gains `jq empty hooks/hooks.json`. `annotate.sh` parses with
  `jq` guarded by `select(type == "object")`, rebuilds the text (`error` on
  failure; stdout, newline, stderr from `tool_response` on success), holds
  it in a shell variable (A-8: no `mktemp`, no file writes), sources the
  `lib/*.sh` beside its own path (never via `CLAUDE_PLUGIN_ROOT`, so a
  copied tree runs its copied lib), runs `detect`, calls `verdict_<name>`
  for each name that has one (a name with no verdict function contributes
  nothing; probe calls join in Item 4.1), and emits one object with `jq -n
  --arg`. When `phantom-chardev` and `phantom-untracked` both fire, only
  `verdict_phantom_untracked` is called: its paragraph restates the chardev
  one. Any failure exits 0 with empty stdout. `hook.bats` runs a copy of
  `hooks/` and `lib/` under `$BATS_TEST_TMPDIR` as `bash
  <copy>/hooks/annotate.sh`, so stubs can be appended to the copied lib
  files; it builds each payload from the Item 1.4 fixtures with `jq`. In
  the fixture sweeps (slices 4, 5) a fixture whose first line is an `Exit
  code` line goes into a failure payload's `error`, any other into a
  success payload's `tool_response.stdout`. Verdict text for
  `phantom-chardev`, `phantom-untracked`, `phantom-gitadd` from
  `detectors.md`. Same commit: delete the phantom-dotfile
  masks/who-sees-them, `git add -A` and visible-unsandboxed paragraphs, and
  the `/tmp reads full` section (untranslated, design rejected
  alternatives), from the memory file; the porcelain-gate and `## Context`
  paragraphs stay, and so does the masks paragraph's sentence on the
  zero-byte read-only regular-file shape, which no verdict carries (the
  chardev matcher needs a `c` mode): it is a skill-mapped remainder for Item
  7.1, and the translation-map row for masks gains `; zero-byte shape →
  skill`. Record the hook's wall time on `quiet-clean-status` and
  on `fire-masks-porcelain` (NFR-3's 100 ms verdict-without-probe bound) in
  `docs/changelog.md` (not gated). `detect` in `lib/matchers.sh` stops
  using `mktemp`: it holds the text in a shell variable and feeds each
  matcher with `printf '%s\n'` (NFR-4); its exit 2 and the header comment
  describing the buffer go with it.
  Requirements: FR-1, FR-3, FR-5, FR-6, FR-10, NFR-2, NFR-3, NFR-4.
  Depends on: Item 1.1, Item 1.2, Item 1.3, Item 1.4
  Interfaces:
  - `hooks/annotate.sh` — stdin: hook payload; stdout: empty, or one
    object `{"hookSpecificOutput":{"hookEventName":string,
    "additionalContext":string},"systemMessage":string}` whose
    `hookEventName` echoes the payload's event name; exit 0 always
  - `verdict_<name> [outcome]` — stdin: the probe's `key=value` lines
    (empty when no probe); stdout line 1 agent paragraph, line 2 human
    line; exit 0. `<name>` is the detector name with `-` as `_`; phantom
    verdicts take no outcome
  - `tests/verdicts.bats` — a `name outcome` row table, one row per
    verdict and outcome (`-` for none), extended by Items 4.1, 4.2 and 6.1
  - `tests/helpers/hook.bash` — loaded by every hook suite:
    `failure_payload <text> [flag]` and `post_payload <stdout> [stderr]
    [flag]` printing a payload; `stub_lib <file> <body>` appending to the
    copied lib file
  Slices:
  1. External contract: `gitadd failure payload yields one verdict` —
     `fire-masks-gitadd-refused` as a `PostToolUseFailure` payload: status
     0; stdout parses; top-level keys exactly `hookSpecificOutput` and
     `systemMessage`; `hookSpecificOutput` keys exactly `hookEventName`
     (value `PostToolUseFailure`) and `additionalContext`; context contains
     `Stage explicit paths`; `systemMessage` equals `git add — refused a
     sandbox mask`. `quiet fixture yields nothing` — `quiet-clean-status` as
     a `PostToolUse` payload: status 0, stdout empty. `hooks.json names
     both events` — `jq` over `hooks/hooks.json` finds `PostToolUse` and
     `PostToolUseFailure`, each with matcher `Bash`, timeout 10 and a
     command ending in `hooks/annotate.sh"`.
     `verdicts under 400 chars` (`verdicts.bats`) — every row of a
     name/outcome table yields a first line under 400 characters and a
     second line containing ` — `; `verdict text is quiet` — `detect` over
     all rows' text concatenated prints nothing; `no removal instruction` —
     with the phantom prohibition phrase `add, delete and report` stripped,
     no row's text matches `rm `, `remove` or `delete` case-insensitively
     (D-7; the phrase is the one sanctioned `delete`, from `detectors.md`).
  2. Success text rebuild: `porcelain on stdout fires untracked` —
     `fire-masks-porcelain` in `tool_response.stdout`, event
     `PostToolUse`: `hookEventName` is `PostToolUse` and context contains
     `reading the sandbox, not the tree`; `listing on stderr fires` — the
     same text in `tool_response.stderr` gives the same context.
  3. Shared phantom paragraph: `both listing verdicts share one paragraph`
     — a payload whose text concatenates `fire-masks-chardev-explicit` and
     `fire-masks-porcelain`: `additionalContext` equals exactly line 1 of
     `verdict_phantom_untracked` (the untracked paragraph restates the
     chardev one, so "chardev absent" cannot be asserted by substring);
     `systemMessage` equals its line 2.
  4. Flag policy: `phantom verdicts ignore the flag` — each phantom fire
     fixture with `dangerouslyDisableSandbox` absent, `false` and `true`
     yields non-empty, byte-identical stdout.
  5. Quiet set: `every quiet fixture is silent` — each `quiet-*` fixture in
     both payload shapes, flag absent and `true`, yields empty stdout.
  6. Malformed payload: `non-json, scalar, array and textless object` —
     inputs `not json`, `42`, `[1]`, `{}` and an object whose
     `tool_response` is a string each yield status 0, empty stdout, empty
     stderr.
  7. Context cap: `paragraph past 2 KB is dropped, human line kept` — with
     a stub `verdict_phantom_gitadd` appended to the copied `verdicts.sh`
     printing a 1900-character paragraph, a failure payload whose text
     concatenates `fire-masks-porcelain` and `fire-masks-gitadd-refused`:
     `additionalContext` is under 2048 bytes, holds the untracked
     paragraph, lacks the stub's; `systemMessage` holds both human lines.
  8. Writes nothing: `detect needs no temp dir` (`matchers.bats`) — with
     `TMPDIR` set to a nonexistent directory, `detect` over
     `fire-lock-add-commit` prints `git-lock` and exits 0; `hook needs no
     temp dir` (`hook.bats`) — slice 1's gitadd payload with `TMPDIR` set
     to a nonexistent directory yields the same stdout as slice 1 (an
     empty-directory check would pass against the old buffer, which
     cleaned up after itself).
  9. Verdict-less name: `a name with no verdict contributes nothing` —
     `stub_lib matchers.sh` redefining `detect` to print `phantom-gitadd`
     then `no-such-detector`: `additionalContext` equals the gitadd
     paragraph alone; with `no-such-detector` alone: empty stdout.
  10. BSD tools: `hook under BSD stubs` — slice 1's gitadd payload with
      `make_bsd_stubs grep sed` on `PATH` yields the same stdout.

- Item 2.4: `lib/probes.sh`, `tests/probes.bats`,
  `tests/helpers/bsd-stubs.bash` — `probe_git_lock` and `probe_config_lock`
  to the A-3 contract, not yet called by the hook (Item 4.1 wires them).
  Path from the error text (for config-lock, the named config file plus
  `.lock`); a relative path resolves against `$2`. Holder check: the first
  of `lsof -t`, `fuser` present on `PATH` decides; neither present →
  `unknown`. Size via `wc -c`, mtime via BSD `stat -f %m` when it succeeds,
  else GNU `stat -c %Y`. Add a `stat` stub to `bsd-stubs.bash` that refuses
  `-c` as BSD does and serves `-f %m` from the real `stat -c %Y` (on Linux
  the real `stat -f` is filesystem mode, so without that the BSD path is
  untestable here). No `2>/dev/null` on the probe's own tool calls: guard
  the expected absence first. Two expected-noise exceptions, each commented
  inline (no-stderr-suppression): the BSD `stat` attempt's output is
  captured and used only on exit 0, since provoking its refusal on GNU is
  the selection mechanism; `fuser` prints the path on stderr on every call,
  so its stderr is captured and matched. Test error texts carry only the
  line naming the lock (the probe does not read git's follow-on).
  Requirements: FR-4, NFR-2. Depends on: Item 1.1
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
     lock open on an fd other than 3, with bats' fd 3 closed (`3>&-`) so
     the run does not wait on it: `held`, `pid=` equal to that job's pid;
     the job is killed in teardown.
  5. `character device is mask` — the lock path a symlink to `/dev/null`
     (so extraction stays the ordinary lock shape), flag `false` and
     `true`: `mask` both times.
  6. `no holder tool is unknown` — `PATH` set to a directory holding only
     the tools the probe needs, without `lsof` and `fuser`: `unknown`,
     `bytes=7`.
  7. `relative path resolves against cwd` — text naming `.git/index.lock`,
     `$2` the repo dir holding a present lock: `orphan`, `path=` absolute.
  8. `config-lock reads its own error` — config-lock error text (shaped as
     `fire-configlock-remote-add`) with an absent lock, flag `false`:
     `mask`; with a present lock: `orphan`.
  9. `BSD stat` — slice 3 with `make_bsd_stubs stat` on `PATH`: `orphan`,
     `bytes=7`, an `age=` integer ≥ 0.

## Phase 3: Evidence (type: general)

- Item 3.1: `docs/references/detectors.md` — live reproductions for the
  lock probes, recorded under `git-lock` and `config-lock` in place of the
  "Live reproduction owed" lines, each with the date, the command shape and
  the probe's printed output. In a scratch repo under `/tmp/claude/` with a
  pre-commit hook that stages a file, run the outcomes that need no sandbox
  first: a hand-made lock prints `orphan`; the same lock held by a
  background process prints `held`. Then a sandboxed `sh -c 'git add f &&
  git commit -m x'` produces the lock error; `probe_git_lock false <repo>`
  run unsandboxed on that text prints `mask`. The
  config-lock reproduction runs in this checkout's root, not the scratch
  repo: the `.git/config.lock` mask sits only in the session's project root
  (seen as a character device there on 2026-09-23). A sandboxed `sh -c`
  write of a throwaway key (`sandboxlies.probe`) produces the config-lock
  error; `probe_config_lock false <this checkout>` prints `mask`; should the
  write succeed instead, unset the key unsandboxed. A sandboxed command
  that does not produce its error, or a probe that prints anything else,
  stops the phase: record what happened beside the outcomes already proved
  and escalate (a 2026-09-23
  review-time attempt of the git-lock shape under `/tmp/claude/` committed
  cleanly). Requirements: FR-4. Depends on: Item 2.4
  Interfaces:
  - `detectors.md` `git-lock` and `config-lock` entries — a `Live
    reproduction (YYYY-MM-DD)` paragraph per outcome proved; its presence
    gates Item 4.1

- Item 3.2: `docs/references/detectors.md`, `tests/extract-fixtures.py`,
  `tests/corpus-eval.py`, `tests/fixtures/`, `tests/matchers.bats` —
  candidate triage and measurement for `readonly-path`, `tmpdir-unset`,
  `resume-lost`, `zellij-socket`, `seccomp-init`. Per candidate: replay
  with `plans/2026-09-02-sandbox-detector-replay.py` (count, sample); pick
  the shape discriminator the sample supports (line start, the tool's own
  prefix, or a follow-on; A-7); extend `tests/corpus-eval.py`'s prefilter
  with the candidate's string and join the flag from the paired tool-use
  input; run it with a scratch shell matcher implementing the
  discriminator as arbiter (under `/tmp/claude/<job>/`, not committed —
  Items 4.2 and 4.3 rebuild it test-first). Record under the candidate, in
  the shape the shipped entries use (the discriminator in its `Matcher.`
  paragraph, described, not quoted; one `Corpus.` line with hit count,
  true count, precision, date and pilot-traffic note, then each false
  positive's class), and the D-15 decision — `ships` or `stays a
  candidate`. The executor names no residual: a false positive that is
  neither self-reference (D-10) nor a residual already named in the
  candidate's `detectors.md` entry is recorded under the candidate and
  escalated to my human partner before `Decision: ships` is written.
  `detectors.md` is ~311 lines against Item 2.1's 400 cap, so
  keep each record to that shape. For each shipping candidate, extend
  `tests/extract-fixtures.py`'s cut list and cut at least one
  `fire-<detector>-*` and one `quiet-<detector>-*` fixture (names letters
  and hyphens only, as the suite's name scan expects), and add each to
  `expected_for` in `tests/matchers.bats` expecting no verdict — true until
  the matcher exists, and the suite's fixture-coverage cases fail on a
  fixture with no row. A candidate with zero true positives is recorded as
  such. Requirements: FR-7, FR-8, NFR-1. Depends on: Item 1.1
  Interfaces:
  - `detectors.md` candidate entry — a `Decision: ships` or `Decision:
    stays a candidate` line, read by Items 4.2 and 4.3
  - `detectors.md` candidate entry — the discriminator stated precisely
    enough to implement as `match_<name>` (anchor, the tool prefix, the
    required substrings described)
  - `tests/fixtures/fire-<detector>-<case>.txt`,
    `tests/fixtures/quiet-<detector>-<case>.txt` — at least one each per
    shipping candidate

## Phase 4: Lock verdicts and shipped candidates (type: tdd)

Items 4.2 and 4.3 build only candidates Item 3.2 records as `ships`. A
candidate recorded `stays a candidate` gets no code change and keeps its
memory section; `/build` reports it as skipped, and an item left with no
shipping candidate is skipped whole. For each shipped candidate, slice 1
flips its fire fixture's `expected_for` row from no verdict to the detector
(its red), and before commit the item re-runs Item 3.2's
`tests/corpus-eval.py` pass with the shipped matcher as arbiter,
re-recording the `Corpus.` line if the hit count moved (NFR-1). Candidate
hook cases go in `tests/hook-candidates.bats` (loading
`helpers/hook.bash`), keeping `tests/hook.bats` under its 400-line cap;
when FR-5's status flips, its pinned-by names both files. Whichever item
first creates `tests/hook-candidates.bats` gives it one case re-running a
fire case under `make_bsd_stubs grep sed` (Portability).

- Item 4.1: `hooks/annotate.sh`, `lib/verdicts.sh`, `tests/hook.bats`,
  `tests/verdicts.bats`, `tests/matchers.bats` — `git-lock` and
  `config-lock` verdicts for all five outcomes, text from `detectors.md`;
  the hook calls each probe per the interface below. The config-lock
  verdicts omit the `GIT_INDEX_FILE` leak clause, which concerns
  `index.lock` only (with it the `mask` paragraph runs to 426 characters
  against FR-6's 400); write the config-lock paragraphs out in full in
  `detectors.md` in place of its `As git-lock` shorthand. Every case here
  that fires a lock detector stubs its probe, so no fixture's absolute path
  reaches the host filesystem. Same commit: delete the `.git/index.lock`
  section, including its `.git/config.lock` paragraph, from the memory
  file, and delete the `tests/matchers.bats` case asserting the live file
  still quotes git's follow-on only partially — with the section and its
  description symptom gone the file no longer quotes it at all, so that
  case goes red; the live-file silence case stays until Item 8.2.
  Requirements: FR-3, FR-4, FR-5, FR-6, FR-10.
  Depends on: Item 2.3, Item 2.4, Item 3.1
  Interfaces:
  - hook → probe — for a name whose `verdict_<name>` is defined and whose
    `probe_<name>` is defined, the hook runs the probe with the text on
    stdin, `$1` the flag (`true`/`false`, absent meaning `false`) and `$2`
    the payload `cwd`; its line 1 becomes the verdict's outcome argument
    and its remaining lines the verdict's stdin
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
  3. `orphan and unknown interpolate size and age` — stub prints `orphan`
     then `bytes=7`, `age=12`: context contains `7 bytes` and `age 12s`;
     the same with `unknown` as line 1: context contains `7 bytes`, `age
     12s` and `no holder check is available`.
  4. `probe receives flag and cwd` — a stub recording its arguments to a
     file under `$BATS_TEST_TMPDIR`: payload with the flag `true` and `cwd`
     `/x` records `true /x`; flag absent records `false /x`.
  5. `config-lock mask names config.lock and update-config` —
     `fire-configlock-remote-add`, stub `mask`: context contains
     `config.lock` and `update-config`.
  6. `piped lock failure on a success payload` — `fire-lock-piped-tail` in
     `tool_response.stdout`, event `PostToolUse`, stub `mask`: context
     contains `GIT_INDEX_FILE` (D-4).
  7. Fixture sweep: `every lock fixture yields its verdict` — each
     `fire-lock-*` and `fire-configlock-*` fixture, payload shape per Item
     2.3's sweep rule, flag absent and `true`, stub `mask`: `systemMessage`
     is the `mask` human line naming `index.lock` or `config.lock`
     respectively.
  8. `no probe without a verdict` — `stub_lib` defining `probe_fake`
     (recording its calls) and a `detect` printing `fake`: empty stdout, no
     call recorded.

- Item 4.2: `lib/matchers.sh`, `lib/verdicts.sh`, `tests/matchers.bats`,
  `tests/hook-candidates.bats`, `tests/verdicts.bats` — the four
  verdict-only candidates, one row each below, built for every row whose
  candidate ships. Per shipped row: `match_<name>` from Item 3.2's
  discriminator; `verdict_<name>` (no outcome) from `detectors.md` and its
  `tests/verdicts.bats` row; the row's flag policy in the hook; and, same
  commit, the row's section deleted from the memory file. Each slice's
  case runs once per shipped row.
  | detector | flag policy | fires with | silent with | context contains | memory deletion |
  |---|---|---|---|---|---|
  | `tmpdir-unset` | fires only when `true` | `true` | absent | `/tmp/claude/` | cost 1 of `Leaving the sandbox`, except the instability clause (skill-mapped) |
  | `resume-lost` | fires only when `false` | absent | `true` | `one unsandboxed call` | the `--resume` section, except the eval-harness consequence (skill-mapped) |
  | `zellij-socket` | fires only when `false` | absent | `true` | `socket is outside the sandbox` | the zellij section |
  | `seccomp-init` | silent when `true` | absent | `true` | `Retry the identical command once` | the sandbox-setup section |
  Requirements: FR-5, FR-6, FR-7, FR-10, NFR-1.
  Depends on: Item 3.2, Item 4.1
  Slices:
  1. `fire and quiet fixtures` (`matchers.bats`) — each cut
     `fire-<detector>-*` fixture yields exactly the row's detector; each cut
     `quiet-<detector>-*` yields nothing.
  2. `<detector> flag policy` (`hook-candidates.bats`) — the fire fixture
     with the flag set as the row's "fires with" yields context containing
     the row's "context contains" string; with the flag as its "silent
     with" yields empty stdout.

- Item 4.3: `lib/matchers.sh`, `lib/probes.sh`, `tests/matchers.bats`,
  `tests/probes.bats`, `tests/hook-candidates.bats` — `readonly-path`
  matcher and probe, no verdict yet, so the hook stays silent on it and
  never runs the probe (Items 2.3 and 4.1's verdict-gated rules). Probe
  test texts reuse the cut fire fixture's refusal line with its quoted path
  replaced. Requirements: FR-4, FR-7, NFR-1. Depends on: Item 2.4,
  Item 3.2, Item 4.1
  Interfaces:
  - `probe_readonly_path <flag> <cwd>` — stdin: result text; stdout line 1
    one of `writable|readonly|nopath`, then `path=` when extracted; exit 0
  Slices:
  1. `fire and quiet fixtures` — as Item 4.2 slice 1, for `readonly-path`.
  2. `writable path` — text naming a file under `$BATS_TEST_TMPDIR`:
     `writable`, `path=` that file.
  3. `absent file checks its parent` — text naming a missing file in a
     writable dir: `writable`; in a `chmod 555` dir: `readonly`.
  4. `no quoted path` — text with no quoted path: `nopath`, no `path=`
     line.
  5. `hook silent without a verdict` (`hook-candidates.bats`) — the fire
     fixture as a failure payload, flag absent, with a stub
     `probe_readonly_path` recording its calls: empty stdout, no call
     recorded.

## Phase 5: readonly-path live proof (type: general)

- Item 5.1: `docs/references/detectors.md` — runs only if `readonly-path`
  ships. Create a scratch repo under `/tmp/claude/` and, unsandboxed, a
  linked worktree of it outside the sandbox's write allowlist (a directory
  directly under `/tmp/`: `/tmp/claude/` itself is writable sandboxed, so a
  worktree there reproduces nothing); a sandboxed `sh -c` write into the
  worktree produces the read-only error; `probe_readonly_path false <cwd>`
  run unsandboxed on that text prints `writable`. Remove the worktree
  unsandboxed afterwards. Record date, command shape and output under
  `readonly-path`. A write that succeeds, or any other probe output, stops
  the phase and escalates. Requirements: FR-4. Depends on: Item 4.3
  Interfaces:
  - `detectors.md` `readonly-path` entry — a `Live reproduction
    (YYYY-MM-DD)` paragraph; its presence gates Item 6.1

## Phase 6: readonly-path verdict (type: tdd)

- Item 6.1: `lib/verdicts.sh`, `tests/hook-candidates.bats`,
  `tests/verdicts.bats` — runs only if `readonly-path` ships. Three
  verdicts from `detectors.md`; flag policy: silent when the flag is
  `true`. Same commit: delete the harness-mounted-config-paths and
  sibling-worktree sections and cost 3 of `Leaving the sandbox`, except
  their skill-mapped remainders — the merge-recovery procedure and cost 3's
  recipe guidance stay for Item 7.1 (translation map). Requirements:
  FR-4, FR-5, FR-6, FR-7, FR-10. Depends on: Item 4.1, Item 5.1
  Slices:
  1. External contract: `writable outcome through the hook` — the fire
     fixture, stub probe printing `writable` and `path=/r/x`: context
     contains `/r/x`, `is writable outside the sandbox` and `compare
     modified files against the target`; human line `read-only — sandbox
     allowlist, writable outside`. Verdict rows added for all three
     outcomes.
  2. `readonly and nopath` — stub `readonly`: context contains `not a
     sandbox effect`; stub `nopath`: context contains `write allowlist` and
     `compare modified files against the target`.
  3. `silent unsandboxed` — flag `true`: empty stdout, and the stub probe
     records no call.

## Phase 7: The skill and repository prose (type: general)

- Item 7.1: `skills/sandbox-lies/SKILL.md`,
  `skills/sandbox-lies/references/` — the symptom-less knowledge, every
  row the `detectors.md` translation map sends to `skill`, including the
  skill-mapped remainders Item 2.3 (the zero-byte mask shape), Item 4.2
  (`tmpdir-unset`, `resume-lost` rows) and Item 6.1 leave — the last two
  taken whether or not their candidate shipped. A stayed candidate's
  detector-mapped part is not copied: it stays in memory only (D-11: never
  both). `SKILL.md` under
  200 lines, third person `description` naming the authoring moments
  (writing an exclusion, a recipe, a cleanliness gate, a subagent
  directive with a scratch path);
  detail in `references/`. Error strings described, not quoted. Before
  commit, grep the skill for requirement and decision ids (FR, NFR, D-n)
  and for `/Users/` and `~/code/`: none ship. Same commit: delete every
  skill-mapped section and paragraph from the memory file. Done when
  `tests/docs.bats` and `precommit` are green and the memory file holds
  only its `## Context` paragraph plus the detector-mapped parts of
  candidates that stayed candidates. Requirements: FR-9, FR-10, FR-11.
  Depends on: Item 4.1, and Items 4.2 and 6.1 where they ran
  Interfaces:
  - `skills/sandbox-lies/SKILL.md` — the skill `sandbox-lies:sandbox-lies`;
    the name Items 7.2 and 8.2 point readers at
  - `memory/ddaanet/sandbox-effects.md` — post-state: frontmatter,
    `## Context` paragraph, and any stayed candidate's detector-mapped part
    only

- Item 7.2: `README.md`, `LICENSE`, `CLAUDE.md` — README: what the plugin
  does, install (the `--plugin-dir` route: a marketplace install aborts on
  the memory submodule's relative url until the out-of-scope `.gitmodules`
  fix lands), the detector list pointing at `detectors.md`, the skill;
  LICENSE: MIT, holder David Allouche, 2026; `CLAUDE.md`: a body for
  agents working here (precommit, the self-quiet rule, fixtures come from
  the cutter), the `@memory/ddaanet/shared-claude.md` import line kept
  last. Requirements: FR-9, FR-11. Depends on: Item 7.1

## Phase 8: Dogfood and final deletion (type: general)

- Item 8.1: `.bin/claude`, `.envrc` — the D-16 shim: prepends
  `--plugin-dir <this checkout>` and execs the next `claude` on `PATH` with
  `.bin` stripped from `PATH`; `.envrc` adds `PATH_add .bin` last.
  `direnv allow` is my human partner's step (see Cross-cutting). Verify
  without waiting for it by invoking `./.bin/claude -p --output-format json`
  unsandboxed from this checkout, with a prompt (naming no skill) asking it
  to list its skills, then run `sh -c 'ls -la'` at the checkout root without
  the sandbox flag: the reply names `sandbox-lies:sandbox-lies`, and the
  session transcript under `~/.claude/projects/`, found by the reply's
  `session_id`, holds the phantom-chardev verdict's wording as hook context
  on that result — the model quoting its own context is corroboration, not
  the evidence. Requirements: D-16, FR-1. Depends on: Item 2.3, Item 7.1

- Item 8.2: `memory/ddaanet/sandbox-effects.md`, `memory/MEMORY.md`,
  `memory/ddaanet/MEMORY.md`, `memory/ddaanet/shared-claude.md`, six
  inbound-link files, `tests/matchers.bats`, `tests/docs.bats`,
  `docs/design.md` — runs when the memory file holds only `## Context`
  (candidates that stayed candidates keep it alive; then this item is
  deferred and reported). Audit the translation map row by row against the
  file's git history (`git -C memory/ddaanet log -p`) and record the audit
  as a column of the translation-map table in `detectors.md`, whose
  "Phase 6 step" reference becomes this item. In one parent
  commit: amend the phantom-dotfile bullet in `shared-claude.md` with the
  `!`-expansion clause and repoint its `sandbox-effects` reference to the
  `sandbox-lies` skill; delete the memory file and both index lines;
  rewrite the `[[sandbox-effects]]` link in
  `cc-bash-background-no-duration-cap`, `cc-worktree-bash-guard`,
  `classifier-denied-self-config`, `codex-review-of-design-docs`,
  `git-add-untracked-deletion`, `bang-shell-shared-cwd` to name the skill;
  delete the remaining `tests/matchers.bats` case that reads the live file
  (Item 4.1 removed the other; keep `quiet-memory-file-read`); add a
  `tests/docs.bats` case that fails when a tracked file under `hooks/`,
  `lib/`, `skills/`, `tests/` outside `tests/fixtures/`, `CLAUDE.md` or
  `README.md` names the retired path `memory/ddaanet/sandbox-effects.md`
  (A-6), its needle built from two fragments so `docs.bats` does not name
  it, fault-injected once. The needle is the full path, not the bare
  filename: `tests/extract-fixtures.py` keeps a `cat sandbox-effects.md`
  cut selector (FR-8 reproducibility) and the `quiet-memory-file-read`
  comment in `tests/matchers.bats` names the file historically. Update
  `## Now` in `docs/design.md`. Then publish the tier with `/gitlore:push`
  once my human partner confirms (outward-facing: it retires the fact for
  every ddaanet repo), and report that other repos mounting the tier keep
  their own root `memory/MEMORY.md` index line, which this item does not
  edit (other repos stay read-only). Requirements: FR-10, FR-11.
  Depends on: Item 1.3, Item 7.1
