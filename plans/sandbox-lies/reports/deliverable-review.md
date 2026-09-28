# Deliverable Review: sandbox-lies

**Date:** 2026-09-28
**Methodology:** `docs/references/deliverable-review.md` (edify; absent from the
installed edify 0.3.0 cache, so the axis definitions were given to each
delegate inline from the skill body)

## Range and inputs

- **Range:** `e873bf4..HEAD` (`.git/build-baseline`, HEAD `2ade145`), as the
  task file names. `edify-review-range.sh plans/sandbox-lies/outline.md`
  printed `52e6dd8..HEAD`, the outline's Provenance base; that span adds the
  pre-build design authoring commits, which are the conformance baseline here,
  not deliverables.
- **Conformance baseline:** `plans/sandbox-lies/outline.md` (no `design.md` in
  the plan directory), with the living `docs/design.md` and its
  `docs/references/` nodes.
- **Excluded as known:** every item in `build-finish.md` §Carry-forward, and
  the fixes its §Review outcomes records, unless the current tree shows the fix
  wrong.
- **Layer 1:** three opus delegates (code; tests; prose + config), unnamed. The
  auto-mode classifier refused each one's report `Write` with no verdict: the
  session runs with `--plugin-dir .`, which marks every file in the checkout as
  sensitive. Each delegate returned its report inline. The findings are merged
  below and tagged **[L1-code]**, **[L1-tests]**, **[L1-prose]**. Findings from
  the main session's cross-cutting pass are tagged **[L2]**.
- **Spot verification in the main session:** L1-prose M-1 against the live
  settings reference (fetched 2026-09-28); L1-code M-1's documentation half;
  L1-tests M-1 (no hook case stubs a failing probe or verdict); L1-code m-4.

## Inventory

103 files, +11693 / −528 outside `plans/`, `tmp/` and handoff files.

| Type | Files | Lines (+) |
| --- | --- | --- |
| Code — hook and lib | `hooks/annotate.sh`, `lib/matchers.sh`, `lib/probes.sh`, `lib/probes-readonly{,-command,-facts}.sh`, `lib/verdicts.sh` | 1538 |
| Code — gates and tooling | `scripts/check-line-limits.sh`, `scripts/check-links.sh`, `scripts/lib/{strip-code.awk,tracked.sh}`, `scripts/run-bats.sh`, `tests/extract-fixtures.py`, `tests/corpus-eval.py`, `.bin/claude` | 878 |
| Test | 24 `tests/*.bats`, 6 `tests/helpers/*.bash` | 6788 |
| Test fixtures | 34 `fire-*`/`quiet-*`, 2 `payload-*.json` | 1077 |
| Agentic prose | `skills/sandbox-lies/SKILL.md` + 4 `references/` nodes | 490 |
| Human docs | `docs/design.md`, `docs/references/{detectors,hook,lock-detectors}.md`, `docs/changelog.md`, `README.md`, `BRIEF.md`, `CLAUDE.md` | 1118 |
| Configuration | `hooks/hooks.json`, `justfile`, `.envrc`, `.gitignore`, `.rumdl.toml`, `pyproject.toml`, `uv.lock`, `LICENSE`, `memory` pointer | 169 |

**Design conformance.** Every outline phase produced its deliverables. The
hook runs on both events (A-1). The nine shipping detectors match the verdict
functions one for one, and the verdict text matches `detectors.md` and
`lock-detectors.md` word for word (checked by L1-prose). The probe contract
(A-3, D-17) agrees across `annotate.sh`, `lib/probes*.sh`, `lib/verdicts.sh`
and `hook.md`. The self-quiet sweep and the line-cap and link gates are in
`precommit`. `just precommit` exited 0 with 251 bats passing and no skips (run
by L1-code and L1-tests). The unspecified deliverables all state why they
exist: the D-17 rework (Item 8.0), the `hook.md` and `lock-detectors.md` splits
forced by the line cap, `verdict-premises.bats`, `scripts/lib/`, and the rumdl
tooling in `pyproject.toml`/`uv.lock`.

## Critical Findings

None.

## Major Findings

