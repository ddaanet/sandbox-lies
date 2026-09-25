# Build report — Phase 3 (Evidence)

Runbook: `plans/sandbox-lies/runbook.md`, Phase 3. Build baseline:
`.git/build-baseline` (unchanged). Status: **stopped at Item 3.2's runbook
escalation point**. Gate 3 (`readonly-path`) is open for my human partner,
below; gates 1 and 2 are answered.

## Commits

- 📝 Item 3.1 — live reproductions: git-lock orphan and held, config-lock mask;
  git-lock mask owed
- 📝 Phase 3 build report — Item 3.1 escalation gate
- 📝 Item 3.1 — opaque-script reruns: no index-lock mask; config-lock mask confirmed
- 📝 Item 3.1 — sandbox tell: sh -c shape confirmed sandboxed
- 📝 Item 3.1 — main session's git call also sandboxed
- 📝 Item 3.2 — candidate triage and measurement

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

## Sandbox tell (the amendment's check)

Both runs were made from this checkout's root. The tell is the
`.git/config.lock` character device, which exists only inside the sandbox.

- Shape 1, `sh -c 'git status >/dev/null; test -c .git/config.lock && echo
  SANDBOXED || echo UNSANDBOXED'`, printed **SANDBOXED**.
- Shape 2, the same two lines in `/tmp/claude/sandbox-lies-3-1/tell.sh` run as
  `sh <script>`, printed **SANDBOXED**.
- The git-lock attempt was repeated with the tell in the same call. In the
  scratch repo, `sh -c 'git add f && git commit -qm y; echo rc=$?; test -c
  <root>/.git/config.lock && …'` printed `rc=0` and then `SANDBOXED`. The
  commit ran sandboxed and succeeded.

Shape 1 prints SANDBOXED, so the recorded `sh -c` shapes, the config-lock
reproduction, and the runbook and carry text stay as they are. The one
`detectors.md` addition is a sentence recording the tell-confirmed repeat.
It is under the self-review threshold at 2 lines in 1 file, and I
self-reviewed the diff. Gate 2 stands unchanged, with question 2 settled: no
rewrite.

## Gate 2 (answered: (a)) — no index-lock mask in this session under any shape

1. **How should the git-lock `mask` outcome be handled now?** Default **(a)**.
   - (a) Accept it by composition, as argued under gate 1 below, and continue
     with Item 3.2.
   - (b) Mask the scratch lock path deliberately. Add
     `/tmp/claude/sandbox-lies-3-1/repo/.git/index.lock` to the sandbox's
     write-deny list, in settings I may not edit. Bubblewrap then presents it
     as a character device, as it does `.git/config.lock`, and the scratch
     `git add` fails.
   - (c) Hold the wiring until a session hits the mask naturally.
2. ~~Should the `sh -c` shapes be rewritten?~~ Settled by the sandbox
   tell: shape 1 is sandboxed, so there is no rewrite. The main session
   was checked too (relayed by team-lead): a visible bare `git -C <root>
   config` failed on the mask there too, and the key was not written.
   `git:*` lifts neither session's sandbox. That fact is recorded in
   `detectors.md` beside the exclusion observation.

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

## Item 3.2 — candidate triage (delegated, committed, one candidate gated)

The work went to `edify:artisan` (Opus; the deliverable is prose). Its report
is `item-3-2.md`, and the work is in the commit "Item 3.2 — candidate triage
and measurement". After the commit, `verify-step.sh` reported CLEAN. Replays
ran one at a time.

| candidate | hits | true | decision |
|---|---:|---:|---|
| `readonly-path` | 162 | 157 | **gated**: no `Decision:` line, no fixtures |
| `tmpdir-unset` | 13 | 13 | ships (100%) |
| `resume-lost` | 2 | 2 | ships (100%, two-hit base) |
| `zellij-socket` | 0 | 0 | stays a candidate (zero true positives) |
| `seccomp-init` | 8 | 8 | ships (100%) |

