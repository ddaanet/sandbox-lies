# Minor batch F — docs accuracy (findings 17 to 23)

Every claim was re-read at HEAD before editing; all held except where noted.

**FR-10 reversal (finding 17).** The outline asked for `Done`; this batch sets
`Done (prose)` in `docs/design.md` FR-10, as the legend prescribes for a
requirement with nothing re-checking it (the tier index and the translation
map are not a test or gate). The line now adds "no test or gate re-checks it".

- 17: legend at design.md line 27 read; FR-10 edited as above.
- 18: FR-6 pins now list `tests/verdicts-readonly-path.bats` (decode and
  display rule). NFR-5 now reads "document, script, awk, TOML or JSON file and
  `justfile`", from the header of `scripts/check-line-limits.sh` (`.sh`,
  `.bash`, `.bats`, `.py` scripts; `.awk`, `.toml`, `.json`, `justfile`
  outside `tests/fixtures/`). Status: dogfood still dated 2026-09-27 on CC
  2.1.283, now stated as before the `resume-lost` probe, the `printf %q`
  `path=` form with its decoder and the worktree-top join, and "no later
  dogfood run is recorded" (the changelog and reports record none; no run
  invented).
- 19: `docs/references/hook.md` Paths gains a sentence: the `readonly-path`
  probe resolves a relative path the same way, but git's partial-checkout
  refusals join onto the worktree top, pointing at `readonly-path.md`, Probe.
- 20: `readonly-path.md` Probe now defines the wire form and its two shapes
  (backslash form, `$'...'` form) once, at first use. `lock-detectors.md`
  uses none of the three terms (grep: no match); instead its config-lock
  Verdicts now say the `.claude/settings.json.lock` suffix test runs on the
  decoded value, not the wire form, and a value decoding to no path keeps
  Re-run. Verified in `verdict_config_lock`, which matches `_verdict_path_raw`.
- 21: changelog 2026-10-11 "review fixes 3" entry gains: an empty path prints
  no `path=` line (lock probes printed a bare one); the two suites
  `tests/verdicts-readonly-path.bats` and `tests/probes-readonly-resolve.bats`
  (both added in the range, names verified by `git log --diff-filter=A`); the
  `pick()` removal (the branch searching all projects when none is named,
  `tests/extract-fixtures.py` diff) and the `corpus-eval.py` docstring loop
  now redirecting once after `done`. Its "alone is git's refusal" phrase was
  also reworded (finding 23 repeats it there).
- 22: "in the home directory" removed from the fourth shape.
- 23: the three phrasings rewritten: "only when the matching line itself is a
  partial-checkout refusal"; "11 of the 195 hits of the 2026-09-27 dogfood";
  "nearest ancestor of `cwd`, itself included" (matches `hook.md`).

Final line counts: design.md 398, changelog.md 192, readonly-path.md 226,
lock-detectors.md 179, hook.md 130. `just format-docs` run (re-wrapped only).
