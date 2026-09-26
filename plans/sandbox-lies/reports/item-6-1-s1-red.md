# Item 6.1 slice 1 — RED: path extraction widened

Mode: RED. SUT `probe_readonly_path` / `_probe_readonly_path_from_line` in
`lib/probes.sh` already existed (built in Item 2.4/4.3), so no stub was
needed and the SUT was not touched except for the two mutation proofs below,
each fully restored.

Tests added to `tests/probes-readonly.bats` (334 lines, under the 400 cap;
no need to split into a second file). Shared helper `erofs_message` (builds
"Read-only file system" from two fragments, self-quiet/FR-11) added to
`tests/helpers/probes.bash`, mirroring `git_lock_error`/`config_lock_error`'s
existing convention there.

Run: `direnv exec . bats --tap tests/probes-readonly.bats` (foreground).

## Per-test output

1. `curly-quoted mkdir path is extracted` — RED
   `[ "${output%%$'\n'*}" = writable ]' failed` (actual output: `nopath`,
   no `path=` line — the curly quotes `‘…’` are not ASCII `'`, so the
   extractor's single-quote pattern finds nothing).

2. `bash line-N path is extracted` — RED
   `[ "${output%%$'\n'*}" = writable ]' failed` (actual: `nopath` — the
   `/bin/bash: line 4: <p>: …` shape has no quotes at all).

3. `dash redirect path is extracted` — RED
   `[ "${output%%$'\n'*}" = writable ]' failed` (actual: `nopath` — same,
   `sh: 1: cannot create <p>: …` is unquoted).

4. `git config-lock path is extracted` — RED
   `[ "${output%%$'\n'*}" = writable ]' failed` (actual: `nopath` — `error:
   could not lock config file <p>: …` is unquoted).

5. `git mkdir path is extracted` — RED
   `[ "${output%%$'\n'*}" = writable ]' failed` (actual: `nopath` — `fatal:
   cannot mkdir <p>: …` is unquoted).

6. `mv target path is extracted, not the source` — RED
   `printf '%s\n' "$output" | grep -qxF "path=$p"' failed` (outcome line
   passed as `writable` — the extractor still returns a path, just the
   wrong one: actual output was `path=<mv-source>` instead of the expected
   `path=<mv-target>`, since the extractor takes the first quoted segment on
   the line).

7. `straight-quoted touch and ln keep their path` — passed on first run
   (already-true behaviour: `cp` and Python's `OSError` are already pinned
   by "writable path" and its siblings and by "relative path resolves
   against cwd"; `touch` and `ln` were not previously exercised against this
   probe, so this test adds them). Proven by mutation below.

8. `unquoted path after an unlisted prefix stays nopath` — passed on first
   run (already-true behaviour: with no ASCII quotes present, the extractor
   already returns empty regardless of the line's tool prefix, e.g. `rm:
   cannot remove <p>: …`; `lib/matchers.sh`'s `_readonly_path_line` was
   independently confirmed to still accept this line, per its generic
   `prefix: … : message` shape with no prefix allowlist). Proven by mutation
   below.

All pre-existing tests in the file (`writable path`, `relative path resolves
against cwd`, `absent file checks its parent`, `existing file checks the
file itself`, `first quoted path on the line`, `quoted path off the matching
line is ignored`, `no quoted path`, `writable path survives BSD grep and
sed`) stayed green, unaffected by the new cases.

## Mutation proof

**Test 7 — `straight-quoted touch and ln keep their path`.**
File: `lib/probes.sh`, function `_probe_readonly_path_from_line`.
String pair:
`s/^[^']*'\([^']*\)'.*/\1/p` → `s/^[^']*'\([^']*\)'.*/\1Q/p`
(appends a literal `Q` after the captured path, so extraction returns the
wrong string). Applied, ran the named test alone: `not ok 1
straight-quoted touch and ln keep their path` —
``[ ... = writable ]`` passed but
``printf '%s\n' "$output" | grep -qxF "path=$p"`` failed (actual path had
the trailing `Q`). Restored with the string pair swapped back
(`\1Q/p` → `\1/p`); `grep -n '\\1Q' lib/probes.sh` found no hit (exit 1);
re-ran the named test alone: `ok 1 straight-quoted touch and ln keep their
path`.

**Test 8 — `unquoted path after an unlisted prefix stays nopath`.**
File: `lib/probes.sh`, function `probe_readonly_path`.
String pair: `if [ -z "$path" ]; then` → `if [ -n "$path" ]; then`
(inverts the empty-path branch, so an unquoted, pathless line no longer
short-circuits to `nopath`). Applied, ran the named test alone: `not ok 1
unquoted path after an unlisted prefix stays nopath` —
``[ "${output%%$'\n'*}" = nopath ]`` failed. Restored with the string pair
swapped back (`if [ -n "$path" ]; then` → `if [ -z "$path" ]; then`, using
the surrounding `printf '%s\n' nopath / return 0` lines to disambiguate
from the unrelated `-n "$path"` check in `probe_config_lock`); `git diff
lib/probes.sh` showed no diff at all (byte-identical to the committed
file); re-ran the named test alone: `ok 1 unquoted path after an unlisted
prefix stays nopath`.

## Other checks

- `shellcheck tests/probes-readonly.bats tests/helpers/probes.bash
  lib/probes.sh` — clean.
- Self-quiet: `bash lib/matchers.sh < tests/probes-readonly.bats` and
  `< tests/helpers/probes.bash` both exit 1 with empty stdout (no
  detector fires on either source file); the curly-quote and EROFS-message
  text is only assembled at bash runtime, never held whole on a single
  source line.
- `git diff --stat -- lib/probes.sh` after the run: empty — the SUT is
  untouched relative to HEAD.

## Scope note

Docs (`docs/references/detectors.md`'s Probe paragraph rewrite),
`lib/verdicts.sh`, `hooks/annotate.sh`, and the hook-candidates/verdicts
test files are out of scope for this slice per the dispatch and were not
touched.

No commit made (RED mode).
