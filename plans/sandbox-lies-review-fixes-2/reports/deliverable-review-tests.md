# Deliverable review — Layer 1, TESTS partition (review-fixes-2)

## Scope and method

- **Range:** `52e6dd82b831a1cc2b7b516d4c248df6fb1ebc8c..HEAD`, the whole
  range. Every `tests/*.bats` and `tests/helpers/*.bash` file was in scope for
  the static axes. Mutation testing covered the tests this job added or changed,
  `git diff --name-only 1718c03..HEAD -- tests/`.
- **Baselines:** `plans/sandbox-lies-review-fixes-2/outline.md` (Items 1.1,
  2.1 and 3.1-3.5, Q1-Q6); `plans/sandbox-lies-review-fixes/reports/deliverable-review.md`
  (Major 1, m-14..m-18); `docs/design.md` FR-3..FR-6, NFR-2 and NFR-4; and the
  prior Layer 1 tests report, whose findings I re-verified rather than skipped.
- **Mutation procedure:** I used a scratch script that replaces one exact
  string and refuses unless the string occurs exactly once. Each mutation was
  confirmed with `command grep -cF` (count 1). Then I ran only the named bats
  file or `-f` case, in the foreground, one process at a time. The restore was
  the same replacement with the strings swapped, confirmed with a count of 0,
  and `git diff --stat -- lib hooks scripts tests justfile` printed nothing
  after every restore. bats ran unsandboxed, with `TMPDIR` pointed at my own
  scratch directory.
- **Inputs, not proof:** I re-ran a sample of the claimed red mutations from
  the build's reports (`review-code-tests.md` A4 and A8, and `phase-3-review.md`'s
  `wc` padding and docs `-qP` mutations). For Major 1 I used the outline's
  literal "drop `/?`" instead of the variants Phase 3 used. I also targeted
  behaviours none of them mutated: id scoping, the regular-file test, the
  HOME fallback, `CLAUDE_CONFIG_DIR` isolation, last-id-decides, glob depth,
  never-open, and each readfile metacharacter separately.

## Mutation table

