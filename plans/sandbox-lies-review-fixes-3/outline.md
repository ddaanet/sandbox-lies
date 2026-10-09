# Outline — sandbox-lies-review-fixes-3

This job closes every open code item in one build: the `path=` encoding my
human partner decided, the first review's deferred Minors (code m-1, m-7, m-8,
m-9, Tests m-6), and the carry-forward from
`plans/sandbox-lies/reports/build-finish.md`. Each item gets a plain verdict on
whether it earns a build slice. The ones that do not are closed as documented
residuals, so nothing stays open for a later job. Classification: Moderate,
Production (`classification.md`). Items use the runbook item shape, so `/build`
can walk this outline directly.

## Provenance

- **Derived from:** `none` as a review lineage. The items come from
  `plans/sandbox-lies-review-fixes-2/reports/deliverable-review.md` and
  `deliverable-review-fixes.md`, and this outline takes over the open items of
  `plans/sandbox-lies-review-fixes-2/outline.md`.
- **Base:** `2309ae69527623112aced16277775ea241a96a3c` is this job's start.

The base deviates from edify's rule of copying the superseded outline's base
verbatim (`52e6dd8`). My human partner asked for it explicitly, so the
deliverable review covers this build alone. The rule's checker,
`edify-review-range.sh`, compares the base with the prior outline's whenever
`Derived from:` names one as superseded. With the old wording it printed
`CONFLICT:`, so `Derived from:` opens with `none` and names the prior outline
only in prose. It then prints `RANGE: 2309ae6…..HEAD`.

## Verdict per item

| # | Item | Verdict | Why |
| --- | --- | --- | --- |
| A | `path=` as `printf %q` | Build | Decided, and confirmed as designed. Only one input triggers it: a newline in the payload `cwd`. The cost is two items. |
| B | Partial-checkout path from a subdirectory | Build | Today it can produce a wrong `readonly` verdict, which says unsandboxing will not help. |
| C | Phantom "project root" wording | Build | False after a persisted `cd`. It is a three-site string edit. |
| D | m-1 quadratic tokenizer | Build | Times out on bash 3.2.0: 38.7 s at the cap, against a 10 s hook timeout. |
| E | Tests m-6 (suite on macOS) | Build | Two lines. Both helpers already exist. |
| F | m-7 line-cap coverage | Build | One `case` arm and one test. No file is near the cap today. |
| G | m-8, m-9 Python tools | Build | My human partner's call. Each fix is small, and each behavioural one gets a red case. |
| H | Five `nopath` shapes | Close | In every recorded case, a path would not change the act. |
| I | Item 8.2 remainder | Close | `memory/ddaanet/sandbox-effects.md` stays as the home of zellij, whose detector cannot ship under D-15 with 0 corpus hits, and of the leak. FR-10 is reworded (Items 7.1, 7.4). |

## Evidence

The probes behind §A, §D and Item H are in `evidence.md`: the `printf %q`
forms on bash 5.2.37 and 3.2.0, the locale pin, assignment eval on 3.2, the
tokenizer timings, the `nopath` hits, and how to rebuild bash 3.2.0.

## Design

### A. `path=` in `printf %q` form

- **Wire.**
  - Every `path=` value is printed by one helper as `path=` plus
    `LC_ALL=C printf %q` of the resolved path.
  - An empty path prints no `path=` line at all. Today
    `_probe_lock_at` prints a bare `path=`. With this change every printed
    value is absolute, and so opens with `/` or `$'`. That rules out a
    leading `~`, and the first bytes tell the two forms apart.
  - The two newline guards go:
    - `pathline` in `_probe_lock_at`, `lib/probes.sh:112-131,219-221`;
    - the newline arm of `probe_readonly_path`'s `nopath`, `lib/probes-readonly.sh:54-60`.

    A newline-bearing path then gets its real outcome (`writable` or
    `readonly`) and one `$'…'` line.
