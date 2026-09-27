# Item 8.0 slice 3 — RED report

`the probe reports the facts` (`tests/probes-readonly-facts.bats`)

## Scope

- New file `tests/probes-readonly-facts.bats` (283 lines): `probe_readonly_path
  <flag> <cwd> <command>` prints, after `path=`, under `writable` and `nopath`
  only: `readfile=`, `merge=1`, `target=`, `match=`, per
  `docs/references/detectors.md` §readonly-path Probe facts table and the
  paragraph after it.
- No lib/ or hooks/ file touched. `probe_readonly_path` already exists (Item
  6.1); today it takes only `$1` (flag, unread) and `$2` (cwd) and prints
  outcome + `path=` only — a third positional argument is accepted (bash
  ignores an unused extra) and every fact assertion below fails on its own
  value, not on a missing symbol. No stub extension or mutation proof was
  needed: every test genuinely reds against the unchanged code.
- Local helpers, none touched in `tests/helpers/`: `run_probe_command`
  (`probes.bash`'s `run_probe` with a `<command>` argument added),
  `partial_checkout_unlink_error` / `partial_checkout_create_error` (git's
  partial-checkout error text, each built from two fragments so this file
  holds neither phrase whole — self-quiet, FR-11; confirmed by `bash
  lib/matchers.sh <tests/probes-readonly-facts.bats` exiting 1 with no
  output), `make_scratch_repo` (HEAD at `main`, branch `feat` changing `a`,
  `b`, `c`; working tree left with `a` staged and `b` unstaged at `feat`'s
  content and `c` edited to a third value — verified by hand: `git diff
  --cached feat -- a` and `git diff feat -- b` are both empty, `git diff feat
  -- c` is not), `index_mtime` (BSD `stat -f %m` then GNU `stat -c %Y`, as
  `lib/probes.sh`'s own mtime read tries).
- `readonly_path_text` and `assert_no_git_above` reused from
  `tests/helpers/probes.bash` via `load helpers/probes`; `tests/probes-
  readonly.bats` itself was not grown or edited.

## Per-test red output

```
not ok 1 readfile reports a command-output path from a single reader
# (in test file tests/probes-readonly-facts.bats, line 86)
#   `printf '%s\n' "$output" | grep -qxF 'readfile=/w/build.log'' failed

not ok 2 readfile reports a quoted command-output path from a reader pipeline
# (in test file tests/probes-readonly-facts.bats, line 97)
#   `printf '%s\n' "$output" | grep -qxF 'readfile=/w/a b.output'' failed

not ok 3 facts appear only under writable and nopath, never readonly
# (in test file tests/probes-readonly-facts.bats, line 108)
#   `printf '%s\n' "$output" | grep -qxF 'readfile=build.log'' failed

not ok 4 readfile requires a command-output extension
# (in test file tests/probes-readonly-facts.bats, line 131)
#   `printf '%s\n' "$output" | grep -qxF 'readfile=build.log'' failed

not ok 5 readfile excludes an in-place editor and redirected output
# (in test file tests/probes-readonly-facts.bats, line 144)
#   `printf '%s\n' "$output" | grep -qxF 'readfile=build.log'' failed

not ok 6 readfile requires every command in a pipeline or list to be a reader
# (in test file tests/probes-readonly-facts.bats, line 165)
#   `printf '%s\n' "$output" | grep -qxF 'readfile=build.log'' failed

not ok 7 merge=1 fires for a git merge-style command segment
# (in test file tests/probes-readonly-facts.bats, line 185)
#   `printf '%s\n' "$output" | grep -qxF 'merge=1'' failed

not ok 8 merge=1 does not fire for a non-merge command or a quoted mention
# (in test file tests/probes-readonly-facts.bats, line 195)
#   `printf '%s\n' "$output" | grep -qxF 'merge=1'' failed

not ok 9 merge=1 fires from git's partial-checkout error in the text, under any command
# (in test file tests/probes-readonly-facts.bats, line 213)
#   `printf '%s\n' "$output" | grep -qxF 'merge=1'' failed

not ok 10 target and match select files at the resolved ref, staged or not, never one edited otherwise
# (in test file tests/probes-readonly-facts.bats, line 233)
#   `printf '%s\n' "$output" | grep -qxF 'target=feat'' failed

not ok 11 an unresolvable ref gives merge=1 and no target
# (in test file tests/probes-readonly-facts.bats, line 252)
#   `printf '%s\n' "$output" | grep -qxF 'merge=1'' failed

not ok 12 the repository is the path's nearest existing directory's, not the cwd's
# (in test file tests/probes-readonly-facts.bats, line 268)
#   `printf '%s\n' "$output" | grep -qxF 'target=feat'' failed

not ok 13 nopath falls back to the cwd's repository
# (in test file tests/probes-readonly-facts.bats, line 281)
#   `printf '%s\n' "$output" | grep -qxF 'target=feat'' failed

bats: 0 passed, 13 failed
```

Notes on where each test lands its red, since several combine a negative
(currently vacuously true — no fact is printed at all yet) with a positive
that fails for real; bats stops a test at its first failing assertion, so the
negative legs below are unexercised until GREEN:

- Test 4 (`readfile requires a command-output extension`) reds at its second
  block: `cat notes.md` correctly prints no `readfile=` today (vacuously —
  nothing does), then `cat build.log` fails to print `readfile=build.log`.
- Test 5 (`readfile excludes an in-place editor and redirected output`) reds
  at its second block (`sed s/a/b/ build.log` expects `readfile=build.log`);
  its `sed -i …` and `cat build.log > copy.txt` negatives are vacuously true
  ahead of it and unexercised after it.
- Test 6 (`readfile requires every command in a pipeline or list to be a
  reader`) reds at its second block (`tail build.log | grep -i error` expects
  `readfile=build.log`), same shape.
- Test 8 (`merge=1 does not fire for a non-merge command or a quoted
  mention`) reds at its *first* block, a positive (`git pull` expects
  `merge=1`), placed first precisely so the test does not red vacuously; its
  two negatives (`git log --merges`, `echo git merge feat`) are unexercised
  until GREEN.
- Test 3 (`facts appear only under writable and nopath, never readonly`) reds
  at its writable-outcome block (`cat build.log` expects `readfile=build.log`
  before any chmod); its `readonly` leg (asserting no facts print there) is
  unexercised — that assertion is currently vacuously true (no outcome prints
  any fact yet), which is exactly why it rides behind the writable assertion
  in the same test rather than standing alone.

All thirteen reds are failed value assertions (`grep -qxF` finding no
matching line) or `run !` finding a line that should be absent already
present for other reasons — never `ImportError`/`command not found`/exit 127.
`$status` was 0 and `$stderr` empty throughout (verified by hand for the
`writable`, `nopath` and `readonly` outcome shapes reused across these tests:
`cat /w/build.log` against a nonexistent-under-writable-parent path yields
`writable`/`path=…`; the same fixture with its quoted segment stripped yields
`nopath`; a `chmod 444` file yields `readonly`/`path=…`, verified enforced
before relying on it).

## Mutation proof

None needed: no test in this batch passed on the unmodified `lib/probes-
readonly.sh` (it emits only `outcome` and `path=`, so every fact assertion
here fails for real; see per-test output above).

## State at end of dispatch

`lib/probes-readonly.sh`, `lib/probes.sh`, `hooks/annotate.sh` are byte-
identical to before this dispatch (`git status` shows no change to any of
them). Only `tests/probes-readonly-facts.bats` was added; `tests/probes-
readonly.bats` and `tests/helpers/probes.bash` were read but not edited.
Nothing committed.
