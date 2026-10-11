# Deliverable review — code and tests, Phase 1 and Item 5.1

- **Range:** `2309ae6..HEAD` (`2015b0f`, `main`). Items 1.1, 1.2, the decoder
  gate fix (`af58339`) and 5.1.
- **Files:** `lib/probes.sh`, `lib/probes-readonly.sh` (encoder),
  `lib/verdicts.sh` (decoder and its two callers), `hooks/annotate.sh` (read
  against them), and the eleven test files of the dispatch.
- **Model:** Opus 5.5 (`claude-opus-5-5`).
- **Result:** the encoding is correct on bash 5.2.37 and 3.2.0 and conforms to
  the outline. 0 Critical, 3 Major (all test gaps; the code is right in each),
  8 Minor. 14 mutations: 11 killed, 3 survived (none equivalent).

## Findings

1. **`tests/verdicts-readonly-path.bats`, case "_verdict_path_read decodes
   \\" and reads an escape %q never writes as no path, silently"** — vacuity,
   **Major**. The `2>&1` follows the assignment `out=$(…)`. Bash does not
   apply it to the substitution, so stderr never reaches `out` and "silently"
   is unasserted. `review-code-decoder.md` records "stderr merged in" and "any
   stderr output" as a failing state. The code is silent today.
   Verified: mutation 11 (below) left the file at 13 passed; and
   `bash -c 'out=$(echo noise >&2; echo val) 2>&1; echo "out=[$out]"'` prints
   `out=[val]`.
2. **`lib/verdicts.sh`, `_verdict_path_read`, the `\\[abEefnrtv\\]` arm** —
   coverage, **Major**. The gate fix replaced one `%b` over the body by a list
   of letters. The cases reach `E`, `n` and `t` only: `\a \b \f \r \v`, which
   `%q` writes for bytes 007, 010, 014, 015 and 013, are decoded by code no
   case runs. All five sit in §A's display range (`\001`-`\037`); dropped from
   the list, a path holding one reads as no path instead of its wire form.
   Verified: mutation 12 survived five suites; with it,
   `_verdict_path_read "$'/x/a\vb'"` returns 1.
3. **`lib/probes-readonly.sh`, `probe_readonly_path`;
   `tests/probes-readonly-members.bats`** — coverage, **Major**. Outline §A
   gives a newline-bearing path "its real outcome (`writable` or `readonly`)";
   slice 3 and its case pin `writable` only, and no case anywhere runs such a
   path to `readonly`. HEAD is right there: a relative refused path under a
   read-only directory whose name holds a newline prints `readonly` and one
   `$'…'` line (run by hand).
   Verified: mutation 3 survived nine suites.
4. **`lib/verdicts.sh`, `verdict_config_lock`** — robustness and error
   signaling, Minor. `_verdict_path_read "$wire"` is called bare and returns 1
   for every `mask` with no decodable `path=` line, the pathless case
   included. A caller under `set -e` gets status 1 and no text; before the
   build it got the paragraph. The hook sets no errexit and calls the verdict
   left of `||`, so it is unaffected. The probes pin errexit callers; no
   verdict case does. `verdict_readonly_path` tests the status and is safe.
   Verified: `bash -c '. lib/verdicts.sh; printf "" | (set -e;
   verdict_config_lock mask false; echo survived); echo "rc=$?"'` prints only
   `rc=1`; the `2309ae6` file prints both lines, `survived`, `rc=0`.
5. **`lib/verdicts.sh`, `_verdict_has_control`** — robustness, Minor. On bash
   3.2.0 the `local LC_ALL=C` is not undone when the function returns: the
   calling shell stays in the C locale. In the hook that shell is the
   verdict's own subshell, so nothing downstream sees it; an in-shell caller
   would. `hooks/annotate.sh` saves and reassigns `LC_ALL` for the same need.
   Apple's 3.2.57 is unverified.
   Verified: `LC_ALL=C.UTF-8 /tmp/claude/bash32/bash -c '. lib/verdicts.sh;
   x=$(printf "\303\251"); printf "%s " "${#x}"; _verdict_has_control /x;
   echo "${#x}"'` prints `1 2`; bash 5.2 prints `1 1`.
6. **`lib/verdicts.sh`, `_verdict_path_read`, the `$'` loop** — robustness,
   Minor. The loop re-scans and re-copies the rest of the body per escape:
   quadratic in the number of escapes, where the outline's single `%b` was
   linear. A 3872-byte path of non-ASCII bytes takes 4.6 s on 5.2 and 4.2 s on
   3.2.0 (968 bytes: 0.33 s; 484: 0.11 s; backslash form, 3800 bytes: 0.008 s).
   The hook's timeout is 10 s, and a timeout loses the annotation with no
   signal, the failure outline §D closed for the tokenizer.
   Verified: scratch script timing `_verdict_path_read` over
   `_probe_path_line`'s output for 1 to 32 segments of 40 CJK characters,
   `LC_ALL=C.UTF-8`, each bash; every run decoded to the input.
