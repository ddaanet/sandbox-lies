# Minor batch F review (findings 17 to 23)

Verdict: the change holds; two small wording defects fixed.

Checked against source:

- 17: the legend in `docs/design.md` reserves `Done` for what a test or gate
  re-checks and prescribes `Done (prose)` for instructions nothing re-checks.
  FR-10's pin (tier index, translation map) is no test or gate. Confirmed.
- 18: FR-6 lists `tests/verdicts-readonly-path.bats`; NFR-5 matches the arms of
  `scripts/check-line-limits.sh`. Status states no later dogfood run is
  recorded; the changelog and reports record none. Truthful.
- 19: `hook.md` sentence matches `_probe_readonly_resolve` and the worktree-top
  join in `probe_readonly_path`.
- 20: wire, backslash and `$'...'` forms match `_probe_path_line`
  (`LC_ALL=C printf %q`) and `_verdict_path_read`. The suffix test in
  `verdict_config_lock` runs on `_verdict_path_raw` (decoded); an undecodable
  value leaves it empty and keeps Re-run. True.
- 21: at the base, `_probe_lock_at` printed a bare `path=` for an empty path;
  `_probe_path_line` now prints nothing. The two suites were added by
  `d16cbb5` and `1dedc30` in the range. The `pick()` all-projects branch and
  the `corpus-eval.py` docstring loop (`done >DIR/verdicts.tsv`) match the
  diff.
- 22: no "home directory" remains in docs, README or skills.
- 23: the three rewrites keep their meaning ("11 of the 195 hits", "itself
  included", "matching line itself").
- design.md is 398 of 400. It grew by 4 from 394 by additions only; the diff
  removes no prose, so nothing was crammed or shaved.

Defects fixed:

1. `lock-detectors.md` said "both forms are defined in readonly-path.md", but
   that section defines only the wire form. Now "the printed value, defined in".
2. The backslash form definition implied every path carries a backslash; it now
   says none precedes a plain path.

`just format-docs` re-wrapped `readonly-path.md`. `just precommit` passed
(446 bats, exit read from its final "precommit passed" line).