- **Reader.**
  - `lib/verdicts.sh` decodes each `path=` value without eval:
    - **A value opening with `/`** is the backslash form. Drop each escaping
      backslash; `read` without `-r` from a process substitution does this
      (NFR-4: no file).
    - **A value opening with `$'`** must match the grammar
      `^\$'([^'\\]|\\.)*'$`. Strip the `$'` and the closing `'`, turn each
      `\'` into `'`, and decode the rest with `printf -v … %b`. The value is
      an argument, never the format.
    - **Any other value** reads as no `path=`. Today's fallbacks apply: "The
      path", and the flag-worded re-run for the config lock.
  - **Display.** The decoded path is shown unless it holds a control byte
    (`\001`-`\037`, `\177`). Then the wire form is shown, because a raw newline
    would split the verdict's paragraph from its human line. A path with a
    blank, or with UTF-8, therefore reads exactly as it does today.
  - The two `.claude/settings.json` suffix matches (`verdict_config_lock`,
    `verdict_readonly_path`) test the decoded value.
- **Why not eval.** Two arguments:
  - The producer is our own probe (`harden-human-gates`), so a guard there is
    not the point.
  - Assignment eval is wrong on 3.2 (`evidence.md`), and word-context eval
    puts an executable surface where a decoder needs none. The
    pattern-substitution step for `\'` has changed meaning across bash
    versions, so the executor runs it on the 3.2.0 build with the pattern and
    the replacement held in variables.
- **Scope.** Only `path=` changes, by my human partner's call; `readfile=`,
  `match=` and `target=` keep their newline skips. The reason, checked against
  `docs/references/readonly-path.md:65-91` and
  `lib/probes-readonly-facts.sh:148-173`: only a newline in `path=` loses the
  path, degrading the outcome to `nopath`. The others lose one optional fact:
  - A `readfile=` with a newline is not printed; the act becomes the generic
    re-run.
  - A ref name cannot hold a newline (git forbids control characters in ref
    names, and the probe skips any candidate holding a blank). The `target=`
    skip comes instead from a repository root holding one, which would split
    every `match=` line. With no `match=` there is no `target=`, so the merge
    clause degrades to the generic `partial=1` wording, or to none.
  - A newline in a changed file's name drops its `match=` line. If that was
    the only match, the merge clause is dropped rather than made generic: the
    one place the reason as first stated is too strong.

### B. Partial-checkout path from the worktree top

`probe_readonly_path` keeps the matching line, which `_readonly_path_line`
already gives once. When `_readonly_partial_checkout_text` holds for that line
alone, a relative path joins onto `_readonly_git_dir "$cwd"`. That function
walks to the nearest ancestor holding a `.git` entry, file or directory, so
linked worktrees and submodules are covered. With no `.git` ancestor it joins
onto `cwd` as today. Every other producer keeps joining onto `cwd` (`cp`, `mv`,
`touch` and bash resolve against their own process cwd). `git -C` stays a
residual (D-1).

### C. Phantom wording

Both phantom paragraphs open with "…entries in this listing are sandbox masks,
not files in the repository." No location is named, so the sentence holds under
any `cwd`. `hook.md`'s "names the project root, the usual case" goes with it.

### D. Tokenizer accumulation

`_readonly_tokenize` appends each character to a pending run of at most 256
characters. The run joins `word` when it fills, and before any read of `word`:
the emission at a separator and at the end, the `#` test, and the `&`
duplication test, which reads the last character. The output is unchanged. The
header's cost sentence is rewritten to the measured figures.

## Items

### Phase 1: `path=` encoding (type: tdd)

Phase 1 runs first and alone; its boundary review sees only it. Between Item
1.1 and Item 1.2 the hook shows backslash-escaped paths to the agent. That
state is internal to the phase and is not a regression for the Item 1.1 review
to flag.

