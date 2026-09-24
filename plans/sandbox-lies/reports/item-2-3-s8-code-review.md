# Item 2.3 slice 8 — code review

Scope: `git show HEAD -- lib/matchers.sh hooks/annotate.sh`, read against the
whole of `lib/matchers.sh`. Fixes are applied in the working tree. Nothing is
committed.

## Verdict

The GREEN meets the slice's letter: no `mktemp`, no exit 2, and the header
comment is gone. But its reading route adds two defects. Both are fixed here:

- F1 is major.
- F2 is major.
- F3 is minor.
- F4 is minor.

F5–F7 are notes and open questions for the orchestrator.

## Findings

### F1 — Major, fixed: `read -r -d ''` stops at the first NUL, a silent false negative

`IFS= read -r -d ''` uses NUL as its delimiter, so `detect` sees only the text
before the first NUL byte. A firing line after a NUL is missed, with no stderr
and exit 1. The GREEN report claimed `$(cat)` "has the same limit". It does not:
`$(cat)` drops each NUL and keeps reading.

Probe on bash 5.2.37. The input was text, a NUL, and then a firing config-lock
line. The line was assembled at run time from two fragments.

| route | stdout | exit |
|---|---|---|
| HEAD (`read -r -d ''`) | empty | 1 |
| same input with the NUL replaced by `\n` | `config-lock` | 0 |
| HEAD~1 (`mktemp` buffer) | `config-lock`, plus bash's `ignored null byte` warning from `match_git_lock`'s `$(cat)` | 0 |
| fixed | `config-lock`, empty stderr | 0 |

The hook path is safe, because jq strips NULs before `detect`. The direct path
is not. `tests/docs.bats` (FR-11) runs `bash lib/matchers.sh` over every tracked
file, and any caller that sources the library also uses it. On that path a
NUL-bearing tracked file would pass the self-quiet sweep even when it holds a
firing line.

**Fix.** `{ text=$(LC_ALL=C tr -d '\000' <&3); } 3<&0`. The costs are one fork
and the byte reads that `tr` does in blocks (see F2).

- `LC_ALL=C` is there because macOS `tr` can reject invalid UTF-8 under a UTF-8
  locale ("Illegal byte sequence").
- `tr -d '\000'` is POSIX `tr` octal syntax and works on BSD.
- The fd-3 route and the group are there because of the closed-stdin case in F3.

The comment in `detect` records these choices.

I chose this over a fork-free loop that concatenates `read -d ''` chunks. That
loop keeps the per-byte cost from F2, so it is not actually cheaper.

### F2 — Major, fixed: `read -d ''` reads a pipe one byte per syscall, so a large quiet result is slower

bash's `read` does unbuffered reads when the delimiter is not newline and the
input cannot seek. In the hook, `detect` gets its stdin from a pipe. So the
GREEN turned one block `cat` into one `read(2)` per byte. The GREEN timed only
the 1 KB `quiet-clean-status` fixture, where this does not show.

In-process microbench, 200 iterations, piped input:

| input | `read -d ''` | `$(LC_ALL=C tr -d '\000')` | `mktemp`+`cat`+`rm` |
|---|---|---|---|
| 1 KB | 2.4 ms | 3.3 ms | 7.7 ms |
| 22.8 KB | 18.6 ms | 4.0 ms | 8.7 ms |

The Bash tool caps output near 30 KB, so the per-byte cost grows up to about
that size. The `tr` route costs about 1 ms more on a small result and is flat
above that.

Hook wall time, mean of 30 runs per cell, interleaved, three rounds. The
payloads were `quiet-clean-status` and a 22.8 KB quiet `tool_response.stdout`
(the head of `docs/design.md`). Every variant was quiet: 0 bytes of stdout.

| variant | 1 KB quiet (r1/r2/r3) | 22.8 KB quiet (r1/r2/r3) |
|---|---|---|
| HEAD~1 (`mktemp`) | 46.7 / 46.8 / 43.5 | 51.7 / 50.5 / 46.7 |
| HEAD (GREEN) | 48.5 / 43.5 / 44.4 | 68.4 / 61.2 / 65.0 |
| fixed | 46.0 / 44.9 / 44.1 | 52.3 / 50.7 / 58.2 |

