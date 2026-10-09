# Review: Item 1.2 code (d16cbb5) and the Phase 1 boundary

**Scope**: `lib/verdicts.sh` (`_verdict_path_read`, `_verdict_has_control`, the
two consumers) and its tests in commit d16cbb5; as the Phase 1 boundary,
`git diff d6d0043..HEAD -- lib tests` (Items 1.1 and 1.2).
**Mode**: review + fix. Nothing committed.
**Requirements**: FR-4, FR-6, NFR-4, D-7. Design: `outline.md` section A and
Items 1.1, 1.2. Scope OUT honoured: comments and docs stating the old contract
(Item 7.7, Phase 7), Items 2-7.

**Overall Assessment**: Ready. The decoder is correct and eval-free. Three
mutations survived the committed tests, one seam had no end-to-end pin; all
four are now tested and re-proved red. No lib change was needed.

## Summary of checks

- `command grep -n eval lib/verdicts.sh`: three hits, all comment text (lines
  141, 155, 188). No `eval`, no `source`, no word-context expansion of a wire
  value: the value reaches only `read` (as data, from a process
  substitution), a regex match, a pattern substitution with pattern and
  replacement in variables, and `printf -v ... %b "$body"` (an argument,
  never the format).
- `shellcheck lib/verdicts.sh lib/probes.sh lib/probes-readonly.sh`: clean.
  `shellcheck -s bats` clean on the two test files edited.
- bash 3.2.0 (`/tmp/claude/bash32/bash`), shipped `lib/verdicts.sh` sourced,
  one `$'...\n...'` value (`$'/x/a\nb/it\'s\'t/f\303\251'`, two escaped quotes,
  a newline, a UTF-8 byte) and one backslash value (`/x/a\ b\&c\\1/f\ `,
  trailing escaped blank): decoded bytes (`od -c`), shown form, return status,
  the `verdict_readonly_path` first line and the `verdict_config_lock` act
  were byte-identical to bash 5.2.37, under `LC_ALL=C` and `LC_ALL=C.UTF-8`
  (four runs compared with `cmp`). The malformed `$'a'b` gives rc 1, both
  outputs empty, "The path". Under `set -euo pipefail` a malformed value
  does not kill a verdict (checked on 3.2.0 and 5.2).
- Whitespace safety: no word splitting of a wire value anywhere (every
  expansion is quoted; `IFS= read`). Blanks, double blanks, trailing blank,
  tab (`$'\t'` form, shown as wire), `&`, `%s`, `\1`, `${HOME}`, backticks,
  globs and a leading `-` round-trip in the committed test.
- `just precommit` (unsandboxed, foreground) after my edits: exit 0,
  "precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line
  limits, links, python compile, tests"; 390 bats passed, 0 failed.

## Mutation proof (Item 1.2, binding)

Method per row: exact once-occurring string replacement in `lib/verdicts.sh`
(driver `/tmp/claude/cr12/mut.py`, which asserts the old string occurs once and
the new text occurs zero times before writing), `command grep -nF` of the new
text to prove it landed, then the five files `tests/verdicts-readonly-path.bats`,
`tests/verdicts-locks.bats`, `tests/verdicts.bats`,
`tests/verdicts-readonly.bats`, `tests/hook-writes.bats` (foreground, one
process), restore by applying the swapped strings, `command grep -cF` of the
mutation text gave 0 and `git diff --stat -- lib` was empty after every row.
Every red below is a failed assertion (`[ ... ]`, `text_lacks`, `grep -qF` in
the test body), never an error or a missing symbol.

