# Item 8.0 slice 3 — GREEN report

`the probe reports the facts` (`tests/probes-readonly-facts.bats`)

## Scope

- `lib/probes-readonly.sh`: `probe_readonly_path` now takes `<command>` as
  `$3`, calls the new `_readonly_print_facts` under `writable` and `nopath`
  (never `readonly`), and its header/function comments were updated to the
  new signature and output. 147 lines.
- New `lib/probes-readonly-facts.sh`, sourced from `lib/probes-readonly.sh`
  (same pattern as the `matchers.sh` source line): `_readonly_print_facts`
  and its helpers — `_readonly_readfile_arg`, `_readonly_tokenize`,
  `_readonly_merge_segment`, `_readonly_partial_checkout_text`,
  `_readonly_git_dir`, `_readonly_resolve_target`, `_readonly_print_matches`.
  336 lines. The split was needed: the combined file would have been 483
  lines, over the 400-line cap.
- No test file touched. `hooks/annotate.sh` and `lib/verdicts.sh` untouched
  (out of scope; slice 2 already passes `tool_input.command` as the probe's
  third argument and already composes the tail from these facts).
- Git's partial-checkout error is matched by two substrings
  (`unable to unlink`+`old`, `unable to create`+`file`), each built from two
  fragments at the call site so no tracked file holds either phrase whole
  (self-quiet, FR-11) — confirmed by the full suite's `tests/docs.bats`
  case below.
- Every git call in the new file runs with `GIT_OPTIONAL_LOCKS=0` (NFR-4):
  `rev-parse --verify --quiet` for `target=`, one whole-repo
  `diff --name-only -z HEAD` plus `cat-file -e`/`cat-file blob` per
  candidate for `match=` — never a per-file `git diff <ref> -- <file>`,
  which the test review found rewrites the index on git 2.47 even under
  `GIT_OPTIONAL_LOCKS=0`.

## Tests made to pass, one at a time

All 14 were already implied by one implementation pass (the readfile,
merge-segment and target/match logic each serve several tests at once), so
each was then run individually with `bats -f "<name>"
tests/probes-readonly-facts.bats` in the order below to confirm it passes
standing alone, not just as part of the full-file run:

1. `readfile reports a command-output path from a single reader` — ok
2. `readfile reports a quoted command-output path from a reader pipeline` — ok
3. `facts appear only under writable and nopath, never readonly` — ok
4. `readfile requires a command-output extension` — ok
5. `readfile excludes an in-place editor and redirected output` — ok
6. `readfile requires every command in a pipeline or list to be a reader` — ok
7. `merge=1 fires for a git merge-style command segment` — ok
8. `merge=1 does not fire for a non-merge command or an echoed mention` — ok
9. `merge=1 fires from git's partial-checkout error in the text, under any command` — ok
10. `target and match select files at the resolved ref, staged or not, never one edited otherwise` — ok
11. `an unresolvable ref gives merge=1 and no target` — ok
12. `the repository is the path's nearest existing directory's, not the cwd's` — ok
13. `nopath falls back to the cwd's repository` — ok
14. `the facts survive BSD grep, sed, stat and wc` — ok

`scripts/run-bats.sh tests/probes-readonly-facts.bats`: 14 passed, 0 failed.

## Full suite and gates

- `scripts/run-bats.sh tests/`: 227 passed, 0 failed (run in the foreground).
- `shellcheck lib/probes-readonly.sh lib/probes-readonly-facts.sh`: clean.
- `just precommit`, run in the foreground and checked by its own exit status
  (`echo "exit=$?"` after the run): **exit 0**. Its own recap: `precommit
  passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits,
  links, tests`. No warnings were printed by this run — the recap line was
  the entire output beyond the bats summary, so there is nothing to record
  under precommit warnings.

## Notes for code review

- `_readonly_tokenize` is a small hand-rolled quote-aware word/segment
  splitter (bash 3.2, no external process): it treats an unquoted `|`, `;`
  or `&` as a segment boundary, except an `&` immediately after `>` or `<`
  in the same word (keeps `2>&1`/`>&2` one word). It does not model a
  reader behind `cd` or a variable assignment — an accepted residual
  detectors.md itself states.
- `_readonly_resolve_target` calls `git rev-parse --verify --quiet
  "$cand^{commit}"` with **no** leading `--`: empirically, adding `--`
  before the revision makes `rev-parse` fail to resolve even a real ref
  (verified by hand against git 2.47.3 in a scratch repo before writing the
  function), so `--verify --quiet` alone is relied on to fail quietly on a
  candidate that looks like an option (`--ff-only^{commit}`).
- `_readonly_print_matches` discards `git cat-file -e`'s stderr with an
  inline-justified `2>/dev/null` (its exit status alone is the signal; the
  message it can print on a miss adds nothing the status doesn't already
  carry) — the one redirect in the new file, called out per the
  no-blanket-`2>/dev/null` convention rather than silently added.

## Commit

One commit, staged by name:
`lib/probes-readonly.sh`, `lib/probes-readonly-facts.sh`,
`tests/probes-readonly-facts.bats`,
`plans/sandbox-lies/reports/item-8-0-s3-red.md`,
`plans/sandbox-lies/reports/item-8-0-s3-test-review.md`,
`plans/sandbox-lies/reports/item-8-0-s3-green.md`.
Subject: `feat: Item 8.0/3 — the probe reports the facts`.
