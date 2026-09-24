# Item 2.3 slice 10 — test review

Test under review: `hook under BSD stubs`, `tests/hook.bats`. Verdict: the
RED phase's mutation holds up, but the test had two defects (one false premise,
one guard too weak to prove anything). Both are fixed in `tests/hook.bats`.
Nothing is committed, and `hooks/` and `lib/` are byte-identical to HEAD.

## Findings

1. **Major: the "sed is never called" premise is false.** The comment said
   "The hook calls no `sed` … so only `grep` is stubbed", and the RED report
   says the same. `hooks/annotate.sh` has no `sed` call of its own, but on every
   call `detect` runs `match_phantom_untracked`, which pipes
   `grep -Eo | sed -E | sort -u | grep -c`. `lib/matchers.sh:112` is where that
   `sed` runs. **Proof:** changing `sed -E` to `sed --regexp-extended` in
   `match_phantom_untracked` (a GNU-only long option that the BSD sed stub
   refuses) left the test **green**, 13/13. The runbook's slice 10 line repeats
   the same premise ("the hook calls no `sed` since slice 1's code review"). I
   left the runbook alone because it is outside my scope.
2. **Major: the non-empty guard does not prove the verdict fired.** `run_hook`
   merges stderr into `$output`. That means a hook that dies the same way in
   both runs gives an `expected` that is non-empty and identical in both, and
   the equality passes. **Proof:** changing `"$text"` to `"$txet"` in
   `annotate.sh`'s `detect` line makes the hook print
   `txet: unbound variable` to stderr and exit before any verdict. Every other
   hook case went red and this test stayed **green**. The neighbouring case
   `hook needs no temp dir` protects itself with `jq -e .` on `expected`. This
   test dropped that check.
3. **Minor: the comment claimed more than it proved.** It says
   "`sed -i` from `-qE` to `-qP`", but the RED report says the mutation was
   applied with `Edit`. It also gives a hard count ("the other 12"), which goes
   stale as soon as a case is added. It did not mention that `$output`
   contains stderr, and it did not name the absolute-path residual.

## Wrong-reason checks that came back clean

- **Does bats itself use the stubbed grep?** No. I ran a probe with a `grep`
  stub that rejects every call (exit 2 plus a stderr marker) and put it on
  `PATH` for `run_hook`. `run` completed with status 0 and the test body ran to
  the end. The only `STUB-REFUSED` lines in `$output` came from the hook's six
  matcher greps. So when this test goes red, the cause is the SUT's grep and
  not bats' own helpers.
- **Does the stubbed PATH reach the hook process?** Yes. A logging `grep` stub
  recorded 6 invocations, all with the matcher arguments from
  `lib/matchers.sh`. `PATH=… run_hook` is a prefix assignment on a function
  call, and it is inherited by the `bash -c` and `bash annotate.sh` children.
- **Exact bytes?** Mostly. The comparison covers stdout plus stderr. bats'
  `run` strips trailing newlines from both sides equally, which leaves one
  residual: a stubbed run that lost only its final newline would still pass.
  That newline comes from the `printf` builtin, which no stub touches.
- **Is `expected` computed in the same run?** Yes. It is now pinned to the
  gitadd verdict as a single JSON document, not just checked for being
  non-empty (fix 2).
- **Does a hook that bypasses PATH pass?** Yes, and this is a residual.
  Changing `grep -qE` to `/usr/bin/grep -qP` in `match_phantom_gitadd` leaves
  the test green. The same residual applies to the stub-based sweep in
  `tests/matchers.bats`. Closing it would take a lint rejecting absolute tool
  paths in `hooks/` and `lib/`, which is outside this slice. The comment now
  names the residual.

## Fixes (tests/hook.bats only, 380 → 378 lines)

- `make_bsd_stubs "$bsd" grep` → `make_bsd_stubs "$bsd" grep sed`.
- `[ -n "$expected" ]` → `printf '%s' "$expected" | jq -e '.systemMessage ==
  "git add — refused a sandbox mask"' >/dev/null`. `jq -e` exits 5 on a
  parse error, whether the non-JSON text comes before or after the JSON, so
  this also pins an empty stderr in the unstubbed run. I checked that directly.
- The comment is rewritten. It now covers what is stubbed and why, the
  same-run pinned `expected`, the merged stderr, both proving mutations, and
  the absolute-path residual.

## Mutation reproductions (against the fixed test)

Each mutation was applied as an exact literal replacement and confirmed unique
(count 1) beforehand. After each run I restored it by the inverse replacement,
confirmed the mutation text count was 0, and confirmed
`git diff --quiet hooks lib` passed.

| # | Mutation | `hook.bats` result |
|---|---|---|
| M1 | `grep -qE` → `-qP`, `match_phantom_gitadd` (the RED report's) | 12/1: only this test, `[ "$output" = "$expected" ]` |
| M2 | `: can only add` → `: \bcan only add`, same line (mine) | 12/1: only this test, same assertion |
| M3 | `sed -E` → `sed --regexp-extended`, `match_phantom_untracked` | 12/1: only this test, same assertion (was 13/0 before the fix) |
| M4 | `"$text"` → `"$txet"` in `annotate.sh`'s detect line | 2/11: this test now reds on the `jq -e` guard (was green before the fix) |
| M5 | `grep -qE` → `/usr/bin/grep -qP`, `match_phantom_gitadd` | 13/0: residual, as documented |

Before the fix, M2 was also run across the whole suite: 93/2. The only
failures were this test and `tests/matchers.bats`'s `the whole fixture sweep
survives BSD grep, sed and mktemp`, which is the stub test at the matcher
layer. Every test that runs without stubs stayed green under GNU grep.

## Out-of-scope observations (not touched)

- `tests/helpers/bsd-stubs.bash`: the grep stub prints its refusal with `echo`
  under `/bin/sh`. On dash that turns the `\b` it is reporting into a
  backspace, so the message shows the pattern *without* the word boundary it
  rejected (seen in the M2 full-suite run). `printf '%s\n'` would fix it.
- `lib/matchers.sh:114`: when `grep -c` fails (seen with the refuse-all probe
  stub), `count` is empty and `[ "$count" -ge 2 ]` prints `integer expression
  expected` to stderr. No real grep fails that way on valid arguments, but it
  is stderr output that no guard catches.
- The false `sed` premise in runbook Item 2.3 slice 10 and in the RED report
  is for the orchestrator to correct.

## Final run

- `scripts/run-bats.sh tests/hook.bats`: 13 passed, 0 failed.
- `scripts/run-bats.sh tests/docs.bats`: 1 passed, 0 failed.
- `scripts/run-bats.sh tests/` (full suite): 95 passed, 0 failed.
- `shellcheck tests/hook.bats`: clean.
- `git diff --quiet hooks lib`: passes (byte-identical to HEAD).
- `git status --porcelain --untracked-files=no`: `M tests/hook.bats` only.
  The scratch probe file `tests/zz-probe-s10.bats` was created for the probes
  above and then removed. Nothing is committed.
