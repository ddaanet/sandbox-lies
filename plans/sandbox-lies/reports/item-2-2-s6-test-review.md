# Item 2.2 slice 6: test review

Scope: the five slice-6 tests in `tests/check-links-edges.bats` and
`plans/sandbox-lies/reports/item-2-2-s6-red.md`. I mutated the SUT in place
for probes only. Each mutation was an exact string replacement, count-checked
unique, and inverted by the swapped replacement in the same call. After every
inversion `git diff --quiet scripts/` passed. Nothing is committed.

## Findings and fixes

1. **Major: `missing helper exits 2`, sub-case "no `lib/`", did not pin the
   `source` guard.** With `source "$LIB_DIR/tracked.sh" || exit 2` changed to
   `|| true` (M3), the whole suite stayed green: 22 of 22. The failed `source`
   falls through to the `strip-code.awk` readability guard. That guard also
   exits 2 with empty stdout, because `lib/` is missing altogether. The
   RED's mutation removed `|| exit 2` outright, which only closes the
   `set -e` exit-1 reading. The same hole let `2>/dev/null` on the `source`
   line (M3b) through.
   **Fix:** the sub-case now asserts bash's own diagnostic, with its
   `<script>: line <n>: ` prefix stripped so the line number is not pinned:
   `[ "${stderr#*: line *: }" = "$copy/lib/tracked.sh: No such file or
   directory" ]`. A fall-through appends the awk guard's line, and
   suppression empties stderr. Either one fails the assertion.
2. **Major: `missing helper exits 2` had no paired positive.** Both negatives
   assert exit 2 from a *copied* script. Nothing showed that the copy runs at
   all when its `lib/` is complete, so a copy broken for some other reason
   would also give exit 2. **Fix:** after the two negatives, the test copies
   `strip-code.awk` into the second copy's `lib/`. It then asserts status 1
   and the exact `broken-link` line. The positive sits after the negatives,
   so errexit cannot hide them behind it. Proven by M3c: the script also
   requires a nonexistent `lib/extra.sh` after the awk guard. Both negatives
   stay green and the positive goes red on `[ "$status" -eq 1 ]`.
3. **Major: `unmerged path walked once` was vacuous if the merge did not
   conflict.** The merge's status is swallowed by `|| true`. Probe: I made
   the feature branch's edit identical to main's, so the merge goes through
   cleanly, and disabled deduplication (M5). The test stayed **green**.
   **Fix:** after the merge, `run git -C "$dir" ls-files -u -- docs/a.md` must
   give status 0 and exactly 3 lines (stages 1–3). Repeating the same probe
   now fails on `[ "${#lines[@]}" -eq 3 ]`. The comment says why the check is
   there.
4. **Minor: the BSD test's comment named the whole test as proven by
   mutation. Only its grep half is.** The RED report is right that no
   single-run `mktemp` mutation reaches a stub refusal. **Fix:** the comment
   now says the grep half is mutation-proven (`-P`, or a `\b` in the pattern)
   and the mktemp half is a smoke run, and gives the reason. I kept the
   test's name, because the grep half does carry a red.
5. **No finding:**
   - **`tracked symlink is skipped`** is paired. The sentinel's line must
     still be reported, and the exact-output assertion rejects the
     symlink's extra line.
   - **`bare-name invocation`** runs the real `$ROOT/scripts/check-links.sh`
     from `scripts/` as `bash check-links.sh`, not a copy. It is the only
     test that reaches the `*) LIB_DIR=lib` arm.

   I considered splitting the two `missing helper` negatives into separate
   test bodies and did not. A red in the first one masks the second, but the
   test is red either way. Splitting would only add diagnostics, at the cost
   of a runbook rename.

## Mutation reproductions (final tests)

Each row ran `bats tests/check-links.bats tests/check-links-edges.bats` (22
tests), except M3c and the vacuity probe, which were filtered to the one
test. Every mutation differs from the RED report's. In every full-suite row
the result was 21 passed and 1 failed, and the red test was the one named for
the behaviour, failing on its own assertion.

| Id | File | Mutation | Red |
|---|---|---|---|
| M1 | tracked.sh | `if [ -L "$root/$file" ] \|\|` → `if [ -d "$root/$file" ] \|\|` | #18 symlink, output |
| M2 | check-links.sh | `*) LIB_DIR=lib ;;` → `*) LIB_DIR=. ;;` | #19 bare-name, status |
| M3 | check-links.sh | `source … \|\| exit 2` → `source … \|\| true` | #20 missing helper, sub-case 1 stderr. **Before the fix: survived (22/22)** |
| M3b | check-links.sh | `source "$LIB_DIR/tracked.sh" 2>/dev/null \|\| exit 2` | #20, sub-case 1 stderr. Before the fix: survived |
| M3c | check-links.sh | `[ -r "$LIB_DIR/extra.sh" ] \|\| exit 2` added after the awk guard | #20, paired positive, status (new assertion) |
| M4 | check-links.sh | awk guard `-r "$LIB_DIR/strip-code.awk"` → `-r "$LIB_DIR/tracked.sh"` | #20, sub-case 2 stderr (names `docs/a.md`) |
| M5 | tracked.sh | `prev="$file"` → `prev="$file/"` (never deduplicates) | #21 unmerged, output |
| probe | test fixture + M5 | feature edit made identical to main's (clean merge), dedup off | #21, stage count. **Before the fix: green** |
| M6 | check-links.sh | extraction grep gains `-e '\bzqzqzq\b'` | #22 BSD, status. The other 21 stay green under GNU grep |

**The RED's BSD claim is confirmed.** `command grep -aoE` and
`command grep -aoP` gave byte-identical extraction on a probe file, using
the real grep rather than the Bash tool's ugrep function. With the RED's own
`-aoE` → `-aoP` mutation applied, the 22-test run gave 21 passed and 1 failed,
with only #22 red, on `[ "$status" -eq 1 ]`. The red comes from the stub, not
from GNU grep.

## Follow-up, not fixed (out of scope)

The `mktemp` BSD stub hands a template-less call (`''`) to the real tool.
The `scripts/lib/tracked.sh` comment says a bare `mktemp` is a usage error on
macOS, so the stub cannot catch a regression to bare `mktemp`. I have not
verified that claim here. My recollection is that macOS `mktemp` has accepted
no arguments since 10.11, which would make the comment stale rather than the
stub incomplete. The macOS dogfood run can settle it.

**Runbook drift:** the slice 6 text says each `missing helper` copy "yields
status 2 and empty stdout". The test now also pins stderr for both copies and
adds the complete-copy positive. `unmerged path walked once` now asserts the
three-stage conflict. Update the slice text to match.

## Final runs (foreground)

- `scripts/run-bats.sh tests/`: `bats: 65 passed, 0 failed`, rc 0.
- `shellcheck tests/check-links-edges.bats`: exit 0.
- `wc -l tests/check-links-edges.bats`: 301, under the 400 cap.
- `git diff --quiet scripts/`: clean, so `scripts/` is byte-identical to
  HEAD.
- `git status --porcelain -- scripts tests plans`: `tests/check-links-edges.bats`
  modified. The RED report and this report are untracked.
