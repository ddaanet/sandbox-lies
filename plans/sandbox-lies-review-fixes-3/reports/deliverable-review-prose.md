# Deliverable review, Layer 1 — prose

- **Range:** `2309ae6..HEAD`, HEAD `2015b0f` on `main`.
- **Files:** `docs/design.md`, `docs/references/readonly-path.md`,
  `docs/references/lock-detectors.md`, `docs/references/detectors.md`,
  `docs/references/hook.md`, `docs/changelog.md`, and the comments of
  `lib/probes.sh`, `lib/probes-readonly.sh`, `lib/verdicts.sh`.
- **Model:** Opus 5.5 (`claude-opus-5-5`).
- **Method:** each diff and each whole file read at HEAD, against the code in
  `lib/`, `scripts/check-line-limits.sh` and the two Python tools, then a
  `/usr/bin/grep` sweep of every tracked file outside `plans/`,
  `tests/fixtures/`, `memory/` and `plugin-dev/`. No suite was run. One
  hand run of the decoder was refused by a harness safety check, so the
  decoder is verified by reading only.
- **Result:** no Critical. 1 Major, in a file the build did not touch. 10
  Minor. The seven items conform to the outline.

## Conformance table

| Item | Outline clause | Status | Evidence at HEAD |
| --- | --- | --- | --- |
| 7.1 | Now: drop the `nopath` sentence | done | `## Now`, Next bullet ends at "a prerequisite of the next." |
| 7.1 | FR-4: one `%q` clause | done | FR-4: "(a `path=` value is printed in `printf %q` form)" |
| 7.1 | FR-10: plugin sections retired, memory keeps the rest | done | FR-10: "Every section the plugin carries is retired. The file keeps what it does not" |
| 7.1 | FR-10: deletion, index-line, inbound-link, `docs.bats` clauses go | done | none of the four remains in FR-10 |
| 7.1 | FR-10: `Item 8.2` pointer goes | done | sweep: no hit outside the changelog |
| 7.1 | FR-10 status becomes Done | done | FR-10 ends "Done."; see finding 4 |
| 7.1 | Status: drop the `Partial` sentence | done | Status ends at "before the `resume-lost` probe." |
| 7.1 | Status: bump "Verified against" | not done, justified | no such text existed at the base; see below |
| 7.1 | FR-10 rewrite must not grow the file | done | 394 lines, 399 at the base |
| 7.2 | `path=` is in `%q` form | done | Probe: "printed as `path=` in `printf %q` form (pinned to the `C` locale ...)" |
| 7.2 | `nopath` means only no path extracted | done | outcome table row: "no path extracted" |
| 7.2 | partial-checkout residual becomes the rule; `git -C` a residual | done | Probe: "joins onto the worktree top, the nearest ancestor of `cwd` holding a `.git` entry"; Residuals: "under `git -C` ..." |
| 7.2 | residual for the five shapes, described, with the leaked-mask note | done | paragraph after Probe; see finding 3 |
| 7.2 | Verdicts: the display rule | done | paragraph after the three verdict bullets |
| 7.3 | `%q` contract replaces the newline exception | done | git-lock Probe, last sentence |
| 7.4 | phantom text, and its twin | done, by an earlier commit | landed in `1dedc30` (Items 2.1 + 3.1); the twin is by reference |
| 7.4 | map intro: no promised deletion, no Item 8.2 audit | done | "the file stays for the two that map nowhere" |
| 7.4 | zellij row stays in memory; new leak row | done | both rows read "stays in memory: ..." |
| 7.5 | `hook.md` phantom sentence | done | Paths: "names no location, so it holds under any working directory" |
| 7.6 | one entry: code, test side, Python tools | done, with gaps | entry dated 2026-10-11; see finding 8 |
| 7.6 | names closed items H and I with reasons | done differently | both described with reasons; the letters are not written |
| 7.7 | `lib/probes.sh` header and `_probe_lock_at` | done | "path= is in printf %q form"; "prints as one `$'...'` path= line" |
| 7.7 | `lib/probes-readonly.sh` header and contract comment | done | both say "printf %q form" and "`nopath` (no path extracted)" |
| 7.7 | `lib/probes-readonly.sh` newline-guard comment | done | removed with the guard it explained (Item 1.1) |
| 7.7 | `lib/verdicts.sh`: "never eval; `%b` decodes an argument, never a format" | done | `verdict_readonly_path` comment, verbatim; true of both `printf -v esc %b` calls |
| Phase 7 | each item runs `just format-docs`; no crammed lines | claimed, not re-run | no prose line over 80 characters in the six docs |

