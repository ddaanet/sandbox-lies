# Item 2.2 — the probe path writes nothing

## Cases added

`tests/hook-writes.bats` (109 lines; loads `helpers/bsd-stubs`, `hook`, `spy`, `probes`):

- "hook needs no temp dir on a readonly-path refusal" — scratch repo,
  text from `readonly_path_text` naming `<repo>/a`, command `git merge feat`,
  flag absent, cwd the repo. Unspied `systemMessage` asserted equal to the
  writable human line; spied run (mktemp spy, nonexistent `TMPDIR`) equal to it,
  spy log absent.
- "hook needs no temp dir on a git-lock refusal" — scratch `.git/` with no lock;
  unspied `systemMessage` asserted equal to the index.lock mask line.
- "hook needs no temp dir on a readonly-path refusal under BSD stubs" — the
  readonly case with `make_bsd_stubs grep sed stat wc` ahead of the spy; output
  equal to the plain run.

`tests/probes-edges.bats` (311 -> 341 lines): "readonly-path probe writes
nothing" — subprocess, mktemp spy, nonexistent `TMPDIR`, before/after `find`
listing around `probe_readonly_path false <repo> 'git merge feat'` on a
`make_scratch_repo` tree; asserts line 1 `writable` and a `merge=1` line.

Adaptation: `git_lock_error` omits the follow-on sentence that `match_git_lock`
requires, so the git-lock case appends it built from two fragments at run time
(first attempt with the bare error left the hook silent).

## Faults (scratch copy under /tmp/claude-1000/sl/scratch-2-2, deleted)

Each alone; a `mktemp >/dev/null 2>&1 || :` line inserted.

- Fault A, `annotate.sh` probe branch before the `"$probe_fn"` call. Red, all on
  `[ ! -e "$SPY_CALLS" ]` with the log showing `mktemp`:
  hook needs no temp dir on a readonly-path refusal;
  hook needs no temp dir on a git-lock refusal;
  hook needs no temp dir on a readonly-path refusal under BSD stubs.
  (probes-edges cases stay green: they source the lib, not the hook.)
- Fault B, top of `_readonly_print_facts` in `lib/probes-readonly-facts.sh`. Red:
  hook needs no temp dir on a readonly-path refusal (spy log present);
  hook needs no temp dir on a readonly-path refusal under BSD stubs (spy log
  present);
  readonly-path probe writes nothing (`[ ! -e "$calls" ]`, probes-edges.bats).
  The git-lock hook case stays green, as it never reaches that function.

All new cases green on the real tree.

## Gate

precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests (258 passed, 0 failed)

## Addendum: shellcheck fix

The committed `tests/hook-writes.bats` failed shellcheck SC2030/SC2031
(`PAYLOAD_FILE` assigned in a @test body, read later). Fixed by assigning
`PAYLOAD_FILE` once in `setup()` and having the helper and cases only read it;
case bodies and fault behaviour are unchanged (shellcheck on the file is clean).

Why the earlier gate passed: the justfile's shellcheck step takes its file list
from `git ls-files`, and `tests/hook-writes.bats` was still untracked when I ran
`just precommit` (I staged it only in the commit step), so the new file was not
linted. It was not a sandboxed or stale run; `probes-edges.bats` was tracked and
lint-clean. The gate is run again below with the file tracked.
