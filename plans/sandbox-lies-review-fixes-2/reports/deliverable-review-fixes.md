# Deliverable review fixes: m-1 to m-22

All 22 Minor findings were checked against the current files. All 22 were real
(the doc claims in m-19, m-20, m-21 were also re-checked against the fetched
`permission-modes` and `sandboxing` docs). None is not-a-defect. Nothing was
committed. The `memory` pointer, `.gitlore/bin/claude` and
`.claude/settings.json` were not touched.

New files: `tests/probes-resume-tree.bats` (needed because
`tests/probes-resume.bats` hit the 400-line cap), `tests/helpers/resume.bash`
(the ids and the `transcript` builder both suites share).

Mutation method: break the code, run the file, restore, and `diff` against a
saved copy. RED = the new test run against the pre-fix `HEAD` code (or the
mutated state), failing on its own assertion.

## m-1 Outline Base comma: fixed

- File: `plans/sandbox-lies-review-fixes-2/outline.md` (the line now reads
  `` `sha` — copied verbatim … ``, as the superseded outline did).
- `edify-review-range.sh` (not touched) now prints
  `RANGE: 52e6dd82b831a1cc2b7b516d4c248df6fb1ebc8c..HEAD`, exit 0.

## m-2 Unsearchable config tree read `lost`: fixed

- Files: `lib/probes.sh`, `tests/probes-resume-tree.bats`,
  `tests/hook-resume.bats`, `docs/references/detectors.md` (the `unknown` list).
- The probe now prints `unknown` when `<root>/projects` is not a readable,
  searchable directory, and when an id has no hit while some project directory
  cannot be listed. It scans `projects/*/` per directory; an empty `projects/`
  still reads `lost`.
- RED (probe cases against the unchanged probe): nonexistent config dir, a
  `projects/` in modes 000/444/311, a `projects` that is a file, and an
  unreadable project directory hiding an id all printed `lost` where
  `unknown` was asserted. The hook case "config dir that does not exist,
  silent" failed at `[ -z "$output" ]` against HEAD (the hook emitted the lost
  verdict).
- Mutations, each red: drop `-x` check (mode-list case), drop `-r` check
  (mode-list case), drop `-d` check (the `projects`-is-a-file case), drop the
  per-directory `blind=1` (unreadable-project-dir case), drop the
  `[ -d "$d" ] || continue` guard (empty-`projects/` case, added for it).
- BSD: one case re-run with `make_bsd_stubs`; mutated `sed -nE` to a long
  option, the case went red.

## m-3 Probe subshell did not undo `set -f`: fixed

- Files: `lib/probes.sh` (`set +f`, comment now true), `tests/probes-resume-tree.bats`.
- RED: "a caller's noglob does not make every id lost" printed `lost`, asserted
  `found`, against HEAD. Mutation: removing `set +f` turns it red.

## m-4 Probe kept its own copy of the matcher's line shape: fixed

- Files: `lib/matchers.sh` (new `_RESUME_LOST_LINE`, one ERE with the id as
  its group, used by `match_resume_lost`), `lib/probes.sh` (sed uses it),
  `tests/probes-resume-tree.bats`.
- The matcher stays `grep -qE`, so its behaviour is unchanged.
- RED: the case widens `_RESUME_LOST_LINE` and asserts both the matcher and
  the probe follow; against HEAD it failed at `match_resume_lost` (the variable
  did not exist). Mutations: a private regex copy in the probe turns it red on
  the probe's `lost` assertion; a private copy in the matcher turns it red on
  the matcher assertion.

## m-5 `annotate.sh` stderr comment: fixed

- File: `hooks/annotate.sh` (comment only). The probe sentences moved after the
  jq description, "it" became "stdin", the orphan line is reflowed, and the
  list now names the `wc -c` redirect and `detect`'s `tr` read failure ("e.g.").
  No test (comment); `bash -n` and shellcheck pass.

## m-6 `readfile=` skip residuals: fixed

- Files: `lib/probes-readonly-command.sh` (`{` joins the skip class, written
  `\{` for shellcheck; comment updated), `tests/probes-readonly-globs.bats`,
  `docs/references/readonly-path.md`, `docs/changelog.md`.
- RED: `cat {a,b}.log` still printed `readfile=` against HEAD
  (`assert_no_readfile` failed on "expected nonzero exit code"). Mutation:
  removing `{` from the class turns it red.
- Docs: the skip sentence now says "a glob, a brace expansion or a `$`
  expansion"; a new residual bullet records that a backtick substitution is not
  skipped and gives the backtick word as `readfile=`.

## m-7 "Never opens the transcript" unpinned: fixed

- Files: `tests/probes-resume-tree.bats` (chmod 000 transcripts, assert
  `found` and empty stderr), `tests/hook-resume.bats` (same through the hook).
  Both skip when run as root.
- Not RED against HEAD by design (the pin covers existing behaviour). Mutation:
  `cat "$d$id.jsonl" >/dev/null` on a hit turned both red (stderr non-empty;
  hook output no longer parses as JSON).

## m-8 Verdict unit case pinned "no text" with `-`: fixed

- File: `tests/verdicts.bats` (the case loops over `-` and `unknown`).
- Not RED against HEAD (coverage). Mutation: `lost | unknown)` in
  `verdict_resume_lost` turns it red; restored.

## m-9 FR-5 pinned-by list: fixed

- File: `docs/design.md` FR-5: carve-out "except `resume-lost`, whose probe
  decides under either value (D-8)" and `tests/hook-resume.bats` named.
