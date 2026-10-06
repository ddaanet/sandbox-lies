# Item 5.5 slice 1 — GREEN

Tests run: `tests/probes-lock-newline.bats`, six cases, all red before.

Order made to pass: one guard in `_probe_lock_at` (`pathline` flag, cleared
when the resolved `$path` holds a newline) read by all six `path=` sites,
which then pass together because the sites share it; the six cases then run
and passed: config-lock mask, git-lock orphan, orphan under BSD stubs, held,
character device, gone. Each was checked in the single bats run; the one guard
could not be grown per test without leaving print sites unguarded, so the
growth was the guard first, then the sites.

Print sites use `${pathline:+"path=$path"}` (bash 3.2 safe, no empty-array
expansion); the final orphan print is wrapped in `if [ -n "$pathline" ]`.

Docs: `lib/probes.sh` header and `_probe_lock_at` comment,
`docs/references/lock-detectors.md` Probe paragraph, `docs/changelog.md`
sentence beside Item 5.4's. `just format-docs` run (it rewrapped a changelog
paragraph at line 246).

Results: new file 6/6; full `just precommit` exit 0, 305 bats passed, 0 failed
(run twice, both green). No warnings printed.
