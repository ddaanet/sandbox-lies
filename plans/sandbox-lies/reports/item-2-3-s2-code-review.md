# Item 2.3 slice 2 — code review

Scope: `git show HEAD -- hooks/annotate.sh` (commit `Item 2.3/2 — success
text rebuilt from stdout and stderr`), read with the whole script. One fix
was applied in the working tree. Nothing is committed.

## Verdict

The rebuild is correct. For string fields it produces exactly FR-3's "stdout,
newline, stderr", except that `$(…)` strips trailing newlines, which does not
change what any matcher sees. No non-string value in either field can make
`detect` fire. There are no critical or major findings. There is one minor
comment fix, three notes that belong to later slices, and one test gap,
which a surviving mutation confirms.

## Probe of the jq expression

`jq -r '.tool_response.stdout // empty, .tool_response.stderr // empty'`,
captured by `$(…)` as the hook does it, byte-dumped with `od -c`:

| payload `tool_response` | jq exit | text |
|---|---|---|
| stdout `""`, stderr `x` | 0 | `\nx` |
| stdout `a\n`, stderr `""` | 0 | `a` |
| stdout `a\n`, stderr `b` | 0 | `a\n\nb` |
| stdout `a`, stderr `b` | 0 | `a\nb` |
| both `""` | 0 | empty, so the hook exits 0 |
| stdout absent or `null`, stderr `b` | 0 | `b` |
| stdout `false`, stderr `b` | 0 | `b` |
| stdout `true` / `42`, stderr `b` | 0 | `true\nb` / `42\nb` |
| stdout `{"k":"?? .bashrc"}` | 0 | pretty JSON, `  "k": "?? .bashrc"` |
| stdout `["?? .bashrc","?? .gitconfig"]` | 0 | pretty JSON, each name quoted and indented |
| `tool_response` `null` or absent | 0 | empty |
| `tool_response` `"x"` or `[1]` | 5 | `Cannot index string/array` on stderr; `\|\| exit 0` |
| stdout `a\u0000b` | 0 | `ab`, plus bash's `ignored null byte` warning on stderr |

Answers to the questions in the dispatch:

- **Empty stdout, non-empty stderr.** An empty string is truthy to `//`, so
  jq prints an empty line first and the text starts with a newline. That is
  literally `"" + "\n" + stderr`, the spec'd shape, and a leading blank line
  is inert: no matcher matches an empty line. `match_git_lock` is two
  independent greps and the rest are line-anchored, so adjacency never
  matters. `match_phantom_untracked` counts with `grep -c .`, which skips
  blanks.
- **stdout ending in a newline.** With stderr non-empty, the result is a
  blank line between the fields. That is again byte-exact to the spec, and
  inert for the same reasons. With stderr empty, `$(…)` strips every
  trailing newline, and `printf '%s\n'` restores one. Only trailing blank
  lines are lost, and no matcher can see them. The `error` arm has the same
  stripping.
- **`// empty` and `false`.** `false // empty` yields nothing. So do `null`
  and an absent field. `true` and numbers print as themselves.
- **Non-string fields reaching `detect`.** Scalars print as `true`, `42` and
  the like. Objects and arrays print as indented JSON, with every string
  value quoted and its newlines escaped. So no line of that output starts
  with raw payload content. It begins with an indent, a quote, a bracket or
  a JSON literal. `match_phantom_untracked` needs a masked name straight
  after `??` or after whitespace, `match_phantom_chardev` needs `c` plus
  nine mode characters, and the two `^error: ` matchers need `error` at the
  start of a line. None of these can be met. `match_git_lock` is unanchored,
  but it needs git's follow-on sentence, which a string inside JSON would
  still carry. A string field is where that text belongs anyway, so a
  non-string field cannot make it fire when the same content as a string
  would not. **No false fire.** The type guard stays with slice 6.

## Findings

### 1. Minor, fixed — the separator mechanism was implicit

The arm has no literal `"\n"`. The newline between the fields comes from
`jq -r` terminating each output of the comma operator. A reader checking
the code against the header ("stdout, a newline, and stderr") sees no
separator and could "fix" it. The test review's probe table needed a row
(J) to establish that this form is correct.

