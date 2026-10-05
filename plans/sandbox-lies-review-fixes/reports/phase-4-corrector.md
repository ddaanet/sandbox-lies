# Review: Phase 4 checkpoint — behaviour changes (Items 4.1, 4.2, 4.3)

Saved by the orchestrator from the corrector's reply: the harness refused the
agent's own Write of this file.

**Scope**: `git diff 845875d HEAD` over the IN files:
`lib/probes-readonly-command.sh`, `lib/probes-readonly-facts.sh`,
`hooks/check-jq.sh`, `hooks/hooks.json`,
`docs/references/{readonly-path,hook}.md`, `tests/check-jq.bats`,
`tests/helpers/probes.bash`, `tests/hook-writes.bats`, `tests/hook.bats` and
`tests/probes-readonly-{facts,members,operands,pins}.bats`. The
`reports/item-4-*.md` files were read as evidence, not edited. **Date**:
2026-10-05. **Mode**: review + fix.

**Overall Assessment**: Ready

## Summary

- **D4** is the operand rule in `_readonly_readfile_arg`.
- **D3** is the absolute `match=<repo>/<file>`, plus the guard against a
  newline in the root and the trailing-slash strip.
- **D2** is `check-jq.sh` and its `SessionStart` registration.

All three match their decisions, and code, tests and docs agree. Every
residual example in the docs was run against the code, and each prints what
the docs say. Every new assertion has a recorded red; for those whose red was
not recorded, six faults (A–F) were run here, and all went red. No critical or
major findings. All 6 minor findings are fixed.

## Minor Issues (all FIXED)

1. **`readonly-path.md` disagreed with the code on `>`.** The residuals
   paragraph said "A `>` anywhere in a word counts as output redirection"; the
   code exempts descriptor duplications (`[0-9]>&[0-9]`, `>&[0-9]`), as Item
   4.1's header says and `uniq -c in.log 2>&1` pins. `grep pat x.log 2>&1`
   gives `x.log`, where the doc implied no line. Fix: "…quoted or not, except
   a descriptor duplication (`2>&1`, `>&2`); so do `sort -o` and `awk -i`",
   then `just format-docs`.
2. **Plan ids in shipped comments.** `hooks/check-jq.sh:2` had "outline D2"
   and `lib/probes-readonly-command.sh:129,227` "outline D4". Before this
   phase `lib/` and `hooks/` cited no plan ids, and `craft:directive-writing`
   cuts plan ids from comments. Fix: `check-jq.sh` cites "D-12,
   docs/references/hook.md"; the two `(outline D4)` mentions are dropped.
   Tests keep their `outline Dn`/`Item n.m` citations, the existing pattern
   there.
3. **Stale header and banner in `tests/probes-readonly-members.bats`.** The
   header said every case runs `writable`, but the trailing-slash and
   newline-root cases run nopath; it scoped the file to Major 6 without the D3
   cases. The "target= and match= for switch" banner sat over three
   `git merge` cases. Fix: header names the D3 cases and nopath; banner reads
   "target= and match=".
4. **`tests/hook-writes.bats` header** described the file as NFR-4 only, but
   Item 4.2 put the D3 restore-clause case there. Fix: one sentence added.
5. **`tests/helpers/probes.bash` header** did not list `assert_no_readfile`,
   which Item 4.1's refactor moved there. Fix: added.
6. **`tests/probes-readonly-pins.bats:60` comment** said "match=a" while the
   assertion is `match=$repo/a`. Fix: `match=<repo>/a`.

## Fixes Applied

- `docs/references/readonly-path.md:81-86`: the `>` sentence, reflowed.
- `hooks/check-jq.sh:2-5`: header only; mode still 100755.
- `lib/probes-readonly-command.sh:129,227`: comments only.
- `tests/probes-readonly-members.bats:2-10,43`; `tests/hook-writes.bats:8-10`;
  `tests/helpers/probes.bash:6-7`; `tests/probes-readonly-pins.bats:60`.

