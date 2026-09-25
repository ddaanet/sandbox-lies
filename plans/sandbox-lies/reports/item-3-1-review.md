# Review: Item 3.1 — live reproductions in detectors.md

**Scope**: uncommitted edit to `docs/references/detectors.md` — the `git-lock`
entry's `Live reproduction (2026-09-25): orphan`, `held` and
`Live reproduction owed: mask` paragraphs; the `config-lock` entry's
`Flag policy.` line and `Live reproduction (2026-09-25): mask` paragraph.
**Date**: 2026-09-25
**Mode**: review + fix

Recall: `plans/sandbox-lies/recall-artifact.md` resolved;
`memory/ddaanet/sandbox-effects.md` and `git-hook-env-leak.md` read (the
config.lock mask and the index.lock error-string sharing are the facts the
paragraphs sit beside). Probe output order checked against `lib/probes.sh`
(`held` → `pid=`, `path=`; `orphan` → `bytes=`, `age=`, `path=`; `mask` →
`path=`).

## Summary

The four paragraphs record the 2026-09-25 run accurately: dates, git version,
holder tool, command shapes, probe invocations and printed output all match the
ground truth, and no git diagnostic text is quoted (self-quiet holds). Three
minor accuracy/clarity fixes applied in place; the file stays at 341 lines and
the precommit gate passes.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

None.

### Minor Issues

1. **`no index.lock anywhere` overclaims the evidence**
   - Location: `docs/references/detectors.md:102-106` (git-lock `mask` owed
     paragraph)
   - Note: the run checked two places — a sandboxed `ls -la` of the project
     root (index.lock absent) and the scratch repo (commit succeeded). "anywhere"
     asserts more than was observed. Rewritten to "no `index.lock` there or in
     the scratch repo".
   - **Status**: FIXED

2. **`sh -c` nesting rationale dropped from tracked text**
   - Location: `docs/references/detectors.md:102-106`
   - Note: the replaced "owed" paragraph carried why the command is nested
     (`git:*` exclusion would otherwise unsandbox a top-level `git`). The new
     paragraph gave the `sh -c` shape without the reason, which is what whoever
     retries the reproduction after the escalation needs. Restored as a short
     parenthetical clause.
   - **Status**: FIXED

3. **`held` paragraph gives no command shape; `orphan` sentence misreads**
   - Location: `docs/references/detectors.md:92-100`
   - Note: the runbook interface asks for the command shape per outcome. `held`
     said "held open on an append descriptor by a background `sleep`"; replaced
     with the actual shape `sleep 30 9>>.git/index.lock`. `pid=` the sleep's
     pid` aligned to the entry's `<placeholder>` convention. The `orphan`
     sentence ("An empty `index.lock` made by hand, then an unsandboxed
     `git add f`, raised …") had two subjects; rewritten as "With an empty
     `index.lock` made by hand, an unsandboxed `git add f` raised …".
   - **Status**: FIXED

## Fixes Applied

- `docs/references/detectors.md:92-96` — orphan paragraph: single-subject
  sentence.
- `docs/references/detectors.md:98-100` — held paragraph: command shape
  `sleep 30 9>>.git/index.lock`; `pid=<the sleep's pid>`.
- `docs/references/detectors.md:102-107` — mask owed paragraph: `sh -c` nesting
  rationale restored; "anywhere" scoped to the project root and the scratch
  repo.

Gate after edits: `just format-docs && just precommit` —
`precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line
limits, links, tests` (bats 131 passed). `git status` shows only
`docs/references/detectors.md` modified (the `??` dotfiles are sandbox masks).

## Requirements Validation

| Requirement | Status | Evidence |
|-------------|--------|----------|
| FR-4 — each probe proved by a live reproduction, recorded in detectors.md | Satisfied for `orphan`, `held`, config-lock `mask`; git-lock `mask` recorded as owed | `detectors.md:92-107, 130-136`: date, command shape, probe call and printed output per proved outcome |
| Self-quiet — no detector diagnostic quoted | Satisfied | "the lock error", "the config-lock error naming `.git/config` relative" — described, not quoted |
| Line cap < 400, rumdl 80-col reflow | Satisfied | 341 lines; `rumdl fmt --check` passes |

**Gaps:** git-lock `mask` not reproduced — recorded by design as the open
escalation (scope OUT).

## Positive Observations

- The config-lock paragraph pins the relative path in git's error, which is the
  detail the probe's path resolution exists for, and closes with the
  key-not-written check that proves the write really failed.
- The git-lock owed paragraph ties the 2026-09-25 attempt to the 2026-09-23 one
  and names the mask that *was* present (`config.lock`), so the escalation
  carries the discriminating observation rather than a bare "did not reproduce".

## Recommendations

None beyond the recorded escalation.
