# Item 3.4 report

## Doc-table check

`docs/references/lock-detectors.md` outcome table: `mask` is "flag false, path
absent outside the sandbox, or it stats as a character device"; `gone` is
"flag true, path absent". `_probe_lock_at`'s absent-path branch in
`lib/probes.sh` prints `gone` + `path=$path` under flag `true`, else `mask` +
`path=$path`. A hand run of the pathless text gave `mask` / `path=` (flag
false) and `gone` / `path=` (flag true). Code and table agree.

## Assertions added (tests/probes-config.bats, existing negatives kept)

- "each probe reads only its own lock line", last call
  (`probe_config_lock` on git-lock text alone): first line is `mask`, and an
  exact `path=` line is present.
- "pathless text never names the base": flag false gives `mask` and an exact
  `path=` line; flag true gives `gone` and an exact `path=` line.

## Faults (scratch copy under /tmp/claude-1000/sl/scratch-3-4, deleted)

- `mask` printed as `unknown` in the absent branch alone: red tests
  "each probe reads only its own lock line" (line 83, an earlier existing
  mask assertion trips first) and "pathless text never names the base"
  (line 142, new: flag false `= mask`). Also red, from existing assertions:
  config-lock reads its own error, config-lock reads the line-start error,
  no .git above cwd keeps cwd, relative cwd terminates, trailing slash.
- `gone` printed as `unknown` alone: red test "pathless text never names the
  base" (line 152, new: flag true `= gone`).
- Because the full `mask` fault trips an earlier assertion first in "each
  probe", a narrowed variant (absent branch prints `unknown` / `path=` only
  when the path is empty) turned red "each probe reads only its own lock
  line" at line 99, the new `= mask` assertion, and line 142 again.
- The `path=` line assertions are exact (`grep -qxF "path="`); not isolated by
  a separate fault beyond the above.

## Gate

`just precommit`: see the pass line below.

Exit 0. bats: 277 passed, 0 failed. "precommit passed: plugin.json,
hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests".
