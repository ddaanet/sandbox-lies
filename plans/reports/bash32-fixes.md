# bash 3.2 fixes

A. LC_ALL before a builtin
- lib/probes-readonly.sh `_probe_path_line` (~100-112): save/assign/restore idiom; comment names the 3.2 reason.
- `$(LC_ALL=C; printf ...)` in tests/helpers/probes.bash:41, probes-lock-newline.bats:30, hook-writes.bats:166, probes-readonly-members.bats:149, probes-readonly-resolve.bats:26, verdicts-readonly-path.bats (7 sites).
- tests/probes-readonly-resolve.bats:228, :262: `expected=$(LC_ALL=C; printf 'path=%q' ...)`.
- The grep afterwards prints nothing.
- Deviation: the new plain assignment draws shellcheck SC2030 (info) in tests/verdicts-readonly-path.bats; added `# shellcheck disable=SC2030` before the line-198 site (new comment line) and SC2030 added to the existing disable before the `$wire_4n` line (~256).

B. hooks/annotate.sh ~75-82: value held in `v`, `[ -z "$v" ] || printf -v ... '%b' "$v"` for cwd and command, with a one-line 3.2 comment.

C. scripts/check-links.sh ~22-28 and scripts/check-line-limits.sh ~30-37: `set +e`, directive, `source`, `source_rc=$?`, `set -e`, `[ "$source_rc" -eq 0 ] || exit 2`; comment extended.
(`set +e` sits above the shellcheck directive line, which stays directly above `source`.)

Gate 1 (run-bats-under 3.2.57, output read before the final comment-only shellcheck edits):
    bats under .../tmp/bash-3.2.57 (bash 3.2.57(3)-release)
    bats: 451 passed, 0 failed — full log: /tmp/claude-1000/sandbox-lies-bats.129LpM
(Exit status was masked by my `| tail`; the text is the evidence. Not re-run after the comment-only edits.)

Gate 2 (just precommit, exit 0):
    bats: 451 passed, 0 failed — full log: /tmp/claude-1000/sandbox-lies-bats.DveAXW
    precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, python compile, tests

Not done: nothing skipped. A is unverifiable on Linux, as stated.
