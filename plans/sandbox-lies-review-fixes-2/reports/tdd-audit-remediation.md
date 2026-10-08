# TDD audit remediation: re-mutating the four single-proof BSD cases

**Scope**: `tdd-audit.md` §Recommendations Important 1, which points at
§Violations Major 2. Covers the BSD re-run case in each of
`tests/check-links.bats`, `tests/hook-malformed.bats`,
`tests/probes-config.bats` and `tests/probes-readonly-pins.bats`, plus
transient mutations of the production code each one reaches. **Date**:
2026-10-08 **Mode**: review + fix

**Count: 4 cases red as-is, 0 blind and fixed.**

## Summary

Every mutation in this report differs from the executor's one in
`phase-3.md` §Mutation proof. Each one sits in code that the case's own
fixture reaches. None sits in `detect`.

- Each case went red on its own assertion under a GNU-only call of the
  stubbed tool.
- Each case's non-BSD sibling stayed green under the same mutation, so the
  stub caused the red, not a broken path.
- Each restore was proven: `command grep` found no mutation text, and both
  cases were green again.

No test needed a fix. Two supplementary mutations survived. Neither survival
is the case's blindness, and neither can be fixed inside the four bats files.
Both are listed under §Observations for the orchestrator.

**Overall Assessment**: Ready

## Mutation proof

Each mutation was an exact replacement of a string that occurs once in its
file. The script asserted a count of 1, and the restore applied the same
replacement with the strings swapped. Every run was
`bats -f '<shared name>' tests/<file>.bats`, which runs the plain case and
its BSD re-run together.

| behaviour | mutation | red or survived-and-fixed |
|-----------|----------|---------------------------|
| check-links: BSD `grep` on the broken-link report path (primary) | `scripts/check-links.sh:101`: pipe the `printf 'broken-link: …'` through `grep -P '^broken-link: '` | red: BSD case at `[ "$status" -eq 1 ]` (`check-links.bats:28`); plain green |
| hook-malformed: BSD `grep` in the gitadd matcher (primary) | `lib/matchers.sh:134` `match_phantom_gitadd`: `grep -qE` to `grep -qP` | red: BSD case at `assert_no_failures` (line 61); both positives report stderr `grep: invalid option -- -qP`; plain green |
| hook-malformed: BSD `sed` in the untracked matcher | `lib/matchers.sh:118` `match_phantom_untracked`: `sed -E` to `sed --regexp-extended` | red: BSD case at line 61; both positives report stderr `sed: illegal option -- -`; plain green |
| probes-config: BSD `sed` in the config-lock path read (primary, case-unique) | `lib/probes.sh:236` `_probe_config_lock_path`: `sed -n` to `sed --sandbox -n` | red: BSD case at `[ -z "$stderr" ]` (`probes-config.bats:31`); plain green |
| probes-config: BSD `stat` in the mtime read | `lib/probes.sh:167`: first read `stat -f %m` to `stat -c %Y` | red: BSD case at `[ -z "$stderr" ]` (line 40, the orphan half); plain green |
| probes-config: BSD `wc` padding | `lib/probes.sh:186`: drop `\| tr -d '[:space:]'` from the `bytes=` read | red: BSD case at `grep -qxF "bytes=7"` (line 42); plain green |
| probes-readonly-pins: BSD `sed` in the path extractor (primary) | `lib/probes-readonly.sh:134` `_probe_readonly_path_from_line`: `sed -n` to `sed --sandbox -n` | red: BSD case at `[ -z "$stderr" ]` (`probes-readonly-pins.bats:66`); plain green |
| probes-readonly-pins: a long option after the first `-e` script (supplementary) | `lib/probes-readonly.sh:153`: `-e ":end"` to `--expression=":end"` | **survived** (both green). A stub gap, not the case's: see §Observations 1. Not fixable in the bats file |
| check-links: BSD `mktemp` template (supplementary) | `scripts/lib/tracked.sh:60`: template `${prog}.XXXXXX` to `${prog}.XXXXXX.list` | **survived** (both green). Real BSD accepts this in a serial run, as the stub does: see §Observations 2 |

After the last restore, `git diff --stat -- lib hooks scripts tests` printed
nothing.

## Per case: what fails it, and what else could produce the red

