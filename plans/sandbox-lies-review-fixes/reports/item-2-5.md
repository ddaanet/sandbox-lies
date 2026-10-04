# Item 2.5 report

Docs (detectors.md tmpdir-unset: fires only when the flag is true; readonly-path.md: silent when true) agree with the flag-policy `case` in `hooks/annotate.sh`. No disagreement.

## Cases added to `tests/hook-candidates.bats` (275 -> 374 lines; no new file needed)

- "every tmpdir-unset fixture is silent unflagged and fires flagged": 3 fixtures (bash-bare, cp-stat, redirect); flag absent silent, flag true systemMessage is the tmpdir-unset human line.
- "every readonly-path fixture fires unflagged with the probe and is silent flagged without it": 6 fixtures (cp-tmp, git-busy, git-config-busy, git-mkdir, python-errno, task-output); `stub_probe readonly_path writable`; flag absent gives the writable human line with the probe reached, flag true silent with the probe not reached.
- "dangerouslyDisableSandbox as the string true reads as false": `fire-tmpdir-unset-redirect`, boolean true fires, string "true" silent.
- Helper `flag_payload` picks failure or post payload by the Exit code first-line rule. Misses collected, count > 0 asserted, as in hook-locks.bats.

## Faults (scratch copy under /tmp/claude-1000/sl/scratch-2-5, deleted; each alone)

1. Flag-policy `case` emptied (arm replaced by a non-matching pattern). Red: new tmpdir-unset sweep (3 fixtures "flag absent: not silent"), new readonly-path sweep (every fixture "flag true: probe reached" and "not silent"), plus existing 1-4 (tmpdir-unset, resume-lost, seccomp-init, readonly-path flag policy; `[ -z "$output" ]`).
2. jq `== true` removed (truthiness). Red: only "dangerouslyDisableSandbox as the string true reads as false" (`[ -z "$output" ]` failed).

## Gate

precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests (bats: 271 passed, 0 failed)
