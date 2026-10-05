# Item 5.4 slice 1 GREEN

Test made to pass (one only): `a resolved refused path holding a newline gives nopath, not path=` in `tests/probes-readonly-members.bats`.

Change in `lib/probes-readonly.sh` `probe_readonly_path`: `_probe_readonly_resolve` now runs before the no-path check, and the existing no-path branch (print `nopath`, then `_readonly_print_facts` with an empty path, return 0) is taken when the resolved `$path` is empty or holds a newline (`[[ $path == *$'\n'* ]]`). The branch body is not duplicated; an empty path resolves to empty, so the earlier empty case is unchanged. The guard keys on the resolved path, not the cwd, and only on a newline (the blank half stays `writable`). The header comment says `nopath` also covers a newline-bearing resolved path. No `2>/dev/null` added.

Docs: `docs/references/readonly-path.md` `nopath` row now reads "no path extracted, or the resolved path holds a newline". `docs/changelog.md`: one sentence added to the 2026-10-05 review-fixes entry, which lists user-visible probe changes. `just format-docs` run.

Lock probes (`lib/probes.sh`): not touched; the code review checks them.

Green run: `bats tests/probes-readonly-members.bats` passes all 12 cases. `just precommit` (foreground) exit 0: 299 bats passed, 0 failed; plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests all passed. No precommit warnings.
