# Item 2.2 slice 4: GREEN

Scope: make `link inside a code span or fence ignored`
(`tests/check-links.bats`) pass without weakening it, keeping everything
slice 1–3 code review earned in `check_links_in`.

## Order worked

1. Read the recall artifact, `item-2-2-s4-red.md`, `item-2-2-s4-test-review.md`,
   the current `scripts/check-links.sh` and `tests/check-links.bats` in full.
2. Checked for an existing NUL-byte/non-UTF-8 bats test on `check-links.sh`
   (there is none yet — that lands in slice 5) and confirmed `walk_tracked_files`
   in `scripts/lib/tracked.sh` already has a precedent for "write to a temp
   file, don't lose the exit status": the same idiom this slice needed for
   awk's.
3. Probed `mawk` (this box's `awk`) with an embedded NUL byte: it round-trips
   the byte unchanged (`length($0)` counts it), so a per-line awk pre-pass
   does not regress byte-safety by truncating a line at a NUL the way a bash
   command substitution capturing the *whole file* would. That ruled out
   `mask=$(awk …)`: bash command substitution is NUL-terminated internally,
   so if any earlier line's fenced content held a NUL, capturing the file
   into a shell variable would still lose whatever came after it. Landed on
   writing awk's output to a temp file instead — the codebase's own
   `walk_tracked_files` comment names exactly this exit-status-loss hazard
   for a process substitution, and command substitution has the sibling
   NUL-truncation hazard for content.
4. Wrote `scripts/lib/strip-code.awk`: a line-at-a-time state machine that
   drops fenced-block lines (opener/closer/content) between a same-character
   open and close, and blanks single-backtick spans with `gsub`, printing
   everything else unchanged. Traced it by hand against every line of the
   test-review's rebuilt fixture before running it (span, info-string
   opener, wrong-marker-is-content, tilde fence, indented fence, sentinel).
5. Wired it into `check_links_in` ahead of the existing
   `grep -aoE -e '\]\([^)]*\)'`: `awk -f "$LIB_DIR/strip-code.awk"` writes to
   a `mktemp` file (explicit BSD-safe template, matching
   `walk_tracked_files`'s own), checked for a non-zero awk exit the same way
   grep's exit was already checked; grep then reads the mask file instead of
   `$ROOT/$file` directly, and `status=$?` handling is unchanged.
6. `scripts/run-bats.sh tests/check-links.bats`: 9 passed, 0 failed —
   confirms the slice-4 test alone.

## Verification

- `scripts/run-bats.sh tests/`: 52 passed, 0 failed (full suite).
- `just precommit`: `precommit passed: plugin.json, shellcheck, bash -n,
  rumdl, line limits, tests`. `shellcheck` run standalone on
  `scripts/check-links.sh` alone reports SC1091 ("not following
  lib/tracked.sh") — confirmed on `git show HEAD:scripts/check-links.sh`
  too, so it predates this slice and is an artifact of running shellcheck
  on one file at a time; the justfile's tracked-file-set invocation (which
  includes `scripts/lib/tracked.sh` in the same run) resolves it, and
  `scripts/lib/strip-code.awk` isn't shell so shellcheck never sees it.
- `scripts/check-links.sh` (repo root): exit 0, no output — no broken links
  in the tracked tree, nothing to record.
- Unreadable-file → exit 2: a throwaway fixture repo under `$TMPDIR`
  (`check-links-unreadable-fixture`), one tracked `docs/a.md` `chmod 000`'d
  (`id -u` is 1000, confirming the run is not root and the mode bit
  actually blocks the read). `scripts/check-links.sh "$fixture"` printed
  `check-links: cannot read docs/a.md` on stderr and exited 2 — the awk
  stage now fails first (mawk itself exits 2 with "Permission denied" on
  that file, verified directly), and the existing check on awk's exit
  status catches it before grep ever runs.

## Files changed

- `scripts/lib/strip-code.awk` (new): the fence/span pre-pass, with the
  CommonMark residuals it leaves out named in its header comment (shorter
  same-character close, double-backtick spans, a span or fence spanning a
  line break, 4-space indented blocks) — each fails loud, reporting the
  link rather than silently passing it.
- `scripts/check-links.sh`: `check_links_in` runs the mask through a temp
  file ahead of the existing `grep -aoE` call; the target of that `grep`
  changed from `$ROOT/$file` to the mask file, everything downstream
  (target parsing, scheme skip, anchor strip, report line, `EXIT_CODE`)
  unchanged.
- `tests/check-links.bats`: uncommitted since RED, unchanged by GREEN.
