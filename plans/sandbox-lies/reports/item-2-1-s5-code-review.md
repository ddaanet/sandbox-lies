# Item 2.1 slice 5 — code review

Scope: `git show HEAD -- justfile docs/design.md` (the precommit wiring line
and the NFR-5 status sentence), then `scripts/check-line-limits.sh` read
whole as the item's finished artifact against the item text and its
Interfaces block. Tests out of scope except for gaps.

## Verified

- **Working directory.** just 1.46.0 runs a recipe in the justfile's
  directory. Neither `justfile` nor the imported `plugin-dev/release.just`
  has `set working-directory` or `[no-cd]`. I checked with a probe justfile
  in `$TMPDIR`: a shebang recipe run from two levels down printed the
  justfile's directory.
- **The default ROOT from precommit.** I added 90 blank lines to
  `tests/check-line-limits.bats`, making it 409 lines. I picked that file
  because it is outside `docs/`, so a `docs/` cwd would not see it. Then I
  ran `direnv exec .. just precommit` from `docs/`. The gate stopped at the
  line-limit check and printed the check's own
  `oversized-file: tests/check-line-limits.bats: 409 lines > 400`, with the
  path relative to the repo root. The recipe exited 1, and neither `tests`
  nor the recap ran. I restored the file to its first 319 lines and
  confirmed its sha256 was back to the original.
- **`report` and exit status.** `report` runs `"$@"` as a plain command
  under `set -euo pipefail`. It is never the condition of an
  `if`/`&&`/`||`, so errexit is active and any non-zero status stops the
  gate: 1 for an overage, 2 for a failure to run. The check's stdout and
  stderr go straight to the terminal. The recap is only reached on success.
- **Position.** The check comes after `rumdl fmt --check`, so counts are
  taken after the reflow (`markdown-formatter-choice`), and before
  `just test`. This matches the item text. Item 2.2's "after the line-limit
  check" slots in cleanly after it.
- **Status sentence.** "Partial (80-column reflow and line caps gated; the
  link check pending)" is correct under the legend. `Done` requires every
  part of the requirement to be pinned, and `check-links.sh` does not exist
  yet. The parenthetical form matches NFR-1's `Partial (harness promoted)`.
- **Script against the item and Interfaces.**
  - Usage `[ROOT]`, default `.`.
  - Output is `oversized-file: <path>: <n> lines > <cap>` on stdout.
  - Exit codes are 0, 1 and 2. Every failure-to-run path exits 2 explicitly
    rather than through a bare `set -e` abort: `mktemp`, `git ls-files`, an
    unreadable file, and an extra argument.
  - The walk is `git ls-files -z`, spooled to a file so git's status is
    kept.
  - Markdown is capped under `docs/`, under `skills/` (200 for
    `skills/*/SKILL.md`) and at the root. Scripts (`.sh`, `.bash`,
    `.bats`, `.py`) are capped at any depth except root-level `plans/` and
    `plugin-dev/`. Symlinks, gitlinks and deleted paths are skipped. There
    is no allowlist.
  - Bash 3.2 and BSD safe: `read -d ''`, an explicit `mktemp` template, and
    `awk` NR. No `2>/dev/null`.

## Findings

1. **Minor, fixed.** NFR-5 said "under 400 lines (a `SKILL.md` under 200)",
   which is off by one against the gate that pins it. The Interfaces block
   and slice 1 report at `401 lines > 400`, so a 400-line file passes, as
   the runbook intended (`docs/design.md` "stands at exactly 400 … Item 2.1
   caps it"). Changed to "at most 400 lines (a `SKILL.md` at most 200)" and
   reflowed with `rumdl fmt`. `docs/design.md` stays at 396 lines. The
   script and tests are unchanged. FR-6's "under 400 characters" is a
   different quantity and was not touched.

No other findings. The justfile line and the script need no change.

## Test gaps (reported, not fixed)

- No bats case runs the script with no argument from inside a fixture
  repo (`cd "$dir" && check-line-limits.sh`). The default ROOT is covered
  only by precommit on the real tree and by the manual fault run above.
- Nothing in the suite asserts that `precommit` invokes the check. Deleting
  the justfile line leaves the suite green. The check itself is covered.
  Only the wiring is not.

## Final runs

- `direnv exec . scripts/run-bats.sh tests/`: 43 passed, 0 failed, rc 0.
- `direnv exec . just precommit`: `precommit passed: plugin.json,
  shellcheck, bash -n, rumdl, line limits, tests`, rc 0.

## Files changed

- `docs/design.md`: the NFR-5 cap wording (5-line reflow of one
  paragraph).

## Refactor flag

None.

Nothing committed. Untracked sandbox-mask dotfiles at the root were
ignored.
