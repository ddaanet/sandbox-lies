# Review: Phase 3 checkpoint — pin gates and harness

**Scope**: `git diff 0ded980 HEAD` (Items 3.1–3.4:
`tests/helpers/bsd-stubs.bash`, `tests/shim.bats`,
`tests/check-line-limits.bats`, `tests/check-links-edges.bats`, new
`tests/helpers/git-env.bash` and its load lines, `tests/probes-config.bats`,
reports `item-3-{1,2,3,4}.md`), against the runbook's Phase 3 section and the
Phase 2 header's D5 rule. **Date**: 2026-10-04 **Mode**: review + fix

## Summary

The four items match their runbook text and every new assertion has a fault that
turns it red, except Item 3.4's exact `path=` positives. The item report
recorded no fault for them, so this review ran two. Two minor issues were fixed
in helpers. The paste stub gave the wrong diagnostic for a missing `-d`
argument. The git-env helper left a `setup_file` context unisolated without any
warning, and its comment misdescribed when bats sources a test file. No suite
defines `setup_file` today. `just precommit` is green after the fixes.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

1. **Item 3.4's `path=` positives had no recorded red (D5)**
   - Location: `tests/probes-config.bats:100`, `:143`, `:153`
   - Problem: the item report says the three `grep -qxF "path="` assertions were
     "not isolated by a separate fault". D5 says an assertion that no fault
     turns red is not done.
   - Fix: this review ran the faults in a scratch copy (see the D5 record
     below). All three go red, and none of the pre-existing negatives catches
     the faults.
   - **Status**: FIXED (evidence supplied; no test change needed)

### Minor Issues

1. **Paste stub reports a missing `-d` argument as an illegal option**
   - Location: `tests/helpers/bsd-stubs.bash`, `_bsd_stub_paste`, the `:|'?')`
     arm
   - Note: BSD getopt prints the "option requires an argument" form for a
     missing option-argument and the "illegal option" form only for an unknown
     option. The stub printed the second for both. No test asserts that text,
     but the stub exists to mimic BSD paste.
   - **Status**: FIXED — the two arms are now separate. A hand run of the
     generated stub gives the missing-argument line for a bare `-d` and the
     illegal-option line for `-x`, each followed by the usage line and exit 1. A
     bare `-s` gives the usage line alone with exit 1, and `-sd: -` gives `a:b`
     with exit 0.

2. **git-env leaves a `setup_file` context unisolated without any warning, and
   its comment misstates when bats sources the file**
   - Location: `tests/helpers/git-env.bash`
   - Note: in bats 1.14, `bats-exec-test` creates and exports
     `$BATS_TEST_TMPDIR` (`bats_create_test_tmpdirs`) before
     `bats_evaluate_preprocessed_source`. Every test process, with its `setup()`
     and `teardown()`, therefore always gets the config. bats also sources the
     file in `bats-exec-file` for `setup_file` and `teardown_file`. There
     `$BATS_TEST_TMPDIR` is unset, so the guard skipped the export with no
     warning and git ran against the host config. The comment said bats loads
     the file "once to gather the test names". It also loads it for
     `setup_file`.
   - **Status**: FIXED — the helper now falls back to `$BATS_FILE_TMPDIR`, which
     `bats-exec-file` creates before the `setup_file` source. During test
     gathering neither variable is set, so the helper still does nothing there
     (no git runs). The comment now names all three contexts.
   - Hand verification in a scratch bats file, with a host `GIT_CONFIG_GLOBAL`
     setting another `user.name` and `commit.gpgsign=true`:
     - With the old helper, `setup_file` read the host `user.name`, so the probe
       went red.
     - With the fix, `setup_file` reads `test` from
       `$BATS_FILE_TMPDIR/host-gitconfig`. The test body reads
       `$BATS_TEST_TMPDIR/host-gitconfig`, `commit.gpgsign=false` and
       `user.email` through a `run bash -c` child. The probe went green.

## Fixes Applied

- `tests/helpers/bsd-stubs.bash` — `_bsd_stub_paste`: the `:` (missing argument)
  and `'?'` (unknown option) getopts arms are split, so each prints BSD's own
  diagnostic.
- `tests/helpers/git-env.bash` — the config directory is
  `${BATS_TEST_TMPDIR:-${BATS_FILE_TMPDIR:-}}`, held in a variable that is unset
  afterwards. The header comment now describes the gather, `setup_file` and
  per-test sourcing.

## D5 record (this review)

All faults ran in a scratch copy at `/tmp/claude-1000/sl/scratch-p3/`
(`hooks/ lib/ scripts/ tests/ .bin/`), one at a time. The scratch copy was
deleted afterwards, and no tracked file was mutated.

