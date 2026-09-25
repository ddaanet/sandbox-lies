# Item 4.3 slices 2-5 — GREEN: probe_readonly_path grown to the RED batch

2026-09-26. Mode GREEN. Batch: the RED/test-review's 8 cases in
`tests/probes-readonly.bats` plus the already-passing `hook silent without a
verdict` in `tests/hook-candidates.bats` (slice 5; unaffected by this
implementation, since no `verdict_readonly_path` exists — Item 6.1). No test
file edited. Scope OUT held: no readonly-path verdict, no flag policy, no
memory/docs/design changes.

## Design decision: matcher-line reuse

The Interfaces block asks to "reuse the matcher's line recognition from
`lib/matchers.sh` rather than duplicating its pattern, if the tests and
structure allow." `tests/probes-readonly.bats` sources only `lib/probes.sh`
(no `lib/matchers.sh`), so reuse requires `lib/probes.sh` to source
`lib/matchers.sh` itself rather than relying on `hooks/annotate.sh`'s own
sourcing order.

- `lib/matchers.sh`: extracted `_readonly_path_line` (the same regex,
  `grep -m1 -E` instead of `grep -qE`, so it also prints the first accepted
  line rather than only signalling a match); `match_readonly_path` now calls
  it. Behaviour unchanged — confirmed by the full suite's `matchers.bats`
  cases staying green throughout, so Item 3.2's corpus figure (162 hits,
  99%) does not need re-recording this slice: the matcher's accept/reject
  set is untouched, only the internal split.
- `lib/probes.sh`: sources `lib/matchers.sh` at load time via a
  `BASH_SOURCE`-relative path (the same dynamic-path pattern
  `hooks/annotate.sh` already uses, with the matching
  `# shellcheck disable=SC1091` comment), `return 1` if the `cd` or the
  source fails. `hooks/annotate.sh` already sources `matchers.sh` before
  `probes.sh`; this second source only matters where a caller (the
  `probes.bats` family) sources `lib/probes.sh` alone. Sourcing twice just
  redefines the same functions — no other probes suite regressed.

## Tests made to pass, one at a time

Implementation grown in five steps, each run individually with
`bats tests/probes-readonly.bats -f <name>` (or the full file, to see which
of the batch's other cases a step incidentally already satisfied) before the
next step:

| step | growth | test run | result |
|---|---|---|---|
| 1 | `_readonly_path_line` → `_probe_readonly_path_from_line` (first quoted segment) → `test -w` on the path as extracted (no resolve, no parent fallback, no nopath) | `writable path` | ok — also incidentally passed `existing file checks the file itself`, `first quoted path on the line`, `writable path survives BSD grep and sed` (full-file run) |
| 2 | added `_probe_readonly_resolve` (plain join onto `$2`/`$PWD`, no `.git` walk) and its call | `relative path resolves against cwd` | ok |
| 3 | added the existence check, parent (`${path%/*}`, `/` when empty) as the `test -w` target when the path is absent | `absent file checks its parent` | ok |
| 4 | added the empty-`path` branch: `nopath`, no `path=` line, before resolution | `no quoted path` | ok |
| 5 | (no further growth needed) | `quoted path off the matching line is ignored` | ok — the negative half exercises step 4's `nopath` branch, the positive half steps 1-2 |

Full-file confirmation after step 5: `direnv exec . bats
tests/probes-readonly.bats` → 1..8, all ok (`writable path`, `relative path
resolves against cwd`, `absent file checks its parent`, `existing file
checks the file itself`, `first quoted path on the line`, `quoted path off
the matching line is ignored`, `no quoted path`, `writable path survives BSD
grep and sed`).

`direnv exec . bats tests/probes-readonly.bats tests/hook-candidates.bats
tests/hook-locks.bats` → 1..26, all ok — `hook silent without a verdict`
(12) and `no probe without a verdict` (25) unaffected, as expected (no
`verdict_readonly_path` exists; the hook's `declare -F` gate still skips the
probe before it would run).

## Full suite, lint, precommit

- `direnv exec . just test` → `bats: 182 passed, 0 failed` (174 baseline +
  8 new).
- `direnv exec . shellcheck lib/probes.sh lib/matchers.sh` → exit 0, no
  findings (checked again after removing a duplicate
  `_probe_readonly_resolve` definition introduced mid-growth, which the
  post-edit shellcheck hook caught as unreachable code — see below).
- `direnv exec . just precommit` → `precommit passed: plugin.json,
  hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests`. No
  warnings from any check; nothing deferred to code review.

No `just lint` target exists in this repo (checked `justfile`); `just
precommit` is the gate the dispatch context and this repo's own standing
rules name.

## Self-correction during growth

Adding step 2's `_probe_readonly_resolve` left a duplicate definition of
that function still present from an earlier full-implementation draft
(written once, then deliberately unwound to grow it test-by-test); the
Bash-tool's own post-edit shellcheck hook flagged the first copy's body as
unreachable (SC2317). Removed the stale duplicate; shellcheck and the full
suite came back clean.

## Files touched

- `lib/matchers.sh` — `_readonly_path_line` extracted from
  `match_readonly_path`, which now calls it; pattern text unchanged.
- `lib/probes.sh` — dynamic self-source of `lib/matchers.sh`;
  `probe_readonly_path` grown from the slice-1 inert stub to the full A-3
  contract; new helpers `_probe_readonly_resolve` and
  `_probe_readonly_path_from_line`.
- No test file touched.

## Requirements coverage carried from the test review

FR-4 (probe contract), FR-7 (readonly-path candidate), NFR-1 (corpus
figure unmoved, matcher behaviour unchanged) — pinned by the batch's 8
cases plus the unaffected `hook-candidates.bats`/`hook-locks.bats` gate
cases, all green.

Commit carries: `tests/probes-readonly.bats`, `tests/helpers/hook.bash`,
`tests/helpers/probes.bash`, `tests/hook-candidates.bats`,
`tests/hook-locks.bats`, `lib/probes.sh`, `lib/matchers.sh`, and this
slice's three reports (`item-4-3-s2-red.md`, `item-4-3-s2-test-review.md`,
`item-4-3-s2-green.md`).