- Item 1.1: `lib/probes-readonly.sh`, `lib/probes.sh` — encode `path=` (§A
  Wire). Requirements: FR-4, NFR-4.
  Slices:
  1. External contract, `tests/probes.bats`: a relative lock path under a
     `cwd` named `r b` prints exactly `path=<tmp>/r\ b/.git/index.lock`. The
     case opens by asserting `BATS_TEST_TMPDIR` holds no byte `%q` escapes. In
     the same slice, `probe_config_lock` with no config-lock line prints
     `mask` and no `path=` line.
  2. `tests/probes-lock-newline.bats`: each of the five pinned print sites
     (absent under each flag, character device, held, final orphan) now prints
     one `path=$'…\n…'` line, the decoded value of the twin's path. No forged
     key line appears, and the header is rewritten to match. The twin outputs
     now differ on their `path=` lines (`$'…'` against `r\ b`), so
     whole-output equality is no longer the assertion. Instead, the outcome
     line and every non-`path=` line must be identical, and each `path=` line
     is asserted to its literal encoded form.
  3. `tests/probes-readonly-members.bats:142`: a relative refused path under a
     newline-bearing `cwd` gives `writable` and one `$'…'` `path=` line, not
     `nopath`. The test is renamed.
  4. Locale pin: a lock path holding `é`, run under `utf8_locale`, prints the
     `\303\251` octal form. On bash 5.2 an unpinned `%q` prints `é` raw, so the
     case is red without the pin. This slice moves `utf8_locale` out of
     `tests/hook-cap.bats` into a new `tests/helpers/locale.bash`, which
     `hook-cap.bats`, `probes.bats` and the slice's own suite load. Its header
     names those three as sharing it. `hook-cap.bats` loads `helpers/hook`, not
     `helpers/probes`, which is why the helper gets its own file.
  5. Every other `path=` assertion the encoder breaks: run the suite, then
     rewrite each failure to the literal encoded form. Expected sites:
     `probes.bats`'s non-UTF-8-byte case, and blank-named trees in
     `probes-readonly*.bats` and `hook-*.bats`. List each one in the slice
     report.
  Interfaces:
  - `_probe_path_line <path>` — prints `path=` + `LC_ALL=C printf %q <path>`
    and a newline; prints nothing for an empty `<path>`. It lives in
    `lib/probes-readonly.sh`, which both probe files reach.
- Item 1.2: `lib/verdicts.sh` — decode and display (§A Reader). Requirements:
  FR-6, D-7. Depends on: Item 1.1.
  Slices:
  1. Through `hooks/annotate.sh` (`tests/hook-writes.bats` or
     `hook-candidates.bats`): a `readonly-path` payload naming a relative path
     under a `cwd` holding a blank. `additionalContext` names the absolute path
     raw in backticks, with no backslash.
  2. `tests/verdicts-readonly.bats`:
     - `path=$'/x/caf\303\251/f'` under `writable` shows `` `/x/café/f` ``,
       byte-exact;
     - `path=$'/x/a\nb/f'` shows the wire form in backticks, and the verdict is
       exactly two lines.
  3. Suffix match on the decoded value:
     - `path=$'/h/jos\303\251/.claude/settings.json'` under `writable` gives
       the `update-config` act;
     - `verdict_config_lock mask` with the matching `.lock` value does the same
       (`tests/verdicts-locks.bats`).
  4. Inert and malformed values:
     - `path=/x/\$\(touch\ <sentinel>\)` shows `/x/$(touch <sentinel>)`, and
       the sentinel file does not exist;
     - `path=$'a'b` shows "The path".
  Interfaces:
  - `_verdict_path_read <wire>` — sets `_verdict_path_raw` (decoded bytes)
    and `_verdict_path_shown` (raw, or the wire form when raw holds a control
    byte); returns 1 with both empty for a malformed value.

### Phase 2: partial-checkout resolution (type: tdd)

- Item 2.1: `lib/probes-readonly.sh` — §B. Requirements: FR-4. The cases go in
  a new `tests/probes-readonly-resolve.bats`, since `probes-readonly.bats` is at
  387 lines. The new file loads `helpers/bsd-stubs` and keeps one case under
  `make_bsd_stubs`, because the probe calls `grep` and `sed`.
  Slices:
  1. From `<repo>/sub`, git's unlink-old refusal
     names `d/f`, built from fragments, and `<repo>/d/f` exists. The probe
     prints `writable` and `path=<repo>/d/f`; today it prints `readonly` and
     `<repo>/sub/d/f`. The same holds for the create-directory-at shape naming
     `d/n`.
  2. A linked worktree (`.git` file) entered at a subdirectory: the path joins
     onto the worktree top.
  3. Regressions:
     - a `cp` refusal naming relative `d/f` from `<repo>/sub` still joins onto
       `<repo>/sub`;
     - a partial-checkout line with no `.git` ancestor joins onto `cwd`.

### Phase 3: phantom wording (type: tdd)

