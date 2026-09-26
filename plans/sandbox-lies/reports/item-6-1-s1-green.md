# Item 6.1 slice 1 — GREEN: path extraction widened

Mode: GREEN. Grew `_probe_readonly_path_from_line` in `lib/probes.sh` to
satisfy the nine new/changed cases in `tests/probes-readonly.bats` left red by
RED and widened by the test review. `probe_readonly_path` needed no change —
its empty-path branch, resolution and `test -w` logic are unaffected by a
wider extractor.

## Design

Single `sed -n` pipeline, one `s///p` + `t end` pair per accepted shape, tried
in order so an earlier, more specific rule shadows a later, more general one:

1. mv's `inter-device move failed: '<src>' to '<dst>'` — takes `<dst>`.
   Anchored on the literal `inter-device move failed: ` prefix, not just any
   `'X' to 'Y'` shape, so it does not fire on the pre-existing `first quoted
   path on the line` test's `cp: cannot create regular file '<a>' to '<b>'`
   line (that one falls through to rule 2 and keeps taking the first quoted
   segment, unchanged).
2. First ASCII single-quoted segment — the pre-existing rule, unchanged.
3. First UTF-8 curly-quoted segment (`‘…’`), matched as literal byte
   sequences rather than a bracket class: `[^‘]*‘\(.*\)’: .*`. A bracket
   class (`[^’]*`) decomposes the 3-byte quote under `LC_ALL=C` into three
   excluded single bytes, one of which (`0x80`) the test's `curly — target`
   em dash shares, so that shape was tried and confirmed to stay red before
   settling on the literal-sequence form (matches the test review's own
   contrast run).
4. bash's `line N: <path>: ` — anchored on the `line ` + digits + `: `
   locator.
5. dash's `cannot create <path>: ` — anchored on a digit immediately before
   `: cannot create `, not the bare substring `cannot create`. Needed because
   `cannot create` alone is also a substring of cp's `cannot create regular
   file '<path>'` and git's `cannot create directory ‘<path>’` once their own
   quotes are stripped (the `no quoted path` test does exactly that to the cp
   fixture); dash's own message always carries a digit locator
   (`sh: 1: cannot create …`) immediately before it, which neither of those
   does.
6. git's `error: could not lock config file <path>: `.
7. git's `fatal: cannot mkdir <path>: `.

Every unquoted capture is `\(.*\)` running to the sed leftmost-longest match's
last `: ` on the line, so a path holding a blank survives (the residual is a
path holding `: ` itself, matching `detectors.md`'s stated residual).

## Tests made to pass, in order

Implemented as one pipeline (all nine cases pass together), then verified one
at a time with `bats -f '<name>' tests/probes-readonly.bats`, in table order:

1. `curly-quoted mkdir path is extracted` — ok
2. `bash line-N path is extracted` — ok
3. `dash redirect path is extracted` — ok
4. `git config-lock path is extracted` — ok
5. `git mkdir path is extracted` — ok
6. `mv target path is extracted, not the source` — ok
7. `straight-quoted touch and ln keep their path` — ok
8. `unquoted path after an unlisted prefix stays nopath` — ok
9. `curly and unquoted paths survive BSD grep and sed` — ok

All eight pre-existing tests in the file stayed green throughout, individually
re-checked in the full-file run below — including `no quoted path` and
`quoted path off the matching line is ignored`, whose stripped-quote line
(`cp: cannot create regular file : Read-only file system`) is exactly the
near-miss the dash rule's digit anchor (item 5 above) was designed to reject.

## Full suite runs

- `direnv exec . bats --tap tests/probes-readonly.bats` (foreground): 17/17
  ok.
- `direnv exec . bats --tap tests/probes.bats tests/probes-edges.bats
  tests/probes-tools.bats tests/probes-config.bats tests/probes-readonly.bats`
  (foreground): 53/53 ok — no regression in the sibling probe suites that
  share `lib/probes.sh`.
- `direnv exec . just test` (foreground): `bats: 190 passed, 0 failed`.
- `shellcheck -x tests/probes-readonly.bats tests/helpers/probes.bash
  lib/probes.sh`: clean.
- Gate: `direnv exec . just precommit`, foreground, exit 0:
  `precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl,
  line limits, links, tests`. No warnings printed.

## Line counts (400 cap)

`lib/probes.sh` 382, `tests/probes-readonly.bats` 371,
`tests/helpers/probes.bash` 178 — all under the cap.

## Scope note

`docs/references/detectors.md`'s `readonly-path` Probe paragraph was already
edited (uncommitted) before this dispatch and needed no further change: the
implementation above matches its stated accepted forms and residual exactly.
`lib/verdicts.sh`, `hooks/annotate.sh`, `tests/hook-*.bats`, `tests/verdicts.
bats`, `memory/` and slices 2-4 (the verdict) were not touched, per scope.

No commit hash recorded here; this report rides the commit it names in its
own subject.
