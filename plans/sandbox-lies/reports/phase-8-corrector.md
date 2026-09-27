# Review: Phase 8 boundary checkpoint

**Scope**: committed changes `7c4f811..HEAD` (Item 8.0's four D-17 slices,
Item 8.1's shim and dogfood numbers, the skill carry, the parent-repo part of
Item 8.2). This also stands in for Item 8.0's own corrector checkpoint.
`memory/` not touched.
**Date**: 2026-09-27
**Mode**: review + fix. Nothing committed; nothing staged.

## Verdict

**Needs a decision on one item; everything else Ready.** One UNFIXABLE
(U-DESIGN): the `readonly-path` merge clause fires on command shape alone, and
over the corpus it fires only where it is false (finding 1). Ten other findings,
all fixed: one major (the shim re-executes itself forever when its own `PATH`
entry has a trailing slash), nine minor. After the fixes, `just precommit` exits
0: `plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links,
tests` (243 bats passed). It ran with `.venv/bin` on `PATH`, because
`direnv exec .` refuses the edited `.envrc` until my human partner runs
`direnv allow`. `docs/design.md` is at 396 lines.

## 1. D-17: spec, code and tests agree

**Text agreement.** Every verdict in `lib/verdicts.sh` matches its
transcription:

- Lock verdicts: the *Re-run*/*Retry* table in `lock-detectors.md`
  (`_lock_rerun` and `_lock_retry`, both flag values), `mask`/`gone`/`held`/
  `orphan`/`unknown` for both locks, and the config-lock settings act under
  both flags. `tests/verdicts-locks.bats` transcribes all of it, and the
  `hook-locks.bats` flag pairs pass through the hook.
- `readonly-path`: the tail and merge clause in `detectors.md` (first-of
  `readfile=` → settings path, `writable` only → whole-call re-run;
  capitalised alone, lowercase after the clause; five names, then
  `and N more`; `target=` with no `match=` gives no clause).
  `tests/verdicts-readonly.bats` transcribes each composition byte for byte.
- The hook passes `"$flag"` to every verdict as `$2`, and
  `tool_input.command` to every probe as `$3`. It is escaped the way the cwd
  is, so `printf %b` cannot eat `\c` or octal escapes. The stub-probe test
  pins this byte for byte, including the non-string, absent and non-object
  cases.

**Conditionals.** Grepped the emitted strings for `if `, `once `, `when ` and
`unless`. Hits:

- `seccomp-init`: "if it fails the same way". This is an exception my human
  partner ruled on, and it stays.
- `_lock_retry true`: "Retry the command once". Here "once" means one time,
  not a condition.
- `_lock_rerun true`: "Re-run the same command once no sandboxed command is
  running". Judged acceptable, not changed. Under flag true the probe has
  already established that a sandboxed command is running now; what the
  script cannot evaluate is when it will stop. That makes the clause a wait,
  like `held`'s "Wait for it, then retry", not a branch the script could
  settle. The wording is `lock-detectors.md`'s committed flag table.
- Phantom verdicts: "With no sandboxed command running in the background".
  Item 8.0 put these out of scope.

git-lock's repeat-failure clause and orphan's "a second identical failure" are
both keyed to a repeat failure, which D-17 leaves in the text. No composition
contains "If a merge", "once they match" or "if it only read", and
`verdicts-readonly.bats` pairs each of those negatives with a positive.

**FR-6 lengths**, measured over `lib/verdicts.sh` with one-character values:

| composition | writable | nopath |
|---|---|---|
| no facts | 126 | 123 |
| `readfile=` | 99 | 96 |
| settings path (the path's 22 characters included) | 150 | — |
| `merge=1` alone | 239 | 236 |
| `merge=1`, `target=`, 1 `match=` | 258 | 255 |
| 5 `match=` | 278 | 275 |
| **7 `match=`** | **289** | **286** |
| 7 `match=` + settings act and path | 313 | — |
| 1000 `match=` ("and 995 more") | 291 | 288 |

Lock verdicts top out at 248 (`git_lock mask false`). Everything is at least 85
characters under the cap. The suite reaches the longest case: its "longest
composition" test measures `writable` + settings path + seven `match=` lines,
which is 313 and stricter than FR-6 needs, since it counts the path. The
seven-name test and every other composition test also assert `< 400`. The
"and N more" count adds at most 2 characters, because the 1000-file bound caps
N at 995. Nothing in the suite measures it, and it does not need to. A long
`target=` is a probe value and falls outside FR-6 by its own definition.

## 2. The design state layer

- **Status** matches what is built: the hook, every shipped verdict, the probes
  with the D-17 facts, the skill and the shim, dogfooded 2026-09-27 on CC
  2.1.283. The memory file stays because zellij has no detector.
- **Verified against** `45c0316e` is accurate for the committed tree: only
  `docs/design.md` changed between it and `HEAD`. The fixes below postdate
  it, so re-stamping it is the Finish audit's job. Left as is.
- **`## Now`** omitted the next step. Item 8.2's memory-tier edits are not
  done, and Focus named only review and the TDD audit (finding 7).
- **FR-1** still said `Partial (dogfood: Item 8.1)` after the dogfood it waited
  on had run (finding 6).
- **FR-4** and **FR-6** pinned-by clauses predate the new files (finding 8).
- **D-17** agrees with its nodes: the probe-facts table in `detectors.md`, the
  flag table in `lock-detectors.md`, and the Flow paragraph in `hook.md`.

**Line budget.** Three small state fixes pushed the hub to 402. To avoid
cramming, D-1's argument moved verbatim into `references/hook.md`, the same
split D-17 already applied to D-6, D-13 and D-14. The hub keeps D-1's
conclusion and its accepted tradeoff and is now at 396. **Next move-out:**
D-8's argument (9 lines, into `hook.md` beside the flag handling) or D-10's
(9 lines). `detectors.md` is at 380, so D-10 needs `hook.md` or a new node.
Only 4 lines of headroom remain, so the next edit that adds more than that
should make one of these moves first.

## 3. The shim

- **Whitespace**: arguments pass through as `"$@"`, and `PATH` is split one
  entry per line with `IFS= read -r`. Verified live with a shim directory
  containing a space, and with empty `PATH` entries, which are preserved.
- **Portability**: the only external tools are `tr`, `paste -sd: -` (explicit
  operand for BSD) and `dirname`.
- **Exit 127**: the message is pinned, and the test now declares its expected
  exit (`run -127`) instead of drawing bats' BW01 warning.
- **`.envrc`**: `PATH_add .bin` is last, which puts `.bin` ahead of
  `.gitlore/bin`.
- **Recursion (finding 2)**: `grep -vxF "$self"` removed the shim's directory
  only when the `PATH` entry was spelled exactly as `cd … && pwd` prints it. A
  trailing slash (`…/.bin/`) or a relative `.bin` entry survived, so
  `command -v claude` found the shim again and the exec loop never ended.
  Confirmed live: `timeout 5` exited 124. **FIXED**: an entry is now dropped
  when its `claude` is the shim itself (`[ "$dir/claude" -ef "$0" ]`). The new
  test goes red against the old shim (status 124 from the bounded runner) and
  green against the fixed one. `-ef` is not POSIX but dash, bash, BSD sh and
  busybox all support it; an inline `SC3013` disable says so.

## 4. The skill paragraph

No internal ids, no private paths, and no `memory/` (it says "a submodule").
The paragraph is imperative where it directs. One act was wrong (finding 3):
"`cd` within the same call" still leaves the Bash tool's working directory in
the subdirectory, because the tool keeps the cwd between calls. The paragraph
also contradicted `references/hook.md`'s "project root only" (finding 4).

## 5. Lifecycle audit

The probe's git calls are `cat-file --batch-check`, `diff-index`,
`hash-object --no-filters --stdin-paths` (no `-w`) and `ls-tree`, all with
`GIT_OPTIONAL_LOCKS=0` and inherited repository variables unset. None of them
writes. I checked this live on a scratch partial-merge repo (`a` staged and `b`
unstaged at feat's content, `c` edited, index back-dated). A `find .git` listing
of every entry's size and mtime was identical before and after a probe that
printed `merge=1`, `target=feat`, `match=a` and `match=b`. There was no
`index.lock` and no `MERGE_HEAD`, `git status` was unchanged, and stderr was
empty. The suite pins the index byte for byte and by mtime, and checks for
`index.lock`, in both `probes-readonly-facts.bats` and
`probes-readonly-pins.bats`. It covers the stat-dirty `d` as well.

Every new fixture lives under `$BATS_TEST_TMPDIR`: scratch repos, recorded
arguments, `bsdtools`, the bounded runner's files, and the shim's stub and
`bare` directories. The one `cd "$ROOT"`, in the new shim test, is in bats'
per-test subshell.

## 6. The Item 8.1 numbers report

**tmpdir-unset has not fired since 2.1.270.** As a statement about the corpus
it is exact: no flag-true hit is recorded at any version after 2.1.270. As a
statement about CC's behaviour, the report's method omits the opportunity
count, and without one, "no fires" could simply mean "no unsandboxed `$TMPDIR`
calls". I measured it: flag-true Bash calls whose command names `TMPDIR`, one
pass over `~/.claude/projects`, deduplicated by tool-use id. Through 2.1.270
there were 29 such calls, with 13 fires. After 2.1.270 there were 27, with 0
fires, 18 of them at 2.1.281 or later. That supports the conclusion. The
report's heading answer "No" to "does it ever fire on current CC" is still
stronger than an absence can carry; "not observed in 27 opportunities" is what
the data says.

**`nopath` is 6.6% of readonly-path hits excluding self.** The method is right.
The split depends only on `_readonly_path_line` and
`_probe_readonly_path_from_line`, both of which run before cwd resolution and
fact printing, so running the probe with cwd `/` and an empty command does not
bias it. The arithmetic holds: 10/152 = 6.58%, 11/195, and 1/43. I checked for
duplicate transcript copies: all 195 hit texts are distinct. It is an event
rate, though. Four of the ten non-self `nopath` hits (the `.git/config`
lines) come from one `micro` session, so seven sessions account for the ten.
One sentence of the report misstates the flag policy ("running silently under
the sandbox rather than never occurring flagged"). The policy is silent when
the flag is true. The report sits outside the changed-file scope, so it was
judged and not edited. No design text cites either figure.

## Findings

### UNFIXABLE

1. **The merge clause fires on command shape alone, and on the corpus only
   where it is false.**
   - **Location**: `lib/probes-readonly-facts.sh` `_readonly_print_facts`,
     spec in the probe-facts table in `detectors.md`.
   - **Problem**: `merge=1` is printed whenever a git segment runs merge,
     pull, checkout, switch, rebase or cherry-pick, whether or not that
     segment is what the refusal killed. With a resolvable target the match
     computation guards itself: after a successful checkout HEAD equals the
     target, so nothing matches and no clause appears. With no `target=`,
     though (`pull`, `rebase`, `cherry-pick`, a path argument, an
     unresolvable ref), the verdict states "The merge or checkout left the
     files it wrote with HEAD unmoved, blocking a re-run: restore them from
     HEAD". That is a restore act resting on no evidence.
   - **Corpus**: I ran the real probe, with each call's command, over all
     195 readonly-path hits. `merge=1` fires on 3, all by command shape and
     none with git's partial-checkout error in the text. None of the 195 hits
     contains that error at all. In all 3 the clause is false:
     - `git checkout <path> > /tmp/co.log`: the redirect was refused before
       git ran.
     - a `git checkout -q <branch> && git branch -f …`: the config write was
       refused after a successful checkout.
     - a scratch-repo script whose `mkdir` was refused.
   - **Investigation**:
     1. Scope OUT: not listed. Item 8.0 excludes only the lock repeat
        clause, seccomp's split, the phantom verdicts and the matchers.
     2. Design deferral: D-17 accepts shell-parsing residuals "named beside
        each fact". This one was not named, and it is now (finding 5).
     3. Codebase pattern: the text needles already provide the evidence the
        clause needs, but gating the no-target clause on them changes the
        slice-2 and slice-3 behaviour the spec and tests fix. The needles
        also miss git's `cannot create directory at` die, which a merge
        creating a new directory prints. For that case the command shape is
        the only signal, so dropping it outright loses a true positive.
     4. Conclusion: several valid designs with different failure
        characteristics, listed below.
   - **Options**:
     - (a) Print the no-target clause only when the text holds a
       partial-checkout needle, adding `cannot create directory at` to the
       needles.
     - (b) Keep the command-shape trigger but word the no-target case
       without the restore act.
     - (c) Keep it as is, with the residual documented.
   - **Recommendation**: (a). It trades one uncorpused true case for three
     observed false ones, and the false ones instruct a restore.
   - **Status**: UNFIXABLE (U-DESIGN). The residual is documented and the
     behaviour is unchanged.

### Major

2. **The shim loops forever on a `PATH` entry naming its directory in another
   spelling**. `.bin/claude:9`, described in §3. **FIXED**: dropping by `-ef`
   against the shim. New test in `tests/shim.bats`, checked red then green.

### Minor

3. **Skill act does not keep the cwd out of subdirectories.**
   `masks-and-gates.md`: "`cd` within the same call". **FIXED**: "A `cd` at
   the head of a call persists too. Give commands absolute paths or
   `git -C <dir>`, or put the `cd` in a subshell, `(cd <dir> && …)`, so the
   working directory never stays in a subdirectory."
4. **`hook.md` contradicts the skill carry.** It said "Phantom masks sit in the
   session's project root only … their verdict says where the masks are".
   **FIXED**: masks sit under the sandboxed call's working directory (the
   project root, or a subdirectory a persisted `cd` left the tool in, seen on
   CC 2.1.281), and the verdict names the project root, the usual case.
5. **Probe-facts residuals incomplete.**
   - `detectors.md` did not name the command-only `merge=1` residual (finding
     1) or the unborn-HEAD case (no `target=`, pinned in slice 4).
   - The `lib/probes-readonly-command.sh` header said "a … git behind a cd" is
     not recognised. It is: `cd /r && git merge feat` gives `merge=1`,
     verified.

   **FIXED**: all three added or corrected in `detectors.md`, and the code
   comment now reads "a reader behind a cd, or a reader or git behind a
   variable assignment or another prefix word".
6. **FR-1 status stale.** `Partial (dogfood: Item 8.1)` after the dogfood ran.
   **FIXED**: `Done`, pinned by `tests/hook.bats` as before.
7. **`## Now` Focus skipped the next step.** **FIXED**: "closing the first
   build — Item 8.2's memory-tier edits, then review and TDD audit."
8. **Pinned-by clauses predate the new files.**
   - FR-4 named `lib/probes-readonly.sh` but not the facts and command files.
   - FR-6 did not name `tests/verdicts-readonly.bats`, where the composition
     lengths are asserted.

   **FIXED**: `lib/probes-readonly*.sh`, and FR-6 now says
   "`tests/verdicts-readonly.bats` each `readonly-path` composition and its
   length". D-1's argument moved to `hook.md` to keep the hub under its cap
   (§2).
9. **Two new bats files break NFR-2's pin.** "Every bats file loads
   `bsd-stubs`" had been true of 19 of 19 files. `probes-readonly-pins.bats`
   and `shim.bats` omitted it. **FIXED**: `load helpers/bsd-stubs` added to
   both.
10. **Changelog.**
    - The D-17 entry's "The two conditions a stateless hook cannot see — a
      repeat failure — stay" named one thing as two. **FIXED**: "The clauses
      keyed to a repeat failure, which a stateless hook cannot see, stay in
      the text."
    - No entry recorded the shim, the dogfood that closed FR-1, or the
      masks-follow-cwd correction. **FIXED**: new 2026-09-27 entry, which
      also records the D-1 move.
11. **Shim test tool list stale.** The `bare` directory still linked `grep`,
    which the shim no longer calls, and the 127 case drew BW01. **FIXED**:
    `grep` dropped, `run -127`.

### Deferred

- **Phantom verdicts name "the project root".** `lib/verdicts.sh` and the
  `detectors.md` phantom paragraphs. After a persisted `cd` the masks sit in
  a subdirectory, and this verdict text sends the agent to the wrong place.
  Reason: Item 8.0 puts the phantom verdicts out of scope. `hook.md` and the
  changelog now record the gap. Candidate wording for a later item: "…
  masks over dotfiles in the working directory …".

### Judged acceptable, not changed

- **`_lock_rerun true`**'s "once no sandboxed command is running" (§1).
- **"— they match `<target>` —,"**: an em-dash pair followed by a comma is
  unusual typography, but it is the spec's exact text in `detectors.md` and
  the tests. The clause is the one reassurance line D-7 allows, telling the
  agent the restore loses nothing.
- **Rejected alternative "Splitting `sandbox-effects` …"**: "It remains the
  fallback if dogfooding shows the hook not firing." The dogfood showed the
  hook firing, but the sentence still works as a reopen-if.

## Requirements validation

| Requirement | Status | Evidence |
|---|---|---|
| FR-4 | Satisfied | `probe_readonly_path <flag> <cwd> <command>`; facts pinned in `probes-readonly-facts.bats`, `probes-readonly-pins.bats` |
| FR-5 | Satisfied | the flag reaches every verdict as `$2`; `hook-locks.bats` pairs both values |
| FR-6 | Satisfied | longest real composition 289 (313 with a settings path); length and quiet assertions on every composition |
| D-17 | Partial | the conditionals are gone; the no-target merge clause is asserted on command shape alone (finding 1) |
| D-16, FR-1 | Satisfied | shim pinned by `tests/shim.bats`; dogfood 2026-09-27, CC 2.1.283 |

## UNFIXABLE

Finding 1 (U-DESIGN): the no-target merge clause is asserted on command shape
alone. My human partner chooses among options (a), (b) and (c).

## Files changed

- `/Users/david/code/sandbox-lies/.bin/claude`: `-ef` strip (finding 2)
- `/Users/david/code/sandbox-lies/tests/shim.bats`: stripped-spelling test,
  `bsd-stubs` and `probes` loads, `run -127`, tool list (findings 2, 9, 11)
- `/Users/david/code/sandbox-lies/tests/helpers/probes.bash`:
  `run_probe_bounded` shared-by note names `shim.bats` (finding 2)
- `/Users/david/code/sandbox-lies/tests/probes-readonly-pins.bats`: `bsd-stubs`
  load (finding 9)
- `/Users/david/code/sandbox-lies/skills/sandbox-lies/references/masks-and-gates.md`:
  the cwd act (finding 3)
- `/Users/david/code/sandbox-lies/docs/references/hook.md`: masks-follow-cwd
  (finding 4); D-1's argument moved in (§2)
- `/Users/david/code/sandbox-lies/docs/references/detectors.md`: residuals
  (findings 1, 5)
- `/Users/david/code/sandbox-lies/lib/probes-readonly-command.sh`: residual
  comment (finding 5)
- `/Users/david/code/sandbox-lies/docs/design.md`: FR-1, FR-4, FR-6, `## Now`,
  D-1 conclusion only (findings 6–8)
- `/Users/david/code/sandbox-lies/docs/changelog.md`: D-17 sentence, new
  2026-09-27 entry (finding 10)

Every edited Markdown file was re-wrapped by `rumdl fmt`. `.bin/claude` was
temporarily restored from `HEAD` for the red check, then put back. Gate log:
`/tmp/claude/phase-8-pc.out`.
