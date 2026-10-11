# Fix M2 — pin content of a word past the 256-char flush

Case added to `tests/probes-readonly-globs.bats` (207 of 400 lines; the suite
already loads `helpers/bsd-stubs`; no stubbed tool is called by the code under
test, so no BSD re-run case). No suite called `_readonly_tokenize` directly;
the new case calls it and reads `_readonly_tokens`.

Case: "an unquoted word past the 256-character flush keeps its content". Input
`cat <600-char word> x.log`, the word being the numbers 00001 to 00120 in five
digits. Asserts three tokens, exact `wcat`, `w<word>` (exact content, length
601), `wx.log`, and `_readonly_tokens_cut` 0.

State that fails it: a pending run dropped, repeated or reordered at either of
the two flushes the word crosses. Nothing else changes the exact content of a
non-repeating word.

## Mutation proof

1. Mutation, one exact replacement (occurs once) in
   `lib/probes-readonly-command.sh` line 44:
   `|| { word="$word$run"; run=''; }` to `|| { run=''; }` (run dropped at the
   top flush).
2. Landed: `command grep -n "|| { run=''; }"` found line 44.
3. Red on its own assertion: `not ok 14 an unquoted word past the 256-character
   flush keeps its content`, `[ "${#_readonly_tokens[1]}" -eq 601 ]' failed`;
   other 13 cases green.
4. Restored by the reverse replacement (script, not a backup or git).
5. Restore proven: `command grep -c "|| { run=''; }"` gave 0, line 44 reads the
   original, suite 14 passed, 0 failed.

## Precommit recap

`just precommit` unsandboxed, foreground, exit status 0: "precommit passed:
plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, python
compile, tests"; bats 416 passed, 0 failed. A first run failed shellcheck
SC2154 on the two tokenizer globals; the case now copies them into locals under
one disable with its reason. The mutation proof ran before that refactor; the
assertions are unchanged.
