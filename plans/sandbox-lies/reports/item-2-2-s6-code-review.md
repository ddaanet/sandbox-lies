# Item 2.2 slice 6: code review

Scope, Part A: `git show HEAD -- justfile docs/design.md` (commit `Item
2.2/6`). I also read `scripts/check-links.sh`, `scripts/lib/tracked.sh` and
`scripts/lib/strip-code.awk` whole, as finished artifacts, against Item 2.2's
text and its Interfaces block. Part B: the carried-over holes in
`tests/check-line-limits.bats`. Nothing is committed.

## Part A: findings

1. **Wiring: no finding.** `report links scripts/check-links.sh` sits
   right after `report 'line limits' …` and before `report tests just
   test`, as Item 2.2 specifies. `report` runs `"$@"` as a plain statement
   under `set -euo pipefail`, not inside `if`, `&&` or `||`, so a non-zero
   exit (1 for a broken link, 2 for a failure to run) stops the recipe at
   that check. The check's own stdout and stderr pass through unchanged,
   and the `passed` recap is never printed. The GREEN report's
   fault-injection run showed this. On the real tree the recap now ends
   `line limits, links, tests`.

2. **NFR-5 `Done.`: accurate against the legend, with one caveat.** The
   legend's `Done` is "implemented and pinned by a test or a gate that
   re-checks it on every commit". Both scripts named under "pinned by" now
   run in `just precommit`, and both have suites. The caveat: the git
   `pre-commit` hook in this repo is gitlore's, not `just precommit`, so
   "every commit" rests on the standing rule to run the gate before
   committing. NFR-2 and the other `Done` rows rest on the same basis, so
   the new status is consistent with how the doc already uses the word. No
   change.

3. **Minor, flagged and not edited: NFR-5's text claims more than the
   gates check.** I verified each gap against the scripts, and gaps (a)–(c)
   with a probe:
   - (a) **"Every document"**: only tracked markdown under `docs/`,
     `skills/` and the root is capped. `plans/` (deliberately frozen),
     `memory/`, `tests/`, `hooks/`, `lib/`, `.claude/` and any other
     directory are not.
   - (b) **"and script"**: only `*.sh`, `*.bash`, `*.bats` and `*.py` are
     capped, and nothing under `plans/` or `plugin-dev/`.
     `scripts/lib/strip-code.awk`, `.gitlore/bin/claude` and the
     `justfile` recipes are scripts that the gate never counts.
   - (c) **"a `SKILL.md` at most 200"**: only `skills/*/SKILL.md` is held
     to 200. `.claude/skills/*/SKILL.md` is out of scope entirely.
   - (d) **"every relative markdown link resolves"**: only in the same
     markdown scope as (a), and only for **inline** links; see finding 4.

   All but the reference-link gap are deliberate scope choices already
   written into Items 2.1 and 2.2. A design-doc edit would align the text,
   for example: "Every document in the rumdl scope (`skills/`, `docs/`,
   root markdown) and every `.sh`/`.bash`/`.bats`/`.py` script outside
   `plans/` and `plugin-dev/` …". The rest of the sentence would keep its
   caps and links clauses. Changing a requirement's wording is a design-doc
   decision, so I left it to you.

4. **Major, documented and flagged: reference-style links are silently
   unchecked.** Item 2.2 says "every relative markdown link … resolves". The
   extraction is `\]\([^)]*\)`, which sees inline links (and images) only.
   I probed a fixture holding `[r]: missing-ref.md` and `see [x][r]`: it
   exited 0 with no line for it. No reference definition exists in the
   real tree's scope today (checked by grep), so nothing is broken now.
   The gap is silent, though, and the script's header overclaimed.
   **Fix applied (documentation only):** the header of
   `scripts/check-links.sh` now says "every relative inline link" and
   names reference definitions as unchecked. **Decision for you:** add
   reference-definition checking as a new TDD slice (new behaviour needs
   its own red), or keep it as a documented residual and narrow NFR-5 and
   Item 2.2's text to "inline". Default if unanswered: keep it as a
   residual, since the tree has none.

5. **Minor, documented: loud residuals the comment did not list.** Probed:
   `[t](b.md "title")` and `[a](<b.md>)`, with `docs/b.md` present, each
   report `broken-link: … -> b.md "title"` and `-> <b.md>`. These are false
   positives, so they are loud rather than silent. **Fix:** the existing
   residual note in `check_links_in` (about a target containing `)`) now
   lists all three loud cases. The paragraph is rewrapped under 80
   columns.

6. **Minor, documented: a target that climbs out of ROOT resolves against
   the host.** `[up](../../../../etc/hostname)` passes, because `-e` checks
   whatever sits at that path on the checking machine. The result is
   silent and host-dependent. **Fix:** a one-line residual comment above
   the `-e` test. I did not change the behaviour. Refusing links that
   escape ROOT would be new behaviour, and a design choice.

