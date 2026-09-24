# Item 2.1 slice 5 — RED report

Mode: RED. Slice 5 (final, merging slices 5–7): remaining contract and
wiring for `scripts/check-line-limits.sh`. All behaviour already exists in
the SUT — every case here is proven by mutation, not by a not-yet-built
feature.

Four tests added to `tests/check-line-limits.bats`: `path with a space`,
`unterminated last line counts`, `extra argument exits 2`, `oversized
markdown survives BSD mktemp`. All four pass green against the unmodified
SUT (`./scripts/run-bats.sh tests/check-line-limits.bats` — 16 passed, 0
failed, up from 12). SUT is byte-identical to HEAD at the end of this
report (`git diff --quiet scripts/check-line-limits.sh` confirmed after
each restore and once more as a final check).

## Mutation proof

### `path with a space`

Fixture: `docs/a b.md`, 401 lines, asserts
`oversized-file: docs/a b.md: 401 lines > 400` and status 1.

- Mutation: `docs/*.md) check_cap "$file" 400 ;;` → `docs/*.md) check_cap
  $file 400 ;;` (drop the quotes around `$file`, unique line in the file).
  The shellcheck-on-edit hook independently flagged this as SC2086 ("Double
  quote to prevent globbing and word splitting"), confirming it is exactly
  the word-splitting bug the test guards.
- Mechanism: unquoted `$file` splits `"docs/a b.md"` on default IFS into
  two words, so `check_cap` receives `file=docs/a` `cap=b.md` (the trailing
  `400` is a third, unused word). `check_cap`'s `[ ! -f "$ROOT/docs/a" ]`
  guard is then true (no such path), so it returns silently before ever
  comparing line counts.
- Red: `[ "$status" -eq 1 ]` failed — actual status 0, empty output.
- Restore: reverted to `check_cap "$file" 400`. `grep -n 'check_cap \$file'
  scripts/check-line-limits.sh` → no hit (exit 1). `git diff --quiet
  scripts/check-line-limits.sh` → clean.

### `unterminated last line counts`

Fixture: `printf '%s' "$(seq 401)"` (command substitution strips the
trailing newline `seq` ends with) → 401 lines, last one unterminated.
Asserts `oversized-file: docs/a.md: 401 lines > 400` and status 1.

- Mutation: `line_count=$(awk 'END { print NR }' <"$ROOT/$file")` →
  `line_count=$(wc -l <"$ROOT/$file")`.
- Mechanism: `wc -l` counts newlines, not records, so the unterminated
  fixture reads as 400, not 401 — empirically confirmed
  (`printf '%s' "$(seq 401)" | wc -l` → `400`, no stray padding).
- Red: `[ "$status" -eq 1 ]` failed — actual status 0 (400 does not exceed
  the 400 cap), empty output.
- Restore: reverted to the `awk` form. `grep -n 'wc -l <'
  scripts/check-line-limits.sh` → no hit (exit 1). `git diff --quiet
  scripts/check-line-limits.sh` → clean.

### `extra argument exits 2`

Fixture: clean 10-line tree, script called with `"$dir" extra` (two
positional arguments). Asserts status 2, empty stdout.

- Mutation: `if [ "$#" -gt 1 ]; then` → `if [ "$#" -gt 2 ]; then`.
- Mechanism: with two arguments `$#` is 2, so the raised threshold no
  longer trips the guard; the script proceeds treating `$dir` as `ROOT`,
  silently ignoring `extra`, and walks the (clean) tree to completion.
- Red: `[ "$status" -eq 2 ]` failed — actual status 0.
- Restore: reverted to `-gt 1`. `grep -n '"\$#" -gt 2'
  scripts/check-line-limits.sh` → no hit (exit 1). `git diff --quiet
  scripts/check-line-limits.sh` → clean.

### `oversized markdown survives BSD mktemp`

No mutation reds this test; it is a portability smoke run, not a
mutation-proven case, and is named accordingly rather than claiming
coverage it lacks.

Reasoning, checked both by reading the stub and empirically:

- The script's only `mktemp` call uses the template
  `"${TMPDIR:-/tmp}/check-line-limits.XXXXXX"` — X's trailing. Per
  `tests/helpers/bsd-stubs.bash`'s `_bsd_stub_mktemp`, a template ending in
  `X` always delegates to the real `mktemp` (`case "$tmpl" in ''|*X) exec
  "$real" "$@" ;; esac`). So for the script as written, running under the
  BSD mktemp stub is behaviourally identical to running unstubbed — there
  is no BSD-specific path for any mutation to diverge onto.
- The one way to reach the stub's own literal-path branch (its refusal
  path) is to change the template so it no longer ends in `X`. But per the
  stub's comment and its source, that branch only *refuses* when the
  literal path already exists — the first call to a fresh literal name
  succeeds (creates the file, no randomisation, but no error). Verified
  empirically: two successive stubbed `mktemp` calls against
  `check-line-limits.XXXXXX.log` (X's mid-template, non-trailing) — first
  call exit 0 (creates the literal file), second call exit 1
  (`mkstemp failed … File exists`). The script calls `mktemp` exactly once
  per run, so a single test invocation can never reach the second,
  refusing call without pre-seeding a same-named collision file outside
  the script's own control — that would be asserting against contrived
  test-harness setup, not against the SUT's behaviour, so it was rejected
  as a mutation.
- Conclusion: no mutation exists that the mktemp stub refuses and that
  reds this test. It stays as a smoke run proving the script still emits
  the standard slice-1 oversized-file line and exit code with the stub on
  `PATH`, per the cross-cutting Portability rule (NFR-2) — `grep` and
  `sed` are correctly excluded per the dispatch, since the script never
  calls them.

## Scope

No SUT changes ship with this report (`scripts/check-line-limits.sh` is
byte-identical to HEAD). `justfile`/`precommit` wiring, Items 2.2–2.4, and
GREEN are out of scope for this dispatch.