| # | Behaviour | file:line | Mutation | Test file(s) run | Result |
| --- | --- | --- | --- | --- | --- |
| 1 | regular-file test | `lib/probes.sh:64` | `[ -f "$f" ]` → `[ -e "$f" ]` | probes-resume | red: "a directory named <id>.jsonl" |
| 2 | id-specific glob | `lib/probes.sh:63` | `"$id".jsonl` → `*.jsonl` | probes-resume | red: 8 cases incl. "unrelated id does not count" |
| 3 | ids only from refusal lines | `lib/probes.sh:55` | sed `^No conversation found with session ID: (…)` → `^.*[=: ](…)` | probes-resume | red: "an id outside a refusal line is not taken" |
| 4 | HOME fallback names `.claude` | `lib/probes.sh:52` | `${HOME:+$HOME/.claude}` → `${HOME:+$HOME}` | probes-resume | red: "unset falls back to HOME/.claude" |
| 5 | config dir set: HOME not read | `lib/probes.sh:63` | glob list + `"${HOME-}"/.claude/projects/*/"$id".jsonl` | probes-resume | red: "CLAUDE_CONFIG_DIR set, HOME/.claude is not read" |
| 6 | every id required (not last-decides) | `lib/probes.sh:66` | `[ -n "$hit" ] \|\| verdict=lost` → `if …; then verdict=found; else verdict=lost; fi` | probes-resume, hook-resume | red: "first id without a transcript" (probe); both "only the second id" cases (hook) |
| 7 | glob depth (archived/ not counted) | `lib/probes.sh:63` | glob list + `"$root"/projects/*/*/"$id".jsonl` | probes-resume | red: "a transcript under archived/" |
| 8 | transcript never opened | `lib/probes.sh:64` | `{ hit=1; break; }` → `{ cat "$f" >/dev/null; hit=1; break; }` | probes-resume, hook-resume | **survived** (17/17, 10/10): see m-1 |
| 9 | BSD sed (sample of A8) | `lib/probes.sh:54` | `sed -nE` → `sed --regexp-extended -n` | probes-resume, hook-resume (`-f`) | red: both BSD cases only; their plain twins green |
| 10 | empty `CLAUDE_CONFIG_DIR` is not unset (sample of A4) | `lib/probes.sh:49` | `${CLAUDE_CONFIG_DIR+set}` = set → `-n "${CLAUDE_CONFIG_DIR-}"` | probes-resume | red: "set but empty is unknown" |
| 11 | no flag gate (Q1), flag true | `hooks/annotate.sh:100` | add `\| resume-lost:true` to the skip case | hook-resume | red: all 4 flag-true cases |
| 12 | no flag gate, flag absent | `hooks/annotate.sh:100` | add `\| resume-lost:false` | hook-resume | red: all 5 flag-absent cases that expect a verdict |
| 13 | `unknown` has no text | `lib/verdicts.sh:254` | `lost)` → `lost \| unknown)` | hook-resume, verdicts | red in hook-resume ("no config root to search, silent"); verdicts.bats green: see m-3 |
| 14 | other outcome prints nothing | `lib/verdicts.sh:254` | `lost)` → `lost \| -)` | verdicts | red: "prints nothing for an outcome it has no text for" |
| 15 | `found` verdict text | `lib/verdicts.sh:259` | `found)` → `Found)` | verdicts, hook-resume | red: verdicts (2 cases), hook-resume (both found cases) |
| 16 | readfile skip: `$` | `lib/probes-readonly-command.sh:238` | `*[*?[\$]*)` → `*[*?[]*)` | probes-readonly-globs | red: 3 `$` cases |
| 17 | readfile skip: `*` | same | → `*[?[\$]*)` | probes-readonly-globs | red: 5 cases incl. BSD |
| 18 | readfile skip: `?` | same | → `*[*[\$]*)` | probes-readonly-globs | red: "cat run?.log" |
| 19 | readfile skip: `[` | same | → `*[*?\$]*)` | probes-readonly-globs | red: "cat run[12].log" |
| 20 | skip tests the name after `<` only | `lib/probes-readonly-command.sh:237` | `case "${word##*<}" in` → `case "$word" in` | probes-readonly-globs | red: "a glob or $ ahead of a glued <" |
| 21 | skip continues the scan | `lib/probes-readonly-command.sh:238` | `) ;;` → `) break ;;` | probes-readonly-globs | red: both "does not hide a later literal" cases and the BSD case |
| 22 | Major 1: `/?` in the grep | `lib/matchers.sh:117` | drop `/?` | matchers-edges | red: "counts a slash-suffixed name" only |
| 23 | Major 1: `/?` in the strip | `lib/matchers.sh:118` | `s\|/?[[:space:]]*$\|\|` → `s\|[[:space:]]*$\|\|` | matchers-edges | red: "counts one name once" only |
| 24 | m-16: no `mktemp` call | `hooks/check-jq.sh:9` | add `: "$(mktemp -u 2>/dev/null \|\| mktemp -u /tmp/claude/…)"` | check-jq | red: case 3 at `[ ! -e "$spy_log" ]` only |
| 25 | BSD case: check-links | `scripts/check-links.sh:69` | `grep -aoE` → `grep -aoP` | check-links | red: the BSD case only (status 2, not 1) |
| 26 | BSD case: docs | `lib/matchers.sh:84` | config-lock `grep -qE` → `grep -qP` | docs (`-f`) | red at `[ ! -s "$err" ]` |
| 27 | BSD cases: hook-malformed, hook-cap | `lib/matchers.sh:134` | gitadd `grep -qE` → `grep -qP` | hook-malformed, hook-cap | red: each file's BSD case only; hook-cap reds at `cap_run`'s matcher guard (`hook-cap.bats:76`) |
| 28 | BSD case: probes-config (sed) | `lib/probes.sh:236` | `sed -n` → `sed --quiet` | probes-config | red: BSD case only, at `[ -z "$stderr" ]` |
| 29 | BSD case: probes-edges/config (stat) | `lib/probes.sh:167` | `stat -f %m` → `stat -c %Y` | probes-edges, probes-config | red: both BSD cases only |
| 30 | BSD `wc` padding (sample of Phase 3) | `lib/probes.sh:186` | drop `\| tr -d '[:space:]'` | probes-edges, probes-config | red: both BSD cases only, at `bytes=7` |
| 31 | BSD case: probes-readonly-pins and the globs BSD case | `lib/probes-readonly.sh:134` | `sed -n \` → `sed --quiet \` | probes-readonly-pins, probes-readonly-globs (`-f`) | red: pins BSD case only; globs BSD case |

31 mutations: 30 red and 1 survivor (#8). Each BSD-stub case added by Item 3.5
went red under a GNU-only form of a tool it stubs, and in every file its plain
twin stayed green. None of the BSD cases is blind.

## Findings

### Critical

None.

### Major

None. Every specified scenario I mutated went red, except one that the design
explicitly leaves ungated (m-1).

### Minor

**m-1. "Never opens the transcript" is unpinned.**

- **Where:** `lib/probes.sh:64`, `tests/probes-resume.bats`.
- **Axis:** coverage.
- **What is wrong:** outline D-a and the probe's own header (`lib/probes.sh:34`,
  "The transcript is never opened") state that the transcript is only tested
  for existence. Mutation #8 made the probe `cat` every hit and survived all 17
  probe cases and all 10 hook cases. Every fixture transcript is readable, so
  reading it is invisible.
- **Mitigation:** `docs/design.md` NFR-4 ends "Done (read scope: review, not
  gated)", so the design records the read scope as unpinned. This is why the
  finding is Minor and not Major.
- **Fix (optional):** one case with a `chmod 000` transcript for each id,
  asserting `found` and empty stderr. Under #8, `cat` writes a permission error
  to stderr and the case goes red. A run as root would not see the permission
  error.

**m-2. FR-5's "pinned by" list omits the file that now pins resume-lost's
flag behaviour.**

- **Where:** `docs/design.md:101-103`; compare `tests/hook-candidates.bats:3-4`.
- **Axis:** conformance (traceability). This finding is cross-partition.
- **What is wrong:** FR-5 says `tests/hook.bats`, `tests/hook-locks.bats` and
  `tests/hook-candidates.bats` "pair each fixture with both flag values". The
  old resume-lost flag-policy case moved out of `hook-candidates.bats` (its
  header now says so). The pairing it carried is now in
  `tests/hook-resume.bats`, which FR-5 does not name.
- **The pairing itself holds:**
  - `hook-resume.bats` covers {no transcript, both, first only, second only}
    × {flag absent, flag true}.
  - Mutations #11 and #12 turn every case of the gated half red.
  - Flag `false` is exercised only as "absent". The hook's parse maps both to
    `false` (`hooks/annotate.sh:43-52`), so this is conforming.

**m-3. The verdict unit case pins "no text" with `-`, not the `unknown` the
probe actually emits.**

- **Where:** `tests/verdicts.bats:112-118`.
- **Axis:** specificity.
- **What is wrong:** mutation #13 (`lost | unknown)`) gave `unknown` the lost
  text and survived `verdicts.bats`. It was caught only end to end, by
  `hook-resume.bats` "no config root to search, silent". The `-` case follows
  the outline literally, and `-` is a token the probe never prints.
- **Fix (optional):** call the case with `unknown` as well.

## Checked and conforming

- **Item 1.1 slices 1-7:**
  - Every slice has a case.
  - Isolation holds: `probes-resume.bats` setup exports both
    `CLAUDE_CONFIG_DIR` and `HOME` under `$BATS_TEST_TMPDIR`. In
    `hook-resume.bats`, every case that reaches the glob calls `resume_cfg`
    first, and the no-root case runs under `env -u HOME -u CLAUDE_CONFIG_DIR`.
  - No other suite runs the real `probe_resume_lost`: `matchers.bats` runs
    `detect` only, and no `hook-*.bats` file besides `hook-resume.bats` feeds
    the resume fixture. No case reads the host's `~/.claude`.
- **The probe behaviours the brief listed:** id extraction (#3), config-dir
  resolution set/empty/unset with the HOME fallback (#4, #5, #10), the
  regular-file test (#1), the every-id requirement (#2, #6), glob depth (#7),
  the `unknown` outcome (#10, #13; A1/A3/A5 per the build report), BSD sed
  (#9) and failglob (A6, claimed by the build report and not re-run here). All
  are mutation-proven except never-open (m-1).
- **Item 2.1 (m-11):** each of the four metacharacters, the `<`-suffix scope
  and scan continuation are mutation-proven (#16-#21). Every negative is
  paired in-case with its positive (`assert_no_readfile` also requires
  `writable`), so an empty output cannot pass.
- **Item 3.1 (Major 1):** each `/?` drop reds exactly one of the two new cases
  (#22, #23).
- **Item 3.2 (m-14):** `assert_no_git_above "$BATS_TEST_TMPDIR"` is the first
  statement of the real-probe case (`hook-candidates.bats:159`), before either
  `run_hook`. The other probe-gated cases in that file stub the probe.
- **Item 3.3 (m-16):** the spy reds on a silent `mktemp` with a fallback (#24).
  The residual is the one the build report already noted: a builtin
  redirection write is invisible to the spy.
- **Item 3.4 (m-15, m-17):**
  - Every "shared by" list matches a whole-tree grep of its helper's callers:
    `make_scratch_repo` (5 files), `hold_lock`/`kill_holder` (3),
    `run_probe_bounded` (3), `stub_probe` (3) and `stub_probe_kv` (3). The
    `probes.bash` header (the `probes*` family plus `hook-candidates`,
    `hook-locks-pathless` and `hook-writes`) matches the set of files that
    load it.
  - `probes-resume.bats` uses only `run_probe`, which has no list, and the
    header glob covers it.
  - The `tests/shim.bats` reference is gone, and the 3 s bound is stated as
    load-sensitive (`probes.bash:210-211`).
- **Item 3.5 (m-18, Q5):**
  - The seven suites with new BSD cases were each red under a GNU-only form of
    a stubbed tool (#25-#31).
  - `hook-verdicts` has no BSD case, and I confirm the skip.
    - Every variant replaces `detect` via `stub_lib`.
    - `verdict_phantom_gitadd` only `printf`s.
    - `annotate.sh` itself calls only `jq`.
    - The only stubbed-tool call in that file is the test's own
      `sed -n '1p'` scaffolding.
    - No `docs/` text claims eight suites; the deviation is recorded in
      `delegate-status.md`.
- **Repo rules:**
  - All bats files load `helpers/bsd-stubs`.
  - Every `fire-*`/`quiet-*` fixture name occurs in `tests/extract-fixtures.py`
    `SPEC`. This range adds no fixtures since `1718c03`.
  - `just precommit` (including `docs.bats`) passed in this session per the
    dispatch.
- **Prior Layer 1 findings (first review), re-verified:**
  - M-1 is fixed (#22, #23).
  - m-1 is fixed (guard).
  - m-2 is fixed (#24).
  - m-3 is fixed (no `shim.bats` reference left in `tests/`).
  - m-4 is fixed (lists).
  - m-5 is addressed by the narrowed rule plus the seven new cases.
- **Observations, not findings:**
  - `check-links.bats`'s BSD case also stubs `mktemp`, which
    `scripts/check-links.sh` never calls.
  - `check-jq.bats`'s BSD case is inert today, because `hooks/check-jq.sh`
    calls no stubbed tool.
  - Both of these act as forward guards and cost nothing.
  - The hook-cap BSD case reds on a matcher GNU-ism at its own matcher guard
    (`hook-cap.bats:76`) rather than inside the hook. Phase 3's mutation showed
    the hook process does carry the stubs.

## Closing `git diff --stat`

```
 memory | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)
```

The `memory` line is the pre-existing submodule state. The pre-staged
`.claude/handoff-*` files appear only in `--cached`. No change of mine remains
in `lib`, `hooks`, `scripts`, `tests` or `justfile`. This report is untracked.