7. **`lib/verdicts.sh`, `_verdict_path_read`, comment above `local re=`** —
   clarity, Minor. It explains the variables by "a quoted \\' in a
   substitution". `af58339` removed that substitution; `re` and `oct` are
   regexes for `=~`. The same arm accepts `\"` and `\e`, which `%q` never
   writes, and no comment says why (excess).
   Verified: `command grep -c 'body//' lib/verdicts.sh` prints 0.
8. **`lib/verdicts.sh`, `_verdict_path_read` and `verdict_readonly_path`** —
   robustness, Minor. Two well-formed values the encoder never prints are read
   as paths: `$''` decodes to empty with status 0 and the paragraph opens with
   an empty code span, not "The path"; `$'rel/.claude/settings.json'` is not
   absolute yet selects the `update-config` act. The producer is our own
   probe, so this is an edge, not an exposure.
   Verified: `printf 'path=%s\n' "\$''" | bash -c '. lib/verdicts.sh;
   verdict_readonly_path writable' | sed -n 1p` opens with two backticks.
9. **Stale text in suites the build did not touch** — conformance, Minor.
   `tests/hook-locks-pathless.bats`'s header still says a newline-bearing lock
   path leaves `path=` out. `tests/hook-locks.bats` (`LOCK_PATH_LINE`)
   describes a raw `path=` value with a blank and `&` as what the real probe
   prints. `tests/helpers/locale.bash` says "the three cases"; four use it
   since Item 5.1. Item 7.7 swept `lib/` only.
   Verified: `command grep -c 'leaves path= out'
   tests/hook-locks-pathless.bats` prints 1.
10. **`tests/verdicts-readonly-path.bats`, case "decodes the same with the BSD
    stubs first on PATH"** — excess, Minor. `lib/verdicts.sh` forks no tool,
    so no stub runs: the case's decode assertions are real (mutation 7 failed
    it) but its BSD leg cannot fail. CLAUDE.md asks for a stub case only where
    the code under test calls a stubbed tool, and the case does not say why.
    Verified: `command grep -nE '\b(sed|grep|stat|wc|mktemp)\b'
    lib/verdicts.sh` prints nothing.
