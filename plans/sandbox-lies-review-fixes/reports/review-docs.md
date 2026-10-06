# Review: finishing review gate — group "docs"

**Scope**: The doc deliverables changed since `a7ff5e5`: `CLAUDE.md`,
`README.md`, `docs/changelog.md`, `docs/design.md`,
`docs/references/{detectors,hook,lock-detectors,readonly-path,rejected-alternatives,sandbox-state}.md`.
I read each one against the code it describes (`lib/`, `hooks/`, and the tests
it names as pins), against the other nodes, and against the runbook's doc items
(1.1; the docs steps of 4.1, 4.2 and 4.3; 5.2; the docs bullets of 5.4 and
5.5). Hunks from `0bbb18c` (the `changelog.md` dogfood entry, D-16 and the
Architecture `.bin/claude` line) are excluded, as are `161d958` and the
vendored `plugin-dev/`.
**Date**: 2026-10-06
**Mode**: review + fix

## Summary

The doc deliverables are complete and agree with the code. The exclusion rule,
including D1's 2026-10-05 revision, reads the same on every docs surface. Every
"where honoured" or "not honoured" qualifier was replaced by the every-command
rule plus the git path-argument exception. The recorded 2.281, 2.288 and 2.289
probes are marked confounded. The CC 2.1.289 bare `git status` is the
observation and the re-probe.

The newline contract from Items 5.4 and 5.5 is stated once per probe family,
matching `lib/probes-readonly.sh` and `lib/probes.sh`:

- `readonly-path.md`'s outcome table: `nopath`, with no `path=`.
- `lock-detectors.md`'s Probe paragraph: the outcome stands and `path=` is left
  out.

I found no dangling link or citation after the `detectors.md` split or after
the `rejected-alternatives.md` and `sandbox-state.md` move-outs.

One minor seam: `docs/design.md`'s Status line still counted the dogfood shim as
built and tested here. I fixed it in place.

**Overall Assessment**: Ready

## Checks performed

- **Exclusion wording across surfaces.** I grepped `honour`, `whole-call`,
  `git:*`, `claude:*`, `exclusion` and `excludedCommands` over `README.md`,
  `CLAUDE.md`, `docs/design.md` and `docs/references/*.md`. Every hit agrees
  with the revised D1:
  - FR-9, D-8, L-2, the Rejected-alternatives line, `sandbox-state.md`,
    `rejected-alternatives.md`, the README skill blurb, and the `detectors.md`
    Translation map and Not-detectors entries.
  - `hook.md`'s D-1 pilot reading, now "what the configuration implied, not an
    observed run".
  - `lock-detectors.md`'s `mask` and config-lock reproductions. They blame the
    `sh` head, the `cd` and `git -C`. The 2.281 `touch` pair and the 2.288 and
    2.289 `git init -q /tmp/<name>` runs are confounded, and the 2.1.289 bare
    `git status` is the re-probe.
  - The changelog entry says the same.
  - `git -C` and the path-argument rule match
    `skills/sandbox-lies/references/excluded-commands.md`, which is the
    settings reference plus the sandboxing doc's `git -C`.
- **`path=` contract after Items 5.4–5.5.**
  - `lock-detectors.md` Probe paragraph against `_probe_lock_at`. Every print
    site goes through `${pathline:+…}` or the final guard. The `pathline=`
    guard sits on the resolved path, matching "the outcome stands and the
    `path=` line is left out".
  - `readonly-path.md`'s `nopath` row against `probe_readonly_path`'s guard on
    the resolved path. Facts are still printed under `nopath`, as the doc's
    "under `writable` and `nopath`" says.
  - `config-lock`'s settings-lock act is keyed on `path=`. With `path=` absent
    it falls to *Re-run*, which is consistent with Item 5.5's premise.
  - FR-4 and `hook.md` Flow describe the contract only generically, so they have
    nothing to contradict.
- **The `match=` row.** `<repo>/<file>` and "trailing slashes stripped" agree
  with `_readonly_git_dir`. Its strip-then-`/` fallback makes a root repository
  give `match=//<file>`, as the residuals say. The restore clause's absolute
  names match Item 4.2.
- **The `readfile=` row and residuals.** They carry Item 4.1's operand rule and
  every residual the runbook lists:
  - other options' separate arguments;
  - clustered and long `-e`/`-f` forms;
  - sed `w`;
  - a descriptor duplication in a pattern or argument slot.
- **mv's `to`.** The inter-device form only, which matches the
  `inter-device move failed` sed arm in `lib/probes-readonly.sh`.
- **`hook.md` Registration and the `jq` paragraph** against `hooks/hooks.json`
  and `hooks/check-jq.sh`:
  - three entries, `bash "${CLAUDE_PLUGIN_ROOT}/hooks/<script>"`, 10 s each;
  - no matcher on `SessionStart`;
  - `command -v jq`;
  - a single fixed `printf`;
  - the `\u001b[0m` escape.

  The pinning descriptions also match the code:
  - `tests/hook.bats` "hooks.json names the three events" checks the keys,
    matchers, timeouts and command strings.
  - `tests/check-jq.bats` uses `env -i`, a cwd outside the checkout, `TMPDIR`
    naming a missing directory, and BSD stubs.
- **design.md "pinned by" lines.** Each named file exists and holds the cases
  claimed:
  - FR-1: `check-jq.bats`.
  - FR-4: `probes-readonly-members.bats`, `probes-readonly-operands.bats` and
    `hook-writes.bats`.
  - NFR-4: `hook-writes.bats`, the two "writes nothing" cases in
    `probes-edges.bats`, and `check-jq.bats`.
