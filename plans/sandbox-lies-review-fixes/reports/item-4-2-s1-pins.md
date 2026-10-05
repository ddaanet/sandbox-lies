# Item 4.2 slice 1 pins - trailing-slash fix

## The case

`tests/probes-readonly-members.bats`, after "match= names are absolute from a
subdirectory cwd": "match= names carry no doubled slash from a cwd with a
trailing slash". It builds a scratch repo, runs `probe_readonly_path` under
nopath (empty refused path) with cwd `<repo>/` and `git merge feat`, and
asserts status 0, empty stderr, first line `nopath`, and the `match=` lines
equal to exactly `<repo>/a`, `<repo>/b`, `<repo>/e f`. The file is 241 lines.

## Mutation proof

Mutation: in `_readonly_git_dir`, the strip loop body `dir="${dir%/}"` was
replaced by `break` (a first attempt, `:`, looped forever and was killed by
timeout; it was restored). With `break`, the new case failed on its own
assertion, tests/probes-readonly-members.bats line 101:
`[ "$(printf '%s\n' "$output" | grep '^match=')" = "$expected" ]`. The other
ten cases passed. Restored by an inverse replacement with one-occurrence
assert (`break` occurs four times in the file, so the restore was anchored on
the loop head); `git diff --stat lib/` was empty afterwards.

## Gate

`just precommit` exit 0: `bats: 301 passed, 0 failed`; `shellcheck -x` on the bats file exit 0.