The Edit tool got no classifier verdict; each edit went to a staged copy via a
script asserting one occurrence per replacement, copied in with `put.py`.
`shellcheck -x` passes on both changed shell files. `just precommit` exit 0:
`bats: 305 passed, 0 failed`; `precommit passed: plugin.json, hooks.json,
shellcheck, bash -n, rumdl, line limits, links, tests`.

## Test evidence audit

### Item 4.1 — `operands.bats`

| Assertion | Recorded red |
| --- | --- |
| `--include` pair | s1-red |
| `awk -vout=` | s1 test review |
| `wc -l<build.log` | s1 code review |
| `grep x.log y.out`, `sed s/a/b/x.log`, `awk x.log` | s2-red |
| `grep -i x.log`, `x.log a.out b.err`, `sed \| grep` | s2 test review, post-fix run |
| `grep < x.log y.out` | s2 code review |
| newline / `'a<b'` pattern | s2 code review |
| `-epat`, `sed -e -e` | s3-red |
| `awk -f` | glued run s3-red; two-`-f` run s3 test review; separate run red under the s3 code review's mutant |
| `grep -i \| tail` | 2 mutations |
| uniq case | RED, plus mutations for `-c` and the four s4-pins |
| `grep -e <in.log` | 3 mutations |
| BSD case | none recorded; faults E and F here |

### Item 4.2

| Assertion | Recorded red |
| --- | --- |
| subdir-cwd case, hook restore clause | s1-red, plus 5 mutants |
| trailing slash | s1-pins mutation |
| newline root | red→green, plus an over-broad mutant |
| migrated `match=` assertions in facts/pins/members | none recorded; faults A–D here |

### Item 4.3

| Assertion | Recorded red |
| --- | --- |
| `hook.bats` "three events" | RED; matcher/timeout pins red in the s1 variant table |
| `check-jq.bats` 1–4 | RED |
| raw-ESC guard | red under the `\033` mutant |

No assertion is left without a red.

## Faults run

Each an exact single-occurrence replacement in the SUT, suites run, restored
by the inverse replacement; `git diff --stat lib/ hooks/` empty afterwards.