- **Figures and their sources.**
  - FR-8's 25 of 34 matches `plans/sandbox-lies/reports/deliverable-review.md`,
    dated 2026-09-28.
  - `phantom-untracked`'s 41 and D-5's 207 match
    `plans/2026-09-02-sandbox-detector-replay-results.md` (21,272 pairs). The
    replay required four or more blanks before a name and missed the tab
    shape; `plans/2026-09-03-sandbox-matcher-corpus-eval.md` says the same.
  - The 57 is over the 21,453-pair corpus.
  - The Candidates re-measurement is credited to two reports. Both exist and
    cover all four shipped candidates.
- **Dangling references.**
  - Anchors `lock-detectors.md#git-lock`, `#config-lock` and
    `readonly-path.md#readonly-path` resolve.
  - `detectors.md:272` "(design, rejected alternatives)" still holds:
    `tmp-full` is named in design.md's list.
  - The `detectors.md` citations left in `lib/`, `hooks/` and `tests/` cite
    detectors that stayed in `detectors.md`, or name both nodes.
  - No docs surface names `.bin/claude` or `tests/shim.bats` as this repo's,
    apart from the Status line fixed below. D-16 belongs to `0bbb18c`.
- **Self-quiet and CLAUDE.md.** `tests/docs.bats` walks `git ls-files` with the
  three pilot files exempt. This matches CLAUDE.md's "every tracked file except
  two exemptions" and FR-11.
- **Runbook doc items.** Every deliverable is present:
  - 1.1: the stub and the "read the node" sentences in `detectors.md` and
    `hook.md`.
  - 4.1, 4.2 and 4.3: the docs steps above.
  - 5.2: every bullet, including the option (a′) move-out with D-9's
    *Rejected* line, and D-8 moved to `sandbox-state.md`.
  - 5.4 and 5.5: the A-3 lines and one changelog sentence each.

## Issues Found

### Critical Issues

None.

### Major Issues

None.

### Minor Issues

1. **design.md Status counted the dogfood shim as built and tested here**
   - Location: `docs/design.md:3-8`
   - Note: The Status line said "Built and tested: … the skill, and the dogfood
     shim." After `0bbb18c`, the shim is the toolkit's `plugin-dev/bin/claude`,
     and `tests/shim.bats` is gone, so nothing in this repository builds or
     tests a shim. The same list also omitted the one component this job built
     and pinned: the `SessionStart` `jq` check (`hooks/check-jq.sh`,
     `tests/check-jq.bats`).
   - Fix: "…, the `SessionStart` `jq` check, and the skill." `just format-docs`
     reflowed the paragraph and the file stays at 399 lines.
   - **Status**: FIXED

## Fixes Applied

- `docs/design.md:3-8` — Status list: dropped the dogfood shim, added the
  `SessionStart` `jq` check. Paragraph reflowed by `just format-docs`; still 399
  lines.
- Verification: `just precommit` was run in the foreground and exited 0. Its
  output: "bats: 309 passed, 0 failed; precommit passed: plugin.json,
  hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests". That run
  includes the `tests/docs.bats` self-quiet sweep and the link gate.

## Requirements Validation

| Requirement | Status | Evidence |
|-------------|--------|----------|
| Item 1.1 split (NFR-5) | Satisfied | `detectors.md:145-152` stub, `readonly-path.md` node, read-before sentences in `detectors.md:6-9` and `hook.md:8-11` |
| Item 4.1 docs (FR-4) | Satisfied | `readonly-path.md:63`, `:90-118` |
| Item 4.2 docs (FR-4, D3) | Satisfied | `readonly-path.md:62`, `:156-161` |
| Item 4.3 docs (NFR-2, D-12) | Satisfied | `hook.md` Registration and the `jq` paragraph; design NFR-3, Architecture |
| Item 5.2 FR-1, D-12 | Satisfied | design FR-1, D-12, Architecture; README §Install |
| Item 5.2 FR-7, NFR-1 | Satisfied | `detectors.md` Candidates intro, `phantom-untracked` corpora, D-5 |
| Item 5.2 FR-8 | Satisfied | design FR-8 qualifier |
| Item 5.2 FR-9 (D1 as revised) | Satisfied | design FR-9/D-8/L-2/Rejected list, `sandbox-state.md`, `rejected-alternatives.md`, `lock-detectors.md`, `hook.md` D-1, README |
| Item 5.2 FR-11 | Satisfied | `CLAUDE.md` exemption wording |
| Item 5.2 NFR-4 | Satisfied | design NFR-4 read scope and its pins |
| Item 5.2 NFR-5 | Satisfied | design.md 399 lines via option (a′) |
| Item 5.2 platform statement, D-3, NFR order | Satisfied | design §What this is, D-3, NFR-4 before NFR-5; README |
| Item 5.4 docs (A-3 `nopath`) | Satisfied | `readonly-path.md:51` |
| Item 5.5 docs (A-3 omitted lock `path=`) | Satisfied | `lock-detectors.md:29-31`; changelog sentence |

**Gaps:** none.

---

## Positive Observations

- The confounded-probe paragraphs in `lock-detectors.md` explain each recorded
  run under the documented rule. They do not just delete the old reading, so
  the evidence trail survives the reversal.
- The option (a′) move-out keeps every rejected name in the hub with a
  conclusion that matches its argument. The node's intro says where each name
  lives.
- `hook.md`'s pinning sentences name what each test asserts and what it does
  not ("No test pins the wording beyond the `jq` name").

## Recommendations

- design.md is at 399 of its 400 lines. The next addition needs a further
  move-out (already on the carry list), not a reword.
