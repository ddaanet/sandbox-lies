# Build report: Phase 5 (readonly-path live proof)

Delegate run of Phase 5 only, from the Phase 4 boundary resume block. Entry
verify-step: `CLEAN` (bats 181 passed; precommit recap `plugin.json, hooks.json,
shellcheck, bash -n, rumdl, line limits, links, tests`). Recall: the artifact's
`sandbox-effects.md` sections on harness-mounted paths, sibling worktree writes
and leaving the sandbox; no further index entry or skill applied to a live
proof.

## Commits

- 📝 Item 5.1 — readonly-path live proof: sandboxed write into a /tmp worktree,
  probe prints writable
- 📝 Phase 5 checkpoint — corrector Ready; live-proof wording and FR-4 remainder
  sharpened
- This report's commit

## Item 5.1 outcome: `writable`, no escalation

Run in session on 2026-09-26, CC 2.1.283, `/bin/sh` is dash. In the outputs
below, `<EROFS>` stands for the kernel's read-only-filesystem message, printed
verbatim in the session: a tracked report quoting it whole would fire the
detector (self-quiet, `tests/docs.bats`).

Pre-check, unsandboxed: `/tmp/sbx-51-wt`, `/tmp/claude/sbx-51` and
`/tmp/sbx-tell-51` absent.

Setup, unsandboxed:

```bash
mkdir -p /tmp/claude/sbx-51 && git init -q /tmp/claude/sbx-51/repo && git -C /tmp/claude/sbx-51/repo -c user.name=probe -c user.email=probe@invalid commit -q --allow-empty -m init && git -C /tmp/claude/sbx-51/repo worktree add -q --detach /tmp/sbx-51-wt && git -C /tmp/claude/sbx-51/repo worktree list && test -w /tmp/sbx-51-wt && echo "worktree writable unsandboxed"
```

```text
/tmp/claude/sbx-51/repo  5685aa6 [main]
/tmp/sbx-51-wt           5685aa6 (detached HEAD)
worktree writable unsandboxed
```

The write, sandboxed (default Bash), with the mask-free tell in the same call:

```bash
sh -c 'touch /tmp/sbx-51-wt/sbx-51-write' > /tmp/claude/sbx-51/write.out 2>&1; echo "write exit=$?"; cat /tmp/claude/sbx-51/write.out; touch /tmp/sbx-tell-51; echo "tell exit=$?"
```

```text
write exit=1
touch: cannot touch '/tmp/sbx-51-wt/sbx-51-write': <EROFS>
touch: cannot touch '/tmp/sbx-tell-51': <EROFS>
tell exit=1
```

The probe, unsandboxed, on the captured text:

```bash
cd /Users/david/code/sandbox-lies && bash -c '. lib/probes.sh; probe_readonly_path false /Users/david/code/sandbox-lies < /tmp/claude/sbx-51/write.out'; echo "probe exit=$?"; ls -l /tmp/sbx-51-wt/sbx-51-write /tmp/sbx-tell-51
```

```text
writable
path=/tmp/sbx-51-wt/sbx-51-write
probe exit=0
ls: cannot access '/tmp/sbx-51-wt/sbx-51-write': No such file or directory
ls: cannot access '/tmp/sbx-tell-51': No such file or directory
```

Extra evidence, unsandboxed: `bash -c '. lib/matchers.sh; detect false <
/tmp/claude/sbx-51/write.out'` printed `readonly-path` (`detect` takes no
argument; the `false` is ignored).

Cleanup, unsandboxed:
`git -C /tmp/claude/sbx-51/repo worktree remove /tmp/sbx-51-wt && rm -rf
/tmp/claude/sbx-51`, then `ls -ld` on all three paths: each absent. No tell
file was ever written, so none needed removing.

Recorded as `**Live reproduction (2026-09-26): \`writable\`.**` in the
`readonly-path` entry of `docs/references/detectors.md`; FR-4's status in
`docs/design.md` now reads `readonly-path` probe proved live, hook call with its
verdict: Item 6.1. Post-item verify-step: `CLEAN`, same recap.

## Phase 5 boundary: corrector verdict and fixes

`phase-5-corrector` (opus, report `phase-5-corrector.md`) over the Item 5.1
diff: **Ready**, no critical or major finding, no UNFIXABLE. Three minors, all
fixed and committed with the report:

- The paragraph now says the `/tmp/` worktree sits outside the sandbox's write
  allowlist. That is why it counts as the sibling-worktree case, and why the
  `/tmp` tell proves the call was sandboxed.
- "quoted" became "in straight quotes", the property the probe's extraction
  depends on.
- FR-4's status now names the hook call as well as the verdict as Item 6.1's
  remainder: `hooks/annotate.sh` skips a detected name with no verdict function
  before it calls the probe, so the `readonly-path` probe is not hook-called
  yet.

Precommit before the commit: bats 181 passed, same recap.

## Findings worth my human partner's attention