**Fix:** a one-line comment above the arm: `# jq -r ends each output with a
newline: that is the separator.` The header comment is accurate as written
(it matches `detectors.md` Conventions and FR-3) and is unchanged.

### 2. Note, for slice 6 — the field reads are not type-guarded

`// empty` drops `null`, `false` and absent fields, and lets `true`,
numbers, objects and arrays through as text. Per the probe above, none of
them can fire. A `tool_response` that is a string or an array makes jq exit
5 and print on stderr, and slice 6 asserts empty stderr for exactly that
input. Suggested shape for slice 6's parse rewrite:
`.tool_response | objects | (.stdout | strings), (.stderr | strings)`, placed
after the object guard on the payload. That makes the rule "strings only"
instead of "anything but null/false". Not implemented.

### 3. Note — NUL bytes

A NUL in either field, from a command that prints binary, is dropped by
`$(…)`. Bash 4.4+ also prints `warning: command substitution: ignored null
byte in input` on stderr. Dropping a NUL only merges bytes within a line,
so it can suppress a fire but never cause one. On exit 0 the stderr goes
only to the debug log (hook-authoring §output-channels). The `error` arm
behaves the same way, so this is not new in this slice. Slice 6's
empty-stderr cases do not include a NUL, so nothing reds. No fix.

### 4. Note — NFR-3 cost: this slice added the quiet-path `detect`, not only a jq

Before this slice, a `PostToolUse` payload exited right after the event
read. Now every successful Bash call runs a second `jq` and the whole of
`detect`. The timings below are from this box, as a mean of 20 runs of
`bash hooks/annotate.sh`:

| path | before (HEAD~1) | after |
|---|---|---|
| `quiet-clean-status` as a `PostToolUse` payload | 18 ms | 56 ms |
| `fire-masks-porcelain` as a `PostToolUse` payload | quiet | 66 ms |
| one bare `jq -r` over the payload | 6 ms | 6 ms |

This cost is inherent to the feature. The success path has to be read. The
verdict path is under NFR-3's 100 ms bound. The slice-1 refactor (fold the
event read and the text read into one jq call) is still worth about 6 ms per
call, now on every successful call rather than only on failures, so the
slice raised its payoff without making the code worse. Most of the quiet
path is `detect` itself: `mktemp`, five matchers, and the `grep | sed | sort
| grep` pipeline in `match_phantom_untracked`. The item paragraph already
takes `mktemp` out of `detect`. These timings are not the changelog figures
the item asks for, which are measured after the item lands.

## Mutation run (the one permitted)

The mutation was an exact replacement in `hooks/annotate.sh`, appending
`, .tool_input.command // empty` to the `PostToolUse` rebuild. This makes
the hook read the command as well as its output, which breaks the
Conventions rule that matchers never read the command.
`scripts/run-bats.sh tests/hook.bats` gave **6 passed, 0 failed**, so the
tests did not red. The replacement was inverted and `git diff --quiet hooks
lib` exited 0 before the fix was applied.

## Test gaps

- **Text drawn from outside `tool_response`.** This is the mutation above,
  and it matches the test review's finding 4. No case, in this slice or in
  slices 3–10 as specified, puts firing text in `tool_input.command` and
  asserts quiet. A command carrying a here-document of porcelain lines would
  fire under such a hook. Suggested case, which fits beside slice 5's quiet
  sweep: a `PostToolUse` payload with quiet stdout and
  `fire-masks-porcelain.txt` as `tool_input.command` yields empty stdout;
  likewise a failure payload with the text in `tool_input.command`.
  Reported, not written.
- **Absent or non-string fields.** No case covers them. They are inert per
  the probe. Slice 6 owns the malformed shapes, and its case list covers a
  string `tool_response` but not a non-string `stdout`.

## Refactor flag

Unchanged from slice 1: fold the event and text reads into one `jq` call
inside slice 6's parse rewrite. It needs no module split. See finding 4 for
what it is worth.

## Files changed

- `hooks/annotate.sh`: a one-line comment above the `PostToolUse` rebuild.

## Verification

- `scripts/run-bats.sh tests/` gave 74 passed, 0 failed.
- `direnv exec . just precommit` exited 0, printing `precommit passed:
  plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links,
  tests`.
