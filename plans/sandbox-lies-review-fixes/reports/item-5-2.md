# Item 5.2 — docs: blocked on the `docs/design.md` line cap

Status: **blocked, nothing staged or committed.** Every bullet of the item is
edited in the working tree, `just format-docs` run. After the item's D-8
move-out, `docs/design.md` is at **417 lines** (cap 400), so per the item I
stopped: a further move-out is a design call, and trimming prose to fit is not
allowed. `just precommit` exits 1 on `oversized-file: docs/design.md: 417 lines
> 400` alone. The gate stops there, so the rest was run by hand: `scripts/check-links.sh` exit 0; `bats
tests/docs.bats` 1/1 ok; the new untracked node `docs/references/sandbox-state.md` piped through `lib/matchers.sh` is quiet (exit 1). The bats suites beyond `docs.bats`
were not run; this item touches no code or tests.

## Line counts (`wc -l`, after `just format-docs`)

| file | before | after | cap |
| --- | ---: | ---: | ---: |
| `docs/design.md` | 398 | 422 before the D-8 move, 417 after | 400 |
| `docs/references/detectors.md` | 271 | 286 | 400 |
| `docs/references/lock-detectors.md` | 155 | 168 | 400 |
| `docs/references/readonly-path.md` | 184 | 186 | 400 |
| `docs/references/hook.md` | 116 | 117 | 400 |
| `docs/references/sandbox-state.md` (new) | — | 16 | 400 |
| `README.md` | 73 | 82 | 400 |
| `CLAUDE.md` | 24 | 25 | 400 |
| `docs/changelog.md` | 242 | 269 | 400 |

The D-8 move-out triggered: D-8's paragraph went verbatim, with its exclusion
qualifier, to the new `docs/references/sandbox-state.md`, and the hub keeps a
four-line stub linking it. That saved 5 lines; the item's additions to
`design.md` came to 24.

Where the 24 lines came from (after reflow): platform paragraph +4; FR-1
(`check-jq.sh`, pinned-by) +3; FR-4 pinned-by +2; FR-8 qualifier +2; FR-9 +1;
NFR-3 (`SessionStart` timeout) +1; NFR-4 (read scope, pinned-by) +4; the
Architecture block +2; D-3 0; D-5 +1; D-12 +3; Rejected alternatives +1; L-2 0.

Options for my human partner (none taken):

1. Move another argument out, as D-1, D-6, D-13 and D-14 were (D-17's argument
   is the largest candidate, about 10 lines; D-15's about 7).
2. Move the FR/NFR "pinned by" lists to a node.
3. Raise `design.md`'s cap.

## Per file

### `docs/references/lock-detectors.md`

- `git-lock` "Live reproduction owed: `mask`": "the `git:*` exclusion unhonoured
  on CC 2.1.281" replaced. Both calls ran sandboxed by their shape (an `sh`
  head; an entry applies only when it covers every command). The 2.281
  `git --version && touch /tmp/…` probe is recorded as confounded (its uncovered
  `touch`), still showing that call sandboxed. The 2.288 (`git:*`) and 2.289
  (`git *`) `git init -q /tmp/<name>` probes are recorded as confounded by the
  absolute-path rule. The CC 2.1.289 observation is the bare covered
  `git status --porcelain` with no masks against `true && git status` with
  masks, and that bare `git status` is named as the re-probe.
- `config-lock` "Live reproduction (2026-09-25): `mask`", last sentence: the
  four shapes (an `sh -c` head, `sh <script>`, `cd <root> && git config`,
  `git -C <root> config`) each stay sandboxed under the every-command rule, so
  no exclusion has to have been ignored. The `/tmp` write test it cited is
  marked confounded.
- The config-lock `Corpus.` line has no exclusion wording and was left alone.

### `docs/references/detectors.md`

- Conventions: added that the main-session Bash tool keeps a top-level `cd` (CC
  2.1.281), and that whether the payload `cwd` follows it is not recorded. Also
  that the lock probes and `readonly-path`'s probe resolve relative paths
  against that `cwd`.
