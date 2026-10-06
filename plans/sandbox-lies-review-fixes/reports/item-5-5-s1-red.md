# Item 5.5 slice 1 — RED

New file `tests/probes-lock-newline.bats` (103 lines), `git add`ed so precommit
lints it; it loads `helpers/bsd-stubs` and `helpers/probes`. Opened rather than
extending `tests/probes-config.bats` (313 lines) because four cases would pass
400. `setup` resets `_probe_holder_pid`, `teardown` calls `kill_holder`. No
`lib/` edit, no stub, no mutation. Nothing committed.

`<g>` = `<tmp>/r age=99999 x`; `<b>` = `<tmp>/r⏎age=99999⏎x`. Every half compares
the whole output. The only holder tool on this host is `fuser`, so the orphan
outcome token is `orphan`; the test takes it from the blank-twin run's line 1
(a comment says why: `unknown` on hosts with no holder tool).

## Per-test result against the unchanged SUT

Each test's positive halves passed; each failed on the assertion of its `<b>`
half (the line in the failure message), not an error or status 127.

1. `config-lock: a resolved lock path holding a newline gives mask without
   path=` — NOT OK at `[ "$output" = mask ]`. The `<g>` half and the
   absolute-path-under-`<b>` half passed first. Forged output (`cat -A`):

   ```text
   mask$
   path=<tmp>/r$
   age=99999$
   x/.git/config.lock
   ```

2. `git-lock orphan: ...` — NOT OK at the `<b>` whole-output equality (`<g>`
   half passed). Forged output:

   ```text
   orphan$
   bytes=3$
   age=844615470$
   path=<tmp>/r$
   age=99999$
   x/.git/index.lock
   ```

3. `git-lock held: ...` — NOT OK at the whole-output equality against
   `held`, `pid=<holder>`. Forged output:

   ```text
   held$
   pid=3744901$
   path=<tmp>/r$
   age=99999$
   x/.git/index.lock
   ```

4. `git-lock gone: ...` — NOT OK at `[ "$output" = gone ]` (`<g>` half with flag
   true passed first). Forged output:

   ```text
   gone$
   path=<tmp>/r$
   age=99999$
   x/.git/index.lock
   ```

## Runs

`bats tests/probes-lock-newline.bats tests/probes-config.bats`, foreground: 16
tests, 4 not ok (the new ones), 12 ok (all 12 pre-existing `probes-config.bats`
cases pass). `shellcheck` on the new file: only SC1091 info (not following
`lib/probes.sh`, same as the sibling files' `source`).

The forged outputs above came from a temporary `cat -A` debug line injected
into the test file; it was removed afterwards (`grep -c 'cat -A'` gives 0) and
the file re-run.

## Mutation proof

None needed: every test reds on its own assertion against the unchanged SUT.

## Warnings

`git status` shows sandbox-mask dotfiles at the root; ignored per the hook note.