**The two clauses the build did not do.**

- *"Verified against" in `design.md`.* Justified.
  `git show 2309ae6:docs/design.md | grep -n -i verified` prints one line,
  the macOS "unverified" sentence. The only dated currency text in Status is
  the dogfood sentence, so the outline named text that never existed. The
  intent is not met either way: see finding 9.
- *`detectors.md` phantom text.* Justified, and inside the range. The base
  held "sandbox masks over dotfiles in the project root";
  `git log 2309ae6..HEAD -- docs/references/detectors.md` lists `1dedc30`
  and `b76e76e`, and `git show 1dedc30 -- docs/` is the rewording. The
  dispatch prompt calls that commit "Item 2.1 GREEN"; it is the combined
  Items 2.1 + 3.1 commit. The twin (`phantom-untracked` Verdict) restates
  `phantom-chardev` by reference and never held the location.

## Findings

### 1. Stale `path=` contract in a test header — Major

- **File:** `tests/hook-locks-pathless.bats`, file header comment. The build
  did not touch this file.
- **Axis:** consistency, accuracy.
- **Description:** the header explains a lock probe printing no `path=` line
  by "a resolved lock path holding a newline leaves path= out". At HEAD a
  newline-bearing lock path prints one `$'...'` line; the only pathless case
  is an empty path (a text with no lock line). Item 7.7 listed the comments
  stating the old contract and missed this one.
- **Verified:** `git log --oneline 2309ae6..HEAD --
  tests/hook-locks-pathless.bats` prints nothing. The header was read
  against `_probe_path_line` in `lib/probes-readonly.sh` (prints for any
  non-empty path) and against the `_probe_lock_at` comment in
  `lib/probes.sh`, which now says the opposite.

### 2. Decoder comment explains code that is gone — Minor

- **File:** `lib/verdicts.sh`, `_verdict_path_read`, the comment above
  `local re=`.
