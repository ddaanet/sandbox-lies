# Build — Phase 8, slice 8.0/5 and its checkpoint

Resumed from `build-phase-8b.md` §Open gate item 1: option (a), approved by my
human partner. Entry state: memory clean, and the tree clean apart from the two
handoff files the main session staged.

## What was built

- `f05d3a8`, the spec first:
  - `docs/references/detectors.md` §readonly-path gains a `partial=1` probe
    fact: the text holds one of git's partial-checkout errors. The
    `cannot create directory at` needle is added beside the two earlier ones.
    The no-target merge clause now needs `partial=1`. A fourth bullet says
    that with neither `target=` nor `partial=1` there is no clause. The
    Residuals paragraph and a 2026-09-27 live reproduction were also added.
  - A changelog entry.
  - Runbook Item 8.0 slice 5, with a list-revision line.
  - Two fixtures cut by `tests/extract-fixtures.py`, each with a `SPEC` entry
    and a `matchers.bats` case:
    - `fire-readonly-path-git-config-busy`, micro, 2026-07-09: a checkout that
      finished, then a refused config write. This is one of the corrector's 3
      false positives.
    - `fire-readonly-path-git-mkdir`: this delegate's own live reproduction,
      a sandboxed `git -C <worktree> checkout` refused on a new directory, on
      CC 2.1.281 (transcript `version`) with git 2.47.3.
- `c46241e`, slice 8.0/5 GREEN. The RED, test-review and GREEN reports went
  in with it, plus the brief's `## Slice 8.0/5` section.
  - `_readonly_partial_checkout_text` has the third needle.
  - `_readonly_print_facts` prints `partial=1` after `merge=1`.
  - `verdict_readonly_path` gives the no-target restore clause only under
    `partial=1`.
- `e5df535`: the code review, Ready. One minor fix: a double-negated guard
  became a plain `if`.
- `f6207c2`: the checkpoint corrector (`reports/phase-8c-corrector.md`),
  Ready. Four minor fixes:
  - `detectors.md` now says where a relative path joins, and names git's
    partial-checkout path residual;
  - the design Verified-against stamp `45c0316e` resolved to no commit and is
    now `45c03163`, checked with `git rev-parse` and ancestry;
  - a test whose name the slice made false was renamed;
  - five history-narration test comments now state what each test pins.

Final state: precommit passed, 249 bats. It checks plugin.json, hooks.json,
shellcheck, bash -n, rumdl, line limits, links and the tests.

## Needle placement

The needle test stays in the probe, which prints it as the fact `partial=1`.
The verdict composes the clause from that fact. The existing contract settles
this:

- `hooks/annotate.sh` passes the verdict only the probe's lines after the
  outcome, never the tool text.
- The Probe facts table is where everything read from the text or the command
  is declared.
- D-17 says "the probe or the verdict decides which acts apply". Here the
  probe decides what the text shows, and the verdict decides which clause that
  selects.

`merge=1` keeps its meaning (a merge-style command, or `partial=1`), so the
slice 3 and slice 4 probe pins stand unchanged. The `match=` clause does not
read `partial=1`: the matching files are their own evidence.

## Deviations

- The spec commit also carries the two cut fixtures and their `matchers.bats`
  cases. They are test inputs committed ahead of RED, so the slice diff holds
  only behaviour tests.
- `fire-readonly-path-git-mkdir` is a real recorded tool result, cut by the
  cutter, but from a scenario this delegate built on purpose: a scratch repo
  with its worktree outside the write allowlist. No corpus call held any of
  the three needles.
- One test pins behaviour the unchanged code already had: `target=` with
  `partial=1` and no `match=` gives no clause. It is a guard, proven by
  mutation. RED flipped the target guard; the test review reproduced the
  proof by dropping the `target=` parse.
- The checkpoint corrector says its three probe-side mutations were "restored
  from a copy", which the contract forbids. `git diff` over `lib/` was empty
  afterwards, and precommit passed on the committed tree.
