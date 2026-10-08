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

- **Derived from:**
  `plans/sandbox-lies-review-fixes-2/reports/deliverable-review.md` and
  `deliverable-review-fixes.md`, superseding
  `plans/sandbox-lies-review-fixes-2/outline.md`
- **Base:** `52e6dd82b831a1cc2b7b516d4c248df6fb1ebc8c` — copied verbatim from
  the superseded outline. Q5 asks whether to keep it.

## Verdict per item

| # | Item | Verdict | Why |
| --- | --- | --- | --- |
| A | `path=` as `printf %q` | Build (Q1) | Decided. Only one input triggers it: a newline in the payload `cwd`. The cost is two slices. |
| B | Partial-checkout path from a subdirectory | Build | Today it can produce a wrong `readonly` verdict, which says unsandboxing will not help. |
| C | Phantom "project root" wording | Build | False after a persisted `cd`. It is a three-site string edit. |
| D | m-1 quadratic tokenizer | Build | Times out on bash 3.2.0: 38.7 s at the cap, against a 10 s hook timeout. |
| E | Tests m-6 (suite on macOS) | Build | Two lines. Both helpers already exist. |
| F | m-7 line-cap coverage | Build | One `case` arm and one test. No file is near the cap today. |
| G | m-8, m-9 Python tools | Close (Q3) | Dev tools run by hand. Their failures are loud, except one false comment. |
| H | Five `nopath` shapes | Close | In every recorded case, a path would not change the act. |
| I | Item 8.2 remainder | Close (Q4) | The zellij section keeps the file alive, so the remainder stays gated. |

## Evidence

Each probe below ran on this box (Linux). Bash 3.2 means a 3.2.0 built from
the GNU tarball (gnu89, glibc malloc, `-O1`). It is indicative only: Apple's
3.2.57 is unverified, and so is everything about macOS. To rebuild it, take
`bash-3.2.tar.gz` from ftp.gnu.org. Configure with `--without-bash-malloc`,
and pass `-std=gnu89` with gcc 14's implicit-declaration, int-conversion,
incompatible-pointer, implicit-int and return-mismatch errors demoted to
warnings, in both `CC` and `CC_FOR_BUILD`. Before `make`, `touch` `y.tab.c`
and `y.tab.h`. The 3.2.57 tarball's `y.tab.c` is stale against its `parse.y`
and fails to link without bison. The `CC` string used, passed as both `CC` and
`CC_FOR_BUILD`, was `gcc -O1 -std=gnu89 -w -fcommon
-Wno-error=implicit-function-declaration -Wno-error=int-conversion
-Wno-error=incompatible-pointer-types -Wno-error=implicit-int
-Wno-error=return-mismatch`.

- **`printf %q` forms.** Bytes 1 to 255 were run through it, between two
  letters, on both versions under `C` and `C.UTF-8`. Each byte gives one of
  two forms:
  - backslash form: a backslash before each shell-special printable byte;
  - `$'…'` form: whenever a byte is not printable. Its escapes are `\a \b \E
    \f \n \r \t \v`, three-digit octal `\NNN`, and `\\` and `\'`.

  The two versions agree byte for byte on single bytes. They diverge in two
  ways:
  - bash 5.2 escapes a leading `~` and bash 3.2 does not;
  - under `C.UTF-8`, bash 5.2 prints a valid multibyte character raw (`café`),
    where bash 3.2 and any `C` locale print `$'caf\303\251'`.
- **The locale pin works.** `LC_ALL=C printf %q …`, as a prefix on the
  builtin, gives the `$'…'` form for non-ASCII under a UTF-8 session on both
  versions. So the wire form does not depend on the hook's locale. The
  extractors already pin `LC_ALL=C` for byte safety.
- **Assignment eval decodes wrongly on 3.2.** bash 3.2's `%q` leaves `~` bare.
  `eval "x=$q"` then tilde-expands after a `:`: `/a:~root/b c` decoded to
  `/a:/root/b c`. A word-context eval and `read` without `-r` both decode it
  right. `printf %b` decodes `\NNN`, `\E` and `\\` on both versions, but not
  `\'`.
- **Tokenizer cost** (`_readonly_tokenize`, 16384 characters):

  | input | bash 5.2.37 | bash 3.2.0 |
  | --- | --- | --- |
  | one word | 4.2 s | 38.7 s |
  | 1600 short words | 1.3 s | 2.5 s |

  The gap between the rows is the `word="$word$ch"` copy. On 3.2 a single word
  past about 8 KB alone exceeds the hook's 10 s timeout, and the annotation is
  then lost with no signal.
- **`nopath` hits.** From `plans/sandbox-lies/reports/item-8-1-dogfood-numbers.md`:
  11 of 195 `readonly-path` hits, in five shapes:
  - tee's refusal of a `/tmp` file;
  - sed's temporary file in a relative directory;
  - git's refusal to write `.git/config`, busy rather than read-only;
  - a removal warning on `.bash_profile`;
  - `cp` with an empty operand.

  Every extractable path there is writable outside the sandbox, so `writable`
  would give the same act `nopath` gives: re-run the whole call unsandboxed.
  None names `.claude/settings.json`. The empty operand holds no path at all.

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
  - Assignment eval is wrong on 3.2 (§Evidence), and word-context eval puts an
    executable surface where a decoder needs none. The pattern-substitution
    step for `\'` has changed meaning across bash versions, so the executor
    runs it on the 3.2.0 build with the pattern and the replacement held in
    variables.