- Item 3.1: `lib/verdicts.sh:16,22` — §C. Requirements: FR-6.
  Slices:
  1. `tests/verdicts.bats:55` pins the new chardev paragraph whole. A new
     assertion pins the untracked paragraph's opening sentence. Both are red
     against the current text, and both paragraphs stay under 400 characters.

### Phase 4: tokenizer (type: general)

- Item 4.1: `lib/probes-readonly-command.sh` — §D. Requirements: NFR-3,
  NFR-2. The `probes-readonly*.bats` suites are the guard and pass unchanged.
  The report records the timing table in `evidence.md`, re-run after the
  change on bash 5.2 and on the 3.2.0 build; the target is under 5 s on 3.2
  for one 16384-character word. Measured, not gated: a timing case would be
  flaky on this box.

### Phase 5: small fixes (type: general)

- Item 5.1: tests — m-6. Requirements: NFR-2.
  - Use `utf8_locale` (moved by Item 1.1/4) in place of the literal `C.UTF-8`
    at `tests/probes.bats:64-70`.
  - Use `index_mtime` at `tests/probes.bats:302`.

  Depends on: Item 1.1.

  The report says "portable by construction, unverified on a Mac".
- Item 5.2: `scripts/check-line-limits.sh` — m-7. Requirements: NFR-5.
  - Cap `*.awk`, `*.toml`, `justfile` and `*.json` at 400, at any depth outside
    `plans/`, `plugin-dev/` and `tests/fixtures/`.
  - Rewrite the header's scope sentence to match. It names extensionless
    files (`.gitlore/bin/claude`, gitlore-generated) as out of scope.
  - Add one case to `tests/check-line-limits.bats` (at 350 lines): a 401-line
    `.awk` is reported.

### Phase 6: Python dev tools (type: tdd)

Each case runs the tool under a scratch `HOME` holding a JSONL corpus written
at run time. Any diagnostic text it needs is built from fragments, so
`tests/docs.bats` stays quiet.
Each new suite loads `helpers/bsd-stubs` and keeps no `make_bsd_stubs` case:
the Python calls no stubbed tool. Each fix gets a mutation check: revert it,
and its case goes red on the assertion.

- Item 6.1: `tests/corpus-eval.py` — m-8, and m-9's shape. Requirements:
  NFR-1, its replay harness. New suite `tests/corpus-eval.bats`.
  Slices:
  1. `extract` first removes every file in `survivors/` and any
     `verdicts.tsv`, both left by an earlier survivor set. Case: extract over
     two survivors, write a `verdicts.tsv`, shrink the corpus to one, extract
     again. One survivor file and no TSV remain; today both stale files do.
  2. `aggregate` skips a verdict line whose file has no manifest entry, and
     prints the skipped count. Today the `manifest[f]` reads at `:234`, `:235`
     and `:246` raise `KeyError`.
  3. A Bash `tool_use` whose `input` is not a dict reads as no command
     (`:152-153`). Case: a string `input` beside one survivor; `extract` exits
     0 and writes it. Today it raises `AttributeError`.

  With no case, since no test reaches them:
  - The docstring loop redirects once, with `>` after `done`, so re-running
    it does not duplicate lines.
  - The prefilter comment (`:48-52`) stops claiming the list is broader than
    every matcher: `crw-` covers the `/dev/null` mask's mode only, not every
    mode `match_phantom_chardev` accepts.
- Item 6.2: `tests/extract-fixtures.py` — m-9. Requirements: FR-8. New suite
  `tests/extract-fixtures.bats`. `OUT` resolves next to the script, so each
  case copies the script into a scratch `tests/`, never cutting into the
  repo's `tests/fixtures/`. The corpus holds a call matching one `SPEC` entry,
  and the case passes that entry's name.
  Slices:
  1. A `null` `timestamp` reads as no day (`:160`; the `.get` default does
     not cover an explicit `null`). Case: such a line before the matching
     call; exit 0, and the cut file's bytes equal the call's output. Today it
     raises `TypeError`.
  2. A non-dict `input` reads as no command (`:165`). Case: a string `input`
     before the matching call, same assertions. Today: `AttributeError`.

  With no case: `pick()`'s all-projects branch goes, with `(project or '*')`
  at `:229`. Every `SPEC` entry names a project and `main()` passes it
  through, so the branch is unreachable; reaching it would need a
  project-less entry no fixture wants. Both cases staying green is the guard.

