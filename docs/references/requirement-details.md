# Requirement detail

The parts of nine requirements in `docs/design.md` that are read only while
working on the thing they govern: probes, flag policy, verdict composition, the
skill, memory retirement, the recovery script, portability, cost and
hermeticity. The hub keeps each requirement's opening sentence and its status;
this node carries the rest.

## FR-4 — Probes

A probe reads the result text on stdin, takes the flag (FR-5), the payload `cwd`
and `tool_input.command` as its arguments, prints an outcome token on its first
line and `key=value` lines after it (a `path=` value is printed in `printf %q`
form); the verdict function reads both, and the flag. Four probes: lock
existence and holder (`git-lock`, `config-lock`), path writability
(`readonly-path`), which also reports the command facts and the partial-merge
files its acts depend on (D-17), and transcript existence (`resume-lost`). Each
probe is proved once against a live reproduction before it ships; the
reproduction is recorded in `references/` (for `resume-lost`, CC's behaviour its
probe reads, not a run of the probe on a live refusal).

## FR-5 — Sandbox-state awareness

Every detector states its flag policy in `references/`; the gating lives in the
hook or the verdict, never in a matcher.

## FR-6 — Verdict text

Verdicts compose in catalogue order; the two `phantom-*` listing verdicts share
one paragraph when both fire, and a paragraph that would push
`additionalContext` past 2 KB is dropped while its human line is kept. The human
line on `systemMessage` is one lowercase clause. No verdict quotes a diagnostic
together with its follow-on sentence.

## FR-9 — The symptom-less knowledge is a skill

That is the plugin's one skill, `skills/sandbox-lies/SKILL.md`, triggered on
those authoring moments.

## FR-10 — Memory retirement, per section

Every section the plugin carries is retired. The file keeps what it does not:
the phantom-dotfile leak, and the zellij section, whose detector stays a
candidate under D-15. One residue survives as prose: the `!`-expansion
phantom-listing rule, folded into the existing phantom-dotfile bullet of
`memory/ddaanet/shared-claude.md`.

## FR-12 — Recovery script

Without `--apply` it prints the plan and changes nothing; with `--apply` it runs
each act as it prints it. Exit 0 is nothing left to do, a plan carried out or a
dry run printed; 1 a failed re-run or act; 2 a usage error or a state it cannot
tell. Its use is in `skills/sandbox-lies/references/refused-merge-recovery.md`.

## NFR-2 — Portability

A suite whose code under test calls one of those five tools keeps one case
re-run with BSD-strict stubs on `PATH`. The code under test is what the suite's
assertions are about: a library it only runs to build its input
(`verdicts*.bats` pipe text through `lib/matchers.sh`) is covered by its own
suites.

## NFR-3 — Cost

With a verdict and no probe, a mean under 100 ms. Probes are bounded: no
recursive `du`, no network, hook timeout 10 s, the `SessionStart` check's too.

## NFR-4 — Hermetic

It reads only what the result names: the repository holding a refused path,
possibly a sibling worktree rather than the call's, or with no path the payload
`cwd`'s; the lock paths the error names; and whether each session id a
`--resume` refusal names has a transcript, never opening one.
