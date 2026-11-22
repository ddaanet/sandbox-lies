# Requirement detail

The parts of four requirements in `docs/design.md` that are read only while
working on the thing they govern: the probe interface, memory retirement, the
recovery script's exit codes and the scope of the portability stubs. The hub
keeps each requirement's statement, its invariants and its status; this node
carries the mechanism.

## FR-4 — Probes

A probe reads the result text on stdin, takes the flag (FR-5), the payload `cwd`
and `tool_input.command` as its arguments, prints an outcome token on its first
line and `key=value` lines after it (a `path=` value is printed in `printf %q`
form); the verdict function reads both, and the flag. Four probes: lock
existence and holder (`git-lock`, `config-lock`), path writability
(`readonly-path`), which also reports the command facts and the partial-merge
files its acts depend on (D-17), and transcript existence (`resume-lost`).

## FR-10 — Memory retirement, per section

Every section the plugin carries is retired. `memory/ddaanet/sandbox-effects.md`
keeps what it does not: the phantom-dotfile leak, and the zellij section, whose
detector stays a candidate under D-15. One residue survives as prose: the
`!`-expansion phantom-listing rule, folded into the existing phantom-dotfile
bullet of `memory/ddaanet/shared-claude.md`.

## FR-12 — Recovery script

Exit 0 is nothing left to do, a plan carried out or a dry run printed; 1 a
failed re-run or act; 2 a usage error or a state it cannot tell. Its use is in
`skills/sandbox-lies/references/refused-merge-recovery.md`.

## NFR-2 — Portability

The code under test is what a suite's assertions are about: a library it only
runs to build its input (`verdicts*.bats` pipe text through `lib/matchers.sh`)
is covered by its own suites.
