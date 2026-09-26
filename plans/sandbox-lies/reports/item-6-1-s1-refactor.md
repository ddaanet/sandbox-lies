# Refactor: Item 6.1 slice 1 — split the readonly-path probe

**Scope**: code review's "Refactoring signals" (`item-6-1-s1-code-review.md`):
`lib/probes.sh` at 392 lines against the 400-line cap; the readonly-path probe
unit (`probe_readonly_path`, `_probe_readonly_resolve`,
`_probe_readonly_path_from_line`, ~110 lines) is separable.
**Handler**: this run (common refactoring — single-module split, no new
abstraction).

## Deslop pass

None of the moved code carried slop (trivial docstrings, narration, dead
code) — the code review had just tightened it. No duplication found to
factor before splitting.

## Change

New file `lib/probes-readonly.sh` holds `probe_readonly_path`,
`_probe_readonly_resolve` and `_probe_readonly_path_from_line`, moved
verbatim (comments included, no behaviour change) from `lib/probes.sh`, plus
its own `_probes_lib_dir`/`BASH_SOURCE`-relative re-source of
`lib/matchers.sh` (the readonly probe's only matchers.sh dependency,
`_readonly_path_line`, which was the sole reason `lib/probes.sh` re-sourced
matchers.sh at all).

`lib/probes.sh` now sources `lib/probes-readonly.sh` instead of
`lib/matchers.sh`, with the same `_probes_lib_dir`/`BASH_SOURCE` pattern. This
was the "fewest moving parts" option: every existing caller of
`lib/probes.sh` (hooks/annotate.sh, and the five bats files that `source
"$ROOT/lib/probes.sh"` directly — probes.bats, probes-edges.bats,
probes-tools.bats, probes-config.bats, probes-readonly.bats) needed no
change, since sourcing `lib/probes.sh` still transitively defines
`probe_readonly_path`. `tests/helpers/hook.bash`'s `hook_copy_tree` copies
`lib/` wholesale (`cp -R "$root/lib" "$HOOK_COPY/lib"`), so it already copies
the new file with no edit needed.

Line counts: `lib/probes.sh` 392 → 283 lines; new `lib/probes-readonly.sh` is
133 lines.

## Comment accuracy

The `_probes_lib_dir` re-source comment that used to explain "why
`probe_readonly_path` re-sources matchers.sh" moved with the function into
`lib/probes-readonly.sh`, reworded to say the re-source is load-bearing when
a caller sources `lib/probes-readonly.sh` (or `lib/probes.sh`) on its own.
`lib/probes.sh` got a new comment for its own re-source, explaining it now
sources `lib/probes-readonly.sh` so a caller sourcing `lib/probes.sh` alone
still gets `probe_readonly_path`.

## Docs

Grepped `docs/` and `CLAUDE.md` for `lib/probes.sh` and for
`probe_readonly_path`/`_probe_readonly_resolve`/`_probe_readonly_path_from_line`.
Two hits, both still true and left unchanged:

- `docs/design.md:82` — "Where · pinned by: `lib/probes.sh` · ..." (FR-4,
  probes) — still true, `lib/probes.sh` still transitively holds/pins the
  probe.
- `docs/design.md:191` — Architecture table, `lib/probes.sh` listed as
  "probe_<verdict> functions (layer 3)" — a layer-level statement, not a
  per-function one; still true.
- `docs/references/detectors.md:171` names `probe_readonly_path` but no file
  for it, so nothing there was made false either.

No rename or reference update is owed to the orchestrator: every caller kept
its existing source line.

## Verification

- `bash -n` on both files: ok.
- Targeted bats: `tests/probes-readonly.bats tests/probes.bats
  tests/probes-edges.bats tests/probes-tools.bats tests/probes-config.bats
  tests/hook-candidates.bats tests/hook-locks.bats tests/hook-cap.bats` — 77
  passed, 0 failed.
- Full gate, foreground: `cd /Users/david/code/sandbox-lies && direnv exec .
  just precommit` — `exit=0`; `bats: 190 passed, 0 failed`; `precommit
  passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits,
  links, tests`.

## Files changed

- `lib/probes.sh` — removed the readonly-path probe unit; its own
  `_probes_lib_dir` block now sources `lib/probes-readonly.sh` instead of
  `lib/matchers.sh`
- `lib/probes-readonly.sh` — new file, the moved unit plus its own
  matchers.sh re-source
- `plans/sandbox-lies/reports/item-6-1-s1-refactor.md` — this report
