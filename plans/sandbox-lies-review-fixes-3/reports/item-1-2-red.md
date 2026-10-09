# Item 1.2 RED — slices 1-4 (one group)

Nothing under `lib/` is touched (`git diff --stat -- lib` empty). Tests added
to three files; no new bats file (`tests/verdicts-readonly.bats` ends at 348
lines, `tests/hook-writes.bats` at 154, `tests/verdicts-locks.bats` at 241).
Wire values are the probe's `%q` forms. Suites ran in the foreground, one file
at a time. The `shellcheck -s bats` run over the three files is clean.

## Result against the unchanged lib

8 new tests: 7 fail on their assertion, 1 is green (mutation proof below).
No `ImportError`, 127 or missing-symbol failure: every failure is a wrong
value in the verdict text, because the unchanged reader joins the wire form
verbatim.

| Slice | Test (file) | Failing line |
|---|---|---|
| 1 | hook names a blank-holding path raw, with no backslash (`hook-writes.bats`) | `[ "${ctx#"$expected"}" != "$ctx" ]` |
| 2a | readonly-path shows a UTF-8 path byte-exact from the `$'...'` form (`verdicts-readonly.bats`) | `[ "$line1" = "$expected$(readonly_path_tail)" ]` |
| 2b | readonly-path shows the wire form for a path holding a newline, in two lines | green, see Mutation proof |
| 3 | readonly-path matches the settings.json suffix on the decoded value | `text_lacks "$line1" 'dangerouslyDisableSandbox'` (the act check) |
| 3 | verdict_config_lock matches the settings.json.lock suffix on the decoded path (`verdicts-locks.bats`) | `grep -qF 'update-config'` |
| 4a | readonly-path decodes the backslash form without running what it holds | line 1 equality |
| 4b | readonly-path reads a malformed path value as no path | `value $'a'b gave: ` + backticked wire form + `Re-run the whole call ...` |
| extra | readonly-path reads an escaped quote in the `$'...'` form | line 1 equality |

Counts per run: hook-writes 4 passed 1 failed; verdicts-readonly 15 passed 5
failed; verdicts-locks 4 passed 1 failed.

## State of the world that fails each, and what else could cause the red

- **Slice 1.** Fails when the verdict prints `path=` with its `%q` escaping
  (`dir\ with\ blank`). Observed ctx on the unchanged lib: the path in
  backticks is `.../dir\ with\ blank/f`. Fixture: cp-tmp refusal text with the
  quoted path replaced by relative `'f'`, `cwd` a directory with a blank that
  exists and is writable, flag removed. Other causes of the red: a wrong
  outcome or path prefix. The expected prefix is the whole backticked absolute
  path plus the writable sentence, so a `nopath`/`readonly` outcome or a
  different resolved path would also red. The debug run showed neither: the
  only difference is the backslashes. The test also re-runs the hook under
  `make_bsd_stubs grep sed stat wc` and requires the same context (green now,
  guard for GREEN; the hook calls the stubbed tools).
- **2a.** Fails when `$'/x/caf\303\251/f'` is joined as-is. Else red only for
  a wrong tail or sentence, which the other cases pin green. The expected
  bytes are built from `$'\303\251'`, so no locale and no UTF-8 literal in the
  file.
- **3 (readonly).** Two failing facts in one line: the display (wire shown)
  and the act (generic re-run, because the wire value ends in `'`). The first
  assertion is the act check, so the red names the act. Two companion
  assertions are green now and discriminate for GREEN: a newline-bearing
  directory must keep the wire form shown and still select the act (the
  decoded value decides), and `settings.jsonx` must keep the generic act (the
  suffix match is not loosened).
- **3 (locks).** Fails when the `$'...'` value is matched undecoded (the wire
  ends in `'`, so `*/.claude/settings.json.lock` never matches). Run under
  both flags. The `config.lock` under `.git` control (same `$'...'` shape)
  keeps the flag-worded act: green now, guards a decoder that matches every
  `$'...'` value.
- **4a.** Fails when the `%q` form `/x/\$\(touch\ <sentinel>\)` is shown with
  its escapes. The sentinel lives under `$BATS_TEST_TMPDIR`; the test checks
  that directory is writable and the sentinel absent beforehand, and absent
  afterwards. The absence assertion is green now and only discriminates if a
  decoder runs the substitution (writable directory proven, creatable).
  Another cause of the red: none; the only variable is the shown text.
- **4b.** Fails because a value outside both grammars is joined verbatim. Four
  values in a loop: `$'a'b` (spec), unclosed `$'a`, `$'a\'` (the escaped quote
  eats the close), and `relative/path`. Only the first is observed red; the
  rest bind GREEN and are unobserved until it runs. The failure message names
  the value.
- **Extra, escaped quote.** `$'/x/it\'s/f'` must show `/x/it's/f`. Not in the
  outline's slice list: added because the Reader part names the `\'` step as
  version-sensitive and no listed case reaches it. Remove if the slice text is
  to be held literally.
- **Extra, control-byte suffix.** Described under 3 (readonly). Added because
  slice 2b is green on the unchanged lib (wire form is what it prints today);
  this case ties the control-byte display to decoding.

Verdict code (`lib/verdicts.sh`) calls no stubbed tool (`read`, `printf`, bash
patterns only), so the verdict-level files need no `make_bsd_stubs` re-run;
the hook case carries one.

## Mutation proof

Test: "readonly-path shows the wire form for a path holding a newline, in two
lines" (`tests/verdicts-readonly.bats`), green on the unchanged lib because the
verdict prints the wire value in backticks today. Two mutations, one per
assertion, each restored by the swapped strings.

1. Line-1 assertion.
   - String pair: `` subject="\`$path\`" `` to `` subject="\`MUTANT\`" ``
     (occurs once, `lib/verdicts.sh:167`).
   - Landed: `command grep -n MUTANT lib/verdicts.sh` gave line 167.
   - Red on `[ "$(printf '%s\n' "$text" | sed -n '1p')" = ... ]`.
   - Restored by the swapped pair; `command grep -n MUTANT lib/verdicts.sh`
     exit 1.
2. Two-line assertion.
   - String pair: `whose allowlist refused it.$rest"` to
     `whose allowlist refused it.$rest` + newline + `MUTANT"` (occurs once,
     line 208).
   - Landed: grep gave `209:MUTANT"`.
   - Line 1 unchanged, red on `[ "$(printf '%s\n' "$text" | sed -n '$=')" = 2 ]`.
   - Restored by the swapped pair; `command grep -n MUTANT lib/verdicts.sh`
     exit 1, `git diff --stat -- lib` empty, and the suite after restore shows
     the test green (15 passed, the 5 failures listed above).

This test only has force once GREEN decodes: a decoder that displays the raw
newline yields a three-line verdict and reds it.

## For GREEN

- Existing tests asserting a blank-named path in verdict text stay as they are
  (the dispatch says Item 1.2's GREEN adjusts them); none were edited here.
- `tests/docs.bats` passes with the new tests (no live diagnostic text).
