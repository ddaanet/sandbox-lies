# Item 2.3 slice 1 — GREEN

Mode: GREEN. Made the five red tests pass one at a time (in file order:
`gitadd failure payload yields one verdict`, `hooks.json names both events`,
`verdicts under 400 chars`, `verdict text is quiet`, `no removal
instruction`); `quiet fixture yields nothing` was already green and stayed
so throughout.

## Order worked

1. `hooks/hooks.json` — registered `PostToolUse` and `PostToolUseFailure`,
   matcher `Bash`, one `command`-type hook each, `bash
   "${CLAUDE_PLUGIN_ROOT}/hooks/annotate.sh"`, timeout 10. Green:
   `hooks.json names both events`.
2. `lib/verdicts.sh` — filled in the three `verdict_phantom_*` functions
   with the `detectors.md` text (agent paragraph on line 1, human line on
   line 2). `verdict_phantom_untracked`'s paragraph restates
   `verdict_phantom_chardev`'s in full plus its own added sentence, per
   `detectors.md`'s "As `phantom-chardev`, with: …". Green: `verdicts under
   400 chars`, `verdict text is quiet`, `no removal instruction`.
3. `hooks/annotate.sh` — replaced the inert stub with the payload -> text ->
   detect -> verdict -> JSON pipeline: resolve the script's own directory
   and source `lib/matchers.sh` and `lib/verdicts.sh` beside it (never via
   `CLAUDE_PLUGIN_ROOT`); read the payload once; take `.hook_event_name`;
   for `PostToolUseFailure` take `.error` as the text (`PostToolUse`
   contributes no text yet — slice 2's success-text rebuild is out of
   scope); run `detect` over the text; for each firing name call
   `verdict_<name>` with `-` mapped to `_`, split its two lines into a
   context paragraph and a human line; join paragraphs with newlines and
   human lines with a single space; emit one object via `jq -n --arg`.
   Every jq/cd/source/cat step that can fail is chained with `|| exit 0`,
   with no blanket stderr redirect anywhere (no-stderr-suppression). Green:
   `gitadd failure payload yields one verdict`.
4. `justfile` — added `report hooks.json jq empty hooks/hooks.json` to
   `precommit`, right after the existing `plugin.json` check.

Deliberately left for later slices, per the dispatch's OUT list: the
`PostToolUse` success-text rebuild (slice 2); the chardev+untracked shared
single-paragraph merge (slice 3); flag (`dangerouslyDisableSandbox`)
handling (slice 4); the `select(type == "object")` malformed-payload guard
(slice 6); the 2 KB context cap (slice 7); removing `mktemp` from `detect`
(slice 8); an explicit guard skipping a name with no `verdict_<name>`
function (slice 9) — `lib/matchers.sh` is untouched this slice; BSD-stubbed
cases (slice 10). No probe is wired (Item 4.1).

## Verification

- `scripts/run-bats.sh tests/hook.bats tests/verdicts.bats`: 6 passed, 0
  failed.
- `scripts/run-bats.sh tests/` (full suite, includes `tests/docs.bats`):
  71 passed, 0 failed — the verdict text stays quiet under the self-quiet
  guard.
- `jq empty hooks/hooks.json`: exits 0.
- `direnv exec . just precommit`: exits 0 —
  `precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl,
  line limits, links, tests`.

## Scope confirmation

`git status` (sandbox-mask dotfiles at the repo root excluded) shows only:
`hooks/` (new), `lib/verdicts.sh` (new), `justfile` (modified, the one
`report hooks.json …` line), `tests/helpers/hook.bash`, `tests/hook.bats`,
`tests/verdicts.bats` (all from RED, unmodified this phase), and the two
prior reports plus this one. No memory-file edit, no `lib/matchers.sh`
change, no work on slices 2–10, Item 2.4, or any later item.
