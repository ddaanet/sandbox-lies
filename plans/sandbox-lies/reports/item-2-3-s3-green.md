# Item 2.3 slice 3 — GREEN

Mode: GREEN.

## Order worked

1. Read the RED and test-review reports, `hooks/annotate.sh`,
   `lib/verdicts.sh`, `lib/matchers.sh`, and `docs/references/detectors.md`'s
   `phantom-chardev` Flag policy paragraph (the one-paragraph-when-both-fire
   rule).
2. Read the current `tests/hook.bats` and `tests/verdicts.bats` to confirm
   the three tests the review left in place: `both listing verdicts share
   one paragraph`, `chardev listing alone keeps its own paragraph`, and
   `verdict text matches detectors.md`.
3. Implemented the fix in `hooks/annotate.sh`'s name loop, matching the test
   review's variant C (skip `phantom-chardev` only when `detect` also prints
   `phantom-untracked`), which the review confirmed passes both the shared
   and chardev-alone tests.
4. Ran `scripts/run-bats.sh tests/`, then `just precommit`.

## Implementation

`detect`'s output is now captured once into `names` (command substitution —
a pipe, not a temp file, so NFR-4 holds) instead of being piped straight
into the loop's process substitution. A `grep -qFx 'phantom-untracked'`
membership check on `names` sets `untracked_fires`. Inside the loop, a name
equal to `phantom-chardev` is skipped with `continue` when
`untracked_fires` is 1; every other name (including `phantom-untracked`
itself, and `phantom-chardev` alone) is unaffected. `detect`'s own output is
untouched, matching the item's placement of the special-case in the hook,
not the detector.

No arrays, no here-document or here-string (the second loop still reads via
process substitution over a `printf`), and the existing `|| exit 0` verdict-
call contract is unchanged.

## Verification

- `scripts/run-bats.sh tests/`: 77 passed, 0 failed (was 76 passed, 1 failed
  before the fix — `not ok 7 both listing verdicts share one paragraph` at
  `tests/hook.bats:172`; that test and `chardev listing alone keeps its own
  paragraph` both pass now).
- `just precommit`: `precommit passed: plugin.json, hooks.json, shellcheck,
  bash -n, rumdl, line limits, links, tests`.
- `git diff hooks/annotate.sh`: only the change described above; `lib/` is
  untouched.

## Untouched

`lib/verdicts.sh`, `lib/matchers.sh`, `hooks/hooks.json` byte-identical to
HEAD. Untracked zero-byte/char-device dotfiles at the repo root are sandbox
masks from this session, not real files — left alone, per
`sandbox-effects`.
