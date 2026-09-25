# Build report — Phase 3 (Evidence)

Runbook: `plans/sandbox-lies/runbook.md`, Phase 3. Build baseline:
`.git/build-baseline` (unchanged). Status: **stopped at Item 3.1's runbook
escalation point** — one gate open for my human partner, below.

## Commits

- 📝 Item 3.1 — live reproductions: git-lock orphan and held, config-lock mask;
  git-lock mask owed

## Entry

- The tree carried an uncommitted `## Resume` section in `build-phase-2.md`
  that was not mine; I left it unstaged and told team-lead. It has since been
  committed by another agent ("Phase 2 build report — resume section"), so the
  point is closed.
- Recall: `recall-artifact.md` resolved; read `sandbox-effects.md` (the
  index.lock section) and `git-hook-env-leak.md`. I did not load the
  artifact's five skills. They cover code, hooks and tests, and Phase 3 is
  evidence only. Item 3.2's dispatch will name the artifact path.

## Item 3.1 — partial, escalated

I ran it directly: it needs genuinely sandboxed calls, and that cannot be
delegated reliably. Live run on 2026-09-25, git 2.47.3. `/usr/bin/fuser` is the
only holder tool on this box.

Proved and recorded in `docs/references/detectors.md`:

- **git-lock `orphan`.** Scratch repo `/tmp/claude/sandbox-lies-3-1/repo`
  whose pre-commit hook stages a file. A hand-made empty `index.lock`, then an
  unsandboxed `git add f`, produced git's lock error. The unsandboxed
  `probe_git_lock true <repo>` printed `orphan`, `bytes=0`, `age=0`, `path=…`.
- **git-lock `held`.** The same lock held open by a background `sleep`. The
  probe printed `held` with the sleep's pid.
- **config-lock `mask`.** A sandboxed `sh -c 'git config sandboxlies.probe 1'`
  in this checkout's root produced the config-lock error with a relative
  `.git/config`. The unsandboxed `probe_config_lock false <root>` printed
  `mask`, `path=<root>/.git/config.lock`. The key was not written, so no unset
  was needed.

Not reproduced (the escalation):

- **git-lock `mask`.** The sandboxed `sh -c 'git add f && git commit -m x'` in
  the scratch repo **committed cleanly**, hook staging included, the same
  result as the 2026-09-23 review-time attempt. This session's sandbox masks
  `.git/config.lock` in the project root (a sandboxed `ls` shows a character
  device; unsandboxed, no file). It masks no `index.lock`, neither there nor in
  the scratch repo, so the error never arises. The runbook says a sandboxed
  command that does not produce its error stops the phase. The attempt is
  recorded as `Live reproduction owed: mask` beside the proved outcomes.

Review: `edify:corrector` (Fable) in checkpoint form, report
`item-3-1-review.md`. It found 3 minor issues and fixed all 3: an overclaim
("anywhere"), the dropped `sh -c` rationale, and the missing `held` command
shape. No UNFIXABLE. After the commit, `verify-step.sh` reported CLEAN.

Item 3.2 has not been started. The runbook stops the phase at this point, so I
did not run it as non-contingent work.

## Open gate — git-lock `mask` has no live reproduction

1. **How should the git-lock `mask` outcome be handled?** Default **(a)**.
   - **(a)** Accept what was proved and continue with Item 3.2 and then
     Phase 4. The paragraph stays "owed". The case for this: `mask` is decided
     in `_probe_lock_at`, which `git-lock` and `config-lock` share. That branch
     (path absent unsandboxed, flag false) was just proved live through
     config-lock. git-lock's own part, extracting the path from git's real
     error text, was proved live by `orphan` and `held`. Only the combination
     has not been observed. Item 4.1's gate is the presence of a
     `Live reproduction` paragraph, and git-lock now has two.
   - **(b)** My human partner makes the mask reproducible. Bubblewrap bind-masks
     a denied path even when it does not exist; `.git/config.lock` is proof.
     So adding `/tmp/claude/sandbox-lies-3-1/repo/.git/index.lock` to the
     sandbox's write-deny list, in settings I may not edit, should make the
     scratch commit fail. I would then rerun the probe and record `mask`. The
     cost is a settings edit and probably a restart.
   - **(c)** Hold Item 4.1's git-lock `mask` wiring until a session hits the
     mask naturally. It can start mid-session, per `sandbox-effects.md`.

## Review findings worth my human partner's attention

- The git-lock mask did not reproduce under the default sandbox in two
  sessions. The index.lock cause the memory describes may depend on which paths
  a session's sandbox denies, and so may be rarer than the corpus's 9 true hits
  suggest. It is worth keeping in mind when the verdict wording ships.

## For the run summary at Finish

- git-lock `mask` is proved by composition, not by a live run (pending the gate
  above).
- config-lock `mask` is proved live on 2026-09-25.

## Deviations

- The recall skill list was not loaded (reason above).
- Item 3.1 was executed in session rather than delegated, because the
  sandboxed/unsandboxed split must be controlled per call.

## Resume

Nothing is in flight. The tracked tree is clean after this report's commit.
The last item commit was "Item 3.1 — live reproductions: git-lock orphan and
held, config-lock mask; git-lock mask owed". Position: Item 3.1 is done except
git-lock `mask`, which waits on the gate. Next: the gate answer, then (under
(a)) Item 3.2, then the Phase 3 boundary corrector. Under (b), redo only the
sandboxed scratch commit (`sh -c 'git add f && git commit -m x'` in
`/tmp/claude/sandbox-lies-3-1/repo` after `echo y >> f`) and the unsandboxed
`probe_git_lock false <repo>` on its output. Then replace the "owed" paragraph
before Item 3.2.

Carry: `docs/design.md` is at 400/400 lines. Item 3.2's replays run one at a
time. The scratch repo `/tmp/claude/sandbox-lies-3-1/` still exists and is safe
to reuse or delete.

## Context usage

My own context is about 60k tokens at the time of this report. The
session-wide budget showed about 14.91M of 15M remaining.
