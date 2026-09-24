# Item 2.3 slice 7 — code review

Scope: `git show HEAD -- hooks/annotate.sh` (commit `Item 2.3/7 — 2 KB
context cap`), read with the whole script. Fixes applied in the working
tree; nothing committed. `lib/` is byte-identical to HEAD.

## Verdict

The cap is correct against FR-6: skip-and-continue, catalogue order, the
joining newline counted, bytes not characters, human line kept on the
common path. One minor defect (the degenerate all-dropped case lost the
human lines), one comment that asserted a false bash 3.2 mechanism, and a
restore question that turns out to be exact in effect. No critical or major
findings.

## Findings

### 1. Minor, fixed — an all-dropped context exited silently, losing the human lines

`[ -n "$context" ] || exit 0` after the loop. When every paragraph is
dropped, which happens only when the first paragraph alone is over
2048 bytes, `context` is empty and the hook printed nothing. That discarded
the human lines FR-6 says are kept ("a paragraph that would push
`additionalContext` past 2 KB is dropped while its human line is kept"). In
production it cannot happen: FR-6 bounds each verdict under 400 characters,
which is at most 1600 bytes even at four bytes a character, and
`verdicts.bats` asserts that bound. The code still encoded "no context → no
output", which contradicts the requirement, so it is fixed and not just
noted.

**Fix:** `[ -n "$context$human" ] || exit 0`, with a one-line comment. It
exits only when there is nothing on either channel. So slice 9's
`no-such-detector` alone, which leaves both empty, still yields empty stdout.
The object keeps the Interfaces shape, with `additionalContext` as the
empty string rather than omitted. I verified this by hand on a copied tree
with `verdict_phantom_gitadd` stubbed to a 2100-byte paragraph and the
gitadd fixture alone. The output was
`{"hookSpecificOutput":{"hookEventName":"PostToolUseFailure","additionalContext":""},"systemMessage":"stub — big"}`,
with exit 0. Every output the old guard produced is unchanged, because the
new guard is strictly weaker.

### 2. Minor, fixed — the comment's bash 3.2 claim is false, and the code does not depend on it

The comment said that under bash 3.2 an `LC_ALL` assignment "takes effect
from the *next* simple command on, not within the one doing the
assignment". bash-3.2's source (`ftp.gnu.org/gnu/bash/bash-3.2.tar.gz`)
says otherwise:

- In an assignment-only simple command, `expand_word_list_internal`
  (`subst.c:8047-8050`) expands and performs each assignment in order
  through `do_word_assignment`.
- `do_assignment_internal` calls `stupidly_hack_special_variables (name)`
  right after `bind_variable` (`subst.c:2345`). That reaches `sv_locale` and
  then `set_locale_var`, which calls `setlocale (LC_ALL, …)` at once
  (`locale.c:178`).
- `${#var}` is `MB_STRLEN`, which is `MB_CUR_MAX > 1 ? MBSLEN : STRLEN`
  (`include/shmbutil.h:44`). The count therefore follows the new locale
  from the next word onward.

So `LC_ALL=C n=${#s}` on one line counts bytes on 3.2 as well. Bash 5.2.37
here agrees. On `s='a—b'`, three forms gave 5: the committed four
statements, the single assignment-only command, and the semicolon-joined
line. The form that really fails is a prefix on a command word,
`LC_ALL=C printf %s "${#s}"`, which gave 3. The command's words are
expanded before its temporary environment is applied. The committed code
uses separate statements, which are correct under every reading. Only the
comment was wrong.

I had no bash 3.2 binary here, so the 3.2 conclusion comes from reading
the source, not from running it.

**Fix:** the comment went from 12 lines to 5. It keeps the FR-6 rule
(joining newline included, human line already kept), says why the count
runs under `LC_ALL=C` (em dashes, `${#var}` counts characters under a UTF-8
locale, no fork), and adds the one line the restore needs (finding 3). The
false mechanism is gone. The comment also used `--` where the other
comments use prose.

### 3. Note, no code change — restoring an unset `LC_ALL` to empty

`LC_ALL=$lc_all_save` leaves an `LC_ALL` that was unset on entry set but
empty. In effect this is the same as `unset LC_ALL`:

- **The shell's own locale.** `set_locale_var` treats an empty value
  exactly as it treats unset. `unset` reaches `sv_locale` with a NULL value,
  which sets `lc_all = ""`. Both paths then call `reset_locale_vars`, which
  re-derives the locale from `LANG` and `LC_*` (`locale.c:168-178`,
  `variables.c:4182-4191`). POSIX likewise ignores a null `LC_ALL`. On bash
  5.2, `${#s}` read 3 again after the restore.
- **The `jq` call that follows.** The variable is exported only if it was
  exported on entry. With `LC_ALL` unset on entry, a child's `env` showed no
  `LC_ALL` after the restore (0 lines). With `LC_ALL=C.UTF-8` exported on
  entry, the child saw `C.UTF-8` again.
- **What differs.** Only `${LC_ALL+set}`, which nothing in the hook reads.

A conditional restore (`${LC_ALL+x}` then `unset`) would be exact in form
but would add lines to buy nothing observable. It is left as it is, and
the comment now says so in one clause, so the next reader does not reopen
the question.

### Checked, no finding

- **Drop rule against FR-6.** The candidate is
  `${context:+$context$nl}$para`, so the joining newline is counted. The
  first paragraph is measured alone. `continue` leaves `context` untouched,
  so a later, smaller paragraph is still tried (skip-and-continue).
  Iteration follows `detect`'s catalogue order. The comparison is `-gt 2048`,
  so a context of exactly 2048 bytes is kept.
- **Human line.** It is appended before the cap check, so it is kept
  whether or not the paragraph is.
- **bash 3.2 / NFR-2.** No fork, no array, no `local`. The locale switch
  covers just the one statement and is restored before the next verdict
  subshell and the final `jq`.
- **NFR-3.** The cap adds three assignments and a test per verdict, with no
  process.
- **Whitespace.** Every expansion is quoted.

## Mutation run (the one permitted)

I deleted the line `  LC_ALL=$lc_all_save` from HEAD's `annotate.sh` by
exact replacement, then ran
`scripts/run-bats.sh tests/hook-cap.bats tests/hook.bats`. The result was
**15 passed, 0 failed**, so the tests did not red. I restored the line by
the inverse replacement, and `git diff --quiet hooks lib` exited 0 before
any fix was applied.

The survival is expected, because the restore has no observable output
today. A hook left in `C` still gives byte-identical results:

- verdict text is literal `printf` output;
- the newline splits are byte-wise;
- `jq` encodes UTF-8 whatever the locale.

The restore is hygiene against a future locale-sensitive step. It does not
guard present behaviour.

## Test gaps (reported, test files not touched)

- **All-dropped context (finding 1).** No case sends a single paragraph
  over 2048 bytes. Suggested case for `tests/hook-cap.bats`: stub
  `verdict_phantom_gitadd` to about 2100 bytes and run the gitadd fixture
  alone. `additionalContext` should be `""` and `systemMessage` the stub's
  human line. This would red against HEAD, which printed nothing.
- **The `LC_ALL` restore.** It is unpinned by outcome (see the mutation
  run), and there is nothing observable to assert until a locale-sensitive
  step follows the cap.
- **Stop at first overflow versus skip and continue.** Still open, as the
  test review recorded (finding 8). Telling them apart needs three
  paragraphs, which Item 4.1's lock verdicts will supply.
- **No test runs under bash 3.2.** The finding 2 conclusion rests on the
  source, as NFR-2's other 3.2 claims do.

## Refactor flag

None.

## Files changed

- `hooks/annotate.sh`: cap comment cut from 12 lines to 5 and corrected;
  the post-loop guard is now `[ -n "$context$human" ]`, with a one-line
  comment.
- `plans/sandbox-lies/reports/item-2-3-s7-code-review.md` (this report).

## Verification

- `shellcheck hooks/annotate.sh` and `bash -n`: clean.
- `scripts/run-bats.sh tests/`: 86 passed, 0 failed.
- `direnv exec . just precommit`: `precommit passed: plugin.json,
  hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests`.
