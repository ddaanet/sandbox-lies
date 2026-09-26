# Build — Phase 4 (lock verdicts and shipped candidates)

Delegate: build-phase-4. Runbook: `plans/sandbox-lies/runbook.md` Phase 4.

## Commits

- 📝 Item 4.1 — detectors.md split; config-lock verdicts in full
- 📝 Item 4.1 — list revision: flag-neutral mask line; hook-locks.bats; joiner
- ✨ Item 4.1/1 — mask outcome through the hook
- 🐛 Item 4.1/1 — code-review fixes
- ✨ Item 4.1/2 — held, orphan and unknown interpolate probe values (slices 2-3)
- ♻️ Item 4.1/2 — code-review fixes
- ✨ Item 4.1/4 — probe arguments, config-lock mask, piped success payload
  (slices 4-6)
- 🐛 Item 4.1/4 — code-review fixes: config.lock behind this error
- ✅ Item 4.1/7 — lock fixture sweep, no probe without a verdict, probe stdin
  (slices 7-8)
- ✨ Item 4.1/9 — cap skips and continues; human lines joined by semicolon
- 📝 Phase 4 build report — Item 4.1 progress
- 🐛 Item 4.1/7 — stdin test local no longer named stderr (bats run unsets it)
- ✨ Item 4.2/1 — tmpdir-unset, resume-lost, seccomp-init ship (slices 1-2)
- 🐛 Item 4.2/1 — code-review fixes: tmpdir-unset discriminator, corpus line
- 📝 Item 4.3 — list revision: command-output reads go to Item 6.1; 4.2 test
  gaps
- ✨ Item 4.3/1 — readonly-path matcher; 4.2 discriminator gaps pinned
- 🐛 Item 4.3/1 — code-review fixes: Python form, replay records
- ✨ Item 4.3/2 — readonly-path probe; hook silent without a verdict (slices
  2-5)
- 🐛 Item 4.3/2 — code-review fixes: nopath under set -e, locale, trailing
  slash, dangling link

## Item 4.1 — lock verdicts

Done except its memory retirement and status flips (see Deviations).

- **Docs prep (opus, `item-4-1-docs.md`).** `docs/references/detectors.md`
  split: `git-lock` and `config-lock` moved whole to
  `docs/references/lock-detectors.md` (142 lines); `detectors.md` 397 → 303,
  keeping a stub per lock detector. Changelog entry recorded. The config-lock
  verdicts are written out in full (no `GIT_INDEX_FILE` clause).
- **Mask wording under flag `true` (the carried check).** Settled flag-neutral
  with no interface change: "…is a sandbox artefact and the repository is
  healthy. Re-run the same command with `dangerouslyDisableSandbox: true`; if it
  already ran that way, re-run it once no sandboxed command is running." The
  human line became `<lock> — sandbox mask, not a real lock` (was
  `no file exists`, false for a character device). Runbook slice 1 revised to
  match.
- **Missing `bytes=`/`age=`/`pid=`.** An absent key drops its clause; nothing
  interpolates empty (slices 2-3, pinned in `verdicts.bats` and
  `hook-locks.bats`, both orders and one-of-two cases).
- **Joiner.** Human lines join with `; ` (slice 9).
- **Hook robustness fixes from slice 1's code review:** a cwd containing a
  newline corrupted the event/flag/cwd/text split; a non-object `tool_input`
  dropped the whole payload; an outcome with no text left a trailing separator.
- **config-lock mask paragraph** opens ``The `config.lock` behind this error``
  (slice 5 asserts `config.lock` in the context; "in this error" was untrue,
  since git names the config file, not the lock).
- Tests: `tests/hook-locks.bats` (new, 382 lines), `tests/verdicts.bats`,
  `tests/hook-cap.bats`.

List revisions: slice 1 (human line, test file), slice 9 (joiner). Otherwise
none.

## Item 4.2 — verdict-only candidates

Done for `tmpdir-unset`, `resume-lost`, `seccomp-init` (matchers, verdicts, flag
policies in the hook; `tests/hook-candidates.bats` new, with its BSD case).
`zellij-socket` skipped: stays a candidate (zero hits), no change.

- Corpus re-measured with the shipped matchers (NFR-1): `resume-lost` and
  `seccomp-init` unchanged; `tmpdir-unset` moved (16 flagged hits, all true,
  none self-reference) and its `Corpus.` line was re-recorded, then corrected by
  the code review.
