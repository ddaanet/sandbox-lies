# Item 2.3 slice 8 — GREEN

Scope: `detect` in `lib/matchers.sh` stops using `mktemp` (NFR-4). It holds
the text in a shell variable and feeds each matcher with `printf '%s\n'`;
its `exit 2` and the header comment describing the buffer go with it. The
hook's `detect` exit-2 comment is corrected to match.

## Order worked

1. Read `docs/design.md` NFR-4, the Item 2.3 paragraph and the Item 1.1
   `Interfaces` line in `plans/sandbox-lies/runbook.md`, the recall
   artifact's memory files, and the newest `shell-gotchas` `SKILL.md`.
2. Read the slice 8 RED and test-review reports, `lib/matchers.sh`,
   `hooks/annotate.sh`, and the new/changed test files.
3. Edited `detect()` in `lib/matchers.sh`: removed the `mktemp` buffer, the
   `rm -f` cleanup, and the `return 2` failure path; reads stdin with
   `IFS= read -r -d ''` into a `text` variable, feeds each matcher with
   `printf '%s\n' "$text" | match_<name>`.
4. Updated `hooks/annotate.sh`'s comment above `names=$(... ) || exit 0`
   (it referenced detect's now-removed exit 2); the `|| exit 0` itself is
   unchanged, now covering only "nothing fired".
5. `shellcheck lib/matchers.sh hooks/annotate.sh` and `bash -n` over both:
   clean.
6. `scripts/run-bats.sh tests/`: 91 passed, 0 failed (was 89 passed, 2
   failed at slice 8 RED — the two temp-dir tests now pass, nothing else
   regressed).
7. `direnv exec . just precommit`: passed — `plugin.json, hooks.json,
   shellcheck, bash -n, rumdl, line limits, links, tests`.
8. NUL handling, checked directly against the reading route (not through
   the hook's jq layer, which already strips NULs before matchers ever see
   the text):
   - `$(cat)` on this box's bash 5.2 prints `warning: command substitution:
     ignored null byte in input` to stderr for a NUL-bearing input.
   - `IFS= read -r -d ''` drops the NUL silently — no stderr output — and
     is the route `detect` now uses. Confirmed empirically: piping
     `printf 'a\000b\n'` through each form, `$(cat)` warned, `read -r -d
     ''` did not.
   - `git ls-files -z | xargs -0 grep -lP '\x00'` over the tracked tree: no
     hits. No tracked file currently carries a NUL, so `tests/docs.bats`
     (which runs `bash lib/matchers.sh` directly over every tracked file)
     has no live case to exercise this, but the route is clean regardless
     of that.
   - Residual: `read -r -d ''` truncates at the first NUL (it is bash's
     delimiter character for this idiom) rather than reading past it — the
     same underlying limit `$(cat)` has, since a bash string cannot hold a
     NUL byte either way. The only difference between the two routes is
     whether bash warns on stderr while doing so; `read` does not.
9. Measured the hook's quiet path: mean of 20 `bash hooks/annotate.sh`
   runs against a `quiet-clean-status` `PostToolUse` payload, built the
   same way `tests/hook.bats` builds it (`post_payload` over
   `tests/fixtures/quiet-clean-status.txt`, no stderr). "Before" ran a copy
   of the HEAD `hooks/annotate.sh`, `lib/matchers.sh` and `lib/verdicts.sh`
   under `$TMPDIR` (never `git stash`/`checkout`); "after" ran a copy of
   the working-tree files, also under `$TMPDIR`. Both quiet (empty stdout,
   exit 0) before timing.

   | | mean (20 runs) |
   |---|---|
   | before (mktemp buffer) | 46 ms |
   | after (`read -r -d ''`) | 51 ms |

   Two further paired re-runs swung both figures between 59 ms and 92 ms
   in either direction — this box's shared, memory-constrained sandbox is
   noisy at this scale, and the mktemp-vs-read difference is a handful of
   syscalls against a `bash`+`jq` startup cost that dominates the total. No
   conclusion beyond "no regression at this magnitude" is supportable from
   these numbers. Recording the NFR-3 timing entries in
   `docs/changelog.md` for `quiet-clean-status` and `fire-masks-porcelain`
   belongs to Item 2.3's main paragraph, not this slice.

## Files changed

- `lib/matchers.sh` — `detect` reads via `IFS= read -r -d ''`, no
  `mktemp`, no `exit 2`
- `hooks/annotate.sh` — comment above `detect`'s `|| exit 0` corrected
- `tests/matchers.bats`, `tests/hook.bats`, `tests/hook-malformed.bats`,
  `tests/hook-cap.bats` — slice 8 tests (unchanged from RED/test-review)
- `tests/helpers/spy.bash` — new, `make_spy` (unchanged from test-review)
- `plans/sandbox-lies/reports/item-2-3-s8-red.md`,
  `plans/sandbox-lies/reports/item-2-3-s8-test-review.md` — carried
  forward from earlier phases
- `plans/sandbox-lies/reports/item-2-3-s8-green.md` (this report)

## Scope

Out: slice 9 (verdict-less names), slice 10 (BSD), memory retirement and
status flips, Item 2.4. `docs/changelog.md`'s NFR-3 timing entries belong
to Item 2.3's main paragraph and are not touched here.
