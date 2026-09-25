# Build report — Phase 3 (Evidence)

Runbook: `plans/sandbox-lies/runbook.md`, Phase 3. Build baseline:
`.git/build-baseline` (unchanged). Status: **stopped at Item 3.1's runbook
escalation point** — gate 2 open for my human partner, below (gate 1 answered).

## Commits

- 📝 Item 3.1 — live reproductions: git-lock orphan and held, config-lock mask;
  git-lock mask owed
- 📝 Phase 3 build report — Item 3.1 escalation gate
- 📝 Item 3.1 — opaque-script reruns: no index-lock mask; config-lock mask confirmed

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

## Gate 1 answer and follow-up (opaque-script shape)

The answer came back as a correction rather than (a), (b) or (c): `git:*` is in
the user settings' `sandbox.excludedCommands`, so the `sh -c` commit would have
run unsandboxed. I was told to rerun both reproductions from an opaque script,
to fix every `sh -c` shape, and to come back as a gate if the error still did
not appear. What the rerun showed:

- A script run as `sh <script>`, with no `git` on the command line, ran `ls`
  on both lock paths and then `git status`. It did this in the scratch repo
  and in this checkout's root. `index.lock` was absent in both places. The
  root's `.git/config.lock` showed as a character device. `git status` exited
  0 in both. **No index lock was masked, so the git-lock error cannot arise.**
- **config-lock, opaque shape:** the script's `git config sandboxlies.probe 1`
  in the root failed with the config-lock error (exit 255). The unsandboxed
  probe printed `mask` with the same path as before. The key was not written.
- **The correction's premise did not hold in this session.** A visible
  `cd <root> && git config sandboxlies.probe 1` failed the same way. So did a
  bare `git -C <root> config sandboxlies.probe 1`. Unsandboxed,
  `.git/config.lock` does not exist and `git config --get sandboxlies.probe`
  exits 1. Every one of those git calls therefore ran sandboxed, even though
  `git:*` is in `~/.claude/settings.json`. The sandbox configuration this
  teammate session was given lists no `excludedCommands` at all. The earlier
  `sh -c` commit was very likely sandboxed too. It succeeded because nothing
  masked the index lock, not because the exclusion lifted the sandbox.
- For that reason I have **not** rewritten `sh -c` to the opaque-script shape
  in the runbook's Item 3.1 text or in the carry list. Doing so would record a
  reason that is false here. `detectors.md` now records the opaque-script
  attempts and the exclusion observation as facts, beside the `sh -c` ones.
  It makes no claim about which shape escapes the exclusion.
- Review: `edify:corrector` (Fable), report `item-3-1-review-2.md`. It fixed
  2 major issues: a sentence overclaiming "every shape" of git call, and the
  exclusion observation, which had not been recorded. It also fixed minor
  wording. No UNFIXABLE.

## Open gate 2 — no index-lock mask in this session under any shape

1. **How should the git-lock `mask` outcome be handled now?** Default **(a)**.
   - (a) Accept it by composition, as argued under gate 1 below, and continue
     with Item 3.2.
   - (b) Mask the scratch lock path deliberately. Add
     `/tmp/claude/sandbox-lies-3-1/repo/.git/index.lock` to the sandbox's
     write-deny list, in settings I may not edit. Bubblewrap then presents it
     as a character device, as it does `.git/config.lock`, and the scratch
     `git add` fails.
   - (c) Hold the wiring until a session hits the mask naturally.
2. **Should the `sh -c` shapes still be rewritten to the opaque-script shape?**
   Default: **no.** Leave the runbook and carry text as they are. The opaque
   shape is only recorded as an equivalent that also works. The rewrite's
   premise, that `git:*` unsandboxes a visible git call, was contradicted in
   this session. Whether it holds in the main session is worth one check
   there: run `git -C /Users/david/code/sandbox-lies config sandboxlies.probe 1`
   with the default sandbox. If it succeeds, it was unsandboxed; then remove
   the key with
   `git -C /Users/david/code/sandbox-lies config --unset sandboxlies.probe`.

## Gate 1 (superseded by gate 2) — git-lock `mask` has no live reproduction

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
The last item commit was "Item 3.1 — opaque-script reruns: no index-lock mask;
config-lock mask confirmed". Position: Item 3.1 is done except git-lock
`mask`, which waits on gate 2. Next: the gate 2 answer, then (under (a))
Item 3.2, then the Phase 3 boundary corrector. Under (b), once the deny entry
is live: rerun `sh /tmp/claude/sandbox-lies-3-1/opaque.sh` sandboxed, after
changing its `git status` to `git add f`, and `echo y >> f` first. Then run
`probe_git_lock false /tmp/claude/sandbox-lies-3-1/repo` unsandboxed on its
output. Replace the "owed" paragraph before Item 3.2.

Carry: `docs/design.md` is at 400/400 lines. Item 3.2's replays run one at a
time. The scratch repo `/tmp/claude/sandbox-lies-3-1/` still exists and is safe
to reuse or delete.

## Context usage

My own context is about 60k tokens at the time of this report. The
session-wide budget showed about 14.91M of 15M remaining.