On the small result the three variants cannot be told apart, because bash and jq
startup dominate. On the large result the GREEN regressed by about 15 ms, and
the fix brings it back to the old buffer's level. The box is noisy: r3 of the
fixed large case drifted.

**Pipelines vs redirections, also fixed.** `printf | match_x` forks a subshell
on both sides of each pipe. The matcher function runs in its own subshell, and
`grep` forks again inside it. I changed the five feeds to
`match_x < <(printf '%s\n' "$text")`. The matcher now runs in the current shell,
which saves one fork per matcher.

Per-feed microbench, 200 iterations, `grep -q` behind a function:

| feed | 1 KB | 22.8 KB |
|---|---|---|
| pipeline | 3.6 ms | 4.0 ms |
| process substitution | 3.3 ms | 3.2 ms |
| file redirection (old buffer) | 2.8 ms | 2.7 ms |

The saving is about 0.3–0.8 ms per matcher, which is marginal but free. Each
matcher still reads a `printf '%s\n'`, as the item specifies. The hook itself
already uses `< <(...)`. Process substitution goes through `/dev/fd`, which
exists on both Linux and macOS, so no FIFO is created. On a system without
`/dev/fd`, bash would fall back to a FIFO in `$TMPDIR`. The temp-dir tests would
not see that.

### F3 — Minor, fixed: stdin handling on a read failure

The read's exit status is unchecked by design. Probes on HEAD:

- With stdin closed (`<&-`), `read` failed. That left `local text` unset, so
  `set -u` printed `text: unbound variable` five times. Exit 1.
- With stdin a directory, the same happened.

My first fix, a bare `text=$(tr …)`, **hung** with stdin closed. The command
substitution's pipe takes the free fd 0, and `tr` then reads its own pipe.
Confirmed with `timeout 5`, rc 124.

A bare `text=$(… <&3) 3<&0` does not help either. On an assignment-only command,
bash expands the substitution before it performs the redirection, so `tr` found
fd 3 closed.

The shipped form puts the redirection on a brace group, which is applied before
the body runs. `text` is initialised to `''`. Results after the fix:

| stdin | stderr | stdout | exit |
|---|---|---|---|
| closed | one `0: Bad file descriptor` line | empty | 1 |
| directory | one `tr: read error: Is a directory` line | empty | 1 |
| empty | none | empty | 1 |

On whether this is acceptable for the 0 fired / 1 none contract, see F6.

### F4 — Minor, fixed: hook comment left over from exit 2

`hooks/annotate.sh` said "Non-zero means nothing fired; the hook stays silent
either way". "Either way" was left over from the two-cause wording. It now reads
"Non-zero means nothing fired, so the hook stays silent."

### F5 — Note: trailing newline

On HEAD, `read -d ''` kept the input's final newline and `printf '%s\n'` added
another, so every matcher saw a trailing blank line. I checked each matcher
against that:

- `config_lock` and `gitadd` are anchored to `^error:`.
- `chardev` needs a `c` mode.
- `git_lock` needs two non-blank patterns.
- `untracked` needs a masked name on the line, and its at-least-2 counter ends
  with `sort -u | grep -c .`, which ignores blank lines.

So the blank line was harmless for every matcher. After the fix, `$(…)` strips
all trailing newlines and `printf` adds exactly one. That is the byte shape the
hook fed the old buffer.

A direct-run input without a final newline still fires. I probed the config-lock
line with no newline: `config-lock`, exit 0.

### F6 — Open question: should a read failure answer "none fired"?

The runbook drops exit 2 along with the buffer, so `detect` now returns 1 on a
read failure. In the hook this path cannot happen, because stdin is a pipe from
`printf`. In `tests/docs.bats` the failure is visible only on bats' stderr. The
sweep would count the file as quiet, and its `status -le 1` guard no longer
catches anything `detect` does.