- **Axis:** accuracy (states the outline's plan, not the code).
- **Description:** it says the pattern sits in a variable because a quoted
  backslash-quote "in a substitution" has changed meaning across bash
  versions. That was true of the Item 1.2 code, which ran a pattern
  substitution on that pair. The review gate (`af58339`) replaced it with
  the per-escape loop and reworded the comment without removing the reason.
  At HEAD the two variables are regexes for `[[ =~ ]]`, no pattern
  substitution remains, and the two removals that do name the pair
  (`${wire#...}`, `${body%...}`) write it inline. Rated Minor because no
  behaviour is misdescribed; the stated reason is. A regex kept in a
  variable has a reason of its own that the comment could state instead: a
  quoted character in an inline `=~` pattern is literal from bash 3.2 on and
  was a regex character before.
- **Verified:** `git show d16cbb5:lib/verdicts.sh` holds
  `body=${body//"$bq"/"$q"}`; `git show af58339 -- lib/verdicts.sh` removes
  that line and `bq`, `q`, and keeps the sentence.

### 3. Unsupported location in the five-shapes residual — Minor

- **File:** `docs/references/readonly-path.md`, `## readonly-path`, Probe,
  the paragraph opening "Five `nopath` shapes stay unextracted".
- **Axis:** accuracy.
- **Description:** the fourth shape is given as "a removal warning on a
  dotfile in the home directory". No source records a location.
  `evidence.md` says only that the warning names one shell start-up dotfile,
  and the dogfood report shows the name relative, as git prints it for the
  working tree. A relative masked name refused as busy is the shape the
  memory file's leak section describes for a mask in the call's working
  directory, which is the case the paragraph's next sentence treats as if it
  were a different one. The changelog says "a dotfile removal", with no
  location. The paragraph's conclusion (same re-run act) holds either way.
  Whether the claim is false is **unverified**: it would be Major if so.
- **Verified:** `grep -n -i home` over `plans/sandbox-lies/reports/`
  `item-8-1-dogfood-numbers.md` and `evidence.md` prints nothing; the
  dogfood report's method note says "the manifest carries no per-call cwd".

### 4. FR-10 is `Done` against the document's own legend — Minor

- **File:** `docs/design.md`, FR-10 and the status legend under `## Now`.
- **Axis:** consistency.
- **Description:** three points, all in the FR-10 paragraph.
  - The legend defines `Done` as "pinned by a test or a gate that re-checks
    it on every commit" and `Done (prose)` as "instructions with nothing
    re-checking them". FR-10's pin is "the tier's index, and the translation
    map", neither a test nor a gate. The base named a `docs.bats` case; it
    went with the deletion. The outline asked for `Done`, so this conforms
    and still contradicts the legend. `tests/matchers.bats` "the live memory
    file still fires nothing" is the one case that reads the kept file.
  - Every other requirement writes "Where · pinned by: X · Y". FR-10 now has
    one separator and no second half.
  - FR-10 says the translation map "audits every paragraph". The map's own
    intro no longer claims an audit and maps sections, two of them nowhere.
- **Verified:** legend and FR-10 read against each other at HEAD;
  `git show 2309ae6:docs/design.md` for the base pin; the Translation map
  intro in `docs/references/detectors.md`.

### 5. "design section B" and "section C" resolve nowhere — Minor

- **File:** `lib/probes-readonly.sh`, comment inside `probe_readonly_path`;
  also the header of `tests/probes-readonly-resolve.bats` and the comment
  above "phantom-untracked opens without naming a location" in
  `tests/verdicts.bats`.
- **Axis:** usability (broken reference).
- **Description:** the three comments cite "design section B" or "C". Every
  other "design" pointer in `lib/` means `docs/design.md`, which has no such
  section; these mean the outline under `plans/`. The durable homes are
  `readonly-path.md`'s Probe paragraph and `detectors.md`'s phantom Verdict.
  The rubric's letter makes a broken reference Major; rated Minor here since
  the claim beside each pointer is true.
- **Verified:** `grep -n -E 'design section'` over the tracked files gives
  those three hits; `grep -n '^## ' docs/design.md` lists no lettered
  section.

### 6. `hook.md` Paths omits the readonly-path rule — Minor

- **File:** `docs/references/hook.md`, the **Paths.** paragraph.
- **Axis:** completeness, consistency across surfaces.
- **Description:** `docs/design.md` §Architecture and this node's own intro
  name it as where "how a probe resolves a relative path" is told. The
  paragraph covers the lock probes only. The build added a second walk with
  different terms (a `.git` entry, file or directory, and only for a
  partial-checkout line), which is in `readonly-path.md` alone. A clause
  pointing there closes it. The gap predates the build; the build widened
  it.
- **Verified:** the paragraph read against `probe_readonly_path` and
  `_probe_resolve_path` (`[ -d "$dir/.git" ]`) versus `_readonly_git_dir`
  (`[ -e "$dir/.git" ]`).

### 7. The docs never define the two wire forms — Minor

- **File:** `docs/references/readonly-path.md`, Probe and the display
  paragraph under **Verdicts.**; `docs/references/lock-detectors.md`,
  git-lock Probe and config-lock Verdicts.
- **Axis:** completeness, usability.
- **Description:** the display paragraph uses "the backslash form", "a
  well-formed `$'…'` form" and "the wire form" with no definition anywhere
  in `docs/`. The outline's §A stated what the reader depends on and no doc
  carries it: `%q` prints one of two forms; every printed value is absolute,
  so it opens with `/` or `$'`, and that first byte is how the reader tells
  them apart, which is why a relative value reads as no path. On the lock
  side, `lock-detectors.md` states the producer half only: it does not say
  that the `.claude/settings.json.lock` test runs on the decoded value, nor
  that a malformed value keeps *Re-run*. `lock-detectors.md` also omits the
  `C` locale pin that `readonly-path.md` gives.
- **Verified:** `grep -rn -E 'printf %q|wire form|backslash form' docs
  skills README.md` gives eight hits, none a definition; read against the
  `case "$wire"` arms of `_verdict_path_read` and against
  `verdict_config_lock`.

### 8. Changelog entry: omissions — Minor

- **File:** `docs/changelog.md`, the 2026-10-11 entry.
- **Axis:** completeness.
- **Description:** nothing the entry states is untrue. It leaves out:
  - the second wire change: an empty path now prints no `path=` line, where
    the lock probes printed a bare one (outline §A Wire; pinned in
    `tests/probes.bats`);
  - the two suites that pin the new contract,
    `tests/verdicts-readonly-path.bats` and
    `tests/probes-readonly-resolve.bats`; "Test side" names only the helper
    move and the Python suites;
  - two Python changes the outline lists: `pick()`'s all-projects branch
    removed from `extract-fixtures.py`, and the `corpus-eval.py` docstring
    loop redirecting once.

  Two wording points: the line-cap change sits under "Test side" though it
  is a gate script, and "The Item 8.2 remainder" names a runbook item the
  entry does not explain.
- **Verified:** entry read against `git diff 2309ae6..HEAD -- tests/*.py
  lib scripts` and `git diff --stat --diff-filter=A 2309ae6..HEAD -- tests`
  (six added files, two named).

### 9. `design.md` statements the build left behind — Minor

- **File:** `docs/design.md`, Status, FR-6 and NFR-5.
- **Axis:** completeness, consistency.
- **Description:**
  - FR-6 lists its pins file by file and omits
    `tests/verdicts-readonly-path.bats`, added in the range for the decode
    and display rule.
  - NFR-5 says "Every document and script is at most 400 lines". The gate
    now also caps awk, TOML and JSON files and a `justfile`, which are
    neither.
  - Status dates the dogfood "before the `resume-lost` probe". The `%q`
    wire, the decoder and the worktree-top join also postdate it, and no
    report in this job records a dogfood run. This is what the outline's
    "bump" clause was reaching for.
- **Verified:** FR-6 read against the added-files list above; NFR-5 against
  the `handle_file` arms of `scripts/check-line-limits.sh`;
  `grep -rl -i dogfood plans/sandbox-lies-review-fixes-3/` names only
  `evidence.md` and the two Item 7 reports. Observed in this session: the
  hook as loaded here annotated my own `git status` with the phantom
  paragraph in its pre-build wording (it named the project root), so the
  running copy of the plugin predates this build, as L-4 and D-16 predict.

### 10. `verdict_readonly_path` comment omits the display rule — Minor

- **File:** `lib/verdicts.sh`, comment above `verdict_readonly_path`.
- **Axis:** accuracy.
- **Description:** it says the verdicts "open with the probe's path= stdin
  line in backticks" and that the decoded path passes through "byte-exact".
  The stdin line is the wire value, not what is shown, and the code joins
  `_verdict_path_shown`, which is the wire form when the path holds a
  control byte. The rule is stated on `_verdict_path_read`; this comment
  reads as if there were no exception.
- **Verified:** comment read against `subject="\`$_verdict_path_shown\`"`
  and the tail of `_verdict_path_read`.

### 11. Three hard-to-parse phrasings — Minor

- **File:** `docs/references/readonly-path.md`, Probe.
- **Axis:** clarity.
- **Description:**
  - "when the matching line alone is one" means: only when the matching
    line itself is a partial-checkout refusal. The changelog repeats the
    phrase.
  - "from the 195 hits of the 2026-09-27 dogfood, 11 of them" buries the
    count; "11 of the 195 hits" says it.
  - "the nearest ancestor of `cwd`" leaves out "itself included", which
    `lock-detectors.md` and `hook.md` both write and `_readonly_git_dir`
    does.
- **Verified:** read against `probe_readonly_path` and `_readonly_git_dir`.

## Checked and clean

- **Producer.** `_probe_path_line` is the only `path=` printer: six call
  sites in `_probe_lock_at`, one in `probe_readonly_path`. It prints
  `LC_ALL=C printf %q` of the path and nothing for an empty one. No
  `pathline` and no newline arm remain in `lib/`.
- **Reader.** The two forms, the grammar, a malformed value (returns 1, both
  outputs empty, "The path", or *Re-run* for the config lock), the display
  rule and its byte range, and the two suffix matches on the decoded value
  all match `readonly-path.md`, the changelog and the
  `_verdict_path_read` header comment.
- **Per-escape loop.** The changelog ("one escape at a time ...") and the
  comment inside the loop describe the code at HEAD, not the outline's
  single `%b` pass. `readonly-path.md` names no mechanism and stays true.
- **Seam.** `hooks/annotate.sh` hands the probe's lines to the verdict
  unchanged, so nothing between producer and reader re-reads the encoding.
- **Resolution rule.** The matching line alone decides; base is
  `_readonly_git_dir "$cwd"`; no ancestor, or an empty `cwd`, falls back;
  every other producer joins onto `cwd`. `git -C` is a residual.
- **Phantom wording.** Both paragraphs in `lib/verdicts.sh` against
  `detectors.md` (`phantom-chardev` verbatim, `phantom-untracked` by
  reference) and `hook.md`. The other "project root" hits describe where
  masks sit or a recorded probe, and are true.
- **`nopath`.** Table row, the two probe comments, `lib/probes.sh` header.
- **Five shapes.** Count and shapes match `evidence.md`; none is quoted.
- **Changelog figures.** 31.7 s and 3.5 s match `reports/item-4-1.md`;
  `evidence.md`'s 38.7 s is the earlier measurement. The three review
  guards match three cases in `tests/corpus-eval.bats` and
  `tests/extract-fixtures.bats`. The line-cap scope matches the script
  header and its `case` arms. `probes.bats` held a literal locale and GNU
  `stat` at the base and uses the two helpers now.
- **FR-10 against the memory file.** It keeps exactly the leak and zellij
  sections; the skill carries neither (`grep -rn -i -E 'leak|outliv'
  skills/` prints nothing).
- **Status agreement.** FR-10, Status and the changelog all say Done; the
  only `Partial` left in `docs/` is the legend's definition.
- **Item 7.7, old contract.** No comment in the three lib files states it
  (`grep -n -i newline` gives the reworded `_probe_lock_at` comment only).
- **Sweep, no finding:** `README.md`, `skills/`, `hooks/`, `scripts/`,
  `docs/references/rejected-alternatives.md`, `sandbox-state.md`: no bare
  `path=`, no `nopath`-by-newline, no "Item 8.2", no old tokenizer cost
  sentence, no old line-cap scope sentence. The 2026-10-05 changelog entry
  states the old contract as dated history. `BRIEF.md` still plans the
  memory file's retirement whole; it is the dated founding brief, noted and
  not counted.
- **Form.** `wc -l docs/design.md`: 394. Lines over 80 characters, counted
  as characters with tables and fences excluded: none in the six docs but
  one changelog heading older than the range. (A byte count flags lines
  holding a dash or a middle dot.) In the three lib files only the
  `shellcheck disable` lines exceed 80. `bash scripts/check-links.sh` and
  `bash scripts/check-line-limits.sh` both exit 0. Every path and symbol
  the changed passages name exists at HEAD, bar finding 5.
- **This report is self-quiet.** `bash lib/matchers.sh` over this file
  exits 1 with no output, which is what `tests/docs.bats` will ask of it.
- **Not checked:** `just format-docs` idempotence and the suites, by
  instruction; the decoder by execution.

## Tree

`git status --short`, unsandboxed, after writing this file: the two
`.claude/handoff-*.md` files and `inbox/` as at the start, plus this report
as the only new path of mine. One scratch list written under `/tmp/claude/`
early in the sweep was removed in the next call.