1. **The skill's `excludedCommands` mechanism contradicts CC's documented
   semantics, and its re-probe cannot tell honoured from not honoured.**
   [L1-prose M-1, verified]
   - **Where:** `skills/sandbox-lies/SKILL.md:36-48` and `:77-80`;
     `references/excluded-commands.md:1-13`, `:39-58`, `:104-110`;
     `references/escapes-and-costs.md:22-26`; `references/masks-and-gates.md:20-22`.
     The same probe shape is in `docs/references/lock-detectors.md`.
   - **Axes:** functional correctness, determinism.
   - **Conflict:** the skill says "one matching segment unsandboxes the *whole*
     call", and that a `false && git status; <payload>` decoy frees the call.
     The current settings reference (§`sandbox.excludedCommands`, fetched
     2026-09-28) says entries apply "only when they cover every command in it".
     It lists shapes that stay sandboxed even when covered: a `cd` anywhere in
     the call, a subshell, a command substitution, a redirection other than a
     descriptor duplication, and a command name taken from a variable. Its
     syntax example is `docker *`, not `:*`.
   - **Confounded evidence:** the recorded "not honoured on CC 2.1.281" probe,
     `git --version && touch /tmp/…`, has an uncovered `touch` segment, so
     under the documented rule it stays sandboxed either way. The hub's
     "re-probe with the `/tmp` write first" prescribes the same shape.
     L1-prose's single-segment `git init -q /tmp/<name>` probe (CC 2.1.283)
     also ran sandboxed, so the "not honoured" conclusion survives. One
     question stays open: whether exclusions are ignored outright, or the
     legacy `git:*` pattern no longer matches.
   - **The cwd ranking rests on the old model.** It puts a trailing
     `cd <root>` ahead of a subshell because a subshell "misses an honoured
     `git:*` exclusion". Under the documented rule a `cd` anywhere forfeits it
     too.
   - **Impact:** on a CC that honours exclusions, an agent expects
     `cd sub && git …` or `git … > out` to run unsandboxed. It guards against
     a decoy escalation that no longer exists, and its re-probe reads "not
     honoured" forever.

2. **A missing `jq` disables the plugin permanently and silently, and nothing
   tells the user to install it.** [L1-code M-1; the documentation half is L2]
   - **Where:** `hooks/annotate.sh:43-59` (`parsed=$(jq …) || exit 0`) and
     `README.md` §Install.
   - **Axes:** error signaling, completeness.
   - **Evidence:** with `jq` off `PATH`, a payload that should fire
     `phantom-untracked` produced a `jq` command-not-found line on stderr,
     exit 0 and no output. CC shows neither reader a hook's stderr on exit 0.
   - **Why FR-3 does not cover it:** FR-3's silent exit fits a single-call
     failure. This one comes from the environment and repeats on every call.
   - **The docs:** D-12 and NFR-2 make `jq` a hard dependency, but the
     README's Install section never mentions it. The failure is silent to both
     the agent and the user, the class the standing test rules say must be
     fixed. How to surface it (install note, `SessionStart` check, one-time
     `systemMessage`) is a design call.

3. **FR-3's runtime-failure path has no test.** [L1-tests M-1, verified]
   - **Where:** `hooks/annotate.sh:111`, `:122` and `:124` (`|| exit 0` after
     a probe or a verdict).
   - **Axes:** coverage, vacuity.
   - **Gap:** no hook case stubs a probe or verdict that exits non-zero.
     Changing all three to `|| true` left the 47 hook tests green.
   - **Impact:** a probe that prints `writable` and then dies emits a verdict
     built on partial facts where the spec requires silence, and nothing goes
     red.

4. **The NFR-4 "writes nothing" pins never reach a probe through the hook, nor
   `probe_readonly_path` at all.** [L1-tests M-2]
   - **Where:** `tests/hook.bats:283-313` uses the gitadd fixture, which has no
     probe. `tests/probes-edges.bats:265` covers `probe_git_lock` only.
   - **Axes:** vacuity, coverage.
   - **Evidence:** a `mktemp` added inside the hook's probe branch left 105
     tests green; the same added in `_readonly_print_facts` left 122 green.
   - **Impact:** A-8 and NFR-4 exist because the hook runs with `$TMPDIR`
     unset. A buffer added on the probe path writes to `/tmp` in production
     and the suite passes.

5. **Two matcher sub-shapes that `detectors.md` specifies have no fire case.**
   [L1-tests M-3]
   - **`tmpdir-unset` in GNU curly quotes** (`lib/matchers.sh:179`): dropping
     the curly quotes from the alternation left every matcher and hook suite
     green. GNU tools print them under a UTF-8 locale, which is the usual
     Linux case.
   - **`phantom-untracked` with leading whitespace and a trailing slash**
     (`lib/matchers.sh:115`): dropping the whitespace alternative left 97
     tests green. Long-format `git status` tab-indents untracked names.
   - **Axes:** coverage, specificity.

6. **Enumerated members of the `readonly-path` fact table are unpinned.**
   [L1-tests M-4]
   - **Unpinned:**
     - `merge=1` for `switch`, `rebase` and `cherry-pick`;
     - `target=` after `switch`;
     - the `*.out` and `*.err` command-output names;
     - the `sort -o`/`--output` and `awk -i`/`--include` writer exclusions.
       These were 8.0/3 code-review fixes that 8.0/4 did not pin.
   - **Axes:** coverage, vacuity.
   - **Evidence:** cutting the subcommand case to `merge | pull | checkout`
     left 85 tests green; removing the extensions and exclusions left 56
     green.
   - **Impact:** an interrupted `git switch` loses its restore clause, and
     `sort -o out.log x` is read as a reader, so the verdict gives the wrong
     re-run act.

