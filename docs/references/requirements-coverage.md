# Requirements coverage

Where each requirement of `docs/design.md` is implemented and what pins it, with
the measurements behind a status; read it before changing a requirement's code
or its tests. The hub keeps each statement and its status word.

**FR-1** — Where · pinned by: `hooks/hooks.json` · `tests/hook.bats` asserts the
three event keys and that the emitted JSON carries only
`hookSpecificOutput.additionalContext` and `systemMessage`;
`tests/check-jq.bats` runs the `SessionStart` command.

**FR-2** — Where · pinned by: `lib/matchers.sh` · `tests/matchers.bats`, which
asserts the full verdict set per fixture so a matcher that starts firing on a
neighbour's symptom fails rather than double-reporting.

**FR-3** — Where · pinned by: `hooks/annotate.sh` · `tests/hook.bats` over both
events' recorded payloads, `tests/hook-malformed.bats` over malformed ones and a
probe or verdict that dies mid-run, `tests/hook-locks.bats` over the probe call.

**FR-4** — Where · pinned by: `lib/probes.sh`, `lib/probes-readonly*.sh` · the
`tests/probes*.bats` family over synthetic trees and the `tests/hook-*.bats`
family over the hook's calls.

**FR-5** — Where · pinned by: `hooks/annotate.sh` · `tests/hook.bats`,
`tests/hook-locks.bats` and `tests/hook-candidates.bats` pair each fixture with
both flag values against that policy, and `tests/hook-resume.bats` pairs
`resume-lost`'s four transcript states with both.

**FR-6** — Where · pinned by: `lib/verdicts.sh` · `tests/verdicts.bats` asserts
length with no probe lines on stdin and runs `detect` over every verdict text
expecting silence; `tests/verdicts-locks.bats` asserts the D-17 flag wording for
the lock verdicts, `tests/verdicts-readonly.bats` each `readonly-path`
composition and its length, `tests/verdicts-readonly-path.bats` the `path=`
decode and display rule; `tests/hook-cap.bats` asserts the 2 KB cap with stub
paragraphs.

**FR-7** — Where · pinned by: the reference's per-detector table ·
`tests/matchers.bats` has a `fire-*` and a `quiet-*` fixture per shipped
detector.

**FR-8** — Where · pinned by: `tests/extract-fixtures.py` · the `fire-*` and
`quiet-*` set is reproducible from the script in part: re-run at the 2026-09-28
review, it re-cut 25 of the 34 byte for byte; two undated entries picked other
calls, as the script warns, and seven were not found in the corpus, cause not
established.

**FR-9** — Where · pinned by: the skill file · `tests/docs.bats` runs `detect`
over it.

**FR-10** — Where · pinned by: the tier's index, and the translation map in
`references/detectors.md` that audits every paragraph. Done (prose): no test or
gate re-checks it.

**FR-11** — Where · pinned by: `tests/docs.bats` runs `detect` over every other
tracked regular file.

**NFR-1** — Where · pinned by: `references/` per detector · the replay harness
under `tests/`. Done (harness promoted; each shipped candidate re-measured with
its shipped matcher as arbiter, not gated).

**NFR-2** — Where · pinned by: `tests/helpers/bsd-stubs.bash` · every bats file
loads it.

**NFR-3** — Where · pinned by: `hooks/hooks.json` timeout · `tests/hook.bats`
asserts empty stdout on quiet fixtures. Done (measured 2026-09-24, means of 30
runs on a 2-core box at load ~2.1 inside the sandbox: 52 ms quiet on
`quiet-clean-status`, 64 ms with a verdict on `fire-masks-porcelain`; an earlier
first pass had one verdict run at 169 ms, so the bound holds for the mean, not
every run; not gated).

**NFR-4** — Where · pinned by: `tests/hook.bats` and `tests/matchers.bats` run
the hook and `detect` with `TMPDIR` naming a missing directory,
`tests/hook-writes.bats` the hook through a real readonly-path and git-lock
probe, `tests/probes-edges.bats` those two probes, `tests/check-jq.bats` the
`SessionStart` check with a `mktemp` spy, `tests/probes-resume.bats` the
`resume-lost` read scope (`HOME/.claude` unread when `CLAUDE_CONFIG_DIR` is set)
and `tests/probes-resume-tree.bats` its other half (no transcript opened). Done
(read scope: `resume-lost`'s pinned, the rest review, not gated).

**NFR-5** — Where · pinned by: `scripts/check-line-limits.sh`,
`scripts/check-links.sh` · both run in `just precommit`.