- **check-links.** The case fails when the broken-link branch, reached only
  by a link whose target is missing, calls a tool the BSD stub refuses. The
  script then ends 2 under `set -euo pipefail` instead of 1. Other possible
  sources of a non-1 status:
  - the stub refusing the extraction grep (`grep -aoE`);
  - `git ls-files` failing.

  The restore run kept the same stubs and the same fixture, with only the
  mutation removed, and it was green. That rules out both sources. The plain
  sibling stayed green under the mutation, so GNU `grep -P` accepts the call.
  The red was the stub's.
- **hook-malformed.** The seven negatives exit in `annotate.sh` before
  `detect`, so they never reach a stubbed tool. Only the two positives do.
  `detect` runs every matcher on every text, so a refusal in any matcher shows
  on both positives' stderr. The `check_fires` empty-stderr clause catches it.
  Another source of "positive did not fire" would be a jq or payload fault,
  which would also red the plain sibling. That sibling stayed green, and the
  failure lines quote each stub's own refusal text.
- **probes-config.** The sed mutation reaches only `probe_config_lock`'s
  extractor. It reds the first half at the stderr check. If the refusal were
  silent, the path would be empty and line 33's `path=$lock` check would red
  next, so the case does not rest on stderr alone. The stat and wc mutations
  hit `_probe_lock_at` and red the orphan half. A competing stderr source
  would be the holder tool's own message. The same holder check runs
  unchanged in the green restore run, which rules it out.
- **probes-readonly-pins.** A refused extractor sed reds the case at
  `[ -z "$stderr" ]`. Nothing else in the case would. A silently empty
  extraction would yield `nopath`, which still prints `merge=1` with exit 0.
  The case does not assert the outcome line. Every refusal the stub can
  produce writes stderr, so no state reachable through the stub slips past.
  An added `writable` assertion would have no failing state here, so the case
  was left as it is. Another source of stderr would be the facts code's own
  `git` calls. The restore run made the same calls under the same stubs and
  was green, so the stderr came from the mutation.

## Observations (outside this dispatch's scope)

1. **The `sed` stub stops scanning at the first non-option argument, and
   `-e`'s script is one.** A long option placed after the first
   `-e <script>` therefore reaches GNU sed and passes. BSD `getopt` steps over
   an option's argument and refuses the long option there. Confirmed against
   the stub directly: a late `--expression=:end` exits 0, and a leading one
   exits 1 with the illegal-option line. The remedy belongs in
   `tests/helpers/bsd-stubs.bash` (`_bsd_stub_sed`), which is OUT of scope
   here: the scan would skip the argument of `-e` and `-f`. No bats-side fix
   can red it, because the case's assertions see whatever GNU sed does. This
   is OUT-OF-SCOPE for this dispatch, for the orchestrator to schedule.
2. **The `mktemp` stub has no reachable failing state in check-links.** The
   walk list's one template ends in `X`. BSD would use a template with
   non-trailing X's as a literal name, and the stub reproduces that, but a
   serial run creates the literal file and its EXIT trap removes it. It fails
   only when a stale or concurrent file holds that literal name, so survival
   is the correct BSD-equivalent answer. A case-side fixture cannot
   anticipate the literal name, so it cannot red this. Two places could
   catch it:
   - a stub stricter than BSD, refusing any template not ending in `X`;
   - a lint over the scripts.

   Both are design calls outside these four files. OUT-OF-SCOPE.
3. `scripts/lib/tracked.sh:44-45` says a bare `mktemp` is a usage error on
   macOS. The stub execs the real tool for an empty template, and current
   macOS `mktemp` accepts no arguments. The comment may be stale. It sits in
   production code, which is OUT of scope.

## Fixes Applied

None to tests or production code. Every mutation was reversed, as proven
above. This report is the only file written.

## Verification

- `git diff --stat` lists only `plans/reports/triage-feedback-log.md` and
  `plans/sandbox-lies-review-fixes-2/delegate-status.md`. Both were dirty
  before this dispatch, in the baseline `git status`, and neither was touched.
  `git status --short -- lib hooks scripts tests` is empty.
- No bats file was edited, so there was no edited-file re-run. Both cases of
  each of the four pairs ran green as the baseline and again after each
  restore.
