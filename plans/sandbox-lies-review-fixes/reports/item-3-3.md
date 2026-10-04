# Item 3.3 report — suites isolated from host git config

## Helper form

`tests/helpers/git-env.bash` exports `GIT_CONFIG_NOSYSTEM=1` and
`GIT_CONFIG_GLOBAL=$BATS_TEST_TMPDIR/host-gitconfig`, a file the helper writes
(`user.name`, `user.email`, `commit.gpgsign=false`) at load time. Form: the
work runs when the helper file is loaded, not from a `setup()` hook, so a
suite's own `setup()` cannot skip it. bats loads a test file once to gather
names (no `$BATS_TEST_TMPDIR` yet, so the helper does nothing) and again inside
each test's process, where `$BATS_TEST_TMPDIR` exists; the file is rewritten
per test and the exports reach `run`, subshells and the hook (run with `bash`,
inheriting the environment). No `env -i` appears in any suite, so no case drops
the variables. No write beyond the per-test tmpdir.

## Suites loading it (after `load helpers/bsd-stubs`)

check-links, check-links-edges, check-line-limits, docs, hook, hook-malformed,
hook-candidates, hook-writes, hook-locks, hook-verdicts, hook-cap, matchers,
verdicts, verdict-premises, probes-readonly, probes-readonly-facts,
probes-readonly-pins, probes-readonly-members, probes-edges, shim.

Left out (no git run: pure text or `-d .git` walk-ups, git never executed;
git's only exec sites are `lib/probes-readonly-facts.sh` and
`scripts/lib/tracked.sh`): probes, probes-tools, probes-config (it makes `.git`
directories with `mkdir` only), matchers-edges, verdicts-locks,
verdicts-readonly.

## Guarded cases

Only one real-probe case depends on a walk-up from `$BATS_TEST_TMPDIR` finding
no `.git`: `merge=1 fires for a git merge-style command segment` in
`tests/probes-readonly-facts.bats` (its comment says no repository holds the
tmpdir). It now calls `assert_no_git_above "$BATS_TEST_TMPDIR"` first. The
two probes-config cases already guarded (`no .git above cwd keeps cwd`,
`relative cwd terminates at the working directory`) are unchanged;
probes-config does not run git, so it does not load the helper. The other
cases with a tmpdir cwd (`git pull`, `git merge feat` there) assert only
`merge=1`/stderr and pass with or without a repo above (checked below with an
outer repo holding `feat` and `commit-tag`).

## Verification runs (by hand, scratch files under /tmp/claude-1000/sl/scratch-3-3)

1. Host `GIT_CONFIG_GLOBAL` file with `commit.gpgsign=true`,
   `tag.gpgsign=true`, `gpg.program=/nonexistent`, against the tree: status 0,
   277 `ok`, 0 `not ok`.
2. Same host file, scratch copy with every `load helpers/git-env` line removed:
   status 1, 273 ok, 4 not ok: `check-links-edges` `unmerged path walked once`
   (gpg failed to sign, `cannot exec '/nonexistent'`), `probes-readonly-pins`
   `a tag on a tree gives merge=1, no target and a clean exit` and `a tag on a
   blob ...`, and `docs` `no tracked file outside the fixtures fires a
   detector` (that one fails for a copy artefact, `plans/` not copied, not for
   the host config; it fails the same under `GIT_CONFIG_GLOBAL=/dev/null`).
3. `TMPDIR` inside a scratch git repo (with commits, `feat`, `commit-tag`),
   against the tree: status 1, 3 not ok: the two probes-config cases and
   `merge=1 fires for a git merge-style command segment`, each failing on
   `assert_no_git_above`.

## Gate

`direnv exec . just precommit`: `bats: 277 passed, 0 failed`, then
`precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests`.
