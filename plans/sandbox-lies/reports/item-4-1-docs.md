# Item 4.1 — docs preparation

Scope: `docs/references/` split, `config-lock` verdicts in full, the `mask`
wording under flag `true`, the `systemMessage` joiner. No code, no tests.

## 1. Split

Files, line counts after `rumdl fmt`:

- `docs/references/detectors.md` — 303 (was 397). Keeps the conventions, the
  corpus note, a stub for each lock detector, the three `phantom-*` entries, all
  five candidates, the translation map and "Not detectors".
- `docs/references/lock-detectors.md` — 142, new. `git-lock` and `config-lock`
  moved whole: matcher, probe, outcome table, flag policy, verdicts, corpus,
  live reproductions. Headings promoted to `##`, so anchors are `#git-lock` and
  `#config-lock`.
- `docs/design.md` — 400 (unchanged count).
- `docs/changelog.md` — 96.

Seam rationale. Need-time: the lock pair is the one cluster a reader works on
alone (Item 4.1 builds exactly these two verdicts against one probe), shares a
probe and outcome set, and has no dependency on the other entries beyond the
conventions paragraph, so it moved whole with no re-stitching. Headroom: the
growth planned for Items 4.2, 4.3, 5.1 and 6.1 (four candidates flipping to
shipped with possibly re-recorded corpus lines, `readonly-path`'s live
reproduction and verdict text) all lands in `detectors.md`, which now has 97
lines of room; the lock file has 258. Splitting candidates from shipped was
rejected: four candidates flip to shipped in Phase 4, so that seam would move
entries across files within days.

Each moved entry leaves a stub in `detectors.md` with its conclusion (what it
fires on, what the probe decides) and a link to its section. The
`detectors.md` opening states that the lock entries live in the node and to read
it before changing either detector. FR-7's "Ten detectors, in
references/detectors.md" stays true (all ten are catalogued there).

Links and citations fixed:

- `docs/design.md` FR-4, FR-5, NFR-1: the backticked citation
  `references/detectors.md` became `references/` where the claim (live
  reproductions, per-detector flag policy, per-detector corpus figures) now
  spans both files. Reflowed with no line added: 400 before and after.
- No inline link needed changing: every existing inline link targets
  `references/detectors.md`, which still exists and routes on. The link gate
  passes.
- Not changed, still accurate: `hooks/annotate.sh:62` (phantom flag policy),
  `tests/hook.bats:248` (Conventions), `tests/matchers.bats:46`,
  `tests/extract-fixtures.py:83`, `tests/corpus-eval.py:49` (candidates),
  `tests/verdicts.bats:83-84` (phantom verdict text). All of those still point
  at `detectors.md`.
- Out of scope, for Item 4.1's slices: the `lib/verdicts.sh` header comment
  says the verdict text comes from `docs/references/detectors.md`. Once the
  lock verdicts land there it should name `lock-detectors.md` too. The frozen
  runbook's "text from `detectors.md`" routes through the stub.
- Not done: a routing table in the repo `CLAUDE.md`, which the splitting rules
  also call for. `CLAUDE.md` was out of scope.

Changelog: one dated entry, `2026-09-25 — lock detectors split out; mask wording
flag-neutral`, in the file's prose style.

## 2. config-lock verdicts, character counts

Counted with Python `len()` on each agent paragraph as it appears in
`lock-detectors.md` (list item joined, human line cut at the final ` · `).
`N` placeholders count as one character each. Real values add a few (a
seven-digit pid adds 6; `bytes` and `age` of ten digits add 18). Every
paragraph stays under 400. The method reproduces the runbook's 426 for the old
`mask` wording with the leak clause plus the config-write clause.

| detector | outcome | chars | human line |
|---|---|---|---|
| git-lock | mask | 324 | `index.lock — sandbox mask, not a real lock` |
| git-lock | gone | 174 | `index.lock — cleared after failure` |
| git-lock | held | 58 | `index.lock — held by pid N` |
| git-lock | orphan | 174 | `index.lock — present, no holder` |
| git-lock | unknown | 120 | `index.lock — present, holder unknown` |
| config-lock | mask | 352 | `config.lock — sandbox mask, not a real lock` |
| config-lock | gone | 65 | `config.lock — cleared after failure` |
| config-lock | held | 58 | `config.lock — held by pid N` |
| config-lock | orphan | 174 | `config.lock — present, no holder` |
| config-lock | unknown | 120 | `config.lock — present, holder unknown` |

The config-lock paragraphs are git-lock's with the leak clause removed from
`mask` and `gone`. `mask` adds this sentence: "Run the `git config` or
`git remote` write unsandboxed, or through the `update-config` skill when the
target is `.claude/settings.json`." Before this change the git-lock `mask`
paragraph was 289 characters. `detect` over `lock-detectors.md`,
`detectors.md`, `design.md` and `changelog.md` prints nothing (exit 1).

## 3. `mask` under flag `true`: applied, flag-neutral

Applied to both detectors. No interface change.

Old wording: "The lock in this error is a sandbox artefact; no such file exists
outside the sandbox and the repository is healthy. Re-run the same command with
`dangerouslyDisableSandbox: true`." New wording (git-lock, before the leak
clause): "The lock in this error is a sandbox artefact and the repository is
healthy. Re-run the same command with `dangerouslyDisableSandbox: true`; if it
already ran that way, re-run it once no sandboxed command is running." Human
line: `<lock> — sandbox mask, not a real lock`, where it was
`<lock> — sandbox mask, no file exists`.

Rationale. The agent knows whether it set the flag, so a prose branch on its
own call needs no flag argument. Here is why the wording is true in each case
the probe reports `mask`:

- Flag false, path absent outside the sandbox (the common case). The call ran
  sandboxed, so the first act applies: re-run unsandboxed. Only the "no such
  file exists outside the sandbox" clause goes. "Sandbox artefact" and "the
  repository is healthy" still carry the don't-touch message.
- Flag true, character device. The branch applies: a mask visible to an
  unsandboxed process exists only while a sandboxed command runs (design.md,
  "Why the hook can see"), so the re-run waits for that. The branch uses the
  same condition the phantom verdicts already use.
- Flag false, character device (the mask is visible outside the sandbox). The
  first act re-runs unsandboxed. That fails again with flag true, and the
  second verdict's branch applies. It converges in one extra call and nothing
  in the text is false.

"Not a real lock" is true for both an absent path and a device node. "No file
exists" is not true for a device node. Every paragraph stays under 400
characters (324 and 352).

Residuals:

- If the live sandbox belongs to another session, the agent may not know when
  none is running.
- Under the same foreign-sandbox condition, a repeat failure that is still the
  mask would be misread by the git-lock leak clause. The clause is premised on
  the wait having held.
- The hook already had both residuals for flag false with a device.

Conflict with the frozen runbook, for the orchestrator. Item 4.1 slice 1
asserts `systemMessage` equals `index.lock — sandbox mask, no file exists`.
Transcribed from `lock-detectors.md`, it is now
`index.lock — sandbox mask, not a real lock`. Slice 1's other assertions still
hold against the new text: the context contains `Re-run the same command with`
and `GIT_INDEX_FILE`. Slice 7 names "the `mask` human line" without a literal.

## 4. systemMessage joiner

`command grep -rn systemMessage docs/` finds four lines: design.md FR-1, FR-6,
the Flow paragraph and D-7. None states a separator. Flow says "the human lines
[concatenate] into `systemMessage`". `detectors.md` and `lock-detectors.md` say
nothing about joining. So there was nothing to update, and nothing was added.

## Precommit

`direnv exec . just precommit`, foreground, final line:

```
precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests
```