- `lib/probes.sh` `_probe_lock_at`, absent-path `mask` line printing
  `path=${path:-$PWD}` (an empty path joined onto the process cwd). Red:
  - `each probe reads only its own lock line` at line 100, the new `path=`
    positive. The `= mask` above it passes.
  - `pathless text never names the base` at line 143, the new flag-false
    `path=`.
  - The pre-existing `grep -cxF "path=$index"` negative stays green under this
    fault.
- The same fault on the `gone` line. Red: `pathless text never names the base`
  at line 153, the new flag-true `path=`.
- Item 3.1's F1 re-run after the stub fix: the trailing `-` was removed from the
  scratch `.bin/claude`. Red:
  `the shim strips its directory under a BSD paste, which reads no implicit stdin`
  (line 100, status). The other six shim cases stayed green.

## Per-item checks

- **3.1**
  - The stub matches BSD paste (FreeBSD/macOS `paste.c`). Its option string is
    `d:s`, and with no operand left it prints the usage line and exits 1,
    whether or not `-s` was given. The stub refuses every operand-less
    invocation, which is stricter than the item text ("refuses `-s` … with no
    file operand") and faithful to BSD. An explicit `-` passes through, because
    getopts stops at a lone `-`.
  - The shim case asserts only the shim's contract, which cases 1 and 2 already
    pin: argv with `--plugin-dir <root>` prepended, empty stderr, `$NEXT`
    present and `$ROOT/.bin` absent in the child's PATH. It leans on no
    incidental line of `.bin/claude`. A re-applied patch that keeps cases 1–2
    green and passes paste an operand keeps it green.
  - `shim.bats` loads `helpers/git-env`, although `.bin/claude` runs no git
    today. This is harmless and defensive against the saved `.bin/claude` patch,
    so it was left.
- **3.2**
  - The `git ls-files` stderr pins are exact. The stub `git` is silent, so the
    script's line is the whole of stderr.
  - The unreadable case pins only stderr's last line, exactly. The shell's own
    redirect error, with its script line number, comes first and is not pinned.
  - Both faults are recorded as red in `item-3-2.md`.
- **3.3**
  - Load-time sourcing in each test process was confirmed in bats 1.14's
    `bats-exec-test`, as above.
  - `GIT_CONFIG_GLOBAL` reaches every git child:
    - No suite or helper uses `env -i`. The `env PATH=… TMPDIR=…` runs in
      `hook.bats`, `matchers.bats` and `probes-edges.bats` keep the rest of the
      environment.
    - `_readonly_repo_facts`'s `unset` list in `lib/probes-readonly-facts.sh`
      leaves out `GIT_CONFIG_GLOBAL` and `GIT_CONFIG_NOSYSTEM`.
  - The left-out suites run no git:
    - git's only exec sites are `lib/probes-readonly-facts.sh` (reached only
      through `probe_readonly_path`), `scripts/lib/tracked.sh`,
      `make_scratch_repo` and `make_fixture_root`.
    - `probes`, `probes-tools` and `probes-config` call only `probe_git_lock`,
      `probe_config_lock` and `probe_holder_pid`.
    - `matchers-edges`, `verdicts-locks` and `verdicts-readonly` run no probe
      and no hook. `matchers-edges`' one `git` token is text inside a status
      block.
  - Every walk-up-dependent real-probe case is guarded. Every
    `probe_readonly_path` call with a `$BATS_TEST_TMPDIR` cwd asserts the
    outcome token, or `readfile=`/`merge=` lines derived from the command text,
    except the one guarded case. That case's empty-stderr assertion is
    meaningful only with no repository above.
- **3.4**
  - `lock-detectors.md`'s outcome table agrees with the pins: `mask` is "flag
    false, path absent", and `gone` is "flag true, path absent". The pathless
    case is an empty, absent path.
  - The kept negatives (`!= orphan`, `!= held`) are now implied by the new
    `= mask`/`= gone` assertions. The item asked for the positives to be added,
    so the negatives were left.
- **General**
  - Phase 3 adds no new bats file and no `2>/dev/null`.
  - Every changed file is at or under 400 lines. `tests/hook-locks.bats` is at
    399.
  - `just precommit` exits 0: 277 passed, 0 failed, and every check passed
    (plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links,
    tests).

## Positive Observations

- The 3.2 git stub on `PATH`, rather than a non-repository root, keeps the
  failure deterministic even when a repository encloses `$BATS_TEST_TMPDIR`.
- The 3.2 unreadable case pins the script's own line exactly. It does not pin
  the shell's error text, which varies by shell and line number.
- The 3.3 verification covers the helper from both sides: it is green under a
  hostile host config, red with the load lines removed, and the guard goes red
  with `TMPDIR` inside a repository.

## Recommendations

- `tests/hook-locks.bats` is at 399 lines. The next case added there should go
  to a new file.
