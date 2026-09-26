# Review: Item 8.0 slice 2 — code review

**Scope**: implementation in commit 3fcd18b — `hooks/annotate.sh`,
`lib/verdicts.sh` (tests out of scope, untouched)
**Date**: 2026-09-26
**Mode**: review + fix

## Summary

The hook now parses `tool_input.command` with the cwd's escaping and passes it
as every probe's third argument; `verdict_readonly_path` composes the
`writable`/`nopath` tail from the probe's facts. The parse cannot error on any
payload I tried. The composition matches detectors.md word for word for every
fact combination. Probe values are joined by plain expansion only. Two minor
issues were found and fixed; neither changes behaviour.

**Overall Assessment**: Ready

## Checks performed

- **Parse cannot error.** The extracted jq program plus the split ran against
  these `tool_input.command` values: an object, an array, `null`, absent, and a
  `tool_input` that is `null` or an array (all read as empty); an embedded NUL
  (dropped); a command made only of three newlines; backslash sequences `\n`,
  `\\`, `\c`, `\x41`, `\0101`, `A`, and a trailing backslash; a leading
  `-e` and a `%s`; non-JSON; a scalar payload. Every run exited 0 with nothing
  on stderr, and each command came back byte-exact (compared with `%q`).
  - The jq expression uses `objects | .command | strings` with `// ""`, the
    same shape the cwd already uses, so a non-object `tool_input` never
    reaches an index. `//` binds tighter than `|`.
  - Every backslash is doubled before `printf %b`, so no lone `\c` or octal
    escape can reach it.
- **The four-line split.** With no text part, `$(...)` strips the trailing
  newlines and leaves three. The case pattern then fails, `text` stays empty
  and the hook exits silent, which is the correct result. A command made only
  of newlines is encoded as `\n` escapes and never moves a split point.
- **Every probe still gets flag and cwd.** The call is
  `"$probe_fn" "$flag" "$cwd" "$command"`. `probe_git_lock` and
  `probe_config_lock` read `$1` and `${2-}` only, and `probe_readonly_path`
  reads `${2-}`. No probe reads `$@`, `$*` or `$#`, so the extra argument
  cannot change what a lock probe does.
- **Wording against detectors.md §readonly-path Verdicts.** I checked every
  outcome (`writable` and `nopath`) against:
  - readfile= present or absent;
  - path= a `.claude/settings.json` or not;
  - merge=1 absent, alone, with target=, with target= and 1, 5 or 7 match=
    lines.

  All of these match:
  - the three acts and their precedence;
  - capitalised when the act stands alone, lowercase after a merge clause;
  - both merge-clause texts, including `— they match \`<t>\` —, then`;
  - no clause when target= is present without match=;
  - five names, then `and N more`.

  `readonly` ignores every fact. The `*/.claude/settings.json` pattern is
  right because `_probe_readonly_resolve` always makes path= absolute.
- **Values are byte-exact.** path=, readfile=, target= and match= values
  containing `%s`, `%b`, `\1`, `&`, `\\`, `\c`, a leading `-n`/`-e` and a
  leading blank all came through byte-exact. They pass through `printf '%s'`
  arguments and `${line#key=}` only: no printf format, no sed, no eval.
- **FR-6.** The longest composition is under 400 characters with
  one-character values (covered by a test). Long match names can push a
  paragraph past the 2 KB cap, and the hook then drops it and keeps its human
  line, as FR-6 intends.
- **NFR-2 / NFR-4.** Nothing new in these files needs bash above 3.2 (`+=` on
  arrays dates from bash 3.1). `"${matches[@]}"` is expanded only after the
  `${#matches[@]} -gt 0` guard, which avoids the `set -u` unbound-variable
  error that bash below 4.4 gives an empty array. There is no bash 3.2 binary
  on this box, so that guard rests on reading the code, not on a run. The
  change adds no here-document and no write.
- **D-7.** No composition tells the agent to remove anything; the clauses
  say "restore".

## Issues Found

### Critical Issues

None.

### Major Issues

None.

### Minor Issues

1. **Header comment restated the spec as narration**
   - Location: `lib/verdicts.sh`, the `verdict_readonly_path` header, second
     paragraph.
   - Note: an 11-line prose copy of detectors.md's tail and merge-clause
     rules. It would drift from the spec, and it described what the code does
     rather than stating a constraint. It also left out the one constraint the
     code does not show: why each act is spelled twice.
   - **Status**: FIXED. Cut to a pointer to detectors.md, the list of fact
     keys, and the constraint that each act is spelled twice because bash 3.2
     has no case conversion.
2. **Unneeded SC2016 disables on double-quoted strings**
   - Location: `lib/verdicts.sh`, the two readfile `act`/`act_low`
     assignments.
   - Note: SC2016 is about single-quoted strings. These two strings are
     double-quoted with escaped backticks, so the directives suppressed
     nothing. The merge-clause assignments, also double-quoted, carry none.
   - **Status**: FIXED. Removed both; shellcheck is still clean.

## Fixes Applied

- `lib/verdicts.sh` `verdict_readonly_path` header: the composition paragraph
  now states only the spec pointer, the fact keys and the bash 3.2 constraint.
- `lib/verdicts.sh`: removed the two `# shellcheck disable=SC2016` lines above
  the double-quoted readfile acts.

## Mutated-SUT run

- **Mutation**: an exact-string replace in `hooks/annotate.sh` removed the
  backslash doubling from the `$cmd` jq expression, keeping only the newline
  escape.
- **Run**: `tests/hook-candidates.bats` and `tests/hook-locks.bats`.
  - `every probe receives tool_input.command byte-exact` went red.
  - `probe receives flag, cwd and command` in hook-locks.bats stayed green. Its
    command is `c`, so it checks that the argument is present, not its
    escaping. The byte-exact test covers the escaping.
- **Restore**: I inverted the same replacement, confirmed the original line
  with `command grep` (count 1), and `git diff` came back empty before any
  fix was applied.

## Requirements Validation

| Requirement | Status | Evidence |
|---|---|---|
| FR-4 (probe receives command as `$3`) | Satisfied | `hooks/annotate.sh` probe call; hook-candidates byte-exact test |
| FR-6 (acts only, under 400, 2 KB cap) | Satisfied | composition tests; hook cap unchanged |
| D-17 (script decides the acts) | Satisfied | `verdict_readonly_path` fact-driven tail; no conditional prose remains |
| D-7 (no removal) | Satisfied | the composition test's D-7 grep |
| NFR-2 / NFR-4 | Satisfied | no bash ≥ 4 construct, no here-document |

## Gate

`just precommit` exit 0: plugin.json, hooks.json, shellcheck, bash -n, rumdl,
line limits, links, tests (213 passed, 0 failed).

## Positive Observations

- The command reuses the cwd's escaping and its jq type guards, so there is
  one encoding to reason about.
- `_readonly_match_list` builds the list from `"$@"`, so a match name with
  blanks or a leading `-` stays whole.
- The act precedence reads straight off the code: readfile= is tested first,
  then the `outcome:path` case.
