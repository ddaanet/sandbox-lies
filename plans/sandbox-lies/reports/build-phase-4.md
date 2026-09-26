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

## Open gate — memory commit approval

The retirement change above is prepared and uncommitted. The gitlore gate blocks
every parent commit while `memory` is dirty, this report's included, until my
human partner approves a summary. The pending change was held against
`gitlore:memory-writing`: each retired section now has an owner that prints the
diagnosis when it fires (the plugin's verdicts, §1 Q2), so the reduction stands;
the surviving sections and the rewritten index line keep their literals. The
file stays over the 4 KB recall cap, as before; Item 8.2 deletes it. Draft, in
the gate's format:

> Retire the lock and candidate sections of sandbox-effects, now carried by
> sandbox-lies
>
> **Reduce ddaanet/sandbox-effects:** the file no longer carries the
> `.git/index.lock` section with its `.git/config.lock` paragraph, cost 1 of
> "Leaving the sandbox" (an unsandboxed `$TMPDIR` collapsing to `/`), the
> `--resume` mechanism (a sandboxed turn's transcript never persists), or the
> sandbox-setup section (`apply-seccomp` failing at namespace init). The
> sandbox-lies plugin now diagnoses each when it fires: the `git-lock` and
> `config-lock` verdicts probe the lock outside the sandbox and report a mask, a
> cleared lock, a holder, an orphan or an unknown holder, replacing the hand-run
> discriminator, and the `tmpdir-unset`, `resume-lost` and `seccomp-init`
> verdicts cover the other three. What the plugin's skill will carry stays: the
> `$TMPDIR` instability paragraph, and the eval-harness consequence under a new
> heading, "Multi-turn `claude` flows must run unsandboxed". Cost 1's note that
> the classifier judges an unsandboxed recipe by its top-level command moves
> into cost 3. The zellij section stays, because its detector did not ship. The
> description, the symptom table and both index lines drop the retired symptoms.

Question: approve this summary as written? Default if the approval carries no
edit: commit with it verbatim. Only a clear, un-negated affirmative counts as
approval.

Uncommitted while the gate is open: `docs/changelog.md`, `docs/design.md`,
`docs/references/detectors.md`, `docs/references/hook.md` (new), `lib/probes.sh`
(a comment pointing at the moved paragraph), `tests/matchers.bats`, `memory`
(the tier: `MEMORY.md`, `ddaanet/MEMORY.md`, `ddaanet/sandbox-effects.md`),
`plans/sandbox-lies/reports/phase-4-retirement.md`, and this report
(`build-phase-4.md`), which the gate also refused to commit.

## Resume

Resume at the Phase 4 retirement commit, then the Phase 4 boundary.

1. On approval: write the approved summary to
   `/Users/david/code/sandbox-lies/.claude/gitlore-memory-message`, stage the
   files listed above by name (plus `memory` and this report), `just precommit`,
   commit
   `docs: Phase 4 — lock and candidate memory retired; statuses flipped; design.md split`.
   Then verify-step (unsandboxed).
2. Phase 4 boundary: Read the build skill's `references/phase-boundary.md` and
   follow it (phase-4-corrector, commit, resume block for Phase 5).
3. Carry into Phase 5 and beyond: Item 6.1's `readonly-path` verdict carries the
   command-output-read clause; `docs/references/lock-detectors.md` and
   `docs/references/hook.md` are new nodes; `tests/hook-locks.bats` is at ~382
   lines; the shared dispatch context lives at `.git/phase4-dispatch.md`
   (untracked, reusable).

## Context usage

About 185k tokens of this delegate's own context at the gate: a resumed delegate
should be fresh for the Phase 4 boundary if the relay is slow.