- Candidates intro: "a scratch shell matcher as arbiter" removed. Each shipped
  candidate's figure is now said to have been re-measured over the same
  extraction with its shipped matcher, none moved, citing both reports by full
  path.
- `phantom-untracked`: the threshold sentence now names the 41/40 corpus (the
  layer-1 replay, 2026-09-02, 21,272 pairs) and says its Python form missed
  tab-indented names, so 41 undercounts. `Corpus.` names the 57's corpus (the
  21,453-pair 2026-09-03 eval in the file's Corpus paragraph, shell matcher as
  arbiter).
- Translation map: the memory section keeps its name ("whole-call semantics"),
  since it identifies the section. Its "lands in" cell reads "skill, corrected:
  an entry frees only a call whose every command it covers".
- Not detectors: the bullet now reads "Which calls an `excludedCommands` entry
  unsandboxes …", with the every-command rule and nothing recording it.

### `docs/references/readonly-path.md`

- Probe paragraph: only `mv`'s inter-device form names the target after `to`.
  `mv`'s other two-path messages give the first quoted path, the source. Checked
  against `lib/probes-readonly.sh` `_probe_readonly_path_from_line` (the
  inter-device `sed` expression is tried first, then the generic first quoted
  segment) and `tests/probes-readonly.bats` ("mv target path is extracted, not
  the source"; "first quoted path on the line", whose comment names mv's
  `cannot move` form). The `nopath` row is untouched (Item 5.4).

### `docs/references/hook.md`

- D-1 paragraph: the pilot's "already unsandboxed by the `claude:*` exclusion"
  is now what the pilot read the configuration as implying, not an observed run,
  and an entry frees only a fully covered call. Registration and the jq section
  were already current from Item 4.3 and were not changed.

### `docs/design.md`

