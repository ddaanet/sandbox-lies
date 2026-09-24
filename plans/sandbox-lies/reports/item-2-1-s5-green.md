# Item 2.1 slice 5 — GREEN report

Mode: GREEN. Slice 5 (final, merging slices 5–7): remaining contract and
wiring for `scripts/check-line-limits.sh`. No SUT change — the slice's four
tests (added in RED, revised in test review) already pass against the
unmodified script; this dispatch wires the check into `just precommit` and
updates the NFR-5 status sentence.

## Step 1 — confirm the slice's tests green

`scripts/run-bats.sh tests/check-line-limits.bats`: 16 passed, 0 failed.

## Step 2 — justfile wiring

`justfile`'s `precommit` recipe gained one line, immediately after the
`rumdl` check and before `just test`:

```
report 'line limits' scripts/check-line-limits.sh
```

No other recipe changed.

## Step 3 — NFR-5 status sentence

`docs/design.md`, NFR-5's status sentence changed from
`Partial (80-column reflow gated; the two scripts pending).` to
`Partial (80-column reflow and line caps gated; the link check pending).`
`rumdl fmt -q --no-cache docs/design.md` reflowed the new sentence across
the 80-column wrap (one `MD013` fix, expected — the file runs through rumdl
in `precommit` ahead of the line-limit check per
`memory/ddaanet/markdown-formatter-choice.md`), taking the file from 395 to
396 lines. `wc -l docs/design.md` → 396, under its 400 cap; no escalation
needed.

## Step 4 — full suite, precommit, and fault injection

- `scripts/run-bats.sh tests/`: 43 passed, 0 failed.
- `just precommit`: recap `precommit passed: plugin.json, shellcheck,
  bash -n, rumdl, line limits, tests` — `line limits` runs after `rumdl`
  and before `tests`, as required.

Fault injection (after step 4's clean run, before restoring): appended 10
blank lines to `docs/design.md` (396 → 406 lines). `just precommit` stopped
at the line-limit check:

```
oversized-file: docs/design.md: 406 lines > 400
error: Recipe `precommit` failed with exit code 1
```

Restored by inverting the append (`sed -i '397,406d' docs/design.md`, never
`git checkout`) — `wc -l` back to 396, and `git diff docs/design.md`
against `HEAD` shows only the step-3 NFR-5 sentence change (the two-line
reflow), confirming the fault-injection round-trip left no residue against
the step-3 state. Re-ran `scripts/run-bats.sh tests/` (43 passed) and
`just precommit` (same recap as above) after the restore — both still
green.

## Scope

No changes to `scripts/check-line-limits.sh` or its tests beyond what RED
and test review already landed. Items 2.2–2.4 untouched. `git status`
before commit shows only the expected modified/untracked files, no phantom
dotfiles.