## Minor Findings

### Code correctness and robustness

- **Quadratic tokenizer** [L1-code m-1]: `lib/probes-readonly-command.sh:44-102`
  grows each word by `word="$word$ch"`, and the comment at `:26-28` claims
  linear cost. A 16384-character word takes 4.5 s alone, and the whole hook
  took 5.2 s on a 40 KB `git merge` command. The cap keeps this under the
  10 s timeout with only half the budget spare, and bash 3.2 on macOS is
  unmeasured. A timeout loses every verdict for that call.
- **`readfile=` takes words that are not input files** [L1-code m-2]:
  `lib/probes-readonly-command.sh:168-173`. An `--include=*.log` option, uniq's
  output operand, and a sed script ending in `.log` each become the file in
  "re-run the command that wrote `<x>`". No `-` prefix exclusion.
- **`match=` names are top-relative but printed bare** [L1-code m-3]:
  `lib/probes-readonly-facts.sh:243` and `lib/verdicts.sh:196`. From a
  subdirectory cwd, the restore act names paths that `git restore` would
  resolve against the subdirectory. Distinct from the carry-forward `path=`
  item: these names come from `diff-index`.
- **`tests/corpus-eval.py` is not idempotent** [L1-code m-8]. A re-extract
  keeps old survivors and the documented loop appends to `verdicts.tsv`, so
  a second pass double-counts, and a shrinking re-extract can raise
  `KeyError`. The comment at `:48-51` wrongly claims the prefilter is broader
  than every matcher: it misses `cr--r--r--`.
- **`tests/extract-fixtures.py` robustness** [L1-code m-9]. A null
  `timestamp` (`:159`) or a non-dict `input` (`:164`) crashes the cutter, and
  the all-projects branch of `pick()` (`:180-182`, `:228`) is unreachable.
- **Line-cap gate coverage** [L1-code m-7]: `scripts/check-line-limits.sh:67`
  never checks `.awk`, the extensionless `.bin/claude`, or `.json`. None is
  over its cap today.

### Stale comments and help text

- `lib/matchers.sh:2` still calls the file the detector pilot's candidate
  matchers. [L1-code m-4, L2]
- `lib/matchers.sh:90-92` claims `CLAUDE_PROJECT_DIR` anchoring closes the
  `/dev` listing false positive. No code reads the variable, and
  `detectors.md` accepts it as a residual. [L1-code m-4, verified]
- `lib/probes.sh:3-6` gives the probe contract as `$1` and `$2`, but the hook
  passes `tool_input.command` as `$3`. [L1-code m-4]
- `just --list` describes `precommit` by the last line of its comment block,
  a sentence fragment. [L2]

### Docs against code or behaviour

- **`mv` target form** [L1-code m-5]: `detectors.md` says `mv`'s `to` names
  the target, but only the inter-device form does, deliberately
  (`lib/probes-readonly.sh:131`, pinned in `probes-readonly.bats`). Fix the
  doc.
- **NFR-4's read scope** [L1-code m-6] says the hook reads only the call's
  repository. The readonly probe reads the refused path's repository (a
  sibling worktree in the recorded reproduction), and the lock probes stat
  paths taken from the error text.
- **Payload `cwd` and a persisted `cd`** [L2]: `docs/references/detectors.md:18-20`
  says the payload `cwd` was the session directory and that where "a `cd`
  inside the call" leaves it is unrecorded. Since `2ade145` the skill states
  that a top-level `cd` persists across calls. Whether the payload `cwd`
  follows that persisted directory decides where the lock and readonly
  probes resolve relative paths, and no node says it is open.
- **Main session only** [L1-prose m-1]: "the Bash tool keeps a `cd` between
  calls" (`SKILL.md:73-75`, `masks-and-gates.md:15-16`) holds only in the
  main session. A subagent's cwd resets per call, per `review-skill-fixes.md`
  §m7.
- **Batching contradiction** [L1-prose m-2]: `escapes-and-costs.md:51-55`
  says both to keep an escaped command in its own call and that batching
  still beats splitting, and the hub gives only the first. "One model call …
  with no generation" is an ungrounded mechanism claim: the classifier
  generates a verdict.
- **Auto-allow exceptions** [L1-prose m-3]: `escapes-and-costs.md:41-44`
  omits the auto-mode exceptions the sandboxing doc lists (per-command allowed
  domains, server-side review of sandboxed commands).
- **Strict mode** [L1-prose m-4]: `escapes-and-costs.md:10-15` and
  `SKILL.md:58-60` say to check for strict mode without naming the key,
  `sandbox.allowUnsandboxedCommands: false`, shown in `/sandbox` Overrides
  as Strict sandbox mode.