| Behaviour | Mutation | Result |
|---|---|---|
| `$'` grammar check | `[[ $wire =~ $re ]] \|\| return 1` to `... \|\| :` | red: malformed, forged, config-lock suffix |
| grammar body class | `re` loosened to `^\$'.*'\$` | red: malformed, forged |
| grammar anchor | closing `\$` of `re` dropped | red: malformed, empty-outputs, forged, config-lock |
| grammar, lone backslash | `[^'\\]` widened to `[^']` | red: malformed (`$'a\'`) |
| `$'` arm reachable | arm pattern `\$\'*)` to `\$\"*)` | red: 9 cases (UTF-8, newline, control, suffix, ...) |
| open quote strip | `body=${wire#\$\'}` to `body=$wire` | red: 7 cases |
| close quote strip | `body=${body%\'}` to `body=$body` | red: 8 cases |
| `\'` substitution | `${body//"$bq"/"$q"}` to `body=$body` | red: escaped quote, forged, BSD |
| `\'` substitution, every occurrence | `${body//...}` to `${body/...}` (first only) | **survived**, fixed (below), then red: escaped quote |
| `%b` decode | `printf -v ... %b "$body"` to body as format | red: `%q`-escapes round-trip (`%s%d`) |
| `%b` decode | `%b` to `%s` | red: 7 cases |
| control-byte display, never wire | `_verdict_path_shown=$wire` to `=$_verdict_path_raw` | red: newline, control bytes, suffix, BSD |
| control-byte display, always wire | `if _verdict_has_control ... \|\| :` | red: 11 cases incl. hook-writes blank path |
| control set, newline only | `*[[:cntrl:]]*` to `*$'\n'*` | red: control-byte case |
| control set, misses `\037` `\177` | range `\001`-`\036` | red: control-byte case |
| control set, misses `\001` | range `\002`-`\177` | red: 11 cases |
| control test locale | `local LC_ALL=C` to `C.utf8` | **survived**, fixed (below), then red: control-byte case |
| consumer display | `subject` uses `_verdict_path_raw` | red: newline, control, suffix, BSD |
| backslash-form read | `read` gains `-r` | red: backslash sentinel, round-trip, BSD, writable-text |
| backslash-form read | `printf '%s\n' "$wire"` to `printf "$wire\n"` | red: round-trip, writable-text, readonly-text |
| backslash-form arm | `/*)` to `/NOPE*)` | red: 20 cases |
| `IFS=` on that read | `IFS=` to `IFS=$' \t\n'` | equivalent, not a defect: a wire opens with `/` and `%q` escapes every blank, and `read` keeps a backslash-escaped blank under default IFS; the trailing-blank round-trip case stays green |
| decoded-value suffix, `verdict_config_lock` | `case "$_verdict_path_raw"` to `case "$wire"` | red: config-lock suffix case |
| decoded-value suffix, `verdict_readonly_path` | `"$outcome:$_verdict_path_raw"` to `"$outcome:$path"` | red: suffix, malformed |
| fallback for malformed | `*) return 1 ;;` to keep the wire as a path | red: malformed, config-lock, two text cases |
| reset on a failed read | `_verdict_path_raw='' ...` to `:` | red: 14 cases (`set -u` unbound variable surfaces as wrong text) |
| reset, initialise only | to `: ${_verdict_path_raw=} ${_verdict_path_shown=}` | **survived**, fixed (below), then red: new empty-outputs case |
| probe seam (Phase 1 boundary) | newline guard put back on `probe_readonly_path`'s `nopath` arm (`lib/probes-readonly.sh`) | red only in the new hook case (below) |

Survivors and what killed them (`tests/verdicts-readonly-path.bats`):

1. **First-occurrence-only `\'` swap.** Every case held one escaped quote.
   The escaped-quote case now also feeds `/x/caf<e-acute>'a'b/f` and
   `/x/caf<e-acute>''\'/f` (two and three `\'` in one value), wires from
   `LC_ALL=C printf %q`.
2. **UTF-8 locale for the control test.** `\200` and `\377` are invalid UTF-8
   and are not `[:cntrl:]` even under a UTF-8 locale, so the `LC_ALL=C` the
   function sets was unobserved. `$'\302\200'` (U+0080, a valid C1 control
   that a UTF-8 `[:cntrl:]` matches) joins the "outside the set, shown
   decoded" loop of the control-byte case.
3. **Reader does not empty its outputs for a malformed value after a good
   read.** Production calls each verdict in its own `$( )`, so stale state is
   unreachable there, but the interface contract is "returns 1 with both
   empty". New case "_verdict_path_read empties both outputs for a malformed
   value after a good read": a good `$'` read, then `$'a'b`; asserts nothing
   is accepted and `[][]`.

After the fixes the survivors' mutations were re-run: G3 (first only), the
UTF-8 locale and the initialise-only reset each go red on their own new
assertion (`not ok 5`, `not ok 3`, `not ok 8` respectively; one failure each,
44 others green), restore proved as above.

## Issues Found

### Major

1. **Three mutation survivors in the decoder's tests.**
   - Location: `tests/verdicts-readonly-path.bats` (escaped-quote case,
     control-byte case, no reader-interface case).
   - Problem: see Survivors above.
   - **Status**: FIXED