- **Scope.** Only `path=` changes. `readfile=`, `match=` and `target=` keep
  their documented newline skips (Q2).

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
  The report records the §Evidence timing table re-run after the change, on
  bash 5.2 and on the 3.2.0 build; the target is under 5 s on 3.2 for one
  16384-character word. Measured, not gated: a timing case would be flaky on
  this box.

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
- Item 5.3: `tests/corpus-eval.py:48-52` — correct the prefilter comment: `crw-`
  covers the `/dev/null` mask's mode, not every mode `match_phantom_chardev`
  accepts. That is all of G under Q3's default.

### Phase 6: docs (type: general)

One item per file. Each runs `just format-docs`, and `docs/design.md` must stay
at or under 400 lines with no crammed lines.

- Item 6.1: `docs/design.md`.
  - Now: drop the `nopath` sentence.
  - FR-4: one clause, "a `path=` value is printed in `printf %q` form".
  - FR-10: per Q4.
  - Status: bump "Verified against".
- Item 6.2: `docs/references/readonly-path.md`.
  - `:28`: `path=` is in `%q` form.
  - `:51`: `nopath` means only that no path was extracted.
  - `:42-45`: the partial-checkout residual becomes the resolution rule, and
    `git -C` stays a residual.
  - Add a residual for the five shapes (§Evidence, described, never quoted).
    It notes that a removal refused on a leaked phantom mask gets the re-run
    act, which the leak makes futile.
  - Verdicts: the display rule from §A Reader.
- Item 6.3: `docs/references/lock-detectors.md:30-31` — the `%q` contract
  replaces the newline exception.
- Item 6.4: `docs/references/detectors.md`.
  - `:84` and its twin: the new phantom text.
  - Translation map: per Q4.
- Item 6.5: `docs/references/hook.md:101-105` — §C.
- Item 6.6: `docs/changelog.md` — one entry covering the code changes and the
  test-side changes, and naming the closed items with their reasons.
- Item 6.7: the comments that state the old contract.
  - `lib/probes.sh:8-13` and `:105-111`;
  - `lib/probes-readonly.sh:6-7`, `:36-39` and `:54-55`;
  - `lib/verdicts.sh:139-145`. Its "never a printf format, sed or eval"
    becomes "never eval; `%b` decodes an argument, never a format".

## Scope

- **IN:** Items 1.1 to 6.7.
- **OUT, closed with a reason:**
  - **G, m-8 idempotency.** The out directory is an operator's scratch.
  - **G, m-9 null fields.** A null timestamp or a non-dict input crashes
    loudly, and neither occurred over 4055 transcripts.
  - **H, the five `nopath` shapes.** See §Evidence.
  - **I, the Item 8.2 remainder.** See Q4.
- **OUT, not code:** the publishing steps, the m-3 scratch transcripts, and the
  rejected `deliverable-review-build-only-range.md`. They stay in
  `.claude/handoff-todo.md`.
- **Observation, not built:** `readonly-path` fires on a removal refused on a
  leaked mask, the symptom of the memory file's leak section. A detector of its
  own would need a corpus replay under D-15.

## Questions

1. **Item A: build as designed?** It decodes the `%q` form in the verdict and
   shows the raw path unless the path holds a control byte. The alternative is
   to close A as a residual: its only trigger is a newline in the payload
   `cwd`, and today's guards are correct and pinned. Default: build.
2. **Encoding scope.** Should only `path=` take `%q`? `readfile=`, `match=` and
   `target=` keep their newline skips. Default: `path=` only.
3. **m-8 and m-9.** Close both and correct only the false comment (Item 5.3)?
   The alternative builds `isinstance` guards, survivor clearing and one bats
   case per tool against a crafted JSONL under a scratch `HOME`. Default:
   close.
4. **Item 8.2.** `memory/ddaanet/sandbox-effects.md` now holds two sections:
   zellij, whose detector cannot ship under D-15 with 0 corpus hits, and the
   phantom-mask leak. Under the default, the file stays as the home of both.
   - FR-10 is rewritten to "every section the plugin carries is retired; the
     file keeps what it does not".
   - The translation map gains a leak row ("stays in memory").
   - The deletion, the `docs.bats` retired-path case, the audit column and the
     index-line edits are dropped as moot.
   - `tests/matchers.bats:280` stays, since the file persists.
   - One memory step for you to approve. The file's opening paragraph says
     the leak section is "not yet in the skill"; reword it to say the file
     keeps that section.

   The alternative folds the leak section into
   `skills/sandbox-lies/references/masks-and-gates.md`, and you approve three
   memory steps:
   - (a) delete the leak section from `sandbox-effects.md`;
   - (b) rewrite its `description` to zellij only;
   - (c) rewrite both index lines (`memory/ddaanet/MEMORY.md:19`,
     `memory/MEMORY.md:7`) to match.

   Default: leave the file.
5. **Review base.** The Provenance rule copies `52e6dd8` verbatim, so the next
   review covers the whole range again (about 300 commits). The alternative is
   this job's start, `2309ae69527623112aced16277775ea241a96a3c`: a range of
   this build alone, which suits one clean review. Default: copy verbatim, as
   the rule says.

## Route

After approval: commit this outline and name `/build plans/sandbox-lies-review-fixes-3`.
No runbook. Phase 1 → 2 → 3 is the only ordering, and the items already carry
their slices.

## Resume

Stopped at the hard context stop, before `/edify:proof`.

- **Done:** `classification.md` and this outline are written. `just precommit`
  exits 0, and both files run quiet under `lib/matchers.sh`.
- **Open:** my human partner's answers to Q1 to Q5. Revise the outline to
  match them.
- **Next:** `/edify:proof plans/sandbox-lies-review-fixes-3/outline.md`. On
  approval, commit and name `/build plans/sandbox-lies-review-fixes-3`.
- The bash 3.2.0 build sits in a scratch directory that will not survive. To
  rebuild it, follow §Evidence.