### Phase 7: docs (type: general)

One item per file. Each runs `just format-docs`, and `docs/design.md` must stay
at or under 400 lines with no crammed lines.

- Item 7.1: `docs/design.md`.
  - Now: drop the `nopath` sentence.
  - FR-4: one clause, "a `path=` value is printed in `printf %q` form".
  - FR-10 (`:150-161`): every section the plugin carries is retired, and the
    memory file keeps what it does not. The deletion, index-line, inbound-link
    and `docs.bats` retired-path clauses go, and so does the `Item 8.2`
    pointer. FR-10's status becomes Done.
  - Status (`:3-9`): drop the `Partial` sentence, and bump "Verified against".
  - The file is at 399 lines, so the FR-10 rewrite must not grow it.
- Item 7.2: `docs/references/readonly-path.md`.
  - `:28`: `path=` is in `%q` form.
  - `:51`: `nopath` means only that no path was extracted.
  - `:42-45`: the partial-checkout residual becomes the resolution rule, and
    `git -C` stays a residual.
  - Add a residual for the five shapes (`evidence.md`; described, never
    quoted). It notes that a removal refused on a leaked phantom mask gets the
    re-run act, which the leak makes futile.
  - Verdicts: the display rule from §A Reader.
- Item 7.3: `docs/references/lock-detectors.md:30-31` — the `%q` contract
  replaces the newline exception.
- Item 7.4: `docs/references/detectors.md`.
  - `:84` and its twin: the new phantom text.
  - Translation map: the intro (`:313-315`) stops promising a deletion
    and drops the Item 8.2 audit. The zellij row says the section stays in
    memory, and a new leak row says the same.
- Item 7.5: `docs/references/hook.md:101-105` — §C.
- Item 7.6: `docs/changelog.md` — one entry covering the code changes, the
  test-side changes and the Python tools, and naming the closed items (H, I)
  with their reasons.
- Item 7.7: the comments that state the old contract.
  - `lib/probes.sh:8-13` and `:105-111`;
  - `lib/probes-readonly.sh:6-7`, `:36-39` and `:54-55`;
  - `lib/verdicts.sh:139-145`. Its "never a printf format, sed or eval"
    becomes "never eval; `%b` decodes an argument, never a format".

## Scope

- **IN:** Items 1.1 to 7.7.
- **OUT, closed with a reason:**
  - **H, the five `nopath` shapes.** See `evidence.md`.
  - **I, the Item 8.2 remainder.** The file's deletion, the `docs.bats`
    retired-path case, the audit column and the index-line edits are moot.
    `tests/matchers.bats:280` stays, since the file persists.
- **OUT, not code:** the publishing steps, the m-3 scratch transcripts, and the
  rejected `deliverable-review-build-only-range.md`. They stay in
  `.claude/handoff-todo.md`.
- **A step for my human partner, not an item:** the opening paragraph of
  `memory/ddaanet/sandbox-effects.md` says the leak section is "not yet in the
  skill". Reword it to say the file keeps that section. The build edits nothing
  under `memory/`.
- **Observation, not built:** `readonly-path` fires on a removal refused on a
  leaked mask, the symptom of the memory file's leak section. A detector of its
  own would need a corpus replay under D-15.

## Questions

None open. My human partner answered all five. The answers are folded into
§Provenance, the verdict table, §A Scope and the Items. They also kept the
`Derived from:` restructure and the `evidence.md` split.

## Route

After approval: commit this outline and name
`/build plans/sandbox-lies-review-fixes-3`. No runbook. Phases run in order,
1 to 7. Phase 1 must come first, and Items 5.1 and 7.7 depend on its encoder.
The items already carry their slices.

## Resume

Approved by my human partner at `/edify:proof`, as it stands: no per-item
iteration, no revisions, no kills.

- **Done:** the five answers are folded into this outline, `classification.md`
  and `evidence.md`. `edify-review-range.sh` prints `RANGE:` for this outline.
- **Next:** `/build plans/sandbox-lies-review-fixes-3`.
- The bash 3.2.0 build sits in a scratch directory that will not survive. To
  rebuild it, follow `evidence.md`.
