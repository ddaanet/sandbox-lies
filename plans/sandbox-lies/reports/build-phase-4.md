# Build — Phase 4 (lock verdicts and shipped candidates)

Delegate: build-phase-4. Runbook: `plans/sandbox-lies/runbook.md` Phase 4.

## Commits

- 📝 Item 4.1 — detectors.md split; config-lock verdicts in full
- 📝 Item 4.1 — list revision: flag-neutral mask line; hook-locks.bats; joiner
- ✨ Item 4.1/1 — mask outcome through the hook
- 🐛 Item 4.1/1 — code-review fixes
- ✨ Item 4.1/2 — held, orphan and unknown interpolate probe values (slices 2-3)
- ♻️ Item 4.1/2 — code-review fixes
- ✨ Item 4.1/4 — probe arguments, config-lock mask, piped success payload (slices 4-6)
- 🐛 Item 4.1/4 — code-review fixes: config.lock behind this error
- ✅ Item 4.1/7 — lock fixture sweep, no probe without a verdict, probe stdin (slices 7-8)
- ✨ Item 4.1/9 — cap skips and continues; human lines joined by semicolon

## Item 4.1 — lock verdicts

Done except its memory retirement and status flips (see Deviations).

- **Docs prep (opus, `item-4-1-docs.md`).** `docs/references/detectors.md`
  split: `git-lock` and `config-lock` moved whole to
  `docs/references/lock-detectors.md` (142 lines); `detectors.md` 397 → 303,
  keeping a stub per lock detector. Changelog entry recorded. The config-lock
  verdicts are written out in full (no `GIT_INDEX_FILE` clause).
- **Mask wording under flag `true` (the carried check).** Settled
  flag-neutral with no interface change: "…is a sandbox artefact and the
  repository is healthy. Re-run the same command with
  `dangerouslyDisableSandbox: true`; if it already ran that way, re-run it once
  no sandboxed command is running." The human line became
  `<lock> — sandbox mask, not a real lock` (was `no file exists`, false for a
  character device). Runbook slice 1 revised to match.
- **Missing `bytes=`/`age=`/`pid=`.** An absent key drops its clause; nothing
  interpolates empty (slices 2-3, pinned in `verdicts.bats` and
  `hook-locks.bats`, both orders and one-of-two cases).
- **Joiner.** Human lines join with `; ` (slice 9).
- **Hook robustness fixes from slice 1's code review:** a cwd containing a
  newline corrupted the event/flag/cwd/text split; a non-object `tool_input`
  dropped the whole payload; an outcome with no text left a trailing
  separator.
- **config-lock mask paragraph** opens ``The `config.lock` behind this error``
  (slice 5 asserts `config.lock` in the context; "in this error" was untrue,
  since git names the config file, not the lock).
- Tests: `tests/hook-locks.bats` (new, 382 lines), `tests/verdicts.bats`,
  `tests/hook-cap.bats`.

List revisions: slice 1 (human line, test file), slice 9 (joiner). Otherwise
none.

## Deviations

- **Slices batched.** Item 4.1 ran as five RED/review/GREEN/review cycles, not
  nine: {1}, {2,3}, {4,5,6}, {7,8}, {9}. Batching by shared SUT and fixture;
  RED and GREEN stayed separate dispatches. Commit subjects carry the first
  slice number and name the range.
- **GREEN in session** for {7,8} (no implementation change: all mutation
  proven) and {9} (a one-line joiner change). Code review for those two:
  none dispatched ({7,8} changed no implementation) / self-review of the
  one-line diff ({9}).
- **Dispatches unnamed.** Teammates cannot name spawned agents; report paths
  follow the naming scheme regardless.
- **Recall at pre-work.** The orchestrator read the recall artifact and
  delegated reading its entries and skills to each dispatch (a shared context
  file, `.git/phase4-dispatch.md`, lists them), to stay inside the context
  budget.
- **Item 4.1's memory retirement and status flips deferred** from its final
  slice commit to one retirement commit after Item 4.3, batched with Item
  4.2's, because every memory commit passes the gitlore approval gate: one
  approval instead of two.
