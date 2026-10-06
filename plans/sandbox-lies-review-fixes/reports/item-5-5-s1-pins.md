# Item 5.5 slice 1 pins: report

New file `tests/hook-locks-pathless.bats` (about 100 lines, loads
`helpers/bsd-stubs`, staged by name). It holds four cases, the optional
end-to-end variant included (about 12 lines).

## Runs added

1. Config-lock mask with no path line, both flags: the outcome alone, exit 0,
   probe marker present, system message `config.lock` mask text, the flag's
   re-run wording, the other flag's wording absent, and no `update-config`.
2. Git-lock held with `pid=4242` and no path line: system message
   `index.lock` held by pid 4242.
3. Real config-lock probe, payload cwd of real newlines forging a settings
   path line: the context lacks `update-config`.
4. The mask case re-run under `make_bsd_stubs` (grep, sed).

## Mutation proof

Each mutation was one exact single-occurrence replacement, then the file run.

- Verdict reads an empty path as the settings path (in `lib/verdicts.sh`, the
  case pattern `*/.claude/settings.json.lock)` became
  `''|*/.claude/settings.json.lock)`): case 1 red at
  `printf '%s' "$ctx" | grep -qF -- "$rerun"` (line 53). Cases 2 to 4 green.
- The no-newline branch passes a forged rest (in `hooks/annotate.sh`,
  `probe_rest=""` became `probe_rest="path=/x/.claude/settings.json.lock"`):
  case 1 red at the same line 53.
- The rest passed to the verdict loses its pid prefix (in `hooks/annotate.sh`,
  `printf '%s\n' "$probe_rest" |` became
  `printf '%s\n' "${probe_rest#pid=}" |`): case 2 red at
  `[ "$sys" = 'index.lock — held by pid 4242' ]` (line 68).
- The newline guard in the probe disabled (in `lib/probes.sh`, the
  `if [[ $path == *$'\n'* ]]; then` test became `if false; then`): case 3 red
  at `assert_lacks "$ctx" 'update-config'`.

A first draft of case 3 passed under that mutation: the cwd carried literal
backslash-n, which the hook's encoder escapes again, so no newline reached the
probe. The payload now carries real newlines and the case went red as above.

## Restore proof

Every restore was the inverse replacement. After the last one, `command grep -c`
of the guard line in `lib/probes.sh` gave 1 and `git diff --stat lib/ hooks/`
printed nothing.

## Gate

`just precommit` exit 0: plugin.json, hooks.json, shellcheck, bash -n, rumdl,
line limits, links, tests (309 passed, 0 failed).