- NFR-4 read scope: it now reads what the result names, the repository holding a
  refused path (possibly a sibling worktree, else the payload `cwd`'s) and the
  lock paths from the error text. Pinned-by adds `tests/hook-writes.bats`,
  `tests/probes-edges.bats` (its "probe writes nothing" and "readonly-path probe
  writes nothing") and `tests/check-jq.bats`.
- Platform statement: a paragraph under "What this is". Linux (bubblewrap)
  recorded; NFR-2 portability covers the tools; the macOS sandbox is unverified.
- D-3: "eleven" became "nine separate hooks, one per shipped detector". Nine
  verified from `lib/matchers.sh` (nine `match_*`) and `lib/verdicts.sh` (nine
  `verdict_*`).
- NFR-4 moved ahead of NFR-5.
- FR-8: qualified with 25 of 34 at the 2026-09-28 review, two undated entries
  picking other calls, seven not found, cause not established.
- D-5: the 207 is attributed to the layer-1 replay (2026-09-02). The 57 is the
  2026-09-03 corpus that `references/detectors.md` names.
- Exclusion wording: FR-9 ("Which calls an `excludedCommands` entry unsandboxes
  (only one whose every command it covers)"); D-8 (now in the new node);
  Rejected alternatives (`git *` needs no hook and approves nothing, frees only
  a fully covered call, `-C` and absolute-path git stay sandboxed); L-2.
- FR-1: `hooks/check-jq.sh` on `SessionStart` named as a second script that
  annotates nothing. Pinned-by adds `tests/hook.bats`'s three event keys and
  `tests/check-jq.bats`.
- Architecture: the `hooks.json` line adds
  `SessionStart · no matcher · timeout 10`, and a `hooks/check-jq.sh` line is
  added. NFR-3 also says the `SessionStart` check has the 10 s timeout (runbook
  Item 4.3's list revision).
- D-12: says the check exists and points to `references/hook.md`.
- Pinned-by from this job's new test files: FR-1 (`check-jq.bats`), FR-4
  (`probes-readonly-members.bats`, `probes-readonly-operands.bats`,
  `hook-writes.bats`), NFR-4 (`hook-writes.bats`, `check-jq.bats`).
  `probes-readonly-operands.bats` is not in the item's list of three, but it is
  a new file of this job (Item 4.1/2) and extends FR-4's pinned-by, so it is
  named too.
- D-8 move-out: done, as above; it does not reach 400.

### `README.md`

- §Install: `jq` on `PATH` is a prerequisite; without it the hook stays silent,
  and a `SessionStart` check tells the user and the agent. Also the platform
  statement (Linux recorded, macOS unverified). The clone URL is unchanged.
- §The skill: "which calls `excludedCommands` really unsandboxes" replaced by
  "that an `excludedCommands` entry unsandboxes only a call whose every command
  it covers".

### `CLAUDE.md`

- The self-quiet bullet now names `tests/fixtures/` and the three pilot files as
  two exemptions from the sweep. Checked against `tests/docs.bats` (`EXEMPT`
  array; `tests/fixtures/*` skipped).

### `docs/changelog.md`

- One entry, "2026-10-05 — review fixes: exclusions, the `jq` notice, readonly
  facts". It covers the D1 rule and skill changes, the confounded probes, the
  `SessionStart` check and README prerequisite, absolute `match=`, the
  `readfile=` operand rule, the doc corrections, and one clause on the test
  pins. Item 5.4 adds its own line.

## Figures and their sources

- **34 fixtures**: `git ls-files tests/fixtures` filtered to `fire-*`/`quiet-*`
  gives 34.
- **25 of 34 byte for byte, two undated entries picking other calls, seven not
  found**: `plans/sandbox-lies/reports/deliverable-review.md` (Docs against
  code, "FR-8 reproducibility", L1-tests). That is the only source found. `rg`
  over `plans/sandbox-lies/` turned up no other report. The cutter was not
  re-run here. "Undated" agrees with `tests/extract-fixtures.py`, whose
  docstring says an entry with no day can pick a different call, and whose SPEC
  holds entries with day `None`.
- **41 (≥2) and 40 (≥5)**: `plans/2026-09-02-sandbox-detector-replay-results.md`
  (layer 1, 21,272 Bash calls, 1,678 JSONL; table row B′ and §B).
- **57, 56 true**: `plans/2026-09-03-sandbox-matcher-corpus-eval.md` (21,453
  pairs, 1,682 JSONL; §2 and §4). Its §3 explains 41 against 57: layer 1's
  `\s{4,}` missed the tab-indented block, "Layer 1's 41 is an undercount".
- **207**: `plans/2026-09-02-sandbox-detector-replay-results.md` §B (layer 1).
- **21,272 pairs (layer 1)**: same file, §Corpus.
- **Hook count, nine**: `lib/matchers.sh` and `lib/verdicts.sh` (nine of each);
  README "Nine ship".
- **Candidates re-measurement**:
  - `plans/sandbox-lies/reports/item-4-2-s1-code-review.md` Major 2:
    `tmpdir-unset` 195/13 identical to the arbiter set, and the `resume-lost`
    and `seccomp-init` sets unchanged.
  - `plans/sandbox-lies/reports/item-4-3-s1-green.md` §NFR-1: `readonly-path`
    gives the identical 162 files.
  - The 55,896 pairs and the shared extraction come from
    `plans/sandbox-lies/reports/item-3-2.md:48` and `item-4-2-s1-green.md:81`.
- **CC 2.1.289 probes and the confounded 2.281/2.288/2.289 runs**:
  - `plans/sandbox-lies-review-fixes/reports/item-5-1.md` probes 1–4.
  - The outline's D1 and its revision bullet.
  - `skills/sandbox-lies/references/excluded-commands.md` §Observed on CC
    2.1.289 and §Earlier probes. The doc wording follows it.

## Addendum (orchestrator, after the gate)

My human partner chose option (a′) on 2026-10-05: each rejected alternative's
argument moved verbatim from `docs/design.md` §Rejected alternatives to the new
node `docs/references/rejected-alternatives.md`. design.md keeps every name with
a one-line conclusion: a *Rejected* line under D-9 for the
`craft`/`prohibitions` home and the `sandbox-gotchas`/`sandbox-effects` names,
and a compact §Rejected alternatives list with a pointer to the node for the
other six. No other section was reworded. After `just format-docs`,
`docs/design.md` is 399 lines and the node 41.