HEAD~1's `cat >"$buf"` behaved the same way, so this is not a regression.
Recommendation: keep the two-value contract, which is what I did. The
alternative is an explicit status above 1 on a read failure, which would make
the `docs.bats` guard meaningful again. Deciding between them is a contract
change, so it belongs to the orchestrator.

### F7 — Note: stale mentions outside `lib/` and `hooks/`, reported, not edited

- `tests/docs.bats:51–52`: "`detect` exits 1 when quiet; above that the matchers
  failed on this file (a full
  $TMPDIR mid-sweep)". Both halves are stale. `detect` has no exit above 1 and touches no `$TMPDIR`.
  The guard still catches bash itself failing, for example 127 or 126. The
  redirect `<"$ROOT/$path"` failing gives status 1 and reads as quiet, and that
  gap predates this slice.
- `plans/sandbox-lies/runbook.md:101–102`: the Item 1.1 Interfaces entry still
  lists "2 on a buffering failure (until Item 2.3 removes the buffer)". Its own
  parenthetical dates it, and the runbook is a frozen plan. Flip it or leave it
  at the orchestrator's discretion.
- `docs/design.md:54` (FR-2): "runs the set over one buffered copy". This is
  still true of an in-memory copy, but it can be read as a file buffer. "Over
  one in-memory copy" would remove the ambiguity.
- `plans/sandbox-lies/outline.md:80–85` (A-8) describes the old `mktemp` buffer
  as the problem being solved. It is historical and correct as written.
- `docs/references/detectors.md`: no mention of detect's exit 2 or the buffer.

## Mutation run (the one permitted)

I made one exact-string mutation to `lib/matchers.sh`, on top of the fix:

```
    { text=$(LC_ALL=C tr -d '\000' <&3); } 3<&0
```
→
```
    IFS= read -r -d '' text
```

This reinstates the NUL truncation. Running
`scripts/run-bats.sh tests/matchers.bats tests/hook.bats tests/docs.bats` gave
**40 passed, 0 failed**, so the suite does not red on F1.

I restored the line by the inverse replacement. `cmp` against the copy saved
before the mutation reported identical. `git diff --quiet hooks` passed at that
point, before the F4 comment edit. `git diff --quiet lib` cannot serve as the
proof here, because `lib/` holds this review's fix.

## Test gaps (not written: tests are out of scope)

1. **NUL before a firing line, direct `detect`** (`matchers.bats`). Pipe the
   quiet text, then `\000`, then a firing line built from fragments, and assert
   the verdict, exit 0 and empty stderr. The mutation above shows that nothing
   reds on F1 today. The existing NUL test runs through the hook, where jq has
   already stripped the NUL.
2. **Closed stdin does not hang** (`matchers.bats`). Run
   `timeout 5 bash lib/matchers.sh <&-` and assert exit 1, empty stdout, and not
   124. The `timeout` binary is GNU coreutils, so the test needs a guard for
   macOS.
3. **Large quiet result stays cheap.** This is timing, so it is not an
   assertion. It belongs in the NFR-3 changelog entry, which should record a
   near-cap quiet payload next to `quiet-clean-status`.

## Refactor flag

None needed. I considered having `detect` take the text as an argument, which
would drop the stdin read altogether on the hook path. That changes the FR-2 and
Interfaces contract, where stdin carries the text, so I am naming it rather than
doing it.

## Verification

- `shellcheck lib/matchers.sh hooks/annotate.sh`: clean.
- `scripts/run-bats.sh tests/`: 91 passed, 0 failed.
- `direnv exec . just precommit`, run after both edits: passed. Its checks were
  `plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests`,
  and tests reported 91 passed, 0 failed.

## Files changed

- `lib/matchers.sh`: `detect` reads through
  `{ text=$(LC_ALL=C tr -d '\000' <&3); } 3<&0` with `text=''`, and feeds each
  matcher by process substitution. The comment is rewritten to cover NUL
  handling, the per-byte cost, the locale, the closed-stdin case and what a read
  failure does.
- `hooks/annotate.sh`: the comment above `detect`'s `|| exit 0`.
- `plans/sandbox-lies/reports/item-2-3-s8-code-review.md`: this report.