- The cap: the additions pushed `design.md` to 409 lines. Resolved with the
  split the hub already uses for D-6, D-12, D-13 and D-14 (a stub with "Argued
  in"): D-15's argument moved to `docs/references/detectors.md` and D-16's to
  `docs/references/hook.md`, each leaving a 3-line stub in the hub. After
  `just format-docs` the hub is 399/400, no crammed lines.

## m-10 "Verified against" lag: fixed, with a caveat

- `docs/design.md` Status now reads `9bd925e`, the last commit touching code
  before this pass. These fixes are uncommitted and change code, so the sha
  must be bumped to the commit that lands them.

## m-11 NFR-4 pins: fixed

- `docs/design.md` NFR-4 names `tests/probes-resume.bats` (`HOME/.claude`
  unread when `CLAUDE_CONFIG_DIR` is set) and `tests/probes-resume-tree.bats`
  (no transcript opened); the status reads "read scope: `resume-lost`'s
  pinned, the rest review, not gated".

## m-12 "Code under test" undefined: fixed

- Files: `CLAUDE.md`, `docs/design.md` NFR-2. Both now say the code under test
  is what the suite's assertions are about, and a library a suite only runs to
  build its input (`verdicts*.bats` piping text through `lib/matchers.sh`) is
  covered by its own suites. Wording only, as the finding says.

## m-13 FR-4 "proved once against a live reproduction": fixed by narrowing

- `docs/design.md` FR-4 says that for `resume-lost` the recorded reproduction
  is CC's behaviour its probe reads (E1 to E5), not a run of the probe on a
  live refusal. The Status line's dogfood date now carries "before the
  `resume-lost` probe". No live run was invented; the review's own live `lost`
  is not in the evidence files and was not recorded.

## m-14 `sandbox-state.md` cost list: fixed

- `docs/references/sandbox-state.md` gains three bullets, each checked against
  `hooks/annotate.sh` and `lib/verdicts.sh`: `tmpdir-unset` silent (gated on a
  true flag); lock verdicts word the re-run as adding the flag; a flagged
  `--resume` of an id that never existed reads `lost`. "What is left" kept.

## m-15 Whose environment picks the config dir: fixed

- `docs/references/detectors.md` Probe paragraph: the hook's (session's)
  environment; a `CLAUDE_CONFIG_DIR=` prefix on the call never reaches it,
  which is why `found` fits E5.

## m-16 Changelog omitted test-side fixes: fixed

- `docs/changelog.md`: closing paragraph of the 2026-10-08 entry lists the
  Major 1 pin, the `.git`-above guard, the `mktemp` spy, the seven BSD cases,
  and this pass's probe changes. The earlier sentence on `readfile=` now says
  "a glob, a brace or a `$` expansion".

## m-17 `??` "unconditionally": fixed

- `skills/sandbox-lies/references/masks-and-gates.md`: "A mask the repository
  does not ignore is reported as a `??` line …; one it ignores shows only under
  `--ignored`, as `!!`" (matches `m4-reprobe-evidence.md` call 3).

## m-18 "each cost a classifier call": fixed

- Same file: "each forfeit the read-only auto-allow and, absent an allow rule,
  cost a classifier call", the hub's twin wording.

## m-19 "Clears it before any classifier call": fixed

- Files: `skills/sandbox-lies/SKILL.md` (two sentences, "a narrow allow
  rule"), `references/excluded-commands.md`, `references/escapes-and-costs.md`
  (auto mode drops broad rules on entry, `Bash(*)` and wildcarded
  interpreters; a command with per-command allowed domains goes to the
  classifier whatever rule matches; "propose a narrow one"). Verified against
  the `permission-modes` doc fetched in this pass.

## m-20 Wrong citation for the two `!` cases: fixed

- `escapes-and-costs.md` now cites the sandboxing doc, "Turn off the retry with
  strict sandbox mode" (confirmed in the fetched page).

## m-21 "Honoured in strict mode too": fixed

- Files: `SKILL.md` ("at user scope"), `escapes-and-costs.md` (both places;
  strict mode via managed settings or `--settings` makes the sandbox
  admin-required and repository `excludedCommands` entries are ignored),
  `excluded-commands.md`. Confirmed against the fetched sandboxing page.

## m-22 Hub's 2.1.293 summary: fixed

- `SKILL.md`: "the same status behind `true && command`" (the form that ran
  was `true && command git status …`). `SKILL.md` stays at 200/200.

## Out of scope, left alone

"Carried, not counted" items, the outline's OUT list and the delegate-status
open decisions were not touched.

## Gate

`just precommit` (run in the foreground, own exit status read): exit 0.
Recap line: `precommit passed: plugin.json, hooks.json, shellcheck, bash -n,
rumdl, line limits, links, python compile, tests` (371 bats tests, 0 failed).

`git status --short`, tracked-file changes only (the `.claude/handoff-*` and
`memory` entries predate this work):

```
M  .claude/handoff-task.md
M  .claude/handoff-todo.md
 M CLAUDE.md
 M docs/changelog.md
 M docs/design.md
 M docs/references/detectors.md
 M docs/references/hook.md
 M docs/references/readonly-path.md
 M docs/references/sandbox-state.md
 M hooks/annotate.sh
 M lib/matchers.sh
 M lib/probes-readonly-command.sh
 M lib/probes.sh
 M memory
 M plans/sandbox-lies-review-fixes-2/outline.md
 M skills/sandbox-lies/SKILL.md
 M skills/sandbox-lies/references/escapes-and-costs.md
 M skills/sandbox-lies/references/excluded-commands.md
 M skills/sandbox-lies/references/masks-and-gates.md
 M tests/hook-resume.bats
 M tests/probes-readonly-globs.bats
 M tests/probes-resume.bats
 M tests/verdicts.bats
```

Untracked, new: `tests/probes-resume-tree.bats`, `tests/helpers/resume.bash`.