11. **Slice 1.1/5 rewrites** — specificity, Minor. The 16 encoded literals in
    `probes-readonly.bats`, `probes-config.bats` and `probes.bats` ("non-UTF-8
    byte", "quote and space") interpolate `BATS_TEST_TMPDIR` with no
    precondition; a scratch root holding a blank fails them for a reason they
    do not name. The slice-1 cases and three other suites carry the check. In
    `probes-config.bats` the three `[ "$output" = mask ]` / `gone` rewrites
    leave first-line and count assertions after them that can no longer fail.
    Verified: `command grep -l 'printf %q "$BATS_TEST_TMPDIR"' tests/*.bats`
    lists `probes`, `probes-lock-newline`, `probes-readonly-members` and
    `probes-readonly-resolve` only.

## Mutations

Each was an Edit of a string occurring once, proved landed by `command grep`,
run one file at a time, restored by the swapped Edit, and proved restored
(no `# MUT`, `git diff --quiet -- <file>` 0, files green).

| # | Slice | Site | Change | Suites run | Result |
| --- | --- | --- | --- | --- | --- |
| 1 | 1.1/1 | `_probe_path_line` | empty path prints a bare `path=` | probes, probes-config | killed by "probe_config_lock with no config-lock line prints mask and no path=" |
| 2 | 1.1/2 | `_probe_lock_at`, vanish site | `path=` line dropped | probes-lock-newline, probes, probes-edges, probes-tools | killed by "git-lock vanishing mid-probe…" (and edges 1, 5; tools 4) |
| 3 | 1.1/3 | `probe_readonly_path` | no `path=` line when `readonly` and the path holds a newline | 7 `probes-readonly*`, hook-writes, hook-candidates | **SURVIVED** (finding 3) |
| 4 | 1.1/4 | `_probe_path_line` | `LC_ALL=C` to `LC_CTYPE=C` | probes, probes-lock-newline, probes-readonly, hook-writes | killed by "a lock path holding e-acute prints the octal form…" (and lock-newline 8) |
| 5 | 1.2/1 | `_verdict_path_read`, `/` arm | `read` replaced by unescaping blanks only | hook-writes, verdicts-readonly-path, verdicts | killed by "…shows each character %q escapes, byte-exact" (and 6, 11; verdicts 8, 9); hook-writes stayed green |
| 6 | 1.2/1 | `hooks/annotate.sh` | probe lines passed to the verdict through `%b` | hook-writes, hook-locks-pathless, hook-candidates, hook-locks | killed by "hook shows the wire form for a path holding a newline…" (and pathless 3) |
| 7 | 1.2/2 | `_verdict_has_control` | `[:cntrl:]` to `![:print:]` | verdicts-readonly-path, verdicts-locks, hook-writes | killed by "…shows a UTF-8 path byte-exact…" (and 3, 4, 5, 10, 11) |
| 8 | 1.2/3 | `verdict_config_lock` | suffix tested on the shown value | verdicts-locks, hook-locks, hook-locks-pathless | killed by "verdict_config_lock matches the settings.json.lock suffix on the decoded path" |
| 9 | 1.2/3 | `verdict_readonly_path` | suffix tested on the shown value | verdicts-readonly-path, verdicts-readonly | killed by "…matches the settings.json suffix on the decoded value" |
| 10 | 1.2/4 | `_verdict_path_read` | `/*)` arm widened to `*/*)` | verdicts-readonly-path, verdicts-locks, hook-writes, hook-candidates | killed by "…reads a malformed path value as no path" (and 10 more; blunt, it also took the `$'` values) |
| 11 | gate fix | `_verdict_path_read`, unknown-escape arm | prints a line to stderr before returning 1 | verdicts-readonly-path, verdicts-locks | **SURVIVED** (finding 1) |
| 12 | gate fix | `_verdict_path_read`, letter list | `a b f r v` dropped | verdicts-readonly-path, verdicts-locks, verdicts, verdicts-readonly, hook-writes | **SURVIVED** (finding 2) |
| 13 | 5.1 | `_probe_lock_path` | `LC_ALL=C` dropped from the `sed` | probes | killed by "non-UTF-8 byte in the path" |
| 14 | 5.1 | `_probe_lock_at` | age 120 s too high | probes, probes-lock-newline | killed by "BSD stat" (and lock-newline 2, 3) |

The three survivors are not equivalent: each changes what the hook prints for
an input the encoder can produce (rows 3 and 12) or what the hook writes to
stderr (row 11).

## Conformance

"Red" is against the pre-build `lib/` and `hooks/` under HEAD's tests, run in
a scratch tree; each red was a failed assertion.

| Slice | Status | Carried by |
| --- | --- | --- |
| 1.1/1 | conforms; red | `probes.bats`: blank case (opens with the tmpdir check, exact `r\ b` line) and the no-`path=` case |
| 1.1/2 | conforms; 8 of 8 red | `probes-lock-newline.bats`: five sites plus the vanish site, literal `good_wire`/`bad_wire`, header rewritten |
| 1.1/3 | conforms; red | `probes-readonly-members.bats`, renamed case, whole output |
| 1.1/4 | conforms; red | `probes.bats` e-acute case; `helpers/locale.bash` loaded by exactly the three suites its header names |
| 1.1/5 | conforms; none weakened | 15 cases, 19 assertions: each still a whole-line fixed match, three now whole-output equalities |
| 1.2/1 | conforms | `hook-writes.bats`: red against Item 1.1's state, green against the full pre-build tree (the outline's phase note) |
| 1.2/2 | conforms; deviation stated | in `verdicts-readonly-path.bats`, not `verdicts-readonly.bats` (its header: the line cap); byte-exact, two lines |
| 1.2/3 | conforms; red | `verdicts-readonly-path.bats` and `verdicts-locks.bats` |
| 1.2/4 | conforms; red | sentinel absent before and after; wire built by `%q` since it holds the tmpdir; `$'a'b` gives "The path" |
| Gate fix | deviates from §A's single `%b`, reason in the code comment | digit-after-escape case; findings 1, 2, 6, 7 |
| 5.1 | conforms | `utf8_locale` and `index_mtime` at both sites; report carries the Mac sentence |

## Checked and clean

- One print site of `path=` (`_probe_path_line`); all seven callers pass the
  resolved path; no bare or raw value can print. Two readers, both decode
  before use; the hook reads no `path=` itself.
- Encode then decode is the identity, and the display rule holds, for 1846
  paths (each byte 1 to 255 in seven positions, plus 61 hostile shapes) on
  bash 5.2.37 and 3.2.0 under `C` and `C.UTF-8`: 0 failures.
- 41 forged or malformed values on both versions: none run (sentinel absent),
  none write to stderr, every status 1 leaves both outputs empty.
- The real hook on eight hostile `cwd` names, both versions: one-line
  context, identical output, a forged `path=` line in the `cwd` selects no
  `update-config` act.
- The encoder's `LC_ALL=C` prefix leaves the caller's locale intact on both
  versions.
- No new `2>/dev/null`; no whitespace splitting in the new code;
  `verdicts-readonly-path.bats` loads `helpers/bsd-stubs`.
- Not checked: Apple's bash 3.2.57 and BSD userland, beyond the stubs.

## Tree

`git status --short`, with the sandbox-mask dotfile lines filtered out:

```
M  .claude/handoff-task.md
M  .claude/handoff-todo.md
?? inbox/
?? plans/sandbox-lies-review-fixes-3/reports/deliverable-review-code-tests-phase1.md
?? plans/sandbox-lies-review-fixes-3/reports/deliverable-review-prose.md
?? plans/sandbox-lies-review-fixes-3/reports/deliverable-review.md
```

Only the `…-code-tests-phase1.md` line is this review's; `deliverable-review.md`
appeared while the review ran and was written by another session.

`git diff --stat`: empty (`git diff --quiet` exits 0).
`command grep -rn '# MUT' lib tests scripts hooks`: no match (exit 1).