- The corrector's design-stamp fix is outside the slice's range. The dispatch
  asked it to check the design's state layer.
- Named subagents could not be spawned, and no dispatch returned a
  SubagentHandback. Every artifact was read at its path.
- Verify-step after GREEN reported DIRTY, listing only the two staged handoff
  files. `git status --porcelain --untracked-files=no` plus `just precommit`
  stood in, per the standing decision.

## For the run summary at Finish

- Slice 8.0/5 was added after the Phase 8 boundary corrector. Its list
  revision is in `runbook.md`. After 8.0/5: none, since it is the item's last
  slice.
- The new needle was grounded by a live reproduction before the spec named
  it. Both merge and checkout die on it when the target adds a directory; HEAD
  stays put.
- Deferred by the checkpoint corrector: the probe resolves the relative path
  in git's partial-checkout errors against the payload `cwd`, but git prints
  it from the worktree top. From a subdirectory, or under `git -C`, the path
  is wrong. If the wrong path's parent is missing it reads `readonly`, which
  carries no merge clause. This predates the range (Item 6.1) and is
  documented as a residual. Recommended as a later slice: resolve from the
  nearest `.git` ancestor when the line carries git's prefix. `git -C` stays
  a residual under D-1.
- `docs/references/detectors.md` is at 399 of 400 lines. The corrector
  recommends splitting §readonly-path into its own node at the next
  addition, not trimming it.
- No refactor signals. No remediation RCA.

## Open gate

None.

## Finish resume block

```text
Finish of /edify:build for plans/sandbox-lies/runbook.md; every item is done
(slice 8.0/5 built in plans/sandbox-lies/reports/build-phase-8c.md).
Repo: /Users/david/code/sandbox-lies. Every command starts with
`cd /Users/david/code/sandbox-lies &&`.
Baseline: .git/build-baseline (whole build). Item 8.0's range starts after 7c4f811.
verify-step: /Users/david/.claude/plugins/cache/ddaanet/edify/0.3.0/skills/build/scripts/verify-step.sh
  run unsandboxed, foreground, timeout 600000 ms. A DIRTY listing only phantom
  dotfiles, or only the main session's staged .claude/handoff-*.md, means: use
  `git status --porcelain --untracked-files=no` plus `just precommit` instead.
tdd-audit: every tdd item's slice reports under plans/sandbox-lies/reports/
  (item-2-*, item-4-*, item-6-1-*, item-8-0-s1..s5-*) and the commit range
  $(cat .git/build-baseline)..HEAD. Slice 8.0/4 is proven by mutation (RED and
  test-review tables). Its code review was orchestrator-written because the
  implementation diff was empty. The `git pull` pin is an outcome pin (bash 3.2
  path not executable here). Slice 8.0/5: three tests red on assertions; its
  guard test (target= with partial=1 and no match=) is mutation-proven; its
  spec and fixtures landed in a commit ahead of RED.
Correctors: phase-8-corrector.md (Phase 8 boundary, standing in for Item 8.0's
  own checkpoint over slices 1-4) and phase-8c-corrector.md (slice 8.0/5).
Review gate: the whole diff since the baseline, weighted to Phase 8. Check
  D-17 across lib/verdicts.sh, the probes and the docs (partial=1 selects the
  no-target merge clause); the shim; the design state layer (docs/design.md is
  at 396 of 400 lines, and the next move-out is D-8's or D-10's argument;
  docs/references/detectors.md is at 399 of 400, and the next addition splits
  §readonly-path into its own node); the skill carry. Carry forward: the
  deferred phantom "project root" wording; the nopath shapes named in design
  Now; the readonly-path relative-path resolution for git's partial-checkout
  errors (subdirectory, git -C), in phase-8c-corrector.md Deferred Items.
Held: /gitlore:push, until the plugin is published and installable in the
  other ddaanet repos. Other repos stay read-only.
```

## Context usage

About 195k tokens by this session's token counter at the report, most of it
the spec and code reads, the corpus scans and the five dispatch round-trips.
The dispatches ran in their own contexts.
