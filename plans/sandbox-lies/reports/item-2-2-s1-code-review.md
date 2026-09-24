# Item 2.2 slice 1: code review

Scope: `scripts/check-links.sh` as committed in `Item 2.2/1`. I read it against
Item 2.2's runbook text, its Interfaces block and slice list, the
recall-artifact memories (`no-stderr-suppression`, `cc-grep-shell-function`
among them), `shell-gotchas` 0.4.0, the slice's RED, test-review and GREEN
reports, the sibling `scripts/check-line-limits.sh` and its five code reviews.
Out of scope: the behaviour of slices 2–6, the precommit wiring, Items 2.3–2.4,
and the test file except for gaps.

Every probe below ran as a script file, so it used the real `grep` (GNU 3.11)
and not the Bash tool's ugrep function.

## Findings

1. **An unreadable file read as "no links", and the run exited 0 (major).**
   `done < <(grep -oE … "$ROOT/$file")` discards grep's status. I reproduced it
   on the committed script: a `chmod 000` `docs/a.md` holding a broken link
   printed grep's `Permission denied` and exited 0. **Fix:** the links are now
   captured, `links=$(…) || status=$?`. Status 1 (no match) stays benign, and
   status ≥ 2 prints `check-links: cannot read <file>` and exits 2, the same way
   the sibling handles an unreadable file. The loop then reads `<<<"$links"`.
   Bash 3.2 has here-strings, and an empty capture yields one empty line, which
   the existing `[ -n "$link" ]` guard skips.
2. **The target was cut at the first `(` of the link text, and nested brackets
   hid the link (major).** `${link#*(}` made `[a (b)](x.md)` report
   `broken-link: docs/a.md -> b)](x.md` even though `x.md` exists. The
   `\[[^]]*\]` text half of the regex also failed to match `[a [b] c](m.md)`, so
   a broken link inside it passed silently (exit 0). Both reproduced. **Fix:**
   the regex now matches only the `](target)` half, `\]\([^)]*\)`, and the
   target is `${link#](}`. The link text no longer affects extraction, and image
   links `![i](x.png)` are still checked. **Residual, stated in a comment:** a
   target containing `)`, which CommonMark allows when the parentheses are
   balanced, is cut at its first `)` and reported broken (`foo(bar`). That
   failure is loud, not silent. The narrower regex has its own loud residual: a
   stray `a](b)` with no opening `[`, which CommonMark does not render as a
   link, would still be checked.
3. **Non-UTF-8 and NUL bytes made links go unchecked with exit 0 (minor).** In a
   UTF-8 locale, a target containing a non-UTF-8 byte fails `[^)]` and never
   matches. A file containing a NUL makes GNU grep print `binary file matches`
   instead of the links. Both reproduced, with exit 0 and a broken link present.
   **Fix:** `LC_ALL=C grep -a`. `-a` exists in BSD grep, and the BSD grep stub
   accepts the new invocation.
4. **`$(dirname "$file")` stripped a trailing newline from a directory name
   (minor, whitespace).** A linking file under `docs/sub<LF>/` was resolved
   against `docs/sub` and reported a link that exists. Reproduced. **Fix:** a
   `case` on `*/*` with `${file%/*}`, or `.` for a root file, so no fork and no
   substitution. This also gives slice 2's root `README.md` its `.` directory.
5. **Comments carried over from the sibling no longer fit (minor).** "would
   surface as 1 and read as an overage": 1 means a broken link here. It now
   reads "as a broken link". "What the port's `find -type f` skipped": this
   script is not a port. The skip comment now says what the arm skips, that grep
   would fail on a gitlink directory or a deleted path and exit the run 2, and
   it keeps the sibling's residual about unsearchable directories.

### Checked and sound

- **Exit-code contract.** An extra argument, a failed `mktemp`, a non-git ROOT
  and now an unreadable file all exit 2 with a diagnostic. A broken link exits 1
  and a clean tree exits 0. `check_links_in` runs in the main shell, so both
  `EXIT_CODE` and `exit 2` propagate.
- **No `2>/dev/null` anywhere.** grep's own stderr (`Permission denied`) passes
  through next to the script's line.