7. **Low, no fix: here-string temp file on bash < 5.1.** `done
   <<<"$links"` makes bash 3.2 (the macOS target) write a temp file in
   `$TMPDIR`. If that fails, the redirection fails and `set -e` exits 1,
   with bash's own message on stderr but no `broken-link` line. It needs a
   full disk or an unwritable `$TMPDIR` right after the walk's own `mktemp`
   succeeded in the same place. I judged it not worth a restructure. I
   note it so that nobody reads it as covered.

8. **Checked, no finding.**
   - **`tracked.sh`**:
     - `markdown_in_scope`'s allowlist order;
     - `parse_root` naming the first extra argument;
     - the walk's `mktemp` and `ls-files` failures both exiting 2;
     - NUL-delimited `IFS= read -r -d ''`;
     - unmerged-path dedupe on adjacent entries;
     - the symlink and non-file guard;
     - the EXIT trap outliving the function through the non-local
       variable.
   - **`strip-code.awk`**:
     - POSIX-only constructs (`\r` inside a bracket expression is a POSIX
       awk escape);
     - fence-character matching;
     - the CRLF closer;
     - an opener with no backtick in its info string;
     - the residual list, which matches the code.
   - **`check-links.sh`**:
     - `LIB_DIR` resolution, including a bare name;
     - the `-r` pre-check on the awk helper;
     - the redirect in place of an operand, for a `name=value` ROOT;
     - folding grep's 1 to 0 under `pipefail`;
     - the RFC 3986 scheme test;
     - `#`-stripping;
     - the stdout format and exit codes against the Interfaces block.

## Part B: `tests/check-line-limits.bats` fixes

- **`deleted tracked file is skipped`**: the fixture adds a present,
  401-line `docs/sentinel.md`, which sorts after `gone.md`. The test now
  asserts status 1, stdout exactly `oversized-file: docs/sentinel.md: 401
  lines > 400`, and empty stderr. The comment now names
  `walk_tracked_files`'s guard in place of `check_cap`'s. It also
  explains the sentinel, with the same wording as the twin in
  `check-links-edges.bats`.
- **`extra argument exits 2`**: now also asserts `[ "$stderr" =
  "check-line-limits: unexpected extra argument: $dir" ]`. The comment
  gains the `"$*"` sentence from its twin.

### Mutation proofs

Each mutation was an exact replacement in `scripts/lib/tracked.sh`, made by
a helper that refuses unless the old string occurs exactly once. I then ran
`bats tests/check-line-limits.bats` (16 tests). Each mutation was restored
by the inverse replacement, and after each one `git diff --quiet scripts/`
passed.

| Id | Mutation | Result |
|---|---|---|
| D3 | `ls-files -z >` → `ls-files >` (the walk becomes one unterminated record) | #12 `deleted tracked file is skipped` red on `[ "$status" -eq 1 ]`, alongside the other positive tests |
| D2 | the guard's `continue` (the one before `"$handler"`) → `break` | only #12 red, on `[ "$status" -eq 1 ]` |
| E2 | `if [ "$#" -gt 2 ]; then` → `if false; then` plus `ROOT="${2:-.}"` → `ROOT="${*:2}"` | only #15 `extra argument exits 2` red, on the new stderr assertion |

The slice-5 test review showed that D3 and E2 kept the old tests green.
After the restores, the baseline run was 16 of 16 passing.

### Runbook drift

- Item 2.1 slice 4 says the deleted-file case "yields status 0". It now
  yields the sentinel's line and status 1.
- Item 2.1 slice 5's `extra argument exits 2` now also pins the exact
  stderr.

## Files changed (uncommitted)

- `scripts/check-links.sh`: comments only (header scope, residual list,
  escaping-ROOT residual). 120 lines.
- `tests/check-line-limits.bats`: the two tests above. 308 lines.

## Refactor flag

None needed. The three artifacts are cohesive and well under their caps.

## Test gaps

- Reference-style links: no test, because the behaviour is absent (finding
  4).
- Link titles, angle-bracket targets and targets escaping ROOT are not
  pinned. They are documented residuals, and pinning today's loud
  behaviour would lock in false positives.
- Open as the runbook already notes: a NUL byte under BSD awk, which only
  the macOS dogfood run can show.

## Final runs (foreground)

- `shellcheck scripts/check-links.sh scripts/lib/tracked.sh
  tests/check-line-limits.bats`: clean. No line over 80 columns in either
  changed file.
- `scripts/run-bats.sh tests/`: `bats: 65 passed, 0 failed`, rc 0.
- `just precommit`: `precommit passed: plugin.json, shellcheck, bash -n,
  rumdl, line limits, links, tests`, rc 0.