- **A shell redirection's write failure takes the `nopath` path.** Both dash's
  (`sh: 1: cannot create <path>: …`) and bash's (`/bin/bash: line 1: <path>: …`)
  forms print the path unquoted. Checked on synthetic lines, unsandboxed, on
  2026-09-26: `detect` names `readonly-path` and the probe prints `nopath` for
  both. `>` into a path the sandbox refuses is probably the most common shape,
  and it gets the `nopath` verdict: the allowlist paragraph with no path, and
  no writable-or-readonly check. A genuinely read-only target written through a
  redirect would therefore be told the sandbox is the cause. This is the
  designed `nopath` fallback, not a defect, and the live proof deliberately used
  `touch` inside `sh -c` so that the path came out quoted. Open question for
  Item 6.1 or later: should the probe also extract the unquoted path from
  these two shapes? Default: leave the probe as built, and let Item 8.1 dogfood
  show how often `nopath` fires.

## For the Finish run summary

- Item 5.1 proved `readonly-path`'s probe live (`writable`) on 2026-09-26. The
  Phase 5 checkpoint made three wording fixes.
- Shell redirection failures reach `nopath` (finding above).

## Deviations

- **Write shape.** The runbook says "a sandboxed `sh -c` write" and does not
  name the command. I used `touch` inside `sh -c` rather than a redirection,
  because the probe extracts a quoted path and a redirection's error prints the
  path unquoted.
- **One review for Item 5.1.** The item's diff (11 lines, 2 files) was over the
  self-review threshold. The phase is this item alone, so the phase-boundary
  corrector was its review, rather than a separate checkpoint followed by an
  identical boundary review.
- **Corrector dispatch.** It was dispatched unnamed, since teammates cannot name
  the agents they spawn; its report path follows the naming scheme. It ended
  without a hand-back message, and its report file, complete with its verdict,
  was read instead.
- **Baseline.** The run's `.git/build-baseline` was kept, not recaptured, since
  it is the whole run's baseline for Finish.
- **Dispatch context.** The Phase 6 shared context is a new file,
  `.git/phase6-dispatch.md`, derived from `.git/phase4-dispatch.md`, which is
  left untouched. Changes: Phase 6 runbook range; `detectors.md`'s
  `readonly-path` entry and `hook.md` as reading; `stub_probe` located correctly
  in `tests/helpers/hook.bash`; `stub_probe_kv` (in `tests/hook-locks.bats`
  only) noted for slice 1's `path=/r/x`; the existing
  `hook silent without a verdict` cases noted as affected; and the retirement
  precedent.

## Open gate

None.

## Phase 6 boundary resume block

```text
Resume /build at Phase 6 of /Users/david/code/sandbox-lies/plans/sandbox-lies/runbook.md.
Phase 5 closed at commit "Phase 5 checkpoint — corrector Ready; live-proof wording and FR-4 remainder sharpened", followed by this report's commit (plans/sandbox-lies/reports/build-phase-5.md).
Build baseline: .git/build-baseline. verify-step: /Users/david/.claude/plugins/cache/ddaanet/edify/0.3.0/skills/build/scripts/verify-step.sh (run unsandboxed).
Next: Item 6.1 (readonly-path verdict, tdd, three slices; its live-proof gate is met: detectors.md readonly-path entry carries "Live reproduction (2026-09-26)"), then the Phase 6 boundary corrector, then Phase 7.
Item 6.1 context: the hook skips a detected name with no verdict function before its probe runs, so shipping verdict_readonly_path is also what wires the probe call (FR-4 status names both). tests/hook-candidates.bats "hook silent without a verdict" and its positive twin pin that skip for readonly-path today. stub_probe (tests/helpers/hook.bash) prints path=stub; stub_probe_kv, for custom key=value lines such as slice 1's path=/r/x, lives only in tests/hook-locks.bats.
Finding carried: shell redirection failures (dash "cannot create", bash "line N:") print the path unquoted and reach nopath; the probe stays as built unless my human partner decides otherwise.
Sandbox facts (CC 2.1.283): git:* in excludedCommands does NOT unsandbox git; masks are visible from every process while any sandboxed command runs, so a mask never proves which call was sandboxed; the mask-free test is `touch /tmp/<name>` (EROFS only inside the sandbox); an unsandboxed call's $TMPDIR is /tmp, not unset.
Carry: Item 6.1's readonly-path verdict carries the command-output-read clause (runbook Item 4.3 list revision). docs/references/lock-detectors.md and docs/references/hook.md are nodes. tests/hook-locks.bats is at 375 lines; docs/design.md at 396/400; detectors.md at 318/400.
Splitting is authorized (my human partner, standing): split any doc an edit pushes past 400 lines, per craft:design-doc-writing, fix inbound links, record in docs/changelog.md.
Phase 6 memory retirement (harness-mounted config, sibling worktree, cost 3) passes the gitlore approval gate: batch it into one memory commit.
Shared dispatch context for Phase 6: .git/phase6-dispatch.md.
```

## Context usage

About 105k tokens of this delegate's own context at the close of the Phase 5
boundary.