2. **No test composes the real probe's `$'...\n...'` output with the verdict
   through the hook.** The probe side (`probes-readonly-members.bats`) and the
   verdict side (`verdicts-readonly-path.bats`) each use their own wire, and the
   one real-probe hook case with a newline cwd (`hook-locks-pathless.bats`,
   config lock) asserts only an absence. The headline outcome of Phase 1
   (a newline-bearing path gets its real outcome and one non-splitting
   paragraph) was pinned nowhere end to end.
   - Location: `tests/hook-writes.bats`.
   - Fix: new case "hook shows the wire form for a path holding a newline, on
     one line": real probe, relative refused path under a cwd whose name holds
     a newline, `additionalContext` equal to the whole one-line verdict with
     the wire form (from `LC_ALL=C printf %q`, guarded to be the `$'` form) in
     backticks. Proof: restoring the old newline `nopath` guard in
     `lib/probes-readonly.sh` reds it (and only it, within the slice's files).
   - **Status**: FIXED

### Minor

1. **Old-contract text left in comments** (`lib/probes.sh` header lines 12-13
   and the `_probe_lock_at` header, `lib/verdicts.sh` `verdict_readonly_path`
   header, `tests/hook-locks-pathless.bats` header and the `LOCK_PATH_LINE`
   fixture comment in `tests/hook-locks.bats`).
   - **Status**: DEFERRED (Item 7.7 / Phase 7, scope OUT).
2. **`LOCK_PATH_LINE`, `path_line` in `verdicts-locks.bats` (lines 87, 133) and
   `stub_probe`'s `path=stub` are raw, not `%q`, values the real probe can no
   longer print.** Every consumer of those fixtures ignores `path=`
   (`_verdict_lock_present`, the git-lock verdict) or asserts only the
   systemMessage (`stub_probe readonly_path` cases), so no assertion depends
   on the value. Left as is.
   - **Status**: OUT-OF-SCOPE (assertions do not read the value; the old-contract
     commentary is Item 7.7)

## Phase 1 boundary: the `path=` contract across its surfaces

- **Print sites.** `command grep -rn 'path=' lib hooks scripts skills`: the only
  producer is `_probe_path_line` (`lib/probes-readonly.sh:93`). All six
  `_probe_lock_at` sites, and `probe_readonly_path`'s `writable`/`readonly`
  print, call it; `nopath` and the pathless config lock print no `path=`.
  No raw `path=$path` remains. `readfile=`, `match=`, `target=` keep their
  newline skips, as the outline scopes.
- **Consumers.** Only `verdict_config_lock` and `verdict_readonly_path` read
  `path=`, both through `_verdict_path_read`. `_verdict_lock_present` skips the
  line (`*=*[!0-9]*`; a `path=` value always opens with `/` or `$'`).
  `hooks/annotate.sh` never inspects it: it splits outcome from the rest and
  feeds the rest to the verdict. No other tracked script reads it.
- **Seam between enforcer and consumer.** Encoder `LC_ALL=C printf %q` and
  decoder were run against each other: the round-trip case builds wires with
  the encoder and asserts the decoder returns the original bytes for 12+
  hostile paths; the new hook case does it through the real probe. `%q`'s
  forms for an absolute path open with `/` or `$'` only; a relative payload
  `cwd` would not, and reads as "The path" (the specified fallback).
- **Stale intermediate-state assertions.** None. The 1.1 report lists none
  ("Temporary, reverted by Item 1.2: None"); the only tests that changed value
  between 1.1 and 1.2 are the two `verdicts.bats` cases, which now feed the
  `%q` wire and assert the decoded text. No test left asserting the
  backslash-escaped display (`command grep` for `\\ ` in `hook-*.bats` and the
  verdict suites finds probe-level wire assertions only).
- **Lifecycle.** The decoder uses a process substitution and no file; the
  sentinel cases create theirs under `$BATS_TEST_TMPDIR` (writable asserted,
  absence asserted before and after, removed by bats); the hook's "needs no
  temp dir" cases stay green. After my runs `git status` shows no new
  untracked file; my scratch directory `/tmp/claude/cr12` was removed.
- **In-scope refactors needing a decision:** none.

## Fixes Applied

- `tests/verdicts-readonly-path.bats` — escaped-quote case: two values with
  several `\'` each; control-byte case: `$'\302\200'` in the decoded-form
  loop, comment updated; new case for the reader's empty outputs (with
  `# shellcheck disable=SC1090,SC2154` and its reason). File is now 196 lines.
- `tests/hook-writes.bats` — new real-probe case for the newline path. File is
  now 175 lines.
- `lib/` untouched (`git diff --stat -- lib` empty).

## Requirements Validation

| Requirement | Status | Evidence |
|---|---|---|
| FR-4 / NFR-4 (one `path=` line per path, no file) | Satisfied | `_probe_path_line`; decoder uses process substitution only; hook "no temp dir" cases green |
| FR-6 / D-7 (decode and display; control bytes show the wire form) | Satisfied | `lib/verdicts.sh:146-183`; mutation table |
| Outline: no eval, grammar `^\$'([^'\\]|\\.)*'$`, `\'` swap in variables, `%b` with the value as argument | Satisfied | `lib/verdicts.sh:146-172`; 3.2.0 run |
| Outline: suffix matches on the decoded value | Satisfied | `verdict_config_lock`, `verdict_readonly_path`; G9/G10 red |
| Outline: malformed reads as no path, fallbacks apply | Satisfied | G1/G2/G11 red |

## Positive Observations

- The `LC_ALL=C` scoping in `_verdict_has_control` is the right call and
  correctly documented; the new U+0080 case now actually observes it.
- Pattern and replacement held in variables, as the outline prescribes for the
  3.2 `\'` divergence; output identical on 3.2.0 and 5.2.37 across locales.
- Test review's decoder matrix already killed 15 wrong decoders; this
  in-place run found only the three gaps that a hand-written reference
  decoder could not (quantifier of the substitution, locale, reset).