- The code review found `match_tmpdir_unset` both missing the canonical bare
  shape and looser than the recorded discriminator; fixed. Its three deferred
  test gaps were pinned in Item 4.3 slice 1's dispatch (a corpus-cut fixture
  `fire-tmpdir-unset-bash-bare`, quiet cases for the quote-free-words rule, the
  root slash and the line-start anchors).
- GREEN stopped on a failing Item 4.1 test
  (`probe reads the result text on stdin`): its local variable named `stderr`
  was unset by bats' `run`. The orchestrator renamed it and committed; why it
  passed at its own commit was not established.
- Memory retirement deferred (see Open gate).

## Item 4.3 — readonly-path matcher and probe

Done. `match_readonly_path` implements the recorded discriminator (both line
forms, EROFS and EBUSY; a new cut fixture `fire-readonly-path-git-busy` pins
EBUSY); `probe_readonly_path` per its interface, in `tests/probes-readonly.bats`
(new); the hook stays silent on the name (no verdict) and never runs the probe.
Corpus re-measured with the shipped matcher: unchanged, line untouched.

- **List revision (my human partner's command-output-read rule).** Neither the
  matcher nor the probe exposes the read: the file read is named only in the
  command, which FR-2 and the probe contract never read, and the refusal line is
  identical to a live one. Item 6.1's verdict carries the rule as a conditional
  clause in the `writable` and `nopath` paragraphs. Recorded in the runbook
  under Item 4.3.
- **Relative quoted path** (the Python fixture's `hooks/hooks.json`) joins onto
  the payload `cwd` plainly, with no walk to the nearest `.git` as the lock
  probes do: a test-review decision, overridable at one fixture line.
- Code review fixes: `nopath` aborted under a `set -e` caller; the matcher fired
  while the probe read no path under a UTF-8 locale with an invalid byte; an
  absent path with a trailing slash tested itself; a dangling symlink always
  read `readonly`. Also fixed: `tests/corpus-eval.py`'s documented replay loop
  wrote records its `aggregate` could not parse when one text fired several
  matchers.

## Retirement and status flips (prepared, uncommitted — Open gate)

Report `phase-4-retirement.md`. Memory: the `.git/index.lock` section (with its
`.git/config.lock` paragraph), cost 1 of `Leaving the sandbox` (instability
paragraph kept), the `--resume` section (eval-harness consequence kept under
"Multi-turn `claude` flows must run unsandboxed"), and the sandbox-setup
section; description, symptom table and both index lines updated. The
`tests/matchers.bats` partial-quote case deleted. design.md status flips for
FR-3 (Done), FR-4, FR-5, FR-6, FR-7, FR-10, NFR-1. **design.md split:** Flow,
"Why the hook can see" and Paths moved to `docs/references/hook.md` (new);
design.md 395 lines; the Architecture-map `scripts/check-*.sh` line restored;
changelog entry added. `just precommit` passes with all of it uncommitted (181
tests).

## Deviations

- **Slices batched.** Item 4.1 ran as five RED/review/GREEN/review cycles, not
  nine: {1}, {2,3}, {4,5,6}, {7,8}, {9}. Batching by shared SUT and fixture; RED
  and GREEN stayed separate dispatches. Commit subjects carry the first slice
  number and name the range.
- **GREEN in session** for {7,8} (no implementation change: all mutation proven)
  and {9} (a one-line joiner change). Code review for those two: none dispatched
  ({7,8} changed no implementation) / self-review of the one-line diff ({9}).
- **Dispatches unnamed.** Teammates cannot name spawned agents; report paths
  follow the naming scheme regardless.
- **Recall at pre-work.** The orchestrator read the recall artifact and
  delegated reading its entries and skills to each dispatch (a shared context
  file, `.git/phase4-dispatch.md`, lists them), to stay inside the context
  budget.
- **Item 4.1's memory retirement and status flips deferred** from its final
  slice commit to one retirement commit after Item 4.3, batched with Item 4.2's,
  because every memory commit passes the gitlore approval gate: one approval
  instead of two.
- **Code review of Item 4.3 slice 1 edited `tests/corpus-eval.py`**, a tool
  outside the slice's file list, to fix the replay-record defect.

## Review findings worth my human partner's attention

- The flag-neutral `mask` wording and the `not a real lock` human line (Item 4.1
  docs prep): a prose branch on the agent's own flag stands in for a sixth
  outcome or a flag argument. Residual: when the live sandbox belongs to another
  session, the agent may not know when none is running.
- The relative-path decision for `probe_readonly_path` (above).
- `memory/ddaanet/git-add-untracked-deletion.md` still cites
  `[[sandbox-effects]]` for a stranded `index.lock`, content that has just left
  the file; the link still resolves and Item 8.2 rewrites it.

## For the Finish run summary

- Slices batched per item (Deviations); two GREENs run in session.
- List revisions: 4.1 slice 1 (human line, test file), 4.1 slice 9 (joiner), 4.3
  (command-output reads to 6.1; 4.2 gaps folded in). Otherwise none.
- Commit-msg hook: a raw emoji subject not in its map (✏️) is refused; use a
  conventional prefix.

## Memory gate — closed

Approved by my human partner with an extended summary (two further memory edits
by the main session: the sandbox-effects exclusion baseline, and the
cc-nested-subagent-spawning context-cap bullet). Committed as "Phase 4 — lock
and candidate memory retired; statuses flipped; design.md split".

## Resume

Superseded: the boundary below ran from this block; resume from `## Phase 4
boundary` instead.

Resume /build at the Phase 4 boundary of
/Users/david/code/sandbox-lies/plans/sandbox-lies/runbook.md. Items 4.1-4.3 and
the deferred retirement are committed; the tree is clean (masks aside). Last
commit: "Phase 4 — lock and candidate memory retired; statuses flipped;
design.md split". Build baseline: .git/build-baseline. verify-step:
/Users/david/.claude/plugins/cache/ddaanet/edify/0.3.0/skills/build/scripts/verify-step.sh
(run unsandboxed). Shared dispatch context: .git/phase4-dispatch.md.

Next: Read the build skill's `references/phase-boundary.md` and follow it —
dispatch `phase-4-corrector` over the Phase 4 diff, commit its report and fixes,
then write the Phase 5 resume block into this report and commit. The corrector
carries two extra items, both approved by my human partner:

1. `docs/references/detectors.md`'s Item 3.1 notes argue from masks that every
   git call ran sandboxed (delegate session and main session). Mask evidence is
   one-directional: masks are visible from every process while any sandboxed
   command runs, so a mask proves nothing about the call that saw it. Keep the
   conclusion; replace the evidence with the mask-free test: in the main session
   on 2026-09-26, `git --version && touch /tmp/sbx-probe-git` failed with the
   read-only error while the same touch with `dangerouslyDisableSandbox`
   succeeded (CC 2.1.283).
2. `tmpdir-unset` caveat: on CC 2.1.283 an unsandboxed call's `$TMPDIR` is
   `/tmp`, not unset (observed 2026-09-26), so the collapsed-to-root failure may
   not occur on current CC; its corpus hits predate that. Record it in the
   `tmpdir-unset` entry, and make sure the Item 4.2 verdict (lib/verdicts.sh,
   its transcription in tests/verdicts.bats, and detectors.md) does not claim
   the variable is always unset outside the sandbox.

Carry into Phase 5 and beyond: Item 6.1's `readonly-path` verdict carries the
command-output-read clause (runbook Item 4.3 list revision);
`docs/references/lock-detectors.md` and `docs/references/hook.md` are new nodes;
`tests/hook-locks.bats` is at ~382 lines. Deviations for the Finish run summary
are listed above.

## Context usage

About 185k tokens of this delegate's own context at the gate: a resumed delegate
should be fresh for the Phase 4 boundary if the relay is slow.

## Phase 4 boundary

Run by a fresh delegate from the `## Resume` block above. Entry verify-step:
`CLEAN` (bats 181 passed; precommit recap `plugin.json, hooks.json, shellcheck,
bash -n, rumdl, line limits, links, tests`).

### Corrector verdict and fixes

`phase-4-corrector` (opus, report `phase-4-corrector.md`) over
`git diff e4cc0d3..HEAD`: **Ready**, no critical finding, no UNFIXABLE.
Committed with its fixes as "Phase 4 checkpoint — vacuous silence case pinned;
tmpdir-unset verdict states only this call; Item 3.1 evidence mask-free".
Precommit before the commit: bats 181 passed, same recap.

- Major, fixed: `tests/hook-candidates.bats` `hook silent without a verdict`
  passed vacuously if nothing fired or the probe stub stopped overriding. Added
  a guard that `detect` names `readonly-path` on the fixture, and a positive
  twin (stub `verdict_readonly_path` defined → probe called). Mutation-proven:
  removing the hook's `declare -F` gate turns the case red.
- Minor, fixed: stale RED-phase comments in `tests/matchers.bats`; the
  `hook-candidates.bats` header now names Item 4.3; plan-item reference removed
  from `lib/probes.sh`'s contract comment; blanket `2>/dev/null` dropped from
  `tests/probes-readonly.bats` teardown; `docs/references/hook.md` Flow now
  states the skip-before-probe rule and the `; ` joiner.
- Deferred: `docs/design.md` `## Now` is stale (still names the corpus replay as
  next). The runbook assigns `## Now` to Item 8.2, so it waits.

### Carry items

1. **Item 3.1 evidence.** The paragraphs had moved to
   `docs/references/lock-detectors.md` with the split. The git-lock
   `Live reproduction owed: mask` paragraph keeps its conclusion (git ran
   sandboxed, `git:*` unhonoured on CC 2.1.283) and now rests on the
   2026-09-26 `/tmp` write test; the two mask-based sentences are gone and a
   sentence says why a mask proves nothing about the call that sees it. The
   config-lock reproduction's "despite `git:*`" claim now points at that test.
   No other `docs/` sentence argued from masks.
2. **`tmpdir-unset` caveat.** A dated `Caveat (2026-09-26)` paragraph in the
   `detectors.md` entry. The verdict changed in its three places together
   (`detectors.md`, `lib/verdicts.sh`, `tests/verdicts.bats`) plus the two
   `systemMessage` assertions in `tests/hook-candidates.bats`: `$TMPDIR`
   "expanded empty in this unsandboxed call" (was "is unset outside the
   sandbox"); human line `$TMPDIR — expanded empty, path collapsed to /` (was
   `$TMPDIR — unset unsandboxed`). Also reworded: design.md NFR-4 ("may be
   unset") and the translation-map row. Changelog entry 2026-09-26.

### Findings worth my human partner's attention

- The Item 3.1 conclusion now rests on an inference across sessions: the `/tmp`
  test ran in the main session on 2026-09-26, the reproductions on 2026-09-25
  (partly in a delegate). It holds if CC was already 2.1.283 then; that was not
  recorded.
- `tmpdir-unset` may be near-dead on current CC (unsandboxed `$TMPDIR` is
  `/tmp`). It stays shipped; its precision was measured on older traffic only.
  Worth a look at Item 8.1 dogfood whether it ever fires.

### For the Finish run summary

- Phase 4 checkpoint applied one major test fix and six minors; `## Now` in
  design.md deferred to Item 8.2.
- The two carry items above changed shipped verdict text (tmpdir-unset) after
  its item closed.

### Deviations

- The corrector was dispatched unnamed (teammates cannot name spawned agents);
  its report path follows the naming scheme. It returned without a hand-back
  message; the report file was complete and was read instead.
- The old `## Resume` section above is marked superseded rather than removed.

### Phase 5 boundary resume block

```text
Resume /build at Phase 5 of /Users/david/code/sandbox-lies/plans/sandbox-lies/runbook.md.
Phase 4 closed at commit "Phase 4 checkpoint — vacuous silence case pinned; tmpdir-unset verdict states only this call; Item 3.1 evidence mask-free", followed by this report's commit.
Build baseline: .git/build-baseline. verify-step: /Users/david/.claude/plugins/cache/ddaanet/edify/0.3.0/skills/build/scripts/verify-step.sh (run unsandboxed).
Next: Item 5.1 (readonly-path live proof; general item; escalate on a successful write or any probe output other than writable), then the Phase 5 boundary corrector, then Phase 6 (Item 6.1, readonly-path verdict, tdd).
Sandbox facts for 5.1 (CC 2.1.283): git:* in excludedCommands does NOT unsandbox git; masks are visible from every process while any sandboxed command runs, so a mask never proves which call was sandboxed; the mask-free test is `touch /tmp/<name>` (EROFS only inside the sandbox); an unsandboxed call's $TMPDIR is /tmp, not unset.
Carry: Item 6.1's readonly-path verdict carries the command-output-read clause (runbook Item 4.3 list revision). docs/references/lock-detectors.md and docs/references/hook.md are new nodes. tests/hook-locks.bats is at 375 lines; docs/design.md at 396/400; detectors.md at 308/400.
Splitting is authorized (my human partner, standing): split any doc an edit pushes past 400 lines, per craft:design-doc-writing, fix inbound links, record in docs/changelog.md.
Phase 6 memory retirement (harness-mounted config, sibling worktree, cost 3) passes the gitlore approval gate: batch it into one memory commit.
Shared dispatch context from Phase 4: .git/phase4-dispatch.md (refresh its phase section for 5/6).
```

### Context usage

About 90k tokens of this delegate's own context at the end of the boundary.