- **Portability.** `grep -a -o -E -e … --` are all BSD grep flags. Under
  `make_bsd_stubs grep sed mktemp`, a fixture with an image link, an empty
  `[e]()` and a broken link produced exactly one `broken-link` line with exit
  1. `${var%/*}`, `${var#](}`, `<<<` and `local … status=0` all work in bash
  3.2.
- **Whitespace.** The walk is NUL-delimited and every expansion is quoted. The
  link loop is line-based, which is correct because grep emits one match per
  line.
- **Real tree:** `scripts/check-links.sh` exits 0.

### Observations for later slices (not fixed, out of scope)

- A title, `[a](b.md "T")`, an angle-bracket destination `<b.md>`, a
  percent-encoded `%20`, and a leading `/` (repo root on GitHub) each give a
  loud false positive. Slice 3's non-file-target work is the natural home.
  Reference-style `[a]: x.md` definitions and links split across lines are never
  checked. That is silent, but it falls outside "inline link", which the item
  text implies.
- The header's slice-progress note, "Slice 1: docs/*.md only. Later slices add
  …", is plan state inside a shipped script. The slice that finishes the scope
  should delete it, as Item 2.1's slice 4 review did for its sibling.

## Mutant run (once, on the committed SUT, before any fix)

I used an exact replacement to disable the skip guard:
`if [ -L "$ROOT/$file" ] || [ ! -f "$ROOT/$file" ]; then` became
`if false; then`. `scripts/run-bats.sh tests/check-links.bats` gave
**`bats: 2 passed, 0 failed`. The tests did not go red.** I restored the file
with the inverse replacement, and `git diff --quiet scripts/check-links.sh`
exited 0. The guard was unpinned. On the committed script it was also inert,
because grep's failure was discarded. After fix 1 it is load-bearing: without
it, a deleted tracked file or a gitlink would exit 2.

## Test gaps (report only; test file out of scope)

- **Deleted tracked file is skipped:** add `docs/gone.md`, `rm` it, expect
  status 0. This pins the guard above, which the mutant showed is unpinned. It
  mirrors Item 2.1's `deleted tracked file is skipped`.
- **Unreadable file exits 2:** a `chmod 000` `docs/a.md`, expecting status 2 and
  empty stdout (fix 1). Skip it when running as root.
- **Link text with parentheses or nested brackets:** `[a (b)](x.md)` beside an
  existing `x.md` expects status 0, and `[a [b] c](missing.md)` expects the
  `broken-link` line (fix 2).
- **Extra argument exits 2:** same as Item 2.1's.
- Fixes 3 and 4 (the byte-level cases and the trailing newline in a directory
  name) are cheap to pin as well, but they are optional.

## Refactor flag

**Warranted: a shared tracked-markdown walk.** The two gates already duplicate
the arity check, the `mktemp` walk list with its trap and failure path, the
`git ls-files -z` spool, the NUL read loop, and the symlink/non-file skip,
comments included. That is about 30 lines. Slice 2 will duplicate the markdown
scope table as well: `docs/*.md`, `skills/*.md`, the `*/*.md` skip, root `*.md`,
and the `plans/`/`plugin-dev/` exclusion. The item text says the scope is "the
same … as Item 2.1". Two hand-maintained `case` tables will drift, and the drift
is silent. Suggested shape: a sourced helper, for example
`scripts/lib/tracked.sh`, that provides the spooled walk and a
`markdown_in_scope <path>` predicate. `check-line-limits.sh` would keep its cap
arms, SKILL.md 200 and scripts 400, and ask the predicate for markdown
membership. Timing: before slice 2's GREEN, so the scope is written once. I have
not performed it.

## Verification

- `shellcheck` and `bash -n` on the script: clean.
- `scripts/run-bats.sh tests/` (foreground): `bats: 45 passed, 0 failed`.
- `direnv exec . just precommit` (foreground):
  `precommit passed: plugin.json, shellcheck, bash -n, rumdl, line limits, tests`,
  exit 0.
- An edge-probe script, run before and after the fixes, covered the unreadable
  file, parentheses in link text, nested brackets, a NUL byte, a Latin-1 target,
  a deleted tracked file, a target containing parentheses, and a trailing
  newline in a directory name. Every finding reproduced before the fixes and
  behaved as described after them. The one exception is the parenthesised
  target, the stated residual.

## Files changed

- `scripts/check-links.sh` (now 100 lines). Nothing committed.
