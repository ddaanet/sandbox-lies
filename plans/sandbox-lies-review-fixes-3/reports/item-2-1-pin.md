# Item 2.1 pin — set -e survivor (code review item 5)

Mode: GREEN (mutation-killing). One test added, one survivor pinned. No lib
change, no other test touched.

## Test added

`tests/probes-readonly-resolve.bats`:
`probe_readonly_path under set -e prints nopath and exits 0 when no line matches`

Runs `bash -c 'set -e; source "$1"; printf "%s\n" "$2" | probe_readonly_path false "$3" x'`
with `$2` = `plain text, no refusal` and `$3` = `$BATS_TEST_TMPDIR`. Asserts
status 0 and first output line `nopath`.

State that fails it: `probe_readonly_path` aborts under errexit on a text with
no matching line (the `|| line=` guard removed), leaving exit 1 and empty output.
What else could produce the same red: a missing `lib/probes.sh` would fail on
`source` with a different status; the case checks status before the output line,
and the unchanged code is green, so the assertion, not the setup, is what reds.

## Mutation proof

Survivor 5 from `item-2-1-code-review.md`.

- Old string (occurs once in `lib/probes-readonly.sh`, verified by
  `command grep -c` = 1): `_readonly_path_line) || line=`
- New string: `_readonly_path_line)`
- Landed: `command grep -n` shows line 51 as
  `line=$(printf '%s\n' "$text" | _readonly_path_line)` with no guard.
- Red on its own assertion:

  ```
  not ok 1 probe_readonly_path under set -e prints nopath and exits 0 when no line matches
  # (in test file tests/probes-readonly-resolve.bats, line 163)
  #   `[ "$status" -eq 0 ]' failed
  ```

- Restore: the replacement applied with the strings swapped (new old-string
  `_readonly_path_line) || line=` with the next line as context, since the bare
  `_readonly_path_line)` also occurs in a comment at line 19 and the bare swap was
  ambiguous and refused by the Edit tool).
- Restore proof:
  - `command grep -c '_readonly_path_line)$'` = 0 (mutation text absent)
  - `git diff --stat -- lib` empty, `git diff -- lib | wc -c` = 0
  - `bats -f 'under set -e prints nopath'` = `ok 1`

## Case green on the restored code

`bats -f 'under set -e prints nopath' tests/probes-readonly-resolve.bats`:
`ok 1 probe_readonly_path under set -e prints nopath and exits 0 when no line matches`

## Gate

`just precommit` (unsandboxed, foreground; moved to background by the harness
at 120 s, read on completion): exit status 0.

Recap line:
`bats: 399 passed, 0 failed`
`precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, python compile, tests`

Warnings: none reported.
