# Runbook — sandbox-lies review fixes

Design: `plans/sandbox-lies-review-fixes/outline.md` (approved at proof
2026-10-04; its Decisions D1–D5 bind every item). Findings:
`plans/sandbox-lies/reports/deliverable-review.md` — "Major N" and "m-N" below
are its labels. Requirements: `docs/design.md` FR/NFR/D ids. Recall:
`recall-artifact.md`. Numbering differs from the outline's: outline Items
2.6–2.9 are Items 3.1–3.4 here, outline Phase 3 is Phase 4 and outline Phase 4
is Phase 5 (the outline's OUT note on "Item 2.6" means Item 3.1).

Standing rules for every item: `just precommit` passes before each commit;
markdown edits run `just format-docs` first; no live file may fire a detector
(`tests/docs.bats` — describe a diagnostic, build test text from fragments);
every new bats file loads `helpers/bsd-stubs` and keeps one case re-run with
`make_bsd_stubs` on `PATH`; once Item 3.3 lands, every suite that runs git
loads `helpers/git-env`; no `fire-*`/`quiet-*` fixture by hand; `.bin/claude`
is never edited. Every bats and lib file stays at or under 400 lines; where an
item names a new test file, that is because the outline's target sits too near
the cap to take the cases.

## Requirements mapping

| Requirement | Phase | Items | Notes |
| --- | --- | --- | --- |
| NFR-5 line cap | 1, 5 | 1.1, 5.2 | `detectors.md` split; `design.md` move-out if needed |
| FR-3 (Major 3) | 2 | 2.1 | runtime-failure silence |
| NFR-4 (Major 4) | 2 | 2.2 | writes nothing on the probe path |
| FR-7 (Major 5) | 2 | 2.3 | curly quotes, tab-indented untracked |
| FR-4 (Major 6, m-5) | 2, 3 | 2.4, 3.4 | fact-table pins; positive config assertions |
| FR-5 (m-1) | 2 | 2.5 | flag pairing |
| D-16 (Tests m-3) | 3 | 3.1 | BSD `paste` stub, shim case |
| NFR-5 (Tests m-2) | 3 | 3.2 | gate exit-2 paths |
| NFR-2 (Tests m-4) | 3 | 3.3 | host git config isolation |
| FR-4 (code m-2) | 4 | 4.1 | D4 operand rule |
| FR-4 (code m-3) | 4 | 4.2 | D3 absolute `match=` |
| NFR-2, D-12, FR-1 (Major 2) | 4, 5 | 4.3, 5.2 | `SessionStart` jq check; README; design |
| FR-9 (Major 1, skill-side Minors) | 5 | 5.1, 5.2 | skill; docs |
| FR-7, FR-8, FR-11, NFR-1, NFR-4 (doc Minors) | 5 | 5.2 | |
| hygiene (stale comments, 4) | 5 | 5.3 | |

## Phase 1: make room (type: general)

- Item 1.1: `docs/references/detectors.md` → new
  `docs/references/readonly-path.md` — move §readonly-path (heading through the
  line before §tmpdir-unset) whole into the new node; leave in `detectors.md` a
  stub entry pointing at it, shaped like the git-lock and config-lock stubs that
  point at `lock-detectors.md`; add the new node beside `lock-detectors.md` in
  the "read before" sentences of `detectors.md`'s opening paragraph and
  `hook.md`'s; run `scripts/check-links.sh` for broken links. No wording change
  inside the moved text. Requirements: NFR-5.
  - Prose citations the link checker cannot see, repointed from `detectors.md`
    to `readonly-path.md` where they cite the readonly-path entry, as the
    lock-detectors split did for `lib/verdicts.sh`'s header:
    `lib/matchers.sh` (the `### readonly-path` pointer above
    `match_readonly_path`); `lib/probes-readonly.sh` (header, and the flag
    policy note above `probe_readonly_path`); `lib/probes-readonly-command.sh`
    (header, tokenizer residuals, `_readonly_readfile_arg`'s and
    `_readonly_merge_segment`'s comments); `lib/probes-readonly-facts.sh`
    (header, `_readonly_print_facts`, `_readonly_repo_facts`); `lib/verdicts.sh`
    (file header's "Text from", the readonly-path tail comment,
    `_readonly_match_list`); `tests/verdicts.bats` (the three "readonly-path …
    verdict text matches detectors.md" cases, names and comments);
    `tests/verdicts-readonly.bats`, `tests/probes-readonly-facts.bats` (headers,
    the five-names comment); `tests/helpers/verdicts.bash`
    (`readonly_path_tail`); `tests/extract-fixtures.py` (the git-mkdir SPEC
    comment's live reproduction). `rg -n 'detectors\.md' lib tests hooks` lists
    them; citations of other detectors stay.
  - Interfaces:
    - `docs/references/readonly-path.md` — the readonly-path entry, including
      its Probe facts table (`readfile=`, `merge=1`, `partial=1`, `target=`,
      `match=` rows); Items 4.1, 4.2 and 5.2 edit it.

## Phase 2: pin hook, matcher and probe behaviour (type: general)

Every item here adds tests against unchanged code. Per outline D5, each new
assertion is shown red under the fault named, one fault at a time, never on a
tracked file: copy `hooks/`, `lib/`, `scripts/`, `tests/` (and `.bin/` for Item
3.1) into a scratch directory under `$TMPDIR`, apply the fault there, and run
the one bats file from the copy; a hook case's own `hook_copy_tree` copy also
serves. Verify a hand probe with `command grep`, not the Bash tool's `grep`
function. The report lists each fault and the test names it turned red. A new
assertion no fault turns red is not done.

- Item 2.1: `tests/hook-malformed.bats` — FR-3's runtime-failure path (Major 3).
  Three cases, each asserting through the file's `check_quiet` (status 0, empty
  stdout, empty stderr) and each paired with `check_fires` on the same stub
  returning 0, as the file's other cases pair. Requirements: FR-3.
  - Probe dies after output: `fire-readonly-path-cp-tmp`, flag absent;
    `stub_lib probes.sh` defines `probe_readonly_path` draining stdin, touching
    a called marker, printing `writable` and `path=/r/x`, then returning 1; the
    case also asserts the marker exists.
  - Verdict dies after a probe: `fire-lock-add-commit`;
    `stub_probe git_lock mask`, and `stub_lib verdicts.sh` defines
    `verdict_git_lock` printing a paragraph and a human line then returning 1;
    asserts `PROBE_CALLED` exists.
  - Probe-less verdict dies: `fire-masks-gitadd-refused`;
    `verdict_phantom_gitadd` stubbed to print two lines then return 1.
  - Faults: in `hooks/annotate.sh`'s main loop, each of the three `|| exit 0`
    after `"$probe_fn"`, after `"$fn" "$outcome" "$flag"` and after
    `"$fn" </dev/null` turned to `|| true`.
- Item 2.2: new `tests/hook-writes.bats` (`hook.bats` is at 378 lines) and
  `tests/probes-edges.bats` — NFR-4 on the probe path (Major 4). Requirements:
  NFR-4.
  - `hook-writes.bats` loads `helpers/bsd-stubs`, `helpers/hook`,
    `helpers/spy` and `helpers/probes`. Two cases in the "hook needs no temp
    dir" shape (`mktemp` spy on `PATH`, `TMPDIR` naming a nonexistent
    directory, output equal to an unspied run of the same payload, spy log
    absent), each payload's `cwd` set to its own scratch tree and its error
    text built with `helpers/probes.bash`, never a fixture's host path.
    Readonly-path: `make_scratch_repo`, text from `readonly_path_text` naming
    `<repo>/a`, `tool_input.command` `git merge feat` so
    `_readonly_print_facts` runs its git reads, flag absent; the unspied
    `systemMessage` is the writable human line. Git-lock: a scratch `.git/`
    with no lock, text from `git_lock_error`; the unspied `systemMessage` is
    the index.lock mask line. The readonly case re-runs with
    `make_bsd_stubs grep sed stat wc` on `PATH` and equal output.
  - `probes-edges.bats`: beside "probe writes nothing", the same subprocess,
    spy, nonexistent `TMPDIR` and before/after `find` listing around
    `probe_readonly_path false <cwd> 'git merge feat'` on a writable refusal in
    a `make_scratch_repo` tree; asserts line 1 `writable` and a `merge=1` line,
    so `_readonly_print_facts` ran.
  - Faults: a `mktemp` call inserted in `annotate.sh`'s probe branch, before
    the `"$probe_fn"` call; one inserted at the top of `_readonly_print_facts`.
- Item 2.3: `tests/matchers-edges.bats` — two fire cases built from fragments
  (Major 5): `tmpdir-unset` on a GNU-style refusal whose path sits in curly
  single quotes (U+2018/U+2019) after the tool's words; `phantom-untracked` on
  a long-format `git status` untracked block, names tab-indented and one with a
  trailing slash, at least two masked names. The file's existing "a near-miss
  pair survives BSD grep and sed" case is its BSD-stub case; the new cases need
  none of their own. Faults: `‘` and `’` dropped from `match_tmpdir_unset`'s
  alternation; the `|[[:space:]]+` alternative dropped from
  `match_phantom_untracked`'s pattern. Requirements: FR-7.
- Item 2.4: new `tests/probes-readonly-members.bats`
  (`probes-readonly-pins.bats` is at 358 lines; this file loads
  `helpers/bsd-stubs` and `helpers/probes` and keeps one case under
  `make_bsd_stubs grep sed stat wc`) — the unpinned fact-table members (Major
  6), through `probe_readonly_path` on a `writable` refusal: `git switch feat`,
  `git rebase feat` and `git cherry-pick feat` each give `merge=1`; in a
  `make_scratch_repo` tree with the refused path `<repo>/a`, `git switch feat`
  gives `target=feat` and `match=a`; `cat build.out` and `tail run.err` give
  `readfile=build.out` and `readfile=run.err`; `sort -o out.log in.log`,
  `sort --output=out.log in.log`, `awk -i inplace 1 x.log` and
  `awk --include=lib.awk 1 x.log` give no `readfile=` line, each paired in the
  same case with its tool's plain reader form (`sort in.log`, `awk 1 x.log`)
  giving `readfile=`. Faults, each alone: `_readonly_merge_segment`'s
  subcommand case cut to `merge | pull | checkout`; `*.out | *.err` removed from
  `_readonly_readfile_arg`'s name case; each of the `sort:-o*`,
  `sort:--output*`, `awk:-i*`, `awk:--include*` arms removed. Requirements:
  FR-4.
- Item 2.5: `tests/hook-candidates.bats` — flag pairing (Tests m-1). Five
  `fire-*` fixtures reach no hook case (`fire-readonly-path-git-busy`,
  `-python-errno`, `-task-output`; `fire-tmpdir-unset-bash-bare`, `-cp-stat`)
  and two reach it with the flag absent only (`fire-readonly-path-git-mkdir`,
  `-git-config-busy`). Add two sweeps in the shape of `hook-locks.bats`'s
  "every lock fixture yields its verdict" (misses collected, asserted empty,
  count > 0): every `fire-tmpdir-unset-*` silent with the flag absent and
  firing its human line with it `true`; every `fire-readonly-path-*`, under
  `stub_probe readonly_path writable`, firing the writable human line with the
  probe reached when the flag is absent and silent with the probe not reached
  when it is `true`. One case sets `dangerouslyDisableSandbox` to the string
  `"true"` on `fire-tmpdir-unset-redirect` and asserts silence (read as false),
  beside the boolean-`true` run of the same text firing. Faults: the
  flag-policy `case` in `annotate.sh` emptied; the jq `== true` test replaced
  by a truthiness test. Requirements: FR-5.

## Phase 3: pin gates and harness (type: general)

Same D5 rule as Phase 2.

- Item 3.1: `tests/helpers/bsd-stubs.bash`, `tests/shim.bats` — a `paste` arm
  in `make_bsd_stubs` that refuses `-s` (alone or bundled, as `-sd:`) with no
  file operand, the way BSD paste reads no implicit stdin, and execs the real
  `paste` otherwise; one shim case re-run with the stub on `PATH` (Tests m-3).
  Fault: the trailing `-` operand removed from `.bin/claude` in the scratch
  copy, with `shim.bats` run from that copy so its `ROOT` is the copy's.
  Requirements: D-16.
- Item 3.2: `tests/check-line-limits.bats`, `tests/check-links-edges.bats` — the
  exit-2 paths (Tests m-2): `scripts/lib/tracked.sh`'s walk when `git ls-files`
  fails, through each gate script (a `git` stub on `PATH` exiting 128, not a
  non-repository root, which a repository above `$BATS_TEST_TMPDIR` would
  answer), gives status 2 and the `<prog>: git ls-files failed under <root>`
  stderr line; `scripts/check-line-limits.sh` on a tracked file it cannot read
  (mode 000, skipped as root the way `check-links-edges.bats`'s "unreadable
  file exits 2" skips) gives status 2 and
  `check-line-limits: cannot read <file>`. Faults: the `if ! … fi` guard around
  the `ls-files` call replaced by the bare call with `|| true`; the read
  guard's `if !` in `check_cap` removed. Requirements: NFR-5.
- Item 3.3: new `tests/helpers/git-env.bash` — host git config isolation (Tests
  m-4). It exports `GIT_CONFIG_NOSYSTEM=1` and `GIT_CONFIG_GLOBAL` pointing at
  a test-owned file setting `user.name`, `user.email` and
  `commit.gpgsign=false`. Every suite that runs git loads it: `check-links`,
  `check-links-edges`, `check-line-limits`, `docs`, `hook`, `hook-malformed`,
  `hook-candidates`, `matchers`, `verdicts`, `verdict-premises`,
  `probes-readonly`, `probes-readonly-facts`, `probes-readonly-pins`, and Items
  2.2's and 2.4's new files (`rg -l` for git calls and `make_scratch_repo`
  confirms the list). Real-probe cases whose expected output depends on a
  walk-up from a `$BATS_TEST_TMPDIR` path finding no `.git` call the existing
  `assert_no_git_above` first; the report lists them. Verification: the full
  suite passes with a host `GIT_CONFIG_GLOBAL` file setting
  `commit.gpgsign=true` and a bogus `gpg.program` exported, and fails with the
  helper's load lines removed in the scratch copy; the guarded cases fail on
  `assert_no_git_above` when bats' temp root (`TMPDIR`) sits inside a scratch
  git repository. Requirements: NFR-2. Depends on: Item 2.2, Item 2.4.
- Item 3.4: `tests/probes-config.bats` — the negative-only assertions (Tests
  m-5) gain the outcome they expect, as the probe gives it on unchanged code:
  in "each probe reads only its own lock line", the last call
  (`probe_config_lock` on git-lock text alone) gives `mask` and an exact `path=`
  line with no value; in "pathless text never names the base", flag `false`
  gives `mask` and flag `true` gives `gone`. Confirm these against
  `lock-detectors.md`'s outcome table first and report a disagreement rather
  than pinning it. Fault: in `_probe_lock_at`'s absent-path branch, `mask` and
  `gone` each printed as `unknown`. Requirements: FR-4.

## Phase 4: behaviour changes (type: tdd)

- Item 4.1: `lib/probes-readonly-command.sh` `_readonly_readfile_arg` — outline
  D4's operand rule (code m-2). Tests in `tests/probes-readonly-members.bats`,
  each through `probe_readonly_path` on a `writable` refusal with the command
  given. Requirements: FR-4. Depends on: Item 2.4, Item 1.1.
  - Slices:
    1. A word opening with `-` is never input:
       `grep --include=*.log pat build.log` prints `readfile=build.log`;
       `grep -r --include=*.log pat .` prints no `readfile=` line.
    2. The first non-option operand of `grep`, `sed` or `awk` is the pattern or
       program: `grep x.log y.out` prints `readfile=y.out`;
       `sed s/a/b/x.log in.out` prints `readfile=in.out`; `sed s/a/b/ in.log`
       still prints `readfile=in.log`.
    3. An `-e`/`-f` family option takes the pattern role: `grep -epat x.log`
       prints `readfile=x.log` (an earlier `-e` makes the first operand input);
       `sed -e s/a/b/ -e s/c/d/x.log in.out` prints `readfile=in.out` (the word
       after a separate `-e` is its argument); `awk -f prog.log in.err` prints
       `readfile=in.err`. List revision after slice 2: a case pinning the
       per-segment reset of the pattern role, in a form this slice leaves
       unconsumed at the segment's end (the slice-2 code review found no case
       does).
    4. `uniq` with an output operand is a writer: `uniq in.txt out.log` prints
       no `readfile=` line; `uniq in.log` prints `readfile=in.log`. List
       revision after slice 3: a pin for a `<` redirection in a separate
       `-e`/`-f` argument slot — `grep -e <in.log pat.log` prints
       `readfile=in.log` and no `readfile=pat.log` (the slice-3 code review's
       fix, unpinned; proven by mutation).
  - List revision after slice 2: slices 3 and 4's tests go in
    `tests/probes-readonly-operands.bats` (the operand-rule section moved there
    by the slice-2 refactor, `probes-readonly-members.bats` being near its
    cap).
  - Docs (same item, after GREEN): `docs/references/readonly-path.md` Probe
    facts table `readfile=` row and residuals (other options' separate arguments
    stay unrecognised); the function's header comment. List revision after
    slice 3: the residuals also name clustered short (`-ne`, `-nf`) and long
    (`--regexp=`, `--expression=`, `--file=`) forms of the `-e`/`-f` family,
    left unrecognised; sed's `w` command and `s///w` flag, which write but are
    not counted as writers; and a descriptor duplication such as `2>&1` taken
    as the operand in a pattern or argument slot.
- Item 4.2: `lib/probes-readonly-facts.sh` — outline D3's absolute `match=`
  names (code m-3). The site is `_readonly_repo_facts`'s merge pass that appends
  `out="${out}match=${files[$i]}"`; the name becomes `<repo>/<name>` with the
  `repo` argument the function already holds (absolute: `_readonly_git_dir`
  joins a relative start onto `$PWD`). Requirements: FR-4. Depends on: Item
  1.1, Item 2.4.
  - Slices:
    1. A `make_scratch_repo` tree with a subdirectory `sub`, refused path
       `<repo>/a`, command `git merge feat`, `cwd` `<repo>/sub`: a direct
       `probe_readonly_path` call in `tests/probes-readonly-members.bats` prints
       `match=<repo>/a`, `match=<repo>/b` and `match=<repo>/e f`; through
       `hooks/annotate.sh` in `tests/hook-candidates.bats`, real probe, flag
       absent, the `additionalContext` restore clause names `` `<repo>/a` ``.
       In the same GREEN every existing probe-output `match=` assertion moves to
       the absolute form — `tests/probes-readonly-facts.bats`,
       `tests/probes-readonly-pins.bats`, and Item 2.4's `match=a` — negatives
       included (`run ! grep -qxF 'match=d'` becomes `match=<repo>/d`; left
       bare it can never fail). The `match=` lines fed as verdict input in
       `tests/verdicts-readonly.bats` and the hook stubs stay: the verdict
       prints whatever name it receives.
  - Docs (same item): `readonly-path.md` Probe facts table `match=` row and the
    restore clause's description.
  - List revision (recorded at the Phase 4 checkpoint): the hook case landed
    in `tests/hook-writes.bats`, `hook-candidates.bats` being near its cap and
    its cases stubbing the probe; Item 5.2's "pinned by" for D3 names
    `hook-writes.bats`.
- Item 4.3: new `hooks/check-jq.sh`; `hooks/hooks.json` — outline D2's
  `SessionStart` check (Major 2). Tests in a new `tests/check-jq.bats`.
  Requirements: NFR-2, D-12, FR-1.
  - Slices:
    1. Registration, `jq` present: the test reads the `SessionStart` command
       string from `hooks/hooks.json` and runs it with `CLAUDE_PLUGIN_ROOT` set
       to the checkout: stdout and stderr empty, status 0. `tests/hook.bats`'s
       "hooks.json names both events" case is extended: keys are the three
       events, and `SessionStart` holds one command hook whose command is
       `bash "${CLAUDE_PLUGIN_ROOT}/hooks/check-jq.sh"`.
    2. `jq` absent: the same command string run with a `PATH` holding the tools
       the script needs but no `jq` (the test's own `jq` resolved by absolute
       path first); stdout parses as exactly one JSON object whose
       `systemMessage` opens with the `\033[0m` style reset and contains `jq`,
       whose `hookSpecificOutput.hookEventName` is `SessionStart`, and whose
       `hookSpecificOutput.additionalContext` contains `jq`; status 0; stderr
       empty. The same run with `TMPDIR` naming a missing directory gives the
       same stdout, and so does a re-run with
       `make_bsd_stubs sed grep mktemp stat wc` ahead on `PATH`.
  - Interfaces:
    - `hooks/check-jq.sh` — stdin ignored; stdout empty or one JSON object built
      by `printf` from fixed text; exit 0 always; writes nothing.
    - `hooks/hooks.json` `SessionStart` — one command hook,
      `bash "${CLAUDE_PLUGIN_ROOT}/hooks/check-jq.sh"`; Item 5.2 documents it.
  - Docs (same item): `docs/references/hook.md` registration and the script's
    role. List revision after slice 1: the registration has no `matcher` (it
    fires on every `SessionStart` source, so a `clear` or `compact` re-issues
    the notice) and a 10 s `timeout`, as the slice-1 test review decided;
    hook.md and Item 5.2's `docs/design.md` NFR-3 and Architecture block say
    so.

## Phase 5: prose (type: general)

- Item 5.1: `skills/sandbox-lies/SKILL.md` and its four `references/` nodes —
  Major 1 per outline D1, and the skill-side Minors. One item: the skill is
  edited as a whole. `SKILL.md` is at 173 of its 200-line cap; move detail to a
  node rather than past the cap. Requirements: FR-9.
  - `SKILL.md`: §"Tell a sandboxed call from an unsandboxed one" first bullet —
    the 2.288/2.289 observations and the single-writer re-probe; §"Writing an
    `excludedCommands` entry" — D1's every-command rule as CC's documented
    mechanism, `git *` syntax, no decoy, the forfeiting shapes; §"Leaving the
    sandbox for one call" — strict mode named
    `sandbox.allowUnsandboxedCommands: false` (Strict sandbox mode in
    `/sandbox`), and the batching rule matching the reference; §"Keeping the
    working directory at the project root" — the persisted `cd` holds in the
    main session (a subagent's cwd resets per call), and the order re-ranked: a
    trailing `cd <root>` and a subshell now both forfeit an exclusion, so the
    subshell's "misses an honoured exclusion" reason goes. The `description`
    names no whole-call semantics and stays.
  - `excluded-commands.md`: retitled; the D1 rule replaces "one matching segment
    unsandboxes the entire call" and the decoy; the 2.281 probe marked
    confounded (its uncovered `touch` keeps it sandboxed under the documented
    rule) beside the 2.288 and 2.289 single-writer probes; Matching bullets
    re-read against D1 (redirections other than descriptor duplication, a `cd`,
    a variable command name now keep a call sandboxed); "Settings reload live"
    kept as observed earlier, version not recorded; the `git:*`-vs-hook section
    reworded to `git *` and the D1 limits.
  - `escapes-and-costs.md`: opening paragraph; §Strict mode (the key);
    §read-only-inspection default (`git *` baseline); §Cost (the auto-mode
    exceptions the sandboxing doc lists — per-command allowed domains,
    server-side review of sandboxed commands; one batching rule; drop "with no
    generation", since the classifier generates a verdict); the recipe line on
    `git:*`.
  - `masks-and-gates.md`: the cwd paragraph (main-session qualifier, re-ranked
    order, exclusion wording); the `` !`cmd` `` paragraph's exclusion wording.
  - `recipes-and-claude.md`: the two `claude:*` exclusion mentions (opening
    paragraph, the unsandboxed-flow list) in `claude *` syntax under D1's
    every-command rule.
- Item 5.2: docs — Major 1 and 2 doc halves and the doc Minors. Requirements:
  FR-1, FR-7, FR-8, FR-9, FR-11, NFR-1, NFR-2, NFR-4, NFR-5, D-12. Depends on:
  Items 1.1, 4.1, 4.2, 4.3, 5.1.
  - `docs/references/lock-detectors.md`: the `mask` reproduction and config-lock
    corpus paragraphs — the 2.281 `/tmp` probe restated as confounded; D1's
    single-writer probe and its 2.288/2.289 results.
  - `docs/references/detectors.md`: Conventions — open question whether the
    payload `cwd` follows a persisted top-level `cd`, and that the lock and
    readonly probes resolve relative paths against it; Candidates intro — credit
    the shipped matchers' re-measurement
    (`plans/sandbox-lies/reports/item-4-2-s1-code-review.md`,
    `item-4-3-s1-green.md`), not a scratch shell matcher; phantom-untracked's 41
    and 57 each name their corpus (from `plans/2026-09-0*` evaluation files), or
    say it is not established; Translation map and Not-detectors exclusion
    wording.
  - `docs/references/readonly-path.md`: `mv`'s `to` names the target only in the
    inter-device form.
  - `docs/references/hook.md`: the D-1 paragraph's pilot reading that calls ran
    "unsandboxed by the `claude:*` exclusion" stated as what the configuration
    implied, not an observed run (D1).
  - `docs/design.md`: NFR-4's read scope (the refused path's repository, and
    paths from the error text); a platform statement (symptoms and figures
    recorded on Linux, macOS unverified); D-3's hook count; NFR-4 ordered before
    NFR-5; FR-8 qualified (25 of 34 fixtures re-cut byte for byte at review
    time, two undated entries pick other calls, seven not found, cause not
    established); D-5's 57 names the same corpus as `detectors.md`'s; FR-9,
    D-8, Rejected alternatives and L-2 exclusion wording; FR-1 and the
    Architecture block name `hooks/check-jq.sh` as a second, non-annotating
    `SessionStart` script; D-12 names the `SessionStart` check; each "pinned
    by" that this job's new test files extend (`hook-writes.bats`,
    `probes-readonly-members.bats`, `check-jq.bats`) names them. If
    `just format-docs` leaves it over 400 lines, move D-8's argument to a new
    `docs/references/` node with a one-paragraph stub and link; if that does
    not bring it to 400, stop and report the count — a further move-out is a
    design call, and trimming prose to fit is not allowed.
  - `README.md`: §Install names `jq` as a prerequisite and the `SessionStart`
    notice; the platform statement; the skill blurb's exclusion wording. The
    clone URL stays (Unchosen host is out of scope).
  - `CLAUDE.md`: the self-quiet bullet says the three pilot files are exempted
    from the sweep.
  - `docs/changelog.md`: one entry for this job's user-visible changes.
  - Out of scope: `BRIEF.md`, the original mission brief, keeps its `claude:*`
    wording as a historical input.
- Item 5.3: comments and help text (stale group). Requirements: none (hygiene).
  - `lib/matchers.sh`: the file header (no longer the pilot's candidate
    matchers); the comment above the listing matchers claiming
    `CLAUDE_PROJECT_DIR` anchoring closes the `/dev` listing false positive —
    nothing reads that variable, and `detectors.md` accepts it as a residual.
  - `lib/probes.sh`: the header's probe contract gains `tool_input.command` as
    `$3`.
  - `hooks/annotate.sh`: its header's claim that nothing reaches stderr — with
    `jq` absent, bash prints a command-not-found line there (exit 0, so Claude
    Code ignores it); say so (List revision after Item 4.3 slice 2, from its
    code review).
  - `justfile`: `just --list` describes `precommit` as
    `Checks that run before every commit.` (the comment block reordered, or a
    `[doc(...)]` attribute; just 1.46 supports both).