Fixtures were cut for the three that ship, one `fire` and one `quiet` each
(`tmpdir-unset` has two `fire`), with `expected_for` rows expecting no
verdict. `tests/corpus-eval.py` and `tests/extract-fixtures.py` were extended
as well. `detectors.md` is now **398/400** lines.

Per the build skill, general items get no per-item review: this item's review
is the Phase 3 boundary corrector, which has not run yet.

## Open gate 3 — five `readonly-path` false positives the executor may not classify

The runbook says a false positive that is neither self-reference (D-10) nor
the entry's named residual ("a genuinely read-only mount") must be escalated
before `Decision: ships` is written. There are five. Samples, with transcript
paths and context, are in `item-3-2.md` under "Gated false positives".

- **FP 1–4:** reading a background task's output file (or a log) back into
  the model. The file holds an earlier *sandboxed* call's read-only refusal,
  such as bash refusing a redirect to `/tmp/...` or git refusing the user git
  config. The diagnosis is right, since it was a sandbox refusal. The verdict's
  "re-run the whole call" points at the read rather than at the command that
  failed.
- **FP 5:** `mkdir` of a path directly under `/`, produced by an empty
  variable. It is not writable outside the sandbox either, so the probe would
  print `readonly` ("not a sandbox effect").

1. **How are FP 1–4 classified?** Default **true positive** (the diagnosis
   holds). The alternative is a new named residual, "a background task's
   output read back". That one needs a residual clause in the entry, and
   `detectors.md` has 2 lines of headroom.
2. **Is FP 5 the named residual?** Default **yes**: widen the entry's residual
   from "a genuinely read-only mount" to "a path not writable outside the
   sandbox either", as a reword in place of the existing sentence.
3. **Should `readonly-path` then ship?** Default **yes**: 161 of 162 true, or
   157 with 5 in residuals. Adding `Decision: ships`, a fire/quiet fixture
   pair and two `expected_for` rows is follow-up work before the Phase 3
   boundary corrector. I would dispatch it under the answers above.
   `detectors.md` has 2 lines left, so any residual wording must rewrite lines
   in place. If it cannot fit, that is the split escalation, a gate.

## Review findings worth my human partner's attention

- The git-lock mask did not reproduce under the default sandbox in two
  sessions. The index.lock cause the memory describes may depend on which paths
  a session's sandbox denies, and so may be rarer than the corpus's 9 true hits
  suggest. It is worth keeping in mind when the verdict wording ships.

## For the run summary at Finish

- Gate 2 answer (my human partner, 2026-09-25): git-lock `mask` is accepted as
  proved by composition. The "owed" paragraph stays, and so do the recorded
  `sh -c` shapes.
- config-lock `mask` is proved live on 2026-09-25.
- `zellij-socket` stays a candidate: there are zero corpus hits.

## Deviations

- The recall skill list was not loaded (reason above).
- Item 3.1 was executed in session rather than delegated, because the
  sandboxed/unsandboxed split must be controlled per call.

## Resume

Nothing is in flight, and the tracked tree is clean after this report's commit.
The last item commit is "Item 3.2 — candidate triage and measurement".

Position: Items 3.1 and 3.2 are committed. Gates 1 and 2 are answered.
`readonly-path` waits on gate 3. Next comes the gate 3 answer, then a
follow-up dispatch for `readonly-path` (its residual wording, its `Decision:`
line, and, if it ships, a fire/quiet fixture pair plus `expected_for` rows),
then the Phase 3 boundary corrector.

Carry:

- `docs/design.md` is at 400/400 lines and `detectors.md` at 398/400.
- The Item 3.2 executor judges these design.md status text changes owed:
  NFR-1 `Partial` gains "candidates measured 2026-09-25", and FR-7 must note
  `zellij-socket` when it flips. The boundary corrector should decide them;
  neither may grow design.md.
- This session's triage printed survivor texts raw, so the next corpus
  re-measurement (Items 4.2/4.3) will find D-10 self-reference hits dated
  2026-09-25 from sandbox-lies.
- The scratch repo `/tmp/claude/sandbox-lies-3-1/` is safe to delete.

## Context usage

My own context is about 105k tokens at the time of this report. The
session-wide budget showed about 14.91M of 15M remaining.