- **Platform scope** [L1-prose m-5]: the discriminators and
  `readonly-path` key on the Linux (bubblewrap) error. Neither README nor
  design says the symptoms and figures were recorded on Linux, while NFR-2
  names macOS. The macOS behaviour was not verified.
- **NFR-1 re-measurement** [L1-prose m-6]: NFR-1 is Done as re-measured with
  the shipped matchers, but `detectors.md:128-129` still credits "a scratch
  shell matcher". The re-measurement is in `item-4-2-s1-code-review.md` and
  `item-4-3-s1-green.md`.
- **Two hit counts** [L1-prose m-7]: `phantom-untracked` gives 41 hits at
  ≥2 (`detectors.md:89`) and 57 (`:101`, D-5), apparently from two corpora
  with neither named. Predates the build.
- **design.md leftovers** [L1-prose m-8]: D-3 says "eleven separate hooks"
  (`:234`), from before `tmp-full` was dropped, and NFR-5 comes before NFR-4.
- **FR-8 reproducibility** [L1-tests, clean notes]: re-running the cutter
  reproduces 25 of 34 fixtures byte for byte. Two undated entries pick other
  calls, as documented, and seven are not found in today's corpus, cause not
  established. FR-8's "reproducible from the script" needs a qualifier.
- **CLAUDE.md wording** [L1-prose m-10]: `CLAUDE.md:11` reads as if the three
  pilot files are scanned; they are exempted.
- **Unchosen host** [L2]: README §Install clones
  `github.com/ddaanet/sandbox-lies`, and `plugin.json` names it as homepage
  and repository. The plugin has no remote and the host is an open decision,
  so both presuppose its answer. `plugin.json` predates the range.

### Tests

- **Flag pairing gaps** [L1-tests m-1]: five fire fixtures never reach the
  hook, two reach it with the flag absent only, and no case feeds a
  non-boolean flag, although FR-5 and the outline pair every fixture with
  both values.
- **Exit-2 paths untested** [L1-tests m-2]: `scripts/lib/tracked.sh:66-69`
  (a `git ls-files` failure; `|| true` there stays green) and
  `check-line-limits.sh:44-47` (unreadable file).
- **`shim.bats` has no stubbed case** [L1-tests m-3], although `.bin/claude`
  guards a BSD `paste` divergence that nothing enforces.
- **Host git config** [L1-tests m-4]: no suite isolates git config.
  `check-links-edges.bats:250-271` commits without disabling signing, and
  several real-probe cases assume no repository above `$BATS_TEST_TMPDIR`
  without asserting it. Each fails loudly rather than passing wrongly.
- **Negative-only assertions** [L1-tests m-5]: `probes-config.bats:96-101` and
  `:131-151` assert only what the outcome is not.
- **Linux-only suite** [L1-tests m-6]: `probes.bats:302` and the stat stub use
  GNU `stat -c`, and `probes.bats:68` needs `C.UTF-8`. The suite itself
  cannot run on a Mac.

## Gap Analysis

| Outline IN item | Status |
| --- | --- |
| Repo init completion | Covered |
| Pilot promotion: suite, fixtures, cutter, layer-2 harness | Covered; tooling robustness: Minor (corpus-eval, extract-fixtures) |
| Hook on both events, `lib/verdicts.sh`, hook/verdict/docs suites | Covered; test gaps Major 3, 4, 5 |
| Lock probes and live reproductions | Covered; git-lock `mask` proved by composition (gate 2 decision) |
| Replay, measurement, candidates under D-15, readonly-path probe | Covered; `zellij-socket` stays a candidate; test gap Major 6 |
| `sandbox-lies` skill | Covered; Major 1 |
| `README.md`, `LICENSE`, `CLAUDE.md` | Covered; Major 2 (jq prerequisite), Minor host and wording |
| Per-section retirement; Phase 6 final deletion, index lines, links, `shared-claude.md` bullet | Partial by my human partner's decision (Item 8.2, carry-forward); bullet amended |
| Line-cap and link gates | Covered; Minor gate-coverage and exit-2 gaps |
| Design amendments A-1 to A-8 | Covered (in `design.md` as D-13, D-14 and the FR/NFR text) |
| Verification standard: each assertion class fault-injected | Not met for the classes in Majors 3–6 (mutations survive) |

## Summary

| Severity | Count |
| --- | --- |
| Critical | 0 |
| Major | 6 |
| Minor | 30 |

Minor count by group: code 6, stale comments and help text 4, docs 14, tests
6. The stale `lib/matchers.sh` header, raised by both L1-code and L2, is
counted once. Four of the six Majors are verification gaps (Majors 3–6), one
is an unsurfaced environment failure (Major 2), and one is a behavioural claim
in the skill that contradicts the documented mechanism (Major 1).