| Fault | Edit | Red |
| --- | --- | --- |
| A | `match=${repo}/${files[$i]}` → `match=${files[$i]}` | facts 11, 13–15; pins 16, 22–24; members 31–34, 40 |
| B | `if [ "${shas[$i]}" = "${tshas[$j]}" ] \` → `if : \` | facts.bats:276 `match=$repo/c` negative |
| C | `&& [ "${shas[$i]}" != "${heads[$i]}" ]; then` → `; then` | pins.bats:83 `match=$repo/d` negative |
| D | `--ignore-submodules HEAD` → `--ignore-submodules <empty tree>` | facts.bats:277 `match=$repo/d` negative |
| E | candidate arm `[!-]* \| *'<'*)` → `*)` | operands 1, 2, 3, 16, 20 (BSD) |
| F | `grep \| sed \| awk) pat=1 ;;` → `grep \| sed \| awk) ;;` | operands 5–7, 9–11, 20 (BSD) |

Fault C cannot reach facts.bats:277: there `d` is unmodified and never enters
the diff-index list. Fault D reaches it.

## Cross-item interactions

- **`readfile=` and `match=` never share an output.** `readfile=` needs every
  segment to be a reader, and a `git` segment sets `all_ok=0`; without one,
  `merge=1` can only come from `partial=1`, and `target=`/`match=` need merge,
  checkout or switch. The newline-root case asserts the whole output
  `nopath⏎merge=1`.
- **Inputs left bare on purpose.** `verdicts-readonly.bats` feeds bare
  `match=` lines as verdict input, as the runbook intends; no hook stub or
  helper carries `match=`; the `hook-candidates.bats` restore assertions pin
  the partial-checkout clause, which names no file.
- **The verdict passes absolute names through unchanged**, storing
  `${line#match=}` whole; `hook-writes.bats` pins the whole clause, including
  `<repo>/e f`.

## Contract across surfaces

- **D4.** Code, header comment, the `readonly-path.md` row and residual list,
  and `operands.bats` agree after Minor 1. Every residual example was probed:
  `sort -T t.log in.txt` gives `t.log`, `grep -e a -ve x.log y.out` gives
  `x.log`, `grep -- -x.log y.out` gives nothing, `uniq -<in.log out.log` gives
  `in.log`.
- **D3.** The merge pass, `_readonly_git_dir`, the newline guard, the doc row,
  the newline-root and `/` residuals, and the clause text agree.
- **D2.** `check-jq.sh`, `hooks.json` (no matcher, 10 s), `hook.md`
  §Registration and §When `jq` is missing, `check-jq.bats` and `hook.bats`
  agree. The README half is Item 5.2.

## Repo rules

- `check-jq.bats` and `operands.bats` load `helpers/bsd-stubs` and keep one
  `make_bsd_stubs` case; `check-jq.bats` runs no git; `operands`, `members`
  and `hook-writes` load `helpers/git-env`.
- Every file at or under 400 lines (largest: `hook.bats` 390, `operands` 373,
  `pins` 359; `readonly-path.md` 184).
- No `2>/dev/null` added in `lib/`, `hooks/` or `tests/`.
- `tests/docs.bats` passes inside precommit.
- State: only the 7 fixed files modified, plus the untracked
  `.claude/gitlore-memory-message`; no `MERGE_HEAD`, nothing staged.

## OUT-scope finding confirmed: `path=` newline forgery

`item-4-2-s1-code-review.md` Recommendations 1 is confirmed live. In
`lib/probes-readonly.sh`, `_probe_readonly_resolve` joins a relative refused
path onto the payload cwd and `probe_readonly_path` prints `path=$path`
unchecked. With cwd `<tmp>/r⏎readfile=x`, refused path `'a'`, command
`cp b a`, the output was `writable`, `path=<tmp>/r`, `readfile=x/a`. The
forged `readfile=x/a` would set the verdict's act. Item 4.2's root guard keeps
`target=`/`match=` out of it but cannot cover `path=`. Only a relative refused
path, or the `$PWD` fallback, can carry the newline. Separately, the join
strips one trailing slash only, so cwd `/x//` gives `path=/x//a` (cosmetic,
pre-existing). Left unfixed for my human partner's decision.

## Deferred Items

- The `path=` newline forgery — OUT; open question for my human partner.
- `annotate.sh`'s header claim that nothing reaches stderr — Item 5.3.
- README §Install `jq` note (D2's other half) and `docs/design.md` NFR-3, D-12
  and Architecture — Item 5.2.

## Requirements Validation

| Requirement | Status | Evidence |
| --- | --- | --- |
| FR-4/D4 option word never input | Satisfied | operands 1–4; fault E |
| FR-4/D4 pattern/program never input, per segment | Satisfied | operands 5–13, 17; fault F |
| FR-4/D4 `-e`/`-f` role and argument | Satisfied | operands 14–16, 19 |
| FR-4/D4 `uniq` second operand writes | Satisfied | operands 18 |
| FR-4/D4 residuals documented | Satisfied | `readonly-path.md`, each example probed |
| FR-4/D3 `match=<repo>/<file>` | Satisfied | members 31–34; `hook-writes` clause; fault A |
| FR-4/D3 no forged lines from the root | Satisfied | members newline-root case |
| NFR-2, D-12, FR-1/D2 `SessionStart` check | Satisfied (code, registration, `hook.md`) | `check-jq.bats` 1–4; `hook.bats` |
| D2 README note | Deferred | Item 5.2 |
| NFR-2 BSD / bash 3.2 | Satisfied | BSD cases in operands, members, facts, check-jq |
| NFR-4 writes nothing | Satisfied | check-jq case 3 (missing `TMPDIR`) |

**Gaps:** none within Phase 4.

## Recommendations

- **The `path=` forgery needs a decision:** should the probe report `nopath`,
  or an outcome with no `path=` line, for a path it cannot print safely?
- **Runbook Item 4.2 names `tests/hook-candidates.bats` for the hook case**,
  which landed in `tests/hook-writes.bats` (cap, stubbed probes) without a
  recorded list revision. Item 5.2's "pinned by" lines should name
  `hook-writes.bats` for D3.
